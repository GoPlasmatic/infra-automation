#!/bin/bash
set -e

# Ghost CMS Infrastructure Deployment Script
# This script automates the deployment of Ghost CMS on Azure

echo "Ghost CMS Infrastructure Deployment"
echo "=================================="

# Check for required tools
command -v terraform >/dev/null 2>&1 || { echo "terraform is required but not installed. Aborting." >&2; exit 1; }
command -v ansible >/dev/null 2>&1 || { echo "ansible is required but not installed. Aborting." >&2; exit 1; }
command -v az >/dev/null 2>&1 || { echo "Azure CLI is required but not installed. Aborting." >&2; exit 1; }

# Set variables
ENVIRONMENT=${1:-production}
TERRAFORM_DIR="terraform"
ANSIBLE_DIR="ansible"

# Function to handle errors
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# Step 1: Azure Login Check
echo "Checking Azure authentication..."
if ! az account show >/dev/null 2>&1; then
    echo "Please login to Azure:"
    az login || error_exit "Azure login failed"
fi

# Step 2: Terraform Deployment
echo ""
echo "Deploying infrastructure with Terraform..."
cd $TERRAFORM_DIR

# Initialize Terraform
terraform init || error_exit "Terraform initialization failed"

# Create workspace if it doesn't exist
terraform workspace select $ENVIRONMENT 2>/dev/null || terraform workspace new $ENVIRONMENT

# Plan deployment
echo "Planning infrastructure changes..."
terraform plan -var-file="environments/$ENVIRONMENT/terraform.tfvars" -out=tfplan || error_exit "Terraform plan failed"

# Apply deployment
read -p "Do you want to apply these changes? (yes/no): " confirm
if [[ $confirm == "yes" ]]; then
    terraform apply tfplan || error_exit "Terraform apply failed"
else
    echo "Deployment cancelled."
    exit 0
fi

# Get outputs
PUBLIC_IP=$(terraform output -raw public_ip_address)
echo "VM Public IP: $PUBLIC_IP"

cd ..

# Step 3: Wait for VM to be ready
echo ""
echo "Waiting for VM to be ready..."
max_attempts=30
attempt=0
while ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 azureuser@$PUBLIC_IP "echo 'VM is ready'" 2>/dev/null; do
    attempt=$((attempt + 1))
    if [ $attempt -ge $max_attempts ]; then
        error_exit "VM is not accessible after $max_attempts attempts"
    fi
    echo "Waiting for VM to accept SSH connections... (attempt $attempt/$max_attempts)"
    sleep 10
done

# Step 4: Run Ansible Playbook
echo ""
echo "Configuring VM with Ansible..."
cd $ANSIBLE_DIR

# Create dynamic inventory
cat > inventory/dynamic.yml <<EOF
all:
  hosts:
    ghost-server:
      ansible_host: $PUBLIC_IP
      ansible_user: azureuser
      ansible_ssh_private_key_file: ~/.ssh/id_rsa
      ansible_python_interpreter: /usr/bin/python3
EOF

# Run the playbook
ansible-playbook -i inventory/dynamic.yml playbook.yml || error_exit "Ansible playbook failed"

cd ..

# Step 5: Build website locally
echo ""
echo "Building website..."
./scripts/build-website.sh || error_exit "Website build failed"

# Step 6: Copy website files to server
echo ""
echo "Copying website files to server..."
rsync -avz --delete ../website/build/ azureuser@$PUBLIC_IP:/opt/website/build/ || error_exit "Website file copy failed"

# Step 7: Deploy with Docker Compose
echo ""
echo "Deploying services..."
ssh azureuser@$PUBLIC_IP "cd /opt/website && sudo docker compose up -d" || error_exit "Docker Compose deployment failed"

# Final message
echo ""
echo "=================================="
echo "Deployment completed successfully!"
echo "=================================="
echo ""
echo "Ghost CMS is now accessible at:"
echo "HTTP: http://$PUBLIC_IP"
echo "HTTPS: https://your-domain.com (after DNS configuration)"
echo ""
echo "Next steps:"
echo "1. Configure your DNS to point to: $PUBLIC_IP"
echo "2. Run the SSL setup script: ./scripts/setup-ssl.sh"
echo "3. Access Ghost admin at: https://your-domain.com/ghost"