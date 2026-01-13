#!/bin/bash
# Don't exit on error - handle errors gracefully
set +e

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
        echo "Warning: DNS for $domain not resolving"
        return 1
    elif [ "$dns_ip" != "$PUBLIC_IP" ]; then
        echo "Warning: DNS for $domain ($dns_ip) does not match server IP ($PUBLIC_IP)"
        return 1
    else
        echo "✓ DNS for $domain correctly points to $PUBLIC_IP"
        return 0
    fi
}

# Function to get the certificate path from certbot for a domain
get_cert_path() {
    local domain=$1
    # Use certbot certificates to get the actual path (needs sudo to read certbot state)
    local cert_path=$(sudo certbot certificates 2>/dev/null | grep -A4 "Domains:.*${domain}" | grep "Certificate Path:" | awk '{print $3}')
    if [ -n "$cert_path" ] && [ -f "$cert_path" ]; then
        echo "$cert_path"
        return 0
    fi

    # Fallback: find the directory with highest suffix (needs sudo for /etc/letsencrypt/live/)
    local cert_dir=$(sudo ls -d /etc/letsencrypt/live/${domain}* 2>/dev/null | sort -V | tail -1)
    if [ -n "$cert_dir" ] && sudo test -f "${cert_dir}/fullchain.pem"; then
        echo "${cert_dir}/fullchain.pem"
        return 0
    fi

    return 1
}

# Function to copy certificates to nginx
copy_certs_to_nginx() {
    local service=$1
    local primary_domain=$2

    echo "Looking for certificate for $primary_domain..."

    # Get the certificate path using certbot
    local fullchain_path=$(get_cert_path "$primary_domain")

    if [ -z "$fullchain_path" ]; then
        echo "ERROR: Could not find certificate for $primary_domain"
        return 1
    fi

    local cert_dir=$(dirname "$fullchain_path")
    echo "Found certificate directory: $cert_dir"

    # Show certificate expiry
    echo "Certificate expiry: $(openssl x509 -enddate -noout -in $fullchain_path 2>/dev/null || echo 'unknown')"

    # Copy certificates
    sudo mkdir -p /opt/docker/nginx/ssl

    if [ "$service" = "main" ]; then
        echo "Copying to /opt/docker/nginx/ssl/fullchain.pem and privkey.pem"
        sudo cp "$cert_dir/fullchain.pem" /opt/docker/nginx/ssl/fullchain.pem
        sudo cp "$cert_dir/privkey.pem" /opt/docker/nginx/ssl/privkey.pem
    else
        echo "Copying to /opt/docker/nginx/ssl/${service}-fullchain.pem and ${service}-privkey.pem"
        sudo cp "$cert_dir/fullchain.pem" "/opt/docker/nginx/ssl/${service}-fullchain.pem"
        sudo cp "$cert_dir/privkey.pem" "/opt/docker/nginx/ssl/${service}-privkey.pem"
    fi

    # Verify copy
    local target_cert="/opt/docker/nginx/ssl/fullchain.pem"
    if [ "$service" != "main" ]; then
        target_cert="/opt/docker/nginx/ssl/${service}-fullchain.pem"
    fi

    if [ -f "$target_cert" ]; then
        echo "Nginx cert expiry: $(openssl x509 -enddate -noout -in $target_cert 2>/dev/null)"
        return 0
    else
        echo "ERROR: Failed to copy certificate"
        return 1
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

    # Create required directories
    sudo mkdir -p /var/www/certbot
    sudo mkdir -p /opt/docker/nginx/ssl

    # Check if a valid certificate already exists
    local existing_cert=$(get_cert_path "$primary_domain")
    if [ -n "$existing_cert" ]; then
        # Check if certificate is still valid for more than 30 days
        if openssl x509 -checkend 2592000 -noout -in "$existing_cert" 2>/dev/null; then
            echo "Certificate for $service is valid for more than 30 days."
            echo "Ensuring nginx has the latest certificate..."
            copy_certs_to_nginx "$service" "$primary_domain"
            return $?
        else
            echo "Certificate for $service expiring soon. Renewing..."
        fi
    else
        echo "No existing certificate found for $service. Obtaining new certificate..."
    fi

    # Try webroot method first (nginx must be running)
    echo "Attempting certificate request via webroot..."
    if ! sudo certbot certonly --webroot --webroot-path=/var/www/certbot \
        --non-interactive --agree-tos --email "$EMAIL" --expand $domain_flags 2>/dev/null; then

        echo "Webroot method failed, stopping nginx and trying standalone..."

        # Stop nginx container
        cd /opt/docker && sudo docker compose stop nginx 2>/dev/null || true
        sudo systemctl stop nginx 2>/dev/null || true
        sleep 5

        # Try standalone method
        if ! sudo certbot certonly --standalone \
            --non-interactive --agree-tos --email "$EMAIL" --expand $domain_flags; then
            echo "ERROR: Failed to obtain certificate for $service"
            cd /opt/docker && sudo docker compose start nginx 2>/dev/null || true
            return 1
        fi

        # Restart nginx
        cd /opt/docker && sudo docker compose start nginx 2>/dev/null || true
    fi

    # Copy the certificate to nginx
    copy_certs_to_nginx "$service" "$primary_domain"
    return $?
}

echo "Starting SSL setup for all services..."

# Define services and their domains
declare -A DOMAINS
DOMAINS["main"]="www.${DOMAIN_NAME} ${DOMAIN_NAME}"
DOMAINS["grafana"]="grafana.${DOMAIN_NAME}"
DOMAINS["webadmin"]="webadmin.${DOMAIN_NAME}"
DOMAINS["reframeapi"]="reframeapi.${DOMAIN_NAME}"

# Setup SSL for each service
SUCCESS_COUNT=0
TOTAL_COUNT=${#DOMAINS[@]}

for service in "${!DOMAINS[@]}"; do
    echo ""
    echo "Processing $service..."
    if setup_ssl_for_service "$service" "${DOMAINS[$service]}"; then
        ((SUCCESS_COUNT++))
        echo "✅ $service: SSL configured successfully"
    else
        echo "⚠️  $service: SSL setup failed or skipped"
    fi
done

# Set permissions on all certificates
sudo chmod 644 /opt/docker/nginx/ssl/*.pem 2>/dev/null || true

# Restart nginx to apply all certificates
echo ""
echo "Restarting nginx to apply certificates..."
cd /opt/docker && sudo docker compose restart nginx 2>/dev/null || echo "Nginx restart failed"

# Wait for nginx to start and verify
sleep 3
if sudo docker ps | grep -q "nginx.*Up"; then
    echo "✓ Nginx is running"
else
    echo "WARNING: Nginx may not be running properly"
fi

# Setup auto-renewal cron job
echo ""
echo "Setting up auto-renewal..."
sudo tee /etc/cron.daily/certbot-renew > /dev/null << 'SCRIPT'
#!/bin/bash
certbot renew --quiet --no-self-upgrade
if [ $? -eq 0 ]; then
    # Copy renewed certs to nginx directory
    for domain_dir in /etc/letsencrypt/live/*/; do
        domain=$(basename "$domain_dir")
        if [[ "$domain" == www.* ]]; then
            cp "${domain_dir}fullchain.pem" /opt/docker/nginx/ssl/fullchain.pem 2>/dev/null
            cp "${domain_dir}privkey.pem" /opt/docker/nginx/ssl/privkey.pem 2>/dev/null
        fi
    done
    chmod 644 /opt/docker/nginx/ssl/*.pem 2>/dev/null
    cd /opt/docker && docker compose restart nginx
fi
SCRIPT

sudo chmod +x /etc/cron.daily/certbot-renew

echo ""
echo "======================================"
echo "SSL Setup Summary:"
echo "  Configured: $SUCCESS_COUNT/$TOTAL_COUNT services"
echo ""
if [ $SUCCESS_COUNT -lt $TOTAL_COUNT ]; then
    echo "  Some services failed. Check logs above for details."
else
    echo "  All services configured successfully!"
    echo "  HTTPS is now enabled for all domains"
fi
echo "======================================"

# Exit successfully if at least one certificate was obtained
if [ $SUCCESS_COUNT -gt 0 ]; then
    exit 0
else
    exit 1
fi
