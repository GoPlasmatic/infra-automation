#!/bin/bash
# Emergency Nginx Fix Script
# Removes problematic config files that cause duplicate upstream errors

set -e

echo "========================================"
echo "Emergency Nginx Fix"
echo "========================================"

RESOURCE_GROUP="multi-app-server-production-rg"
VM_NAME="multi-app-server-production-vm"

echo "Fixing nginx configuration on production server..."

az vm run-command invoke \
    -g $RESOURCE_GROUP \
    -n $VM_NAME \
    --command-id RunShellScript \
    --scripts '
        echo "Step 1: Removing problematic config files..."
        sudo rm -f /opt/docker/nginx/sites-enabled/future.conf
        sudo rm -f /opt/docker/nginx/sites-enabled/*.conf.disabled
        sudo rm -f /opt/docker/nginx/sites-enabled/*-old.conf

        echo "Step 2: Removing from running container..."
        if sudo docker ps | grep -q main_nginx; then
            sudo docker exec main_nginx sh -c "rm -f /etc/nginx/sites-enabled/future.conf 2>/dev/null" || true
            sudo docker exec main_nginx sh -c "rm -f /etc/nginx/sites-enabled/*.disabled 2>/dev/null" || true
        fi

        echo "Step 3: Restarting nginx..."
        cd /opt/docker
        sudo docker compose restart nginx

        echo "Step 4: Waiting for nginx to stabilize..."
        sleep 10

        echo "Step 5: Checking status..."
        if sudo docker ps | grep -q "main_nginx.*healthy"; then
            echo "✅ Nginx is healthy"
        else
            echo "⚠ Nginx status unclear, checking logs..."
            sudo docker logs main_nginx --tail 20
        fi

        echo "Step 6: Listing final config files..."
        ls -la /opt/docker/nginx/sites-enabled/
    ' \
    --query 'value[0].message' -o tsv

echo ""
echo "========================================"
echo "Fix completed!"
echo "========================================"
echo ""
echo "Verify the website is accessible:"
echo "  curl -I http://20.169.212.253"
echo "  curl -I https://www.goplasmatic.io"
