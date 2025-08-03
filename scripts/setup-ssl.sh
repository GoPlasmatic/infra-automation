#!/bin/bash
set -e

# SSL Setup Script for Multi-Application Server
# This script configures Let's Encrypt SSL certificates

echo "Multi-Application SSL Setup"
echo "==========================="

# Get parameters
SERVICE=${1}
DOMAIN_NAME=${2}
EMAIL=${3}
PUBLIC_IP=${4}

if [ -z "$SERVICE" ] || [ -z "$DOMAIN_NAME" ] || [ -z "$EMAIL" ] || [ -z "$PUBLIC_IP" ]; then
    echo "Usage: $0 <service> <domain_name> <email> <public_ip>"
    echo "Services: main, grafana, future, webadmin"
    echo "Example: $0 main www.yourdomain.com your-email@domain.com 1.2.3.4"
    echo "Example: $0 grafana grafana.yourdomain.com your-email@domain.com 1.2.3.4"
    echo "Example: $0 future future.yourdomain.com your-email@domain.com 1.2.3.4"
    exit 1
fi

# Check DNS
echo "Checking DNS configuration..."
DNS_IP=$(dig +short $DOMAIN_NAME @8.8.8.8 | tail -n1)
if [ "$DNS_IP" != "$PUBLIC_IP" ]; then
    echo "Warning: DNS for $DOMAIN_NAME ($DNS_IP) does not point to $PUBLIC_IP"
    read -p "Continue anyway? (yes/no): " confirm
    if [[ $confirm != "yes" ]]; then
        exit 1
    fi
fi

# SSH into the server and setup SSL
echo "Configuring SSL on the server..."
ssh azureuser@$PUBLIC_IP << EOF
    set -e
    
    # Stop nginx temporarily
    sudo systemctl stop nginx || true
    
    # Get SSL certificate
    sudo certbot certonly --standalone \
        --non-interactive \
        --agree-tos \
        --email $EMAIL \
        -d $DOMAIN_NAME \
        -d www.$DOMAIN_NAME
    
    # Copy certificates to nginx directory
    sudo mkdir -p /opt/ghost/nginx/ssl
    sudo cp /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem /opt/ghost/nginx/ssl/
    sudo cp /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem /opt/ghost/nginx/ssl/
    sudo chmod 644 /opt/ghost/nginx/ssl/*.pem
    
    # Update Ghost URL in docker-compose
    cd /opt/ghost
    sudo sed -i "s|DOMAIN_NAME=.*|DOMAIN_NAME=$DOMAIN_NAME|" .env
    
    # Restart services
    sudo docker compose down
    sudo docker compose up -d
    
    # Setup auto-renewal
    echo "0 0,12 * * * root certbot renew --quiet --post-hook 'docker restart ghost_nginx'" | sudo tee /etc/cron.d/certbot-renew
EOF

echo ""
echo "SSL setup completed!"
echo "==================="
echo ""
echo "Your Ghost CMS is now accessible at:"
echo "https://$DOMAIN_NAME"
echo "https://www.$DOMAIN_NAME"
echo ""
echo "Admin panel: https://$DOMAIN_NAME/ghost"