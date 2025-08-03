# Azure DNS Zone management
# Automatically creates and manages DNS zone for your domain

resource "azurerm_dns_zone" "main" {
  name                = var.domain_name
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# DNS A Records for all services
locals {
  subdomains = [
    "@",        # root domain
    "www",      # main website
    "grafana",  # monitoring
    "webadmin", # Ghost admin
    "future",   # Ghost preview
    # "docs",     # documentation (future)
    # "api"       # API service (future)
  ]
}

resource "azurerm_dns_a_record" "records" {
  for_each            = toset(local.subdomains)
  name                = each.value
  zone_name           = azurerm_dns_zone.main.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  records             = [azurerm_public_ip.main.ip_address]
}

# Output nameservers for domain configuration
output "nameservers" {
  description = "Azure DNS nameservers - Update these in your domain registrar (GoDaddy)"
  value       = azurerm_dns_zone.main.name_servers
}

output "dns_zone_id" {
  description = "Azure DNS Zone resource ID"
  value       = azurerm_dns_zone.main.id
}