# Azure Container Registry Usage Guide

## Overview
The infrastructure includes a cost-optimized Azure Container Registry (ACR) using the Basic tier, which costs approximately $5/month and provides:
- 10 GB of storage
- 2 webhooks
- Sufficient performance for internal deployments

## Registry Details
- **Name**: PlasmaticContainerRegistry
- **SKU**: Basic (most cost-effective)
- **Admin Access**: Enabled for simple authentication

## How to Use the Registry

### 1. Get Registry Credentials
After Terraform deployment, retrieve the credentials:

```bash
# Get the login server URL
terraform output -raw acr_login_server

# Get the admin username (usually the registry name)
terraform output -raw acr_admin_username

# Get the admin password (sensitive output)
terraform output -raw acr_admin_password
```

### 2. Login to the Registry

#### From Local Machine:
```bash
# Using Azure CLI
az acr login --name PlasmaticContainerRegistry

# Or using Docker directly
docker login plasmaticcontainerregistry.azurecr.io \
  -u PlasmaticContainerRegistry \
  -p <admin_password>
```

#### From the VM:
```bash
# SSH into the VM
ssh azureuser@<vm_public_ip>

# Login to ACR
sudo docker login plasmaticcontainerregistry.azurecr.io \
  -u PlasmaticContainerRegistry \
  -p <admin_password>
```

### 3. Push Images to Registry

```bash
# Tag your local image
docker tag myapp:latest plasmaticcontainerregistry.azurecr.io/myapp:latest

# Push to registry
docker push plasmaticcontainerregistry.azurecr.io/myapp:latest
```

### 4. Pull Images in Docker Compose

Update your `docker-compose.yml` to use ACR images:

```yaml
services:
  myapp:
    image: plasmaticcontainerregistry.azurecr.io/myapp:latest
    # ... rest of configuration
```

### 5. Configure GitHub Actions for ACR

Add these secrets to your GitHub repository:
- `ACR_LOGIN_SERVER`: plasmaticcontainerregistry.azurecr.io
- `ACR_USERNAME`: PlasmaticContainerRegistry
- `ACR_PASSWORD`: (admin password from Terraform output)

Example GitHub Actions workflow:

```yaml
- name: Login to ACR
  uses: docker/login-action@v2
  with:
    registry: ${{ secrets.ACR_LOGIN_SERVER }}
    username: ${{ secrets.ACR_USERNAME }}
    password: ${{ secrets.ACR_PASSWORD }}

- name: Build and push
  uses: docker/build-push-action@v4
  with:
    push: true
    tags: ${{ secrets.ACR_LOGIN_SERVER }}/myapp:${{ github.sha }}
```

## Cost Optimization Tips

1. **Clean up old images regularly** to stay within 10GB storage limit:
   ```bash
   az acr repository delete --name PlasmaticContainerRegistry --repository myapp --tag old-tag
   ```

2. **Use image layers efficiently** - base images should be reused across services

3. **Monitor storage usage**:
   ```bash
   az acr show-usage --name PlasmaticContainerRegistry --output table
   ```

## Security Considerations

1. The registry uses admin credentials for simplicity and cost-effectiveness
2. For production, consider:
   - Rotating admin passwords regularly
   - Using service principals for CI/CD (requires Standard tier)
   - Restricting network access to only your VM's IP

## Troubleshooting

### Authentication Issues
```bash
# Regenerate admin credentials if needed
az acr credential renew --name PlasmaticContainerRegistry --password-name password
```

### Storage Limit Reached
```bash
# List all repositories and their sizes
az acr repository list --name PlasmaticContainerRegistry --output table

# Delete unused repositories
az acr repository delete --name PlasmaticContainerRegistry --repository unused-repo
```

### Pull Rate Limits
Basic tier has sufficient limits for small teams:
- 100 pulls per minute
- Adequate for internal VM deployments