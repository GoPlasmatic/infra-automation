#!/bin/bash
# Disk Usage Analysis Script
# Shows what's consuming disk space to help with future capacity planning

echo "========================================="
echo "DISK USAGE ANALYSIS"
echo "========================================="
echo "Date: $(date)"
echo ""

echo "1. OVERALL DISK USAGE"
echo "========================================="
df -h
echo ""

echo "2. TOP-LEVEL DIRECTORY SIZES"
echo "========================================="
echo "This shows which top-level directories are using the most space:"
du -sh /* 2>/dev/null | sort -hr | head -20
echo ""

echo "3. DOCKER DISK USAGE"
echo "========================================="
if command -v docker &> /dev/null; then
    echo "Docker system usage:"
    docker system df -v 2>/dev/null || echo "Could not get Docker stats"
    echo ""

    echo "Docker directory breakdown:"
    if [ -d "/var/lib/docker" ]; then
        echo "Total Docker directory size:"
        du -sh /var/lib/docker 2>/dev/null
        echo ""
        echo "Docker subdirectories:"
        du -sh /var/lib/docker/* 2>/dev/null | sort -hr
        echo ""
        echo "Docker volumes:"
        du -sh /var/lib/docker/volumes/* 2>/dev/null | sort -hr | head -15
    fi
else
    echo "Docker not installed or not accessible"
fi
echo ""

echo "4. APPLICATION DATA USAGE"
echo "========================================="
if [ -d "/opt/docker" ]; then
    echo "/opt/docker contents:"
    du -sh /opt/docker/* 2>/dev/null | sort -hr
fi

if [ -d "/opt/applications" ]; then
    echo ""
    echo "/opt/applications contents:"
    du -sh /opt/applications/* 2>/dev/null | sort -hr
fi
echo ""

echo "5. SYSTEM LOGS USAGE"
echo "========================================="
echo "Log directory sizes:"
du -sh /var/log/* 2>/dev/null | sort -hr | head -15
echo ""
echo "Journal logs size:"
journalctl --disk-usage 2>/dev/null || echo "Could not get journal disk usage"
echo ""

echo "6. LARGEST FILES ON SYSTEM"
echo "========================================="
echo "Top 20 largest files:"
find / -type f -size +100M -exec ls -lh {} \; 2>/dev/null | awk '{ print $9 ": " $5 }' | sort -k2 -hr | head -20
echo ""

echo "7. INODE USAGE"
echo "========================================="
df -i
echo ""

echo "8. RECOMMENDATIONS FOR SPACE MANAGEMENT"
echo "========================================="
echo "Based on typical issues, consider:"
echo "1. Configure log rotation with limits:"
echo "   - Docker logs: Set max-size and max-file in daemon.json"
echo "   - System logs: Configure logrotate"
echo ""
echo "2. Regular Docker cleanup:"
echo "   docker system prune -a --volumes  # Removes unused data"
echo ""
echo "3. Monitor these directories regularly:"
echo "   - /var/lib/docker/overlay2 (container layers)"
echo "   - /var/lib/docker/volumes (persistent data)"
echo "   - /var/log (system and application logs)"
echo ""
echo "4. Set up automated cleanup cron jobs"
echo ""

echo "========================================="
echo "Analysis complete!"
echo "========================================="
