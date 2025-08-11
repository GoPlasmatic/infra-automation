#!/bin/bash
set -e

# Script to configure nginx with the correct domain names
# This replaces hardcoded domains with the actual domain from environment

DOMAIN_NAME=${1}

if [ -z "$DOMAIN_NAME" ]; then
    echo "Error: Domain name is required"
    echo "Usage: $0 <domain_name>"
    exit 1
fi

echo "Configuring nginx for domain: $DOMAIN_NAME"

# Update nginx configurations
cd /opt/docker/nginx/sites-enabled

# Update website.conf
if [ -f "website.conf" ]; then
    echo "Updating website.conf..."
    sudo sed -i "s/goplasmatic\.io/${DOMAIN_NAME}/g" website.conf
fi

# Update grafana.conf
if [ -f "grafana.conf" ]; then
    echo "Updating grafana.conf..."
    sudo sed -i "s/goplasmatic\.io/${DOMAIN_NAME}/g" grafana.conf
fi

# Update future.conf
if [ -f "future.conf" ]; then
    echo "Updating future.conf..."
    sudo sed -i "s/goplasmatic\.io/${DOMAIN_NAME}/g" future.conf
fi

# Update ghost-admin.conf
if [ -f "ghost-admin.conf" ]; then
    echo "Updating ghost-admin.conf..."
    sudo sed -i "s/goplasmatic\.io/${DOMAIN_NAME}/g" ghost-admin.conf
fi

# Update reframeapi.conf
if [ -f "reframeapi.conf" ]; then
    echo "Updating reframeapi.conf..."
    sudo sed -i "s/goplasmatic\.io/${DOMAIN_NAME}/g" reframeapi.conf
fi

# Update Ghost environment variables in docker-compose.yml
cd /opt/docker
if [ -f "docker-compose.yml" ]; then
    echo "Updating Ghost URLs in docker-compose.yml..."
    sudo sed -i "s/future\.goplasmatic\.io/future.${DOMAIN_NAME}/g" docker-compose.yml
    sudo sed -i "s/webadmin\.goplasmatic\.io/webadmin.${DOMAIN_NAME}/g" docker-compose.yml
fi

echo "Domain configuration complete!"