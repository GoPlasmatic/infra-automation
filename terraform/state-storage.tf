# Terraform State Storage - Automatically provisioned
# This creates the storage account for Terraform state as part of the infrastructure

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
  
  # Security settings
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

# Output the state storage details for initial setup
output "tfstate_resource_group" {
  value       = azurerm_resource_group.tfstate.name
  description = "Resource group for Terraform state storage"
}

output "tfstate_storage_account" {
  value       = azurerm_storage_account.tfstate.name
  description = "Storage account for Terraform state"
}

output "tfstate_container" {
  value       = azurerm_storage_container.tfstate.name
  description = "Container name for Terraform state"
}

# Create a local file with backend configuration
resource "local_file" "backend_config" {
  content = templatefile("${path.module}/backend-config.tpl", {
    resource_group_name  = azurerm_resource_group.tfstate.name
    storage_account_name = azurerm_storage_account.tfstate.name
    container_name       = azurerm_storage_container.tfstate.name
  })
  
  filename = "${path.module}/backend-config.tf"
  
  depends_on = [
    azurerm_storage_container.tfstate
  ]
}