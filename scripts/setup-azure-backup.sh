#!/bin/bash
set -e

# Azure Backup Configuration Script
echo "Azure Backup Setup"
echo "=================="

# Get parameters
PUBLIC_IP=${1}

if [ -z "$PUBLIC_IP" ]; then
    echo "Usage: $0 <public_ip>"
    exit 1
fi

# Get storage account details from Terraform
echo "Getting storage account details..."
cd terraform
STORAGE_ACCOUNT=$(terraform output -raw storage_account_name)
STORAGE_KEY=$(terraform output -raw storage_account_key)
cd ..

# Configure backup on the VM
echo "Configuring automated backups on VM..."

ssh azureuser@$PUBLIC_IP << EOF
    set -e
    
    # Install Azure CLI if not present
    if ! command -v az &> /dev/null; then
        echo "Installing Azure CLI..."
        curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    fi
    
    # Create backup script
    sudo tee /opt/backup/azure-backup.sh > /dev/null << 'SCRIPT'
#!/bin/bash
set -e

# Configuration
BACKUP_DIR="/opt/backup"
DATE=\$(date +%Y%m%d_%H%M%S)
STORAGE_ACCOUNT="$STORAGE_ACCOUNT"
STORAGE_KEY="$STORAGE_KEY"
CONTAINER="backups"
RETENTION_DAYS=7

# Create backup directory
mkdir -p \$BACKUP_DIR/temp

# Backup Docker volumes
echo "Backing up Docker volumes..."
cd \$BACKUP_DIR/temp

# Ghost content
sudo docker run --rm -v ghost_content:/data -v \$(pwd):/backup alpine tar czf /backup/ghost_content_\${DATE}.tar.gz -C /data .

# MySQL data
sudo docker exec ghost_db mysqldump -u root -p\${MYSQL_ROOT_PASSWORD} ghost_production | gzip > ghost_db_\${DATE}.sql.gz

# Nginx logs
sudo docker run --rm -v nginx_logs:/data -v \$(pwd):/backup alpine tar czf /backup/nginx_logs_\${DATE}.tar.gz -C /data .

# Create combined archive
tar czf ghost_backup_\${DATE}.tar.gz *.tar.gz *.sql.gz

# Upload to Azure Storage
echo "Uploading to Azure Storage..."
az storage blob upload \\
    --account-name \$STORAGE_ACCOUNT \\
    --account-key "\$STORAGE_KEY" \\
    --container-name \$CONTAINER \\
    --name ghost_backup_\${DATE}.tar.gz \\
    --file ghost_backup_\${DATE}.tar.gz

# Cleanup local files
rm -rf \$BACKUP_DIR/temp/*

# Delete old backups from Azure
echo "Cleaning up old backups..."
CUTOFF_DATE=\$(date -d "\$RETENTION_DAYS days ago" +%Y%m%d)

az storage blob list \\
    --account-name \$STORAGE_ACCOUNT \\
    --account-key "\$STORAGE_KEY" \\
    --container-name \$CONTAINER \\
    --output tsv \\
    --query "[?properties.lastModified < '\$(date -d "\$RETENTION_DAYS days ago" -u +%Y-%m-%dT%H:%M:%S)Z'].name" | \\
while read -r blob; do
    echo "Deleting old backup: \$blob"
    az storage blob delete \\
        --account-name \$STORAGE_ACCOUNT \\
        --account-key "\$STORAGE_KEY" \\
        --container-name \$CONTAINER \\
        --name "\$blob"
done

echo "Backup completed at \$(date)"
SCRIPT

    # Make script executable
    sudo chmod +x /opt/backup/azure-backup.sh
    
    # Create cron job for daily backups
    echo "Setting up cron job..."
    (crontab -l 2>/dev/null; echo "0 2 * * * /opt/backup/azure-backup.sh >> /var/log/azure-backup.log 2>&1") | crontab -
    
    # Create log file
    sudo touch /var/log/azure-backup.log
    sudo chmod 666 /var/log/azure-backup.log
    
    echo "Backup configuration completed!"
EOF

echo ""
echo "Azure backup has been configured!"
echo "Backups will run daily at 2 AM"
echo ""
echo "To run a backup manually:"
echo "ssh azureuser@$PUBLIC_IP 'sudo /opt/backup/azure-backup.sh'"
echo ""
echo "To check backup logs:"
echo "ssh azureuser@$PUBLIC_IP 'tail -f /var/log/azure-backup.log'"