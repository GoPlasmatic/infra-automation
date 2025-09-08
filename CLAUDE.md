# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is an Infrastructure as Code (IaC) repository for deploying production infrastructure on Azure, hosting Ghost CMS as the main website along with API services and monitoring. The infrastructure is deployed exclusively through GitHub Actions CI/CD pipeline.

## Key Architecture Components

### Infrastructure Stack
- **Terraform**: Manages Azure resources (VM, networking, DNS, storage)
- **Docker Compose**: Orchestrates services (Ghost, MySQL, Nginx, Prometheus, Grafana)
- **GitHub Actions**: Automated CI/CD pipeline for infrastructure and application deployment
- **DNS**: External DNS management (GoDaddy)

### Service Architecture
```
Azure VM (Ubuntu 24.04 LTS)
├── Nginx (Reverse Proxy)
│   ├── www.domain → Ghost CMS (Main Website)
│   ├── webadmin.domain → Ghost Admin Panel
│   ├── reframeapi.domain → Reframe API Service
│   ├── sandbox.domain → Sandbox Environment
│   └── grafana.domain → Monitoring Dashboard
├── Ghost CMS + MySQL
├── Reframe API (SWIFT Processing)
├── Sandbox (Testing Environment)
├── Prometheus + Grafana (Monitoring)
└── Node Exporter + cAdvisor (Metrics)
```

## Essential Commands

### Local Development
```bash
# Validate Terraform configuration
cd terraform
terraform fmt
terraform validate

# Test shell scripts syntax
for script in scripts/*.sh; do bash -n "$script"; done

# Validate Docker Compose
cd docker
docker compose config
```

### Deployment Commands
```bash
# Deploy infrastructure (GitHub Actions only)
git push origin main  # Triggers terraform workflow

# Manual operations (SSH to VM first)
ssh azureuser@<public-ip>
sudo docker compose -f /opt/docker/docker-compose.yml ps
sudo docker compose -f /opt/docker/docker-compose.yml logs <service>
sudo docker compose -f /opt/docker/docker-compose.yml restart <service>
```

### Troubleshooting Commands
```bash
# Check GitHub Actions logs for deployment errors
# Go to Actions tab in GitHub repository

# Generate Azure credentials
./scripts/generate-azure-credentials.sh

# Manual backup
./scripts/backup.sh <public-ip> <storage-account> [container]
```

## Critical Files and Their Purposes

### Terraform State Management
- `scripts/bootstrap-terraform.sh`: Creates state storage in isolated bootstrap directory
- State storage is created automatically during first deployment
- Bootstrap script runs independently to avoid resource conflicts

### GitHub Actions Workflows
1. **terraform.yml**: 
   - Triggered by changes to terraform/**
   - Creates Azure infrastructure
   - Outputs VM public IP
   
2. **deploy.yml**:
   - Triggered after terraform or by docker/** changes  
   - Configures domains dynamically
   - Deploys applications via SSH
   - Sets up SSL certificates automatically

### Domain Configuration
- `scripts/configure-nginx-domains.sh`: Replaces hardcoded domains with DOMAIN_NAME variable
- `scripts/setup-ssl-automated.sh`: Automated SSL setup for all subdomains
- All services use dynamic domain configuration from DOMAIN_NAME variable

## GitHub Secrets Requirements

**Mandatory Secrets:**
- `AZURE_CREDENTIALS`: Service principal JSON (may be at org level)
- `SSH_PUBLIC_KEY`: For VM access
- `SSH_PRIVATE_KEY`: For deployment
- `VM_ADMIN_USERNAME`: Default: azureuser
- `EMAIL_ADDRESS`: For Let's Encrypt SSL
- `ACR_URL`: Azure Container Registry URL (org level)
- `ACR_USERNAME`: ACR username (org level)
- `ACR_PASSWORD`: ACR password (org level)

**Mandatory Variables:**
- `DOMAIN_NAME`: Your domain (e.g., example.com)

## Common Issues and Solutions

### Terraform Duplicate Resource Errors
- Caused by leftover temp files from bootstrap script
- Solution: Bootstrap script now uses isolated directory approach
- Files created in terraform/bootstrap/ then cleaned up

### Azure Login Errors
- "Not all values are present" = AZURE_CREDENTIALS missing or wrong format
- Use `./scripts/generate-azure-credentials.sh` to create proper credentials
- Ensure repository has access to org-level secrets

### AzureRM Provider v4 Changes
- `enable_https_traffic_only` → `https_traffic_only_enabled`
- Ubuntu image: "0001-com-ubuntu-server-jammy" → "ubuntu-24_04-lts"
- Provider version: ~> 4.13

## Deployment Flow

1. **Push to main branch** triggers GitHub Actions
2. **Terraform workflow**:
   - Cleans temp files
   - Runs bootstrap script (creates state storage)
   - Provisions Azure resources
   - Creates DNS zone and records
3. **Deploy workflow**:
   - Configures nginx with correct domains
   - Deploys Docker containers
   - Sets up SSL certificates
   - Runs health checks

## Important Notes

- Ghost CMS is the main website at www.domain
- All manual deployment options have been removed
- SSL/HTTPS is automatic and mandatory
- Terraform state storage is automatic
- DNS is managed externally in GoDaddy
- All domain references use DOMAIN_NAME variable (no hardcoding)
- Website and future subdomains have been removed (Ghost is now the main site)
- Infrastructure updates should only be done through GitHub Actions

## Version Information

- Terraform: >= 1.10
- AzureRM Provider: ~> 4.13
- Ubuntu: 24.04 LTS
- Docker images are pinned to specific versions in docker-compose.yml