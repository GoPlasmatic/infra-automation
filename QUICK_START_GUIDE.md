# Quick Start Guide

## Prerequisites
- Azure subscription with active credits
- GitHub repository with Actions enabled
- Domain name with DNS management access
- Email address for SSL certificates

## Step 1: Set GitHub Secrets

### Generate SSH Keys
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/github_actions_key -N ""
```

### Add Secrets in GitHub
Go to Repository Settings > Secrets and variables > Actions

**Required Secrets:**
1. `SSH_PUBLIC_KEY` - Contents of `~/.ssh/github_actions_key.pub`
2. `SSH_PRIVATE_KEY` - Contents of `~/.ssh/github_actions_key`
3. `VM_ADMIN_USERNAME` - Set to `azureuser`
4. `EMAIL_ADDRESS` - Your email for SSL certificates

**Required Variables:**
1. `DOMAIN_NAME` - Your domain (e.g., `yourdomain.com`)
2. `PROJECT_NAME` - Leave default or set custom name
3. `ENVIRONMENT` - Leave as `production`
4. `AZURE_LOCATION` - Leave as `East US` or change
5. `VM_SIZE` - Leave as `Standard_B2s` or change

## Step 2: Push to GitHub

```bash
git add .
git commit -m "Initial infrastructure setup"
git push origin main
```

## Step 3: Monitor Deployment

1. Go to Actions tab in GitHub
2. Watch the `Terraform Apply` workflow
3. Once complete, watch the `Deploy Applications` workflow

## Step 4: Get Public IP

After Terraform completes:
1. Check the workflow output for `public_ip_address`
2. Or check Azure Portal for the VM's public IP

## Step 5: Configure DNS

Add these A records to your domain:
```
A  @          <PUBLIC_IP>
A  www        <PUBLIC_IP>
A  grafana    <PUBLIC_IP>
A  webadmin   <PUBLIC_IP>
A  future     <PUBLIC_IP>
```

## Step 6: Wait for SSL

- DNS propagation: 5-30 minutes
- SSL certificates are automatically configured
- Check deployment logs for SSL setup status

## Step 7: Access Your Services

- **Website**: https://www.yourdomain.com
- **Monitoring**: https://grafana.yourdomain.com (admin/admin)
- **Ghost Admin**: https://webadmin.yourdomain.com/ghost
- **Ghost Preview**: https://future.yourdomain.com

## First-Time Ghost Setup

1. Go to https://webadmin.yourdomain.com/ghost
2. Create your admin account
3. Configure site settings
4. Start creating content

## Troubleshooting

### Check Deployment Logs
- GitHub Actions tab shows all logs
- Look for any red ✗ marks

### SSH Access
```bash
ssh -i ~/.ssh/github_actions_key azureuser@<PUBLIC_IP>
```

### Check Services
```bash
sudo docker compose ps
sudo docker compose logs nginx
```

## Common Issues

1. **SSL Certificate Failed**
   - Ensure DNS is propagated: `nslookup www.yourdomain.com`
   - Check email is valid

2. **Services Not Accessible**
   - Verify Azure NSG allows ports 80, 443
   - Check nginx is running: `sudo docker compose ps`

3. **Ghost Not Loading**
   - Check Ghost logs: `sudo docker compose logs ghost`
   - Ensure MySQL is running: `sudo docker compose ps mysql`

## Next Steps

- Change Grafana password (default: admin/admin)
- Configure Ghost email settings
- Set up backups (automated via cron)
- Monitor resource usage in Azure Portal