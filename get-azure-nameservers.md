# Get Azure DNS Nameservers

Run this command to get your Azure DNS nameservers:

```bash
az network dns zone show \
  --resource-group multi-app-server-production-rg \
  --name goplasmatic.io \
  --query nameServers \
  --output table
```

If you get an error, first login to Azure:
```bash
az login
```

## Expected Output

You should see 4 nameservers like:
- ns1-XX.azure-dns.com.
- ns2-XX.azure-dns.net.
- ns3-XX.azure-dns.org.  
- ns4-XX.azure-dns.info.

## Update in GoDaddy

1. Log in to GoDaddy
2. Go to Domain Settings for goplasmatic.io
3. Scroll down to "Nameservers" section
4. Click "Change Nameservers"
5. Choose "Enter my own nameservers (advanced)"
6. Delete existing nameservers
7. Add the 4 Azure nameservers (without the trailing dots)
8. Save changes

## Alternative: Check Terraform Output

You can also add this to your terraform/outputs.tf to see nameservers in GitHub Actions:

```hcl
output "nameserver_list" {
  description = "List of Azure DNS nameservers"
  value       = join("\n", azurerm_dns_zone.main.name_servers)
}
```
