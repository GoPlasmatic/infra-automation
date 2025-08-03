#\!/bin/bash

# Get Azure DNS nameservers for your domain
DOMAIN_NAME="goplasmatic.io"
RESOURCE_GROUP="multi-app-server-production-rg"

echo "Getting Azure DNS nameservers for $DOMAIN_NAME..."
echo ""

# Check if az CLI is installed
if \! command -v az &> /dev/null; then
    echo "Azure CLI not installed. Please install it first."
    exit 1
fi

# Get nameservers
NAMESERVERS=$(az network dns zone show \
    --resource-group $RESOURCE_GROUP \
    --name $DOMAIN_NAME \
    --query nameServers \
    --output tsv 2>/dev/null)

if [ -z "$NAMESERVERS" ]; then
    echo "Error: Could not retrieve nameservers. Make sure:"
    echo "  1. You're logged in to Azure (az login)"
    echo "  2. The DNS zone exists in resource group $RESOURCE_GROUP"
    echo "  3. You have permissions to access the resource"
else
    echo "Azure DNS Nameservers for $DOMAIN_NAME:"
    echo "========================================"
    echo "$NAMESERVERS" | tr '\t' '\n' | nl -w2 -s'. '
    echo ""
    echo "Update these nameservers in GoDaddy:"
    echo "1. Log in to GoDaddy"
    echo "2. Go to Domain Settings for $DOMAIN_NAME"
    echo "3. Select 'Manage DNS'"
    echo "4. Click 'Change Nameservers'"
    echo "5. Choose 'Enter my own nameservers (advanced)'"
    echo "6. Remove existing nameservers"
    echo "7. Add the 4 Azure nameservers listed above"
    echo "8. Save changes"
fi
