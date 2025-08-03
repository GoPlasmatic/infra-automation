# GitHub Actions Workflows

This directory contains all the CI/CD workflows for automated deployment.

## Workflows

### 1. terraform.yml
- **Trigger**: Changes to `terraform/**` files
- **Purpose**: Provisions and manages Azure infrastructure
- **Environment**: production
- **Key Steps**:
  - Terraform init with remote backend
  - Terraform plan
  - Terraform apply (on main branch only)
  - Saves outputs for other workflows

### 2. deploy.yml
- **Trigger**: 
  - Changes to `docker/**` or `ansible/**` files
  - After successful Terraform runs
- **Purpose**: Deploys application updates to the VM
- **Key Features**:
  - Detects which components changed
  - Only deploys changed components
  - Runs health checks after deployment

### 3. initial-setup.yml
- **Trigger**: 
  - Manual workflow dispatch
  - After successful Terraform runs (first time)
- **Purpose**: Initial VM configuration
- **Key Steps**:
  - Creates directory structure
  - Clones website repository
  - Starts all services
  - Configures SSL certificates

## Deployment Flow

1. **Infrastructure Changes**:
   ```
   Push terraform changes → terraform.yml → Provisions/Updates Azure resources
   ```

2. **Application Changes**:
   ```
   Push docker/app changes → deploy.yml → Deploys only changed components
   ```

3. **Initial Setup**:
   ```
   Run manually or after first terraform → initial-setup.yml → Configures new VM
   ```

## Component-based Deployment

The deploy workflow intelligently detects changes:
- **Website**: Changes to `Dockerfile.website` or website section in docker-compose
- **Nginx**: Changes to nginx configuration files
- **Monitoring**: Changes to Prometheus configuration
- **Ghost**: Changes to Ghost configuration (when enabled)

## Health Checks

All workflows include health checks:
- Website: Port 3000
- Nginx: Port 80
- Grafana: Port 3001
- Prometheus: Port 9090
- Ghost: Port 2368 (when enabled)

## Secrets Required

See [GITHUB_SECRETS.md](../../GITHUB_SECRETS.md) for complete list.

## Running Workflows

### Manual Trigger
```bash
# Via GitHub CLI
gh workflow run initial-setup.yml

# Via GitHub UI
Actions → Select workflow → Run workflow
```

### Monitoring
- Check Actions tab for workflow status
- Each job shows detailed logs
- Failed deployments don't affect running services

## Best Practices

1. **Test locally first**: Validate docker-compose changes locally
2. **Use PR workflow**: Test infrastructure changes in PR before merging
3. **Monitor health checks**: Ensure services are healthy after deployment
4. **Check logs**: Review workflow logs for any warnings

## Troubleshooting

### Common Issues

1. **SSH Connection Failed**:
   - Check SSH_PRIVATE_KEY secret
   - Verify VM public IP hasn't changed

2. **Docker Build Failed**:
   - Check Dockerfile syntax
   - Ensure base images are accessible

3. **Health Checks Failed**:
   - Services may need more time to start
   - Check service logs on VM

### Debugging

SSH into VM to check services:
```bash
ssh -i ~/.ssh/your-key azureuser@VM_IP
cd /opt/docker
sudo docker-compose ps
sudo docker-compose logs <service>
```