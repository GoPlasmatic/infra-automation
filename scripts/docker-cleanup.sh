#!/bin/bash
#
# Docker Cleanup Script
# Removes unused Docker resources to free up disk space
#
# Usage:
#   ./docker-cleanup.sh [--aggressive]
#
# Options:
#   --aggressive    Perform more aggressive cleanup (prunes all unused images, not just dangling ones)
#

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running in aggressive mode
AGGRESSIVE=false
if [[ "$1" == "--aggressive" ]]; then
    AGGRESSIVE=true
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Docker Cleanup Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Show disk space before cleanup
echo -e "${YELLOW}Disk space BEFORE cleanup:${NC}"
df -h / | grep -E "Filesystem|/dev/root"
echo ""

# Show Docker disk usage before cleanup
echo -e "${YELLOW}Docker disk usage BEFORE cleanup:${NC}"
sudo docker system df
echo ""

# 1. Remove stopped containers
echo -e "${GREEN}[1/6] Removing stopped containers...${NC}"
STOPPED=$(sudo docker container prune -f 2>&1 | grep "Total reclaimed space" || echo "0B")
echo "  ✓ $STOPPED"
echo ""

# 2. Remove dangling images (untagged)
echo -e "${GREEN}[2/6] Removing dangling images...${NC}"
DANGLING=$(sudo docker image prune -f 2>&1 | grep "Total reclaimed space" || echo "0B")
echo "  ✓ $DANGLING"
echo ""

# 3. Remove unused images (if aggressive mode)
if [ "$AGGRESSIVE" = true ]; then
    echo -e "${GREEN}[3/6] Removing ALL unused images (aggressive mode)...${NC}"
    IMAGES=$(sudo docker image prune -a -f 2>&1 | grep "Total reclaimed space" || echo "0B")
    echo "  ✓ $IMAGES"
else
    echo -e "${YELLOW}[3/6] Skipping unused images cleanup (use --aggressive to enable)${NC}"
fi
echo ""

# 4. Remove unused volumes
echo -e "${GREEN}[4/6] Removing unused volumes...${NC}"
VOLUMES=$(sudo docker volume prune -f 2>&1 | grep "Total reclaimed space" || echo "0B")
echo "  ✓ $VOLUMES"
echo ""

# 5. Remove build cache
echo -e "${GREEN}[5/6] Removing build cache...${NC}"
BUILD_CACHE=$(sudo docker builder prune -f 2>&1 | grep "Total:" || echo "Total: 0B")
echo "  ✓ $BUILD_CACHE"
echo ""

# 6. Truncate large container log files (> 100MB)
echo -e "${GREEN}[6/6] Truncating large container log files (> 100MB)...${NC}"
LOG_COUNT=0
LOG_SIZE_FREED=0

for log in /var/lib/docker/containers/*/*-json.log; do
    if [ -f "$log" ]; then
        LOG_SIZE=$(stat -f%z "$log" 2>/dev/null || stat -c%s "$log" 2>/dev/null)
        # Convert to MB
        LOG_SIZE_MB=$((LOG_SIZE / 1024 / 1024))

        if [ "$LOG_SIZE_MB" -gt 100 ]; then
            echo "  Truncating: $(basename $(dirname $log)) (${LOG_SIZE_MB}MB)"
            sudo truncate -s 0 "$log"
            LOG_COUNT=$((LOG_COUNT + 1))
            LOG_SIZE_FREED=$((LOG_SIZE_FREED + LOG_SIZE_MB))
        fi
    fi
done

if [ $LOG_COUNT -eq 0 ]; then
    echo "  ✓ No large log files found"
else
    echo "  ✓ Truncated $LOG_COUNT log files, freed ${LOG_SIZE_FREED}MB"
fi
echo ""

# Show disk space after cleanup
echo -e "${GREEN}========================================${NC}"
echo -e "${YELLOW}Disk space AFTER cleanup:${NC}"
df -h / | grep -E "Filesystem|/dev/root"
echo ""

# Show Docker disk usage after cleanup
echo -e "${YELLOW}Docker disk usage AFTER cleanup:${NC}"
sudo docker system df
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Cleanup completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Tips:${NC}"
echo "  - Run with --aggressive to remove ALL unused images"
echo "  - Consider running this script weekly via cron"
echo "  - Monitor disk usage with: df -h /"
echo "  - Monitor Docker usage with: docker system df"
echo ""
