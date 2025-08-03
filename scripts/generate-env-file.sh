#!/bin/bash

# Generate a secure .env file for deployment

DOMAIN_NAME=${1:-goplasmatic.io}

# Generate secure passwords
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

cat > docker/.env << EOF
# Domain configuration
DOMAIN_NAME=${DOMAIN_NAME}

# Ghost CMS configuration
GHOST_MYSQL_ROOT_PASSWORD=$(generate_password)
GHOST_MYSQL_DATABASE=ghost_production
GHOST_MYSQL_USER=ghost
GHOST_MYSQL_PASSWORD=$(generate_password)

# Mail configuration (update these with your mail service)
MAIL_SERVICE=Mailgun
MAIL_USER=postmaster@mg.${DOMAIN_NAME}
MAIL_PASS=your_mailgun_password_here
MAIL_FROM=noreply@${DOMAIN_NAME}

# Backup configuration
BACKUP_RETENTION_DAYS=7

# Monitoring configuration
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=$(generate_password)
EOF

echo "Generated docker/.env file with secure passwords"
echo ""
echo "IMPORTANT: Update the MAIL_* settings with your actual email service credentials"
echo ""
echo "To use this file:"
echo "1. Review and update email settings in docker/.env"
echo "2. Commit the file: git add docker/.env && git commit -m 'Add environment configuration'"
echo "3. Push to deploy: git push origin main"