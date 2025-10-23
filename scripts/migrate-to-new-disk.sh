#!/bin/bash
# Disk Migration Script - Move all application data to new disk
# This script will:
# 1. Identify disk usage to understand what's consuming space
# 2. Format and mount the new disk
# 3. Stop containers
# 4. Move all application data to new disk
# 5. Update configurations
# 6. Restart services

set -e

echo "========================================="
echo "DISK MIGRATION SCRIPT"
echo "========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NEW_DISK_MOUNT="/mnt/appdata"
DOCKER_DATA_ROOT="${NEW_DISK_MOUNT}/docker"
APP_DATA_ROOT="${NEW_DISK_MOUNT}/applications"

echo -e "${GREEN}Step 1: Analyzing current disk usage${NC}"
echo "========================================="
echo "Current disk status:"
df -h
echo ""
echo "Detailed space analysis:"
echo "Top disk consumers:"
du -sh /* 2>/dev/null | sort -hr | head -15
echo ""
echo "Docker-specific usage:"
if [ -d "/var/lib/docker" ]; then
    echo "Total Docker size:"
    du -sh /var/lib/docker 2>/dev/null || echo "Cannot access Docker directory"
    echo ""
    echo "Docker subdirectories:"
    du -sh /var/lib/docker/* 2>/dev/null | sort -hr | head -10
fi
echo ""
echo "Application data:"
if [ -d "/opt/docker" ]; then
    du -sh /opt/docker/* 2>/dev/null | sort -hr
fi
echo ""
echo "System logs:"
du -sh /var/log/* 2>/dev/null | sort -hr | head -10
echo ""

read -p "Press Enter to continue with disk identification..."

echo -e "${GREEN}Step 2: Identifying available disks${NC}"
echo "========================================="
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE
echo ""

# Auto-detect the new unmounted disk
NEW_DISK=$(lsblk -ndpo NAME,TYPE,MOUNTPOINT | awk '$2=="disk" && $3=="" {print $1; exit}')

if [ -z "$NEW_DISK" ]; then
    echo -e "${RED}No unmounted disk found!${NC}"
    echo "Please specify the disk manually:"
    read -p "Enter disk device (e.g., /dev/sdc): " NEW_DISK
fi

echo -e "${YELLOW}Using disk: $NEW_DISK${NC}"
read -p "Is this correct? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

echo -e "${GREEN}Step 3: Formatting and partitioning new disk${NC}"
echo "========================================="
# Create partition
echo "Creating partition on $NEW_DISK..."
(
echo g # Create GPT partition table
echo n # New partition
echo 1 # Partition number
echo   # Default first sector
echo   # Default last sector
echo w # Write changes
) | fdisk $NEW_DISK

# Get partition name (e.g., /dev/sdc1)
PARTITION="${NEW_DISK}1"
# Wait for partition to be recognized
sleep 2
partprobe $NEW_DISK || true
sleep 2

# Format with ext4
echo "Formatting $PARTITION with ext4..."
mkfs.ext4 -F $PARTITION

echo -e "${GREEN}Step 4: Mounting new disk${NC}"
echo "========================================="
mkdir -p $NEW_DISK_MOUNT
mount $PARTITION $NEW_DISK_MOUNT

# Verify mount
if mountpoint -q $NEW_DISK_MOUNT; then
    echo -e "${GREEN}Disk successfully mounted at $NEW_DISK_MOUNT${NC}"
else
    echo -e "${RED}Failed to mount disk!${NC}"
    exit 1
fi

# Create directory structure
mkdir -p $DOCKER_DATA_ROOT
mkdir -p $APP_DATA_ROOT
mkdir -p $APP_DATA_ROOT/ghost/content
mkdir -p $APP_DATA_ROOT/backups

echo "New disk structure created:"
ls -la $NEW_DISK_MOUNT

echo -e "${GREEN}Step 5: Stopping Docker containers${NC}"
echo "========================================="
cd /opt/docker
docker compose down

echo -e "${GREEN}Step 6: Moving Docker volumes data${NC}"
echo "========================================="
echo "Stopping Docker service temporarily..."
systemctl stop docker

if [ -d "/var/lib/docker" ]; then
    echo "Moving Docker data to new disk..."
    rsync -avP /var/lib/docker/ $DOCKER_DATA_ROOT/

    echo "Backing up original Docker directory..."
    mv /var/lib/docker /var/lib/docker.backup.$(date +%Y%m%d_%H%M%S)
fi

echo -e "${GREEN}Step 7: Moving application data${NC}"
echo "========================================="
# Move Ghost content if exists
if [ -d "/opt/applications/ghost/data/content" ]; then
    echo "Moving Ghost CMS content..."
    mkdir -p $APP_DATA_ROOT/ghost
    rsync -avP /opt/applications/ghost/data/content/ $APP_DATA_ROOT/ghost/content/
fi

# Move any existing application data
if [ -d "/opt/applications" ]; then
    echo "Backing up /opt/applications..."
    rsync -avP /opt/applications/ $APP_DATA_ROOT/
fi

echo -e "${GREEN}Step 8: Configuring Docker to use new disk${NC}"
echo "========================================="
# Configure Docker daemon to use new data root
cat > /etc/docker/daemon.json <<EOF
{
  "data-root": "$DOCKER_DATA_ROOT",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

echo "Docker daemon configuration updated:"
cat /etc/docker/daemon.json

echo -e "${GREEN}Step 9: Updating fstab for persistent mounting${NC}"
echo "========================================="
# Get UUID of the partition
UUID=$(blkid -s UUID -o value $PARTITION)
echo "Partition UUID: $UUID"

# Backup fstab
cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d_%H%M%S)

# Add to fstab if not already there
if ! grep -q "$UUID" /etc/fstab; then
    echo "UUID=$UUID $NEW_DISK_MOUNT ext4 defaults,nofail 0 2" >> /etc/fstab
    echo "Added to /etc/fstab"
else
    echo "Entry already exists in /etc/fstab"
fi

echo -e "${GREEN}Step 10: Creating symlinks for compatibility${NC}"
echo "========================================="
# Create symlink for Docker data
ln -sf $DOCKER_DATA_ROOT /var/lib/docker

# Update application paths in docker directory
if [ -d "/opt/applications" ]; then
    mv /opt/applications /opt/applications.backup.$(date +%Y%m%d_%H%M%S)
fi
ln -sf $APP_DATA_ROOT /opt/applications

echo "Symlinks created:"
ls -la /var/lib/docker
ls -la /opt/applications

echo -e "${GREEN}Step 11: Starting Docker service${NC}"
echo "========================================="
systemctl start docker
sleep 5
docker info | grep "Docker Root Dir"

echo -e "${GREEN}Step 12: Verifying disk space${NC}"
echo "========================================="
df -h
echo ""
echo "New disk usage:"
du -sh $NEW_DISK_MOUNT/*

echo -e "${GREEN}Step 13: Starting containers${NC}"
echo "========================================="
cd /opt/docker
docker compose up -d

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}MIGRATION COMPLETE!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Summary:"
echo "- New disk mounted at: $NEW_DISK_MOUNT"
echo "- Docker data root: $DOCKER_DATA_ROOT"
echo "- Application data: $APP_DATA_ROOT"
echo ""
echo "Disk usage after migration:"
df -h
echo ""
echo -e "${YELLOW}IMPORTANT: Monitor the containers${NC}"
echo "Run: docker compose ps"
echo "Run: docker compose logs -f"
echo ""
echo -e "${YELLOW}To clean up old backup data (after verification):${NC}"
echo "sudo rm -rf /var/lib/docker.backup.*"
echo "sudo rm -rf /opt/applications.backup.*"
