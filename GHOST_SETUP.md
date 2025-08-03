# Ghost CMS Setup Guide

Ghost CMS is now configured as the primary service in this infrastructure. Follow these steps to deploy and configure Ghost.

## Prerequisites

1. Ensure you have configured the environment variables in `docker/.env`:
   ```bash
   cp docker/.env.example docker/.env
   # Edit docker/.env with your actual values
   ```

2. Configure DNS A records for:
   - `webadmin.{your-domain}` → Your server IP
   - `future.{your-domain}` → Your server IP

3. SSL certificates are automatically configured:
   - Certificates are provisioned during deployment
   - Auto-renewal is set up via cron
   - All Ghost services will have HTTPS enabled

## Deployment Steps

1. **Deploy the infrastructure** (if not already done):
   ```bash
   ./scripts/deploy.sh production
   ```

2. **Start Ghost services** (SSL is automatic):
   ```bash
   ssh azureuser@<public-ip> "cd /opt/docker && sudo docker compose up -d ghost ghost_db"
   ```

3. **Verify services are running**:
   ```bash
   ssh azureuser@<public-ip> "sudo docker compose ps"
   ```

## Initial Configuration

1. Access Ghost admin at: https://webadmin.{your-domain}/ghost
2. Create your administrator account
3. Configure site settings:
   - Site title and description
   - Logo and cover image
   - Social media links
   - SEO settings

4. Choose or upload a theme
5. Start creating content!

## Testing

- View your Ghost site at: https://future.{your-domain}
- Admin panel: https://webadmin.{your-domain}/ghost

## Final Migration

When ready to make Ghost your main website:

1. Update the nginx configuration to point `www.goplasmatic.io` to Ghost
2. Remove or archive the React website container
3. Update DNS if needed

## Troubleshooting

### Check Ghost logs:
```bash
ssh azureuser@<public-ip> "sudo docker logs ghost_cms"
```

### Check MySQL logs:
```bash
ssh azureuser@<public-ip> "sudo docker logs ghost_db"
```

### Restart Ghost:
```bash
ssh azureuser@<public-ip> "cd /opt/docker && sudo docker compose restart ghost ghost_db"
```

## Backup

Ghost content is automatically backed up by the backup script. The following directories are included:
- `/applications/ghost/data/content` - Themes, images, and uploads
- MySQL database volume

Run manual backup:
```bash
./scripts/backup.sh <public-ip> <storage-account>
```