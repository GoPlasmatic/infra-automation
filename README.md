# Multi-Application Infrastructure as Code

This repository contains Infrastructure as Code (IaC) for deploying Ghost CMS and monitoring services on a single Azure VM.

## Architecture

- **Cloud Provider**: Azure
- **VM Size**: Standard_B2s (2 vCPUs, 4GB RAM)
- **Operating System**: Ubuntu 22.04 LTS
- **Container Platform**: Docker & Docker Compose
- **Web Server**: Nginx (reverse proxy)
- **Storage**: 64GB Premium SSD
- **Primary Services**: Ghost CMS (blog and website), Grafana monitoring
- **Legacy Service**: React/Vite website (being replaced by Ghost)
- **State Management**: Automatic Terraform state storage in Azure
- **SSL/TLS**: Automatic Let's Encrypt certificates for all services
- **DNS Management**: Uses external DNS provider (GoDaddy)

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

## Directory Structure

```
.
├── terraform/          # Azure infrastructure definitions
├── ansible/           # Server configuration playbooks
├── docker/           # Docker Compose and configurations
├── applications/     # Application-specific configurations
│   ├── ghost/       # Ghost CMS
│   └── website/     # Current React/Vite website
└── scripts/          # Deployment and maintenance scripts
```

## VM Specifications (Current - B2s)

- **Cost**: ~$30/month
- **Resources**: 2 vCPUs, 4GB RAM
- **Storage**: 64GB Premium SSD
- **Suitable for**: Ghost CMS + Docs + Light API service

### Scaling Options
1. **B1s** (1 vCPU, 1GB RAM) - ~$7.60/month (downgrade if needed)
2. **B2ms** (2 vCPUs, 8GB RAM) - ~$60/month
3. **B4ms** (4 vCPUs, 16GB RAM) - ~$120/month

To scale up:
```bash
# Update vm_size in terraform.tfvars
# Then run:
cd terraform
terraform plan
terraform apply
```

## Ghost CMS Deployment

When ready to deploy Ghost CMS:
1. Uncomment the Ghost services in `docker/docker-compose.yml`
2. Enable nginx configs for Ghost
3. Configure DNS records for Ghost subdomains
4. Run SSL setup for Ghost domains

## Performance Features

- 2GB swap file for memory flexibility
- Optimized sysctl settings
- Premium SSD for better I/O performance
- Docker networks for service isolation
- Nginx configured for multiple services
- Prometheus + Grafana monitoring stack

## Monitoring

Access Grafana dashboard at `https://grafana.{your-domain}` after deployment.

Default credentials:
- Username: admin (or value from GRAFANA_ADMIN_USER)
- Password: Set in docker/.env file

Pre-configured dashboards:
- System Overview: CPU, Memory, Disk, Network metrics
- Docker Containers: Container-specific metrics

## Subdomain Structure

- `www.{your-domain}` - Main website (currently React app)
- `grafana.{your-domain}` - Monitoring dashboard
- `webadmin.{your-domain}` - Ghost CMS admin interface
- `future.{your-domain}` - Ghost CMS frontend preview

### DNS Configuration

Configure these A records in your DNS provider (e.g., GoDaddy) pointing to the VM's public IP:
- `@` (root domain)
- `www` - Main website
- `grafana` - Monitoring dashboard  
- `webadmin` - Ghost CMS admin
- `future` - Ghost frontend preview

All HTTP traffic is automatically redirected to HTTPS. SSL certificates are automatically provisioned once DNS records propagate.

## Ghost CMS Configuration

Ghost CMS is configured as the primary content management system. The React website remains as a legacy service until the final migration to Ghost is complete.

### Post-Deployment Steps:
1. Set up Ghost admin user at webadmin.{your-domain}/ghost
2. Configure Ghost theme and settings
3. Test the site at future.{your-domain}
4. When ready, update DNS to point www.{your-domain} to Ghost

## Maintenance

All infrastructure changes should be made through code and deployed via GitHub Actions. For operational tasks:

### Backup (Manual)
```bash
# SSH into VM first, then run:
./scripts/backup.sh <public-ip> <storage-account> [container-name]
```

### Monitor Resource Usage
```bash
# SSH into VM and check:
ssh azureuser@<public-ip> "htop"
ssh azureuser@<public-ip> "docker stats"
```

### Update Containers
To update containers, modify the docker-compose.yml and push to GitHub. For emergency updates only:
```bash
ssh azureuser@<public-ip> "cd /opt/docker && sudo docker compose pull && sudo docker compose up -d"
```

## Security

- SSH access restricted to allowed IPs
- Automatic security updates enabled
- Fail2ban configured
- SSL/TLS encryption with Let's Encrypt (automatic)
- Docker containers with limited privileges
- Firewall (UFW) enabled

## Cost Breakdown (B2s)

- **VM**: ~$30/month
- **Storage**: 64GB Premium SSD ~$10/month
- **Public IP**: Static IP ~$5/month
- **Total**: ~$45/month

## Troubleshooting

### Resource Monitoring
```bash
# Check memory and CPU usage
ssh azureuser@<public-ip> "htop"

# Check Docker container stats
ssh azureuser@<public-ip> "docker stats"

# Check disk usage
ssh azureuser@<public-ip> "df -h"
```

### Performance Tips
- Enable browser caching in Nginx
- Use image optimization for Ghost
- Consider CDN for static assets
- Monitor with Prometheus (optional)

## Deployment Checklist

### Initial Setup (GitHub Actions)
- [ ] Fork/clone repository to your GitHub account
- [ ] Configure all required GitHub Secrets (see GITHUB_SECRETS.md)
- [ ] Update `docker/.env` with your values and commit
- [ ] Configure DNS A records for all subdomains
- [ ] Push to main branch to trigger deployment
- [ ] Monitor GitHub Actions for successful deployment
- [ ] Wait for DNS propagation (5-30 minutes)
- [ ] Verify SSL certificates are configured (automatic)
- [ ] Access Grafana at `https://grafana.{your-domain}`
- [ ] Set up Ghost admin at `https://webadmin.{your-domain}/ghost`

### Ghost CMS Configuration
- [ ] Create admin account
- [ ] Configure site settings and metadata
- [ ] Choose or upload theme
- [ ] Set up email configuration
- [ ] Create initial content
- [ ] Test at `https://future.{your-domain}`

### Final Migration (When Ready)
- [ ] Back up all data
- [ ] Update Ghost URL to production domain
- [ ] Switch nginx configs to serve Ghost on www
- [ ] Archive React website
- [ ] Update DNS if needed