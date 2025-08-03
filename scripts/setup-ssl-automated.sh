#!/bin/bash
set -e

# Automated SSL Certificate Setup Script
# This script sets up Let's Encrypt SSL certificates for all configured domains

# Get parameters
PUBLIC_IP=${1}
EMAIL=${2}
DOMAIN_NAME=${3}

if [ -z "$PUBLIC_IP" ] || [ -z "$EMAIL" ] || [ -z "$DOMAIN_NAME" ]; then
    echo "Usage: $0 <public_ip> <email> <domain_name>"
    exit 1
fi

echo "======================================"
echo "Automated SSL Certificate Setup"
echo "======================================"
echo "Using email: $EMAIL"
echo "Server IP: $PUBLIC_IP"
echo "Domain: $DOMAIN_NAME"
echo ""

# Function to check if DNS is pointing to our server
check_dns() {
    local domain=$1
    local dns_ip=$(dig +short $domain | tail -n1)
    
    if [ -z "$dns_ip" ]; then
        echo "Warning: DNS for $domain () does not match server IP ($PUBLIC_IP)"
        return 1
    elif [ "$dns_ip" != "$PUBLIC_IP" ]; then
        echo "Warning: DNS for $domain ($dns_ip) does not match server IP ($PUBLIC_IP)"
        return 1
    else
        echo "✓ DNS for $domain correctly points to $PUBLIC_IP"
        return 0
    fi
}

# Function to run commands either locally or via SSH
run_command() {
    if [ -f /opt/docker/docker-compose.yml ]; then
        # We're on the server, run directly
        eval "$1"
    else
        # We're remote, use SSH
        ssh -o StrictHostKeyChecking=no azureuser@$PUBLIC_IP "$1"
    fi
}

# Function to setup SSL for a service
setup_ssl_for_service() {
    local service=$1
    local domains=$2
    local primary_domain=$(echo $domains | awk '{print $1}')
    
    echo ""
    echo "Setting up SSL for $service ($domains)..."
    
    # Check if all domains are pointing to our server
    local all_dns_ready=true
    for domain in $domains; do
        if ! check_dns $domain; then
            all_dns_ready=false
        fi
    done
    
    if [ "$all_dns_ready" = false ]; then
        echo "Skipping $service - DNS not ready"
        return 1
    fi
    
    # Build domain flags for certbot
    local domain_flags=""
    for domain in $domains; do
        domain_flags="$domain_flags -d $domain"
    done
    
    # Create certbot webroot directory
    run_command "sudo mkdir -p /var/www/certbot"
    
    # First, ensure nginx is running and has the certbot webroot location
    run_command "sudo mkdir -p /var/www/certbot"
    run_command "sudo mkdir -p /opt/docker/nginx/ssl"
    
    # Try webroot method first (nginx must be running)
    if ! run_command "sudo certbot certonly --webroot --webroot-path=/var/www/certbot --non-interactive --agree-tos --email $EMAIL --expand --force-renewal $domain_flags 2>/dev/null"; then
        # If webroot fails, stop ALL services using port 80 and try standalone
        echo "Webroot method failed, stopping services and trying standalone..."
        
        # Stop nginx container
        run_command "cd /opt/docker && sudo docker compose stop nginx 2>/dev/null || true"
        
        # Also stop system nginx if running
        run_command "sudo systemctl stop nginx 2>/dev/null || true"
        
        # Wait for port to be free
        run_command "sleep 5"
        
        # Try standalone method
        if ! run_command "sudo certbot certonly --standalone --non-interactive --agree-tos --email $EMAIL --expand --force-renewal $domain_flags"; then
            echo "ERROR: Failed to obtain certificate for $service"
            # Restart services anyway
            run_command "cd /opt/docker && sudo docker compose start nginx 2>/dev/null || true"
            return 1
        fi
        
        # Restart nginx
        run_command "cd /opt/docker && sudo docker compose start nginx 2>/dev/null || true"
    fi
    
    # Copy certificates to nginx directory
    run_command "sudo mkdir -p /opt/docker/nginx/ssl"
    
    if [ "$service" = "main" ]; then
        # Main site uses default cert names
        run_command "sudo cp /etc/letsencrypt/live/$primary_domain/fullchain.pem /opt/docker/nginx/ssl/fullchain.pem"
        run_command "sudo cp /etc/letsencrypt/live/$primary_domain/privkey.pem /opt/docker/nginx/ssl/privkey.pem"
    else
        # Other services use service-specific names
        run_command "sudo cp /etc/letsencrypt/live/$primary_domain/fullchain.pem /opt/docker/nginx/ssl/${service}-fullchain.pem"
        run_command "sudo cp /etc/letsencrypt/live/$primary_domain/privkey.pem /opt/docker/nginx/ssl/${service}-privkey.pem"
    fi
    
    # Set permissions
    run_command "sudo chmod 644 /opt/docker/nginx/ssl/*.pem 2>/dev/null || true"
    
    echo "SSL setup complete for $service"
    return 0
}

echo "Starting SSL setup for all services..."

# Define services and their domains
declare -A DOMAINS
DOMAINS["main"]="www.${DOMAIN_NAME} ${DOMAIN_NAME}"
DOMAINS["grafana"]="grafana.${DOMAIN_NAME}"
DOMAINS["future"]="future.${DOMAIN_NAME}"
DOMAINS["webadmin"]="webadmin.${DOMAIN_NAME}"

# Setup SSL for each service
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
run_command "cd /opt/docker && sudo docker compose restart nginx"

# Setup auto-renewal
echo ""
echo "Setting up auto-renewal..."
run_command "sudo tee /etc/cron.daily/certbot-renew > /dev/null << 'SCRIPT'
#!/bin/bash
certbot renew --quiet --no-self-upgrade
if [ \$? -eq 0 ]; then
    cd /opt/docker && docker compose restart nginx
fi
SCRIPT"

run_command "sudo chmod +x /etc/cron.daily/certbot-renew"

echo ""
echo "======================================"
echo "SSL Setup Summary:"
echo "  Configured: $SUCCESS_COUNT/$TOTAL_COUNT services"
echo ""
echo "Next steps:"
if [ $SUCCESS_COUNT -lt $TOTAL_COUNT ]; then
    echo "  1. Update DNS records to point to $PUBLIC_IP"
    echo "  2. Wait for DNS propagation (5-30 minutes)"
    echo "  3. Re-run this script to configure remaining services"
else
    echo "  All services configured successfully!"
    echo "  HTTPS is now enabled for all domains"
fi
echo "======================================"