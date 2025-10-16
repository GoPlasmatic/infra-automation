#!/bin/bash
set -e

# Comprehensive Backup Script for All Services
# Backs up all Docker volumes, configs, and critical files before deployment

echo "========================================"
echo "Comprehensive Infrastructure Backup"
echo "========================================"

# Configuration
PUBLIC_IP=${1}
STORAGE_ACCOUNT=${2}
CONTAINER_NAME=${3:-infrastructure-backups}
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/tmp/backup-${BACKUP_DATE}"

if [ -z "$PUBLIC_IP" ] || [ -z "$STORAGE_ACCOUNT" ]; then
    echo "Usage: $0 <public_ip> <storage_account> [container_name]"
    echo "Example: $0 20.169.212.253 stmultiapppro6do9 infrastructure-backups"
    exit 1
fi

echo "Server IP: $PUBLIC_IP"
echo "Storage Account: $STORAGE_ACCOUNT"
echo "Container: $CONTAINER_NAME"
echo "Backup Date: $BACKUP_DATE"
echo ""

# Create backup on the server
echo "Step 1/5: Creating backup directory on server..."
ssh azureuser@$PUBLIC_IP << EOF
    set -e
    sudo mkdir -p ${BACKUP_DIR}
    cd ${BACKUP_DIR}
    echo "Backup directory created: ${BACKUP_DIR}"
EOF

echo "Step 2/5: Backing up Docker volumes and databases..."
ssh azureuser@$PUBLIC_IP << 'SCRIPT'
    set -e
    cd /tmp/backup-*

    echo "  - Backing up Ghost MySQL database..."
    # Backup Ghost MySQL database with credentials from .env
    source /opt/docker/.env
    sudo docker exec ghost_db mysqldump -u root -p${GHOST_MYSQL_ROOT_PASSWORD} ghost_production > ghost-db.sql 2>/dev/null || \
        sudo docker exec ghost_db mysqldump -u root -pajQtVKFljU8PhSUCgtaOtGFzh ghost_production > ghost-db.sql
    gzip ghost-db.sql
    echo "    ✓ Ghost database backed up"

    echo "  - Backing up Ghost content files..."
    sudo docker exec ghost_cms tar -czf - /var/lib/ghost/content > ghost-content.tar.gz 2>/dev/null || true
    echo "    ✓ Ghost content backed up"

    echo "  - Backing up Grafana data volume..."
    sudo docker run --rm -v docker_grafana_data:/data -v $(pwd):/backup alpine tar czf /backup/grafana-data.tar.gz -C /data .
    echo "    ✓ Grafana data backed up"

    echo "  - Backing up Prometheus data volume..."
    sudo docker run --rm -v docker_prometheus_data:/data -v $(pwd):/backup alpine tar czf /backup/prometheus-data.tar.gz -C /data .
    echo "    ✓ Prometheus data backed up"

    echo "  - Backing up nginx logs volume..."
    sudo docker run --rm -v docker_nginx_logs:/data -v $(pwd):/backup alpine tar czf /backup/nginx-logs.tar.gz -C /data . 2>/dev/null || true
    echo "    ✓ Nginx logs backed up"
SCRIPT

echo "Step 3/5: Backing up configuration files..."
ssh azureuser@$PUBLIC_IP << 'SCRIPT'
    set -e
    cd /tmp/backup-*

    echo "  - Backing up nginx configs..."
    sudo tar czf nginx-configs.tar.gz -C /opt/docker/nginx .
    echo "    ✓ Nginx configs backed up"

    echo "  - Backing up docker-compose and .env..."
    sudo tar czf docker-configs.tar.gz -C /opt/docker docker-compose.yml .env
    echo "    ✓ Docker configs backed up"

    echo "  - Creating backup manifest..."
    cat > backup-manifest.txt << 'MANIFEST'
Backup Manifest
===============
Date: $(date)
Server: $(hostname)

Contents:
- ghost-db.sql.gz: Ghost MySQL database dump
- ghost-content.tar.gz: Ghost content files (/var/lib/ghost/content)
- grafana-data.tar.gz: Grafana data volume
- prometheus-data.tar.gz: Prometheus data volume
- nginx-logs.tar.gz: Nginx logs volume
- nginx-configs.tar.gz: Nginx configuration files
- docker-configs.tar.gz: Docker Compose and environment files

Docker Container Status at Backup Time:
----------------------------------------
MANIFEST
    sudo docker ps --format "{{.Names}}: {{.Status}}" >> backup-manifest.txt

    echo "    ✓ Manifest created"
SCRIPT

echo "Step 4/5: Creating consolidated backup archive..."
ssh azureuser@$PUBLIC_IP << EOF
    set -e
    cd /tmp/backup-*

    # Create final archive
    BACKUP_FILE="infrastructure-backup-${BACKUP_DATE}.tar.gz"
    sudo tar czf \${BACKUP_FILE} *.gz *.txt

    # Set permissions for download
    sudo chmod 644 \${BACKUP_FILE}

    echo "Backup archive created: \${BACKUP_FILE}"
    ls -lh \${BACKUP_FILE}
EOF

# Download backup
echo "Step 5/5: Downloading backup locally and uploading to Azure..."
BACKUP_FILE="infrastructure-backup-${BACKUP_DATE}.tar.gz"
LOCAL_BACKUP_DIR="./backups"
mkdir -p $LOCAL_BACKUP_DIR

echo "  - Downloading from server..."
scp azureuser@$PUBLIC_IP:${BACKUP_DIR}/${BACKUP_FILE} ${LOCAL_BACKUP_DIR}/

# Ensure Azure Blob Storage container exists
echo "  - Ensuring Azure Storage container exists..."
az storage container create \
    --name $CONTAINER_NAME \
    --account-name $STORAGE_ACCOUNT \
    --auth-mode login \
    --only-show-errors > /dev/null 2>&1 || true

# Upload to Azure Blob Storage
echo "  - Uploading to Azure Blob Storage..."
az storage blob upload \
    --account-name $STORAGE_ACCOUNT \
    --container-name $CONTAINER_NAME \
    --name $BACKUP_FILE \
    --file ${LOCAL_BACKUP_DIR}/${BACKUP_FILE} \
    --auth-mode login \
    --overwrite

# Cleanup server backup
echo "  - Cleaning up server backup directory..."
ssh azureuser@$PUBLIC_IP "sudo rm -rf ${BACKUP_DIR}"

# Calculate file sizes
LOCAL_SIZE=$(du -h ${LOCAL_BACKUP_DIR}/${BACKUP_FILE} | cut -f1)

echo ""
echo "========================================"
echo "✅ BACKUP COMPLETED SUCCESSFULLY"
echo "========================================"
echo "Backup file: $BACKUP_FILE"
echo "Local copy: ${LOCAL_BACKUP_DIR}/${BACKUP_FILE} (${LOCAL_SIZE})"
echo "Azure location: ${STORAGE_ACCOUNT}/${CONTAINER_NAME}/${BACKUP_FILE}"
echo ""
echo "Backup includes:"
echo "  - Ghost MySQL database"
echo "  - Ghost content files"
echo "  - Grafana data"
echo "  - Prometheus data"
echo "  - Nginx configurations"
echo "  - Docker Compose files"
echo "  - Nginx logs"
echo ""
echo "To restore from this backup:"
echo "  1. Download: az storage blob download --account-name ${STORAGE_ACCOUNT} --container-name ${CONTAINER_NAME} --name ${BACKUP_FILE} --file ${BACKUP_FILE} --auth-mode login"
echo "  2. Extract and restore volumes as needed"
echo "========================================"

exit 0
