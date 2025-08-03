#!/bin/bash
set -e

# Automated SSL Setup Script for GitHub Actions
# This script sets up SSL certificates for all configured domains

echo "======================================"
echo "Automated SSL Certificate Setup"
echo "======================================"

# Get parameters
PUBLIC_IP=${1}
EMAIL=${2}
DOMAIN_NAME=${3}

if [ -z "$PUBLIC_IP" ] || [ -z "$EMAIL" ] || [ -z "$DOMAIN_NAME" ]; then
    echo "Error: Missing required parameters"
    echo "Usage: $0 <public_ip> <email> <domain_name>"
    exit 1
fi

echo "Using email: $EMAIL"
echo "Server IP: $PUBLIC_IP"
echo "Domain: $DOMAIN_NAME"

# Define all domains that need SSL based on the base domain
declare -A DOMAINS=(
    ["main"]="www.${DOMAIN_NAME} ${DOMAIN_NAME}"
    ["grafana"]="grafana.${DOMAIN_NAME}"
    ["future"]="future.${DOMAIN_NAME}"
    ["webadmin"]="webadmin.${DOMAIN_NAME}"
)

# Function to check DNS
check_dns() {
    local domain=$1
    local dns_ip=$(dig +short $domain @8.8.8.8 | tail -n1)
    
    if [ "$dns_ip" = "$PUBLIC_IP" ]; then
        return 0
    else
        echo "Warning: DNS for $domain ($dns_ip) does not match server IP ($PUBLIC_IP)"
        return 1
    fi
}

# Function to setup SSL for a service
setup_ssl_for_service() {
    local service=$1
    local domains=$2
    local primary_domain=$(echo $domains | cut -d' ' -f1)
    
    echo ""
    echo "Setting up SSL for $service ($domains)..."
    
    # Check DNS for all domains
    local dns_ready=true
    for domain in $domains; do
        if ! check_dns $domain; then
            dns_ready=false
        fi
    done
    
    if [ "$dns_ready" = false ]; then
        echo "Skipping $service - DNS not ready"
        return 1
    fi
    
    # Generate domain flags for certbot
    local domain_flags=""
    for domain in $domains; do
        domain_flags="$domain_flags -d $domain"
    done
    
    # SSH into server and setup SSL
    ssh -o StrictHostKeyChecking=no azureuser@$PUBLIC_IP << EOF
        set -e
        
        # Create certbot webroot directory
        sudo mkdir -p /var/www/certbot
        
        # Get SSL certificate using webroot method (nginx must be running)
        sudo certbot certonly --webroot \
            --webroot-path=/var/www/certbot \
            --non-interactive \
            --agree-tos \
            --email $EMAIL \
            --expand \
            --force-renewal \
            $domain_flags || {
                # If webroot fails, try standalone (stops nginx temporarily)
                echo "Webroot method failed, trying standalone..."
                cd /opt/docker && sudo docker compose stop nginx
                sudo certbot certonly --standalone \
                    --non-interactive \
                    --agree-tos \
                    --email $EMAIL \
                    --expand \
                    --force-renewal \
                    $domain_flags
                cd /opt/docker && sudo docker compose start nginx
            }
        
        # Copy certificates to nginx directory
        sudo mkdir -p /opt/docker/nginx/ssl
        
        if [ "$service" = "main" ]; then
            # Main site uses default cert names
            sudo cp /etc/letsencrypt/live/$primary_domain/fullchain.pem /opt/docker/nginx/ssl/fullchain.pem
            sudo cp /etc/letsencrypt/live/$primary_domain/privkey.pem /opt/docker/nginx/ssl/privkey.pem
        else
            # Other services use service-specific names
            sudo cp /etc/letsencrypt/live/$primary_domain/fullchain.pem /opt/docker/nginx/ssl/${service}-fullchain.pem
            sudo cp /etc/letsencrypt/live/$primary_domain/privkey.pem /opt/docker/nginx/ssl/${service}-privkey.pem
        fi
        
        # Set permissions
        sudo chmod 644 /opt/docker/nginx/ssl/*.pem
        
        echo "SSL setup complete for $service"
EOF
    
    return 0
}

# Setup SSL for each service
echo ""
echo "Starting SSL setup for all services..."

SUCCESS_COUNT=0
TOTAL_COUNT=${#DOMAINS[@]}

for service in "${!DOMAINS[@]}"; do
    if setup_ssl_for_service "$service" "${DOMAINS[$service]}"; then
        ((SUCCESS_COUNT++))
        echo "✅ $service: SSL configured successfully"
    else
        echo "⚠️  $service: SSL setup skipped (DNS not ready)"
    fi
done

# Restart nginx to apply all certificates
echo ""
echo "Restarting nginx to apply certificates..."
ssh -o StrictHostKeyChecking=no azureuser@$PUBLIC_IP << 'EOF'
    cd /opt/docker && sudo docker compose restart nginx
EOF

# Setup auto-renewal
echo ""
echo "Setting up auto-renewal..."
ssh -o StrictHostKeyChecking=no azureuser@$PUBLIC_IP << 'EOF'
    # Create renewal script
    sudo tee /etc/cron.daily/certbot-renew > /dev/null << 'SCRIPT'
#!/bin/bash
certbot renew --quiet --no-self-upgrade
if [ $? -eq 0 ]; then
    cd /opt/docker && docker compose restart nginx
fi
SCRIPT
    
    sudo chmod +x /etc/cron.daily/certbot-renew
    echo "Auto-renewal configured"
EOF

echo ""
echo "======================================"
echo "SSL Setup Summary:"
echo "  Configured: $SUCCESS_COUNT/$TOTAL_COUNT services"
echo "  Email: $EMAIL"
echo "======================================"

if [ $SUCCESS_COUNT -lt $TOTAL_COUNT ]; then
    echo ""
    echo "⚠️  Warning: Some services were skipped due to DNS issues."
    echo "   Please ensure all DNS records are configured and propagated."
    echo "   You can re-run this script later to configure remaining services."
    exit 0  # Don't fail the deployment
fi

echo ""
echo "✅ All SSL certificates configured successfully!"