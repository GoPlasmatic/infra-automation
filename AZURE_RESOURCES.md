# Azure Resources Overview

This document outlines all Azure resources required for the multi-application infrastructure.

## Required Azure Resources

### 1. **Compute Resources**
- **Virtual Machine (VM)**
  - Type: Standard_B2s (2 vCPUs, 4GB RAM)
  - OS: Ubuntu 22.04 LTS
  - Purpose: Hosts all Docker containers

### 2. **Networking Resources**
- **Public IP Address** ✅ REQUIRED
  - Type: Static IP
  - SKU: Standard
  - Purpose: Fixed IP for DNS A records
  - Cost: ~$5/month

- **Virtual Network (VNet)**
  - Address space: 10.0.0.0/16
  - Purpose: Network isolation

- **Subnet**
  - Address range: 10.0.1.0/24
  - Purpose: VM network segment

- **Network Security Group (NSG)**
  - Inbound rules: SSH (22), HTTP (80), HTTPS (443)
  - Purpose: Firewall rules

- **Network Interface**
  - Purpose: Connects VM to VNet and Public IP

### 3. **Storage Resources**
- **OS Disk**
  - Size: 64GB Premium SSD
  - Purpose: Operating system and applications

- **Storage Account** (Recommended)
  - Type: Standard LRS
  - Purpose: 
    - Backup storage
    - Static content CDN origin
    - Ghost media uploads (optional)
  - Cost: ~$2-5/month

### 4. **DNS Resources** (Optional)
- **Azure DNS Zone**
  - Domain: {your-domain}
  - Purpose: Manage DNS records in Azure
  - Alternative: Use external DNS provider
  - Cost: ~$0.50/month + queries

### 5. **Backup Resources** (Recommended)
- **Azure Backup Vault**
  - Purpose: VM backups
  - Alternative: Storage account backups
  - Cost: Based on storage used

### 6. **Monitoring Resources** (Optional)
- **Application Insights**
  - Purpose: Application performance monitoring
  - Integration with Ghost/React apps

- **Log Analytics Workspace**
  - Purpose: Centralized logging
  - Cost: Based on data ingestion

### 7. **Security Resources** (Recommended)
- **Key Vault**
  - Purpose: Store secrets, SSL certificates
  - Cost: ~$0.03/secret/month

- **Azure Firewall** (Optional)
  - Purpose: Advanced network security
  - Cost: ~$1.25/hour (expensive)

## Resource Dependencies

```
Resource Group
├── Virtual Network
│   └── Subnet
├── Public IP (Static) ✅ REQUIRED
├── Network Security Group
├── Network Interface (connects VM + Public IP + Subnet)
├── Virtual Machine
├── Storage Account (for backups)
├── DNS Zone (optional)
└── Key Vault (recommended)
```

## Cost Optimization

### Minimal Setup (~$46/month)
- VM (B2s): ~$30
- OS Disk (64GB Premium): ~$10
- Public IP: ~$5
- Terraform State Storage: ~$1
- **Total**: ~$46/month

### Recommended Setup (~$55/month)
- Minimal setup +
- Storage Account: ~$5
- DNS Zone: ~$0.50
- Key Vault: ~$1
- Backup storage: ~$3-5
- **Total**: ~$55/month

### Why Public IP is Required

1. **DNS A Records**: Your domains need to point to a fixed IP
2. **SSL Certificates**: Let's Encrypt needs consistent IP
3. **Direct Access**: Users access your services via this IP
4. **Stability**: Dynamic IPs would break DNS resolution

### Alternative Architectures

#### Using Azure Application Gateway (More Complex/Expensive)
- Application Gateway with public IP
- VM with private IP only
- Cost: Additional ~$200/month

#### Using Azure Front Door (Enterprise)
- Global load balancing
- Built-in SSL
- Cost: ~$35/month + bandwidth

## Terraform Configuration Updates Needed

The current Terraform already includes:
- ✅ Resource Group
- ✅ Virtual Network & Subnet
- ✅ Public IP (Static)
- ✅ Network Security Group
- ✅ Network Interface
- ✅ Virtual Machine
- ✅ Terraform State Storage (Automatic)

Should add:
- ⏳ Storage Account for backups
- ⏳ DNS Zone (optional)
- ⏳ Key Vault (recommended)

### Automatic State Storage

Terraform state storage is now automatically provisioned:
- Creates dedicated resource group: `{project}-tfstate-rg`
- Creates storage account with random suffix
- Configures backend automatically
- No manual setup or secrets required

## Public IP Management

### Current Configuration
```hcl
resource "azurerm_public_ip" "main" {
  allocation_method = "Static"  # Important: Must be static
  sku              = "Standard"
}
```

### DNS Setup
After deployment, get the public IP:
```bash
terraform output public_ip_address
```

Then update your DNS:
```
A  @          <PUBLIC_IP>
A  www        <PUBLIC_IP>
A  grafana    <PUBLIC_IP>
A  webadmin   <PUBLIC_IP>
A  future     <PUBLIC_IP>
```

### IP Whitelisting
For enhanced security, consider:
1. Cloudflare proxy (hides real IP)
2. Azure DDoS Protection
3. Restrict SSH to specific IPs (already configured)