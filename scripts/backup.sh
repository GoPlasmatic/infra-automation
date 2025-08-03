#!/bin/bash
set -e

# Ghost CMS Backup Script
# This script creates backups of Ghost data and uploads to Azure Blob Storage

echo "Ghost CMS Backup"
echo "================"

# Configuration
PUBLIC_IP=${1}
STORAGE_ACCOUNT=${2}
CONTAINER_NAME=${3:-ghost-backups}

if [ -z "$PUBLIC_IP" ] || [ -z "$STORAGE_ACCOUNT" ]; then
    echo "Usage: $0 <public_ip> <storage_account> [container_name]"
    echo "Example: $0 1.2.3.4 mystorageaccount ghost-backups"
    exit 1
fi

# Create backup on the server
echo "Creating backup on server..."
ssh azureuser@$PUBLIC_IP << 'EOF'
    set -e
    
    # Create backup directory
    sudo mkdir -p /tmp/ghost-backup
    cd /tmp/ghost-backup
    
    # Backup Ghost content
    sudo docker exec ghost_cms tar -czf - /var/lib/ghost/content > ghost-content.tar.gz
    
    # Backup MySQL database
    sudo docker exec ghost_db mysqldump -u root -p${MYSQL_ROOT_PASSWORD} ghost_production > ghost-db.sql
    gzip ghost-db.sql
    
    # Create archive
    DATE=$(date +%Y%m%d_%H%M%S)
    sudo tar -czf ghost-backup-${DATE}.tar.gz ghost-content.tar.gz ghost-db.sql.gz
    
    echo "Backup created: ghost-backup-${DATE}.tar.gz"
EOF

# Download backup
echo "Downloading backup..."
BACKUP_FILE=$(ssh azureuser@$PUBLIC_IP "ls -t /tmp/ghost-backup/ghost-backup-*.tar.gz | head -1")
scp azureuser@$PUBLIC_IP:$BACKUP_FILE ./

# Get storage key from Terraform output
echo "Getting storage credentials..."
STORAGE_KEY=$(cd terraform && terraform output -raw storage_account_key)

# Upload to Azure Blob Storage
echo "Uploading to Azure Blob Storage..."
FILENAME=$(basename $BACKUP_FILE)
az storage blob upload \
    --account-name $STORAGE_ACCOUNT \
    --account-key $STORAGE_KEY \
    --container-name $CONTAINER_NAME \
    --name $FILENAME \
    --file $FILENAME

# Cleanup
rm -f $FILENAME
ssh azureuser@$PUBLIC_IP "sudo rm -rf /tmp/ghost-backup"

echo ""
echo "Backup completed successfully!"
echo "File uploaded to: $STORAGE_ACCOUNT/$CONTAINER_NAME/$FILENAME"