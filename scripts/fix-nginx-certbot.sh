#!/bin/bash

# Update all nginx configs to include certbot configuration

cd /opt/docker/nginx/sites-enabled

for conf in *.conf; do
    echo "Updating $conf..."
    
    # Add certbot include after the first server_name in port 80 blocks
    sudo sed -i '/listen 80;/,/^}/ {
        /server_name/a\
\
    # Let'"'"'s Encrypt verification\
    include /etc/nginx/snippets/certbot.conf;\
    
    }' "$conf"
done

echo "All nginx configs updated with certbot support"