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