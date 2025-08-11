# Azure Container Registry Configuration
# Basic tier configuration for cost-effective internal deployments
# Basic tier costs approximately $5/month with 10GB storage and 2 webhooks

resource "azurerm_container_registry" "main" {
  name                = "PlasmaticContainerRegistry"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"  # Using Basic tier for minimum cost
  admin_enabled       = true     # Enable admin for simple authentication with the VM

  # Enable public network access (required for VM to pull images)
  public_network_access_enabled = true

  # Anonymous pull disabled for security
  anonymous_pull_enabled = false

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Purpose     = "Container Registry for Internal Deployments"
    ManagedBy   = "Terraform"
    CostTier    = "Basic"
  }
}