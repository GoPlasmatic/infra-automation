# Pre-Deployment Validation Checklist

Follow this checklist before pushing to GitHub to ensure successful deployment.

## 1. Local Script Validation

### Bash Scripts Syntax Check
```bash
# Check all shell scripts for syntax errors
for script in scripts/*.sh; do
  echo "Checking $script..."
  bash -n "$script"
done
```

### Terraform Validation
```bash
cd terraform/environments/production
terraform init
terraform validate
terraform fmt -check
```

### Docker Compose Validation
```bash
cd docker
docker compose config
```

### Ansible Playbook Validation
```bash
cd ansible
ansible-playbook playbooks/deploy.yml --syntax-check
```

## 2. GitHub Secrets Verification

### Required Secrets (Must be set before deployment)
- [ ] `SSH_PUBLIC_KEY` - Your SSH public key for VM access
- [ ] `SSH_PRIVATE_KEY` - Your SSH private key for deployment
- [ ] `VM_ADMIN_USERNAME` - Admin username (default: azureuser)
- [ ] `EMAIL_ADDRESS` - Email for SSL certificates

### Verify Org-Level Secret
- [ ] `AZURE_CREDENTIALS` - Should already exist at org level

### Required Variables (Repository Settings > Variables)
- [ ] `DOMAIN_NAME` - Your domain (e.g., yourdomain.com)
- [ ] `PROJECT_NAME` - Project name (default: multi-app-server)
- [ ] `ENVIRONMENT` - Environment (default: production)
- [ ] `AZURE_LOCATION` - Azure region (default: East US)
- [ ] `VM_SIZE` - VM size (default: Standard_B2s)

## 3. Domain Preparation

### DNS Readiness
- [ ] Domain registered and accessible
- [ ] Access to DNS management panel
- [ ] Ready to create A records after VM deployment

## 4. Local Testing Commands

### Test Domain Variable Substitution
```bash
# Test nginx configuration script
DOMAIN_NAME="test-domain.com" bash -n scripts/configure-nginx-domains.sh

# Test SSL setup script
DOMAIN_NAME="test-domain.com" EMAIL_ADDRESS="test@email.com" bash -n scripts/setup-ssl-automated.sh
```

### Verify File Permissions
```bash
# Ensure scripts are executable
chmod +x scripts/*.sh
ls -la scripts/
```

## 5. Configuration Review

### Check Environment Files
```bash
# Verify .env.example has all required variables
cat docker/.env.example | grep -E "DOMAIN|EMAIL"

# Verify terraform variables
cat terraform/environments/production/terraform.tfvars.example
```

## 6. Git Status Review

### Check Modified Files
```bash
git status
git diff --staged
```

### Files That Should Be Modified
- [ ] `/scripts/setup-ssl-automated.sh` (new)
- [ ] `/scripts/configure-nginx-domains.sh` (new)
- [ ] `/terraform/state-storage.tf` (new)
- [ ] `/.github/workflows/deploy.yml` (updated)
- [ ] `/docker/docker-compose.yml` (updated)
- [ ] `/GITHUB_SECRETS.md` (updated)
- [ ] Various nginx configs (updated)
- [ ] Documentation files (updated)

## 7. Deployment Order

Once pushed, GitHub Actions will:
1. **Terraform Workflow**:
   - Create state storage automatically
   - Provision Azure infrastructure
   - Output VM public IP

2. **Deploy Workflow** (triggers after Terraform):
   - Configure nginx with your domain
   - Set up Docker services
   - Configure SSL certificates automatically
   - Start all services

## 8. Post-Deployment Steps

### After GitHub Actions Complete
1. Get public IP from Terraform output
2. Update DNS A records:
   ```
   A  @          <PUBLIC_IP>
   A  www        <PUBLIC_IP>
   A  grafana    <PUBLIC_IP>
   A  webadmin   <PUBLIC_IP>
   A  future     <PUBLIC_IP>
   ```
3. Wait for DNS propagation (5-30 minutes)
4. Access services:
   - https://www.{your-domain}
   - https://grafana.{your-domain}
   - https://webadmin.{your-domain}/ghost
   - https://future.{your-domain}

## 9. Troubleshooting Resources

- GitHub Actions logs in the Actions tab
- SSH into VM: `ssh -i ~/.ssh/your_key username@public_ip`
- Docker logs: `sudo docker compose logs`
- Nginx logs: `sudo docker compose logs nginx`

## 10. Final Checks

- [ ] All scripts pass syntax validation
- [ ] All required secrets are documented
- [ ] Domain name is ready
- [ ] Email address for SSL is valid
- [ ] You understand the deployment flow

## Ready to Deploy?

If all checks pass:
```bash
git add .
git commit -m "Automated infrastructure setup with domain configuration"
git push origin main
```

Then monitor the GitHub Actions tab for deployment progress.