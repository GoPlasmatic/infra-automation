#!/bin/bash
set -e

# Bootstrap script for Terraform state storage
# This script sets up the initial state storage before main infrastructure deployment

echo "==================================="
echo "Terraform State Storage Bootstrap"
echo "==================================="

# Cleanup function to ensure temp files are removed
cleanup() {
    echo "Cleaning up temporary files..."
    rm -f main-bootstrap.tf state-storage-temp.tf variables-temp.tf
    mv main.tf.backup main.tf 2>/dev/null || true
}

# Set trap to cleanup on exit
trap cleanup EXIT

cd terraform

# Check if backend-config.tf already exists
if [ -f "backend-config.tf" ]; then
    echo "Backend configuration already exists. Skipping bootstrap."
    exit 0
fi

echo "Setting up Terraform state storage..."

# Initialize Terraform without backend first
mv main.tf main.tf.backup 2>/dev/null || true

# Create temporary main.tf without backend
cat > main-bootstrap.tf << 'EOF'
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
    local = {
      source  = "hashicorp/local"
      version = "~> 2.7"
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
EOF

# Copy only the state storage configuration
cp state-storage.tf state-storage-temp.tf
cp variables.tf variables-temp.tf

# Initialize and apply only state storage
terraform init
terraform apply -auto-approve \
  -target=azurerm_resource_group.tfstate \
  -target=azurerm_storage_account.tfstate \
  -target=azurerm_storage_container.tfstate \
  -target=random_string.state_storage_suffix \
  -var="project_name=${PROJECT_NAME:-multi-app-server}" \
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

# Create backend configuration
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
echo "Now initializing Terraform with backend..."

# Re-initialize with backend
terraform init -force-copy \
  -backend-config="resource_group_name=$RESOURCE_GROUP" \
  -backend-config="storage_account_name=$STORAGE_ACCOUNT" \
  -backend-config="container_name=$CONTAINER" \
  -backend-config="key=terraform.tfstate"

echo "Bootstrap complete! State storage is configured."