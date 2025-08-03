output "public_ip_address" {
  description = "Public IP address of the Ghost CMS VM"
  value       = azurerm_public_ip.main.ip_address
}

output "vm_id" {
  description = "ID of the Ghost CMS virtual machine"
  value       = azurerm_linux_virtual_machine.main.id
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "ssh_connection_string" {
  description = "SSH connection string"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.main.ip_address}"
}

output "vm_size_info" {
  description = "VM size information"
  value       = "VM Size: ${var.vm_size} (2 vCPUs, 4GB RAM)"
}

output "storage_account_name" {
  description = "Name of the storage account for backups"
  value       = azurerm_storage_account.main.name
}

output "storage_account_key" {
  description = "Primary access key for storage account"
  value       = azurerm_storage_account.main.primary_access_key
  sensitive   = true
}

output "dns_instructions" {
  description = "Instructions for DNS configuration"
  value = <<-EOT
    
    ====================================
    DNS Configuration Required
    ====================================
    
    Add these A records in GoDaddy DNS:
    
    @ (root)     → ${azurerm_public_ip.main.ip_address}
    www          → ${azurerm_public_ip.main.ip_address}
    grafana      → ${azurerm_public_ip.main.ip_address}
    webadmin     → ${azurerm_public_ip.main.ip_address}
    future       → ${azurerm_public_ip.main.ip_address}
    
    DNS propagation takes 5-30 minutes typically.
    ====================================
  EOT
}