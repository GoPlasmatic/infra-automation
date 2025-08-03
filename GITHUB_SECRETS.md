# GitHub Actions Secrets Configuration

This document lists all the GitHub Secrets and Variables required for automated deployment via GitHub Actions CI/CD pipeline.

**Note**: This infrastructure is designed to be deployed exclusively through GitHub Actions. Manual deployment is not supported.

## Quick Reference

| Secret | Required | Notes |
|--------|----------|-------|
| AZURE_CREDENTIALS | ✅ | Already available at org level |
| SSH_PUBLIC_KEY | ✅ | For VM access |
| SSH_PRIVATE_KEY | ✅ | For deployment |
| VM_ADMIN_USERNAME | ✅ | Default: azureuser |
| EMAIL_ADDRESS | ✅ | For Let's Encrypt SSL certificates |

## GitHub Actions Deployment

The following secrets are required for automated deployment via GitHub Actions:

## Required GitHub Secrets

### 1. AZURE_CREDENTIALS ✅ (Already set at org level)
Azure Service Principal credentials in JSON format:
```json
{
  "clientId": "YOUR_CLIENT_ID",
  "clientSecret": "YOUR_CLIENT_SECRET",
  "subscriptionId": "YOUR_SUBSCRIPTION_ID",
  "tenantId": "YOUR_TENANT_ID"
}
```

To create this:
```bash
az ad sp create-for-rbac --name "github-actions-sp" --role Contributor --scopes /subscriptions/YOUR_SUBSCRIPTION_ID --sdk-auth
```

### 2. SSH_PUBLIC_KEY
Your SSH public key content (not the file path). This will be used to access the VM.
```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAB... your-email@example.com
```

### 3. SSH_PRIVATE_KEY
Your SSH private key content. This will be used by GitHub Actions to deploy to the VM.
```
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEA...
-----END RSA PRIVATE KEY-----
```

### 4. VM_ADMIN_USERNAME
The admin username for the VM (default: azureuser)

### 5. EMAIL_ADDRESS 🔴 (MANDATORY)
Email address for Let's Encrypt SSL certificates. This is required as SSL setup is now automated.
```
your-email@domain.com
```
**Note**: SSL certificates are automatically configured during deployment. Use a valid email address as Let's Encrypt will send certificate expiration notices here.

## Required GitHub Variables (Repository Settings > Secrets and variables > Variables)

### 1. PROJECT_NAME
Project name (default: multi-app-server)

### 2. ENVIRONMENT
Environment name (default: production)

### 3. AZURE_LOCATION
Azure region (default: East US)

### 4. VM_SIZE
Azure VM size (default: Standard_B2s)

### 5. ALLOWED_SSH_IPS
Comma-separated list of IPs allowed to SSH (in CIDR format)
```
["YOUR_IP/32", "GITHUB_ACTIONS_IP/32"]
```

### 6. DOMAIN_NAME 🔴 (MANDATORY)
Your domain name. This is used to configure all services and SSL certificates.
```
your-domain.com
```
**Note**: All subdomains (www, grafana, webadmin, future) will be created under this domain.

### 7. CREATE_DNS_ZONE (Deprecated)
Azure DNS zone is now created automatically. This variable is no longer needed.

## Setting up Secrets in GitHub

1. Go to your repository on GitHub
2. Click on Settings > Secrets and variables > Actions
3. Add each secret using "New repository secret"
4. Add each variable using the "Variables" tab

## Summary: Mandatory Secrets

- 🔴 **MANDATORY**: SSH_PUBLIC_KEY, SSH_PRIVATE_KEY, VM_ADMIN_USERNAME, EMAIL_ADDRESS
- ✅ **AVAILABLE**: AZURE_CREDENTIALS (org level)

**Note**: 
- Terraform state storage is automatically provisioned
- SSL certificates are automatically configured during deployment
- All services will have HTTPS enabled by default

## Workflow Triggers

The workflows will trigger on:
- **Terraform**: Changes to `terraform/**` files
- **Deploy**: Changes to `docker/**` or `ansible/**` files
- **Deploy**: After successful Terraform runs

## Setup Steps for GitHub Actions

### Step 1: Verify Org-Level Secrets
- ✅ `AZURE_CREDENTIALS` - Should already be available at org level

### Step 2: Create Required Secrets (Repository Level)
1. **SSH Keys** (for VM access):
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/github_actions_key
   ```
   - Add public key as `SSH_PUBLIC_KEY`
   - Add private key as `SSH_PRIVATE_KEY`

2. **VM Admin Username**:
   - Add `VM_ADMIN_USERNAME` (default: `azureuser`)

3. **Email Address**:
   - Add `EMAIL_ADDRESS` for Let's Encrypt SSL certificates

### Step 3: Configure Variables (not secrets)
In repository settings under Variables:
- `PROJECT_NAME` (default: multi-app-server)
- `ENVIRONMENT` (default: production)
- `AZURE_LOCATION` (default: East US)
- `VM_SIZE` (default: Standard_B2s)
- `DOMAIN_NAME` (e.g., goplasmatic.io)

## Monitoring Deployments

You can monitor deployments in the Actions tab of your GitHub repository. Each workflow run will show:
- Terraform plan and apply results
- Deployment status for each component
- Health check results
- Any errors or warnings