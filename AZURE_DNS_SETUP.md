# Azure DNS Setup Guide

This guide explains how to migrate your domain DNS management from GoDaddy to Azure DNS.

## Overview

Azure DNS provides:
- Reliable, secure DNS hosting
- Automatic DNS record management for all services
- Integration with Azure infrastructure
- 99.99% SLA availability
- Global anycast network

## Migration Process

### Step 1: Deploy Infrastructure

When you deploy the infrastructure, Azure automatically:
1. Creates an Azure DNS zone for your domain
2. Sets up all required A records for services
3. Provides Azure nameservers in the output

### Step 2: Get Azure Nameservers

After Terraform deployment completes:

1. Check GitHub Actions output for nameservers:
   ```
   nameservers = [
     "ns1-01.azure-dns.com.",
     "ns2-01.azure-dns.net.",
     "ns3-01.azure-dns.org.",
     "ns4-01.azure-dns.info."
   ]
   ```

2. Or retrieve them manually:
   ```bash
   # From your local machine with Azure CLI
   az network dns zone show --name your-domain.com --resource-group multi-app-server-rg --query nameServers
   ```

### Step 3: Update GoDaddy Nameservers

1. **Log into GoDaddy**
   - Go to https://godaddy.com
   - Sign in to your account

2. **Navigate to Domain Settings**
   - Click "My Products"
   - Find your domain
   - Click "DNS" or "Manage"

3. **Change Nameservers**
   - Look for "Nameservers" section
   - Click "Change"
   - Select "Custom" or "Enter my own nameservers"
   - Remove GoDaddy's default nameservers
   - Add Azure nameservers (remove trailing dots):
     ```
     ns1-01.azure-dns.com
     ns2-01.azure-dns.net
     ns3-01.azure-dns.org
     ns4-01.azure-dns.info
     ```
   - Click "Save"

4. **Confirm Changes**
   - GoDaddy will show a warning about changing nameservers
   - Confirm you want to proceed
   - Changes take 5 minutes to 48 hours to propagate (usually under 1 hour)

### Step 4: Verify DNS Propagation

1. **Check nameserver propagation**:
   ```bash
   # Check which nameservers are active
   nslookup -type=NS your-domain.com
   
   # Or use dig
   dig NS your-domain.com
   ```

2. **Verify A records**:
   ```bash
   # Check root domain
   nslookup your-domain.com
   
   # Check subdomains
   nslookup www.your-domain.com
   nslookup grafana.your-domain.com
   nslookup webadmin.your-domain.com
   nslookup future.your-domain.com
   ```

3. **Use online tools**:
   - https://dnschecker.org
   - https://whatsmydns.net
   - Enter your domain and check NS records

## DNS Records Created Automatically

Azure DNS automatically creates these A records pointing to your VM's public IP:

| Record | Type | Subdomain | Purpose |
|--------|------|-----------|----------|
| @ | A | your-domain.com | Root domain |
| www | A | www.your-domain.com | Main website |
| grafana | A | grafana.your-domain.com | Monitoring dashboard |
| webadmin | A | webadmin.your-domain.com | Ghost CMS admin |
| future | A | future.your-domain.com | Ghost frontend preview |

## Benefits of Azure DNS

1. **Automatic Management**: No manual DNS record updates needed
2. **High Availability**: Azure's global anycast network
3. **Fast Updates**: Changes propagate quickly
4. **Integration**: Works seamlessly with Azure resources
5. **Security**: Azure RBAC and activity logs
6. **Cost**: Only ~$0.50/month + minimal query charges

## Troubleshooting

### DNS Not Resolving

1. **Check propagation time**: Wait up to 48 hours
2. **Verify nameservers**: Ensure all 4 Azure nameservers are added
3. **Clear DNS cache**:
   ```bash
   # Windows
   ipconfig /flushdns
   
   # macOS
   sudo dscacheutil -flushcache
   
   # Linux
   sudo systemctl restart systemd-resolved
   ```

### Wrong IP Address

1. Check Azure DNS zone has correct records:
   ```bash
   az network dns record-set a list --zone-name your-domain.com --resource-group multi-app-server-rg
   ```

2. Verify VM public IP matches DNS records

### GoDaddy Issues

- Ensure you're changing nameservers, not adding DNS records
- Remove all GoDaddy nameservers before adding Azure ones
- Don't use GoDaddy's DNS management after switching

## Rollback Process

If needed, you can switch back to GoDaddy:

1. Note down all DNS records from Azure
2. Change nameservers back to GoDaddy defaults:
   ```
   domaincontrol.com
   domaincontrol.com
   ```
3. Manually recreate DNS records in GoDaddy

## Important Notes

- **Email Services**: If using GoDaddy email, note MX records before switching
- **Other Records**: Document any TXT, CNAME, or other records
- **TTL**: Azure uses 300 seconds (5 minutes) by default
- **Downtime**: No downtime if done correctly
- **SSL**: Certificates continue working after DNS switch

## Post-Migration

Once DNS is on Azure:
- All DNS changes are managed through Terraform
- No manual updates needed
- New subdomains can be added to `terraform/dns.tf`
- Infrastructure updates automatically update DNS

## Cost

- Azure DNS Zone: ~$0.50/month
- DNS Queries: ~$0.40 per million queries
- Total: Usually under $1/month for most sites