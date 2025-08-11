variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "ghost-cms"
}

variable "environment" {
  description = "The deployment environment"
  type        = string
  default     = "production"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

variable "vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_public_key" {
  description = "SSH public key content (used in GitHub Actions)"
  type        = string
  default     = ""
}

variable "allowed_ssh_ips" {
  description = "List of IP addresses allowed to SSH"
  type        = list(string)
  default     = []
}

variable "domain_name" {
  description = "The domain name for Ghost CMS"
  type        = string
}

variable "email_address" {
  description = "Email address for SSL certificate"
  type        = string
}


variable "enable_backups" {
  description = "Enable Azure VM backups"
  type        = bool
  default     = true
}

# Azure Container Registry Variables
variable "acr_sku" {
  description = "SKU for Azure Container Registry (Basic, Standard, or Premium) - Basic is cheapest at ~$5/month"
  type        = string
  default     = "Basic"  # Basic is the cheapest option, sufficient for internal deployments
  
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "ACR SKU must be Basic, Standard, or Premium"
  }
}

variable "acr_admin_enabled" {
  description = "Enable admin user for Azure Container Registry"
  type        = bool
  default     = true
}

variable "acr_public_network_access_enabled" {
  description = "Enable public network access to ACR"
  type        = bool
  default     = true
}

variable "acr_anonymous_pull_enabled" {
  description = "Enable anonymous pull for public images"
  type        = bool
  default     = false
}

variable "acr_data_endpoint_enabled" {
  description = "Enable dedicated data endpoint (Premium SKU only)"
  type        = bool
  default     = false
}

variable "acr_network_rule_set_enabled" {
  description = "Enable network rule set (Premium SKU only)"
  type        = bool
  default     = false
}

variable "acr_network_rule_default_action" {
  description = "Default action for network rules (Allow or Deny)"
  type        = string
  default     = "Allow"
}

variable "acr_ip_rules" {
  description = "IP rules for ACR network access"
  type = list(object({
    action   = string
    ip_range = string
  }))
  default = []
}

variable "acr_georeplications" {
  description = "Geo-replication locations for ACR (Premium SKU only)"
  type = list(object({
    location                = string
    zone_redundancy_enabled = bool
    tags                    = map(string)
  }))
  default = []
}

variable "acr_retention_policy_enabled" {
  description = "Enable retention policy for untagged manifests (Premium SKU only)"
  type        = bool
  default     = false
}

variable "acr_retention_days" {
  description = "Number of days to retain untagged manifests"
  type        = number
  default     = 7
}

variable "acr_content_trust_enabled" {
  description = "Enable content trust (Premium SKU only)"
  type        = bool
  default     = false
}

variable "acr_encryption_enabled" {
  description = "Enable customer-managed key encryption (Premium SKU only)"
  type        = bool
  default     = false
}

variable "acr_encryption_key_vault_key_id" {
  description = "Key Vault key ID for ACR encryption"
  type        = string
  default     = ""
}

variable "acr_webhook_enabled" {
  description = "Enable webhook for CI/CD integration"
  type        = bool
  default     = false
}

variable "acr_webhook_service_uri" {
  description = "Service URI for ACR webhook"
  type        = string
  default     = ""
}

variable "acr_webhook_scope" {
  description = "Scope for ACR webhook (repository:tag)"
  type        = string
  default     = ""
}

variable "acr_webhook_actions" {
  description = "Actions that trigger the webhook"
  type        = list(string)
  default     = ["push"]
}

variable "acr_webhook_custom_headers" {
  description = "Custom headers for webhook requests"
  type        = map(string)
  default     = {}
}