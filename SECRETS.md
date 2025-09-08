# Required GitHub Secrets

Configure these secrets in your GitHub repository settings:

## Azure & Infrastructure
- `AZURE_CREDENTIALS` - Service principal JSON (may be at org level)
- `SSH_PUBLIC_KEY` - For VM access
- `SSH_PRIVATE_KEY` - For deployment
- `VM_ADMIN_USERNAME` - Default: azureuser
- `EMAIL_ADDRESS` - For Let's Encrypt SSL

## Container Registry
- `ACR_URL` - Azure Container Registry URL
- `ACR_USERNAME` - ACR username
- `ACR_PASSWORD` - ACR password

## Variables
- `DOMAIN_NAME` - Your domain (e.g., goplasmatic.io)

## Generating Azure Credentials

```bash
./scripts/generate-azure-credentials.sh
```

Or manually:
```bash
az ad sp create-for-rbac \
  --name "github-actions-sp" \
  --role Contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID \
  --sdk-auth
```