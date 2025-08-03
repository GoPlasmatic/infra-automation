#!/bin/bash

# Script to generate Azure credentials for GitHub Actions
# This creates a service principal with the correct format

set -e

echo "=== Azure Service Principal Generator for GitHub Actions ==="
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed. Please install it first:"
    echo "   https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Login to Azure
echo "📝 Logging into Azure..."
az login

# Get subscription list
echo ""
echo "📋 Available subscriptions:"
az account list --output table

# Prompt for subscription
echo ""
read -p "Enter your Subscription ID: " SUBSCRIPTION_ID

# Set the subscription
az account set --subscription "$SUBSCRIPTION_ID"

# Confirm subscription
SUB_NAME=$(az account show --query name -o tsv)
echo "✅ Using subscription: $SUB_NAME"

# Generate service principal
echo ""
echo "🔐 Creating service principal..."
SP_NAME="github-actions-sp-$(date +%s)"

# Create service principal with Contributor role
CREDS=$(az ad sp create-for-rbac \
  --name "$SP_NAME" \
  --role Contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID \
  --sdk-auth)

# Display the credentials
echo ""
echo "✅ Service principal created successfully!"
echo ""
echo "=== AZURE_CREDENTIALS Secret Value ==="
echo "Copy the JSON below and add it as a GitHub secret:"
echo ""
echo "$CREDS"
echo ""
echo "=== Instructions ==="
echo "1. Go to your GitHub repository"
echo "2. Navigate to Settings > Secrets and variables > Actions"
echo "3. Click 'New repository secret'"
echo "4. Name: AZURE_CREDENTIALS"
echo "5. Value: Paste the JSON above (including the curly braces)"
echo "6. Click 'Add secret'"
echo ""
echo "📝 Note: If using organization-level secrets:"
echo "   - Add to Organization Settings > Secrets instead"
echo "   - Grant repository access to the secret"
echo ""
echo "🔒 Security: This service principal has Contributor access to your subscription."
echo "   Consider using more restrictive permissions for production."

# Save to file optionally
read -p "Save credentials to file? (y/n): " SAVE_TO_FILE
if [[ $SAVE_TO_FILE =~ ^[Yy]$ ]]; then
    FILENAME="azure-credentials-$(date +%Y%m%d-%H%M%S).json"
    echo "$CREDS" > "$FILENAME"
    echo "✅ Saved to: $FILENAME"
    echo "⚠️  Remember to delete this file after adding to GitHub!"
fi