#!/bin/bash
set -e

# Bootstrap script for Terraform state storage
# This script sets up the initial state storage before main infrastructure deployment

echo "==================================="
echo "Terraform State Storage Bootstrap"
echo "==================================="

cd terraform

# Check if backend-config.tf already exists
if [ -f "backend-config.tf" ]; then
    echo "Backend configuration already exists. Skipping bootstrap."
    exit 0
fi

# Check if state storage resources already exist in Azure
PROJECT_NAME="${PROJECT_NAME:-multi-app-server}"
RESOURCE_GROUP="${PROJECT_NAME}-tfstate-rg"

echo "Checking if state storage already exists..."
if az group show --name "$RESOURCE_GROUP" &>/dev/null; then
    echo "State storage resource group already exists."
    
    # Get storage account name
    STORAGE_ACCOUNT=$(az storage account list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)
    
    if [ -n "$STORAGE_ACCOUNT" ]; then
        echo "Found existing storage account: $STORAGE_ACCOUNT"
        
        # Create backend configuration with existing resources
        cat > backend-config.tf << EOF
# Auto-generated backend configuration
terraform {
  backend "azurerm" {
    resource_group_name  = "$RESOURCE_GROUP"
    storage_account_name = "$STORAGE_ACCOUNT"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}
EOF
        
        echo "Backend configuration created with existing resources!"
        exit 0
    fi
fi

echo "Setting up Terraform state storage..."

# Clean any existing temp files and state
echo "Cleaning up any existing temporary files..."
rm -f *-temp.tf main-bootstrap.tf backend-config.tf .terraform.lock.hcl
rm -rf .terraform/

# Create a separate bootstrap directory
mkdir -p bootstrap
cd bootstrap

# Create minimal terraform configuration for state storage only
cat > main.tf << 'EOF'
terraform {
  required_version = ">= 1.10"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.13"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

variable "project_name" {
  type    = string
  default = "multi-app-server"
}

variable "environment" {
  type    = string
  default = "production"
}

variable "location" {
  type    = string
  default = "East US"
}

resource "random_string" "state_storage_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "azurerm_resource_group" "tfstate" {
  name     = "${var.project_name}-tfstate-rg"
  location = var.location

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "Terraform State Storage"
  }
}

resource "azurerm_storage_account" "tfstate" {
  name                     = "tfstate${random_string.state_storage_suffix.result}"
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = azurerm_resource_group.tfstate.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "Terraform State Storage"
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"
}

output "tfstate_resource_group" {
  value = azurerm_resource_group.tfstate.name
}

output "tfstate_storage_account" {
  value = azurerm_storage_account.tfstate.name
}

output "tfstate_container" {
  value = azurerm_storage_container.tfstate.name
}
EOF

# Initialize terraform
terraform init

# Import existing resources if they exist
PROJECT_NAME="${PROJECT_NAME:-multi-app-server}"
RESOURCE_GROUP="${PROJECT_NAME}-tfstate-rg"

# Check if resource group exists and import it
if az group show --name "$RESOURCE_GROUP" &>/dev/null; then
    echo "Importing existing resource group..."
    terraform import azurerm_resource_group.tfstate "/subscriptions/${ARM_SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}" || true
    
    # Get storage account and import it
    STORAGE_ACCOUNT=$(az storage account list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)
    if [ -n "$STORAGE_ACCOUNT" ]; then
        echo "Importing existing storage account: $STORAGE_ACCOUNT"
        
        # Extract the suffix from the storage account name (everything after 'tfstate')
        SUFFIX=${STORAGE_ACCOUNT#tfstate}
        echo "Storage account suffix: $SUFFIX"
        
        # Import the random string with the existing suffix
        terraform import random_string.state_storage_suffix "$SUFFIX" || true
        
        # Import the storage account
        terraform import azurerm_storage_account.tfstate "/subscriptions/${ARM_SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Storage/storageAccounts/${STORAGE_ACCOUNT}" || true
        
        # Import the container
        terraform import azurerm_storage_container.tfstate "https://${STORAGE_ACCOUNT}.blob.core.windows.net/tfstate" || true
    fi
fi

# Now apply
terraform apply -auto-approve \
  -var="project_name=${PROJECT_NAME}" \
  -var="environment=${ENVIRONMENT:-production}" \
  -var="location=${AZURE_LOCATION:-East US}"

# Get the outputs
RESOURCE_GROUP=$(terraform output -raw tfstate_resource_group)
STORAGE_ACCOUNT=$(terraform output -raw tfstate_storage_account)
CONTAINER=$(terraform output -raw tfstate_container)

echo "State storage created:"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Storage Account: $STORAGE_ACCOUNT"
echo "  Container: $CONTAINER"

# Go back to main terraform directory
cd ..

# Create backend configuration in main terraform directory
cat > backend-config.tf << EOF
# Auto-generated backend configuration
terraform {
  backend "azurerm" {
    resource_group_name  = "$RESOURCE_GROUP"
    storage_account_name = "$STORAGE_ACCOUNT"
    container_name       = "$CONTAINER"
    key                  = "terraform.tfstate"
  }
}
EOF

echo "Backend configuration created successfully!"

# Clean up bootstrap directory
rm -rf bootstrap/

echo "Bootstrap complete! State storage is configured."