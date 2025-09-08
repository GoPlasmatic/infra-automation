# Infrastructure as Code for Plasmatic.io

Production infrastructure for deploying Ghost CMS, API services, and monitoring on Azure.

## Architecture

- **Cloud Provider**: Azure
- **VM Size**: Standard_B2s (2 vCPUs, 4GB RAM)
- **Operating System**: Ubuntu 24.04 LTS
- **Container Platform**: Docker & Docker Compose
- **Web Server**: Nginx (reverse proxy)
- **Storage**: 64GB Premium SSD
- **SSL/TLS**: Automatic Let's Encrypt certificates
- **DNS**: External provider (GoDaddy)

## Deployment Method

This infrastructure is deployed exclusively through GitHub Actions. Manual deployment is not supported.

## Prerequisites

1. GitHub repository with Actions enabled
2. Required GitHub Secrets configured (see GITHUB_SECRETS.md)
3. Azure subscription with appropriate permissions

## Quick Start

1. Fork or clone this repository to your GitHub account

2. Configure GitHub Secrets:
   - Follow the instructions in GITHUB_SECRETS.md
   - Set up all required secrets in your repository settings

3. Configure the `.env` example:
   ```bash
   cp docker/.env.example docker/.env
   # Commit the .env file with your configuration
   ```

4. Push changes to trigger deployment:
   ```bash
   git add .
   git commit -m "Configure infrastructure"
   git push origin main
   ```

5. Monitor deployment in the GitHub Actions tab

6. Configure DNS in GoDaddy:
   - Add A record for @ pointing to VM public IP
   - Add A record for www pointing to VM public IP
   - Add A record for grafana pointing to VM public IP
   - Add A record for webadmin pointing to VM public IP
   - Add A record for future pointing to VM public IP

7. Wait for DNS propagation (5-30 minutes)
   - SSL certificates will be automatically configured once DNS propagates
   - All services will have HTTPS enabled
   - Certificate renewal is automated via cron

## Services

- **Ghost CMS**: Main website and content management at `www.goplasmatic.io`
- **Reframe API**: SWIFT message transformation at `reframeapi.goplasmatic.io`
- **Sandbox**: Testing environment at `sandbox.goplasmatic.io`
- **Grafana**: Monitoring dashboard at `grafana.goplasmatic.io`
- **Admin**: Ghost admin interface at `webadmin.goplasmatic.io`

## Cost (B2s VM)

- VM: ~$30/month
- Storage: ~$10/month  
- IP: ~$5/month
- **Total: ~$45/month**

## Quick Start

1. Configure GitHub Secrets (see below)
2. Push to main branch to trigger deployment
3. Configure DNS A records pointing to VM public IP
4. SSL certificates auto-configure after DNS propagation


## DNS Configuration

Add these A records in GoDaddy pointing to VM public IP:
- `@` (root domain)
- `www` - Ghost CMS website
- `grafana` - Monitoring dashboard
- `webadmin` - Ghost admin panel
- `reframeapi` - Reframe API service
- `sandbox` - Sandbox environment

## GitHub Secrets Required

- `AZURE_CREDENTIALS` - Azure service principal
- `SSH_PUBLIC_KEY` - VM access
- `SSH_PRIVATE_KEY` - Deployment
- `VM_ADMIN_USERNAME` - Default: azureuser
- `EMAIL_ADDRESS` - Let's Encrypt SSL
- `ACR_URL` - Azure Container Registry
- `ACR_USERNAME` - ACR username
- `ACR_PASSWORD` - ACR password
- `DOMAIN_NAME` - Your domain (e.g., goplasmatic.io)



## Maintenance

### Backup
```bash
./scripts/backup.sh <public-ip> <storage-account> [container]
```

### Monitor Resources
```bash
ssh azureuser@<public-ip> "docker stats"
```

### View Logs
```bash
ssh azureuser@<public-ip> "sudo docker compose -f /opt/docker/docker-compose.yml logs <service>"
```