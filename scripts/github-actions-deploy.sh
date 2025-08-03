#!/bin/bash
set -e

# GitHub Actions Deployment Script
# This script handles deployment from GitHub Actions to the VM

echo "Deploying from GitHub Actions"
echo "============================="

# Parse arguments
VM_IP=$1
COMPONENT=$2
ACTION=${3:-deploy}

if [ -z "$VM_IP" ] || [ -z "$COMPONENT" ]; then
    echo "Usage: $0 <vm_ip> <component> [action]"
    echo "Components: website, nginx, monitoring, ghost, all"
    echo "Actions: deploy (default), restart, health-check"
    exit 1
fi

# Function to check service health
check_health() {
    local service=$1
    local port=$2
    local path=${3:-/}
    
    echo "Checking health of $service..."
    if curl -f -s -o /dev/null "http://$VM_IP:$port$path"; then
        echo "✓ $service is healthy"
        return 0
    else
        echo "✗ $service is not responding"
        return 1
    fi
}

# Function to deploy website
deploy_website() {
    echo "Deploying website..."
    
    # Sync website files
    rsync -avz --delete \
        -e "ssh -o StrictHostKeyChecking=no" \
        ../website/ azureuser@$VM_IP:/opt/website/
    
    # Rebuild and restart container
    ssh -o StrictHostKeyChecking=no azureuser@$VM_IP << 'EOF'
        cd /opt/docker
        sudo docker-compose build website
        sudo docker-compose up -d website
        
        # Wait for service to start
        sleep 10
EOF
    
    check_health "Website" 3000
}

# Function to deploy nginx
deploy_nginx() {
    echo "Deploying Nginx configuration..."
    
    # Sync nginx configuration
    rsync -avz \
        -e "ssh -o StrictHostKeyChecking=no" \
        docker/nginx/ azureuser@$VM_IP:/opt/docker/nginx/
    
    # Test and reload nginx
    ssh -o StrictHostKeyChecking=no azureuser@$VM_IP << 'EOF'
        cd /opt/docker
        
        # Test configuration
        sudo docker exec nginx nginx -t
        
        # Reload nginx
        sudo docker-compose restart nginx
EOF
    
    check_health "Nginx" 80
}

# Function to deploy monitoring
deploy_monitoring() {
    echo "Deploying monitoring stack..."
    
    # Sync prometheus configuration
    rsync -avz \
        -e "ssh -o StrictHostKeyChecking=no" \
        docker/prometheus/ azureuser@$VM_IP:/opt/docker/prometheus/
    
    # Restart monitoring services
    ssh -o StrictHostKeyChecking=no azureuser@$VM_IP << 'EOF'
        cd /opt/docker
        sudo docker-compose restart prometheus grafana node_exporter cadvisor
EOF
    
    sleep 10
    check_health "Grafana" 3001
}

# Function to deploy Ghost
deploy_ghost() {
    echo "Deploying Ghost CMS..."
    
    ssh -o StrictHostKeyChecking=no azureuser@$VM_IP << 'EOF'
        cd /opt/docker
        
        # Enable Ghost in docker-compose if not already enabled
        if ! grep -q "^ghost:" docker-compose.yml; then
            echo "Enabling Ghost CMS..."
            # This would need proper sed commands to uncomment Ghost sections
        fi
        
        # Update and restart Ghost
        sudo docker-compose pull ghost
        sudo docker-compose up -d ghost ghost_db
        
        # Enable nginx configs for Ghost
        if [ -f nginx/sites-enabled/ghost-admin.conf.disabled ]; then
            sudo mv nginx/sites-enabled/ghost-admin.conf.disabled nginx/sites-enabled/ghost-admin.conf
        fi
        
        if [ -f nginx/sites-enabled/future.conf.disabled ]; then
            sudo mv nginx/sites-enabled/future.conf.disabled nginx/sites-enabled/future.conf
        fi
        
        sudo docker-compose restart nginx
EOF
    
    sleep 20
    check_health "Ghost" 2368 "/ghost"
}

# Function to run all health checks
run_health_checks() {
    echo "Running health checks..."
    
    local all_healthy=true
    
    check_health "Website" 3000 || all_healthy=false
    check_health "Nginx" 80 || all_healthy=false
    check_health "Grafana" 3001 || all_healthy=false
    check_health "Prometheus" 9090 "/-/healthy" || all_healthy=false
    
    # Check Ghost if enabled
    if ssh -o StrictHostKeyChecking=no azureuser@$VM_IP "cd /opt/docker && grep -q '^ghost:' docker-compose.yml"; then
        check_health "Ghost" 2368 "/ghost" || all_healthy=false
    fi
    
    if [ "$all_healthy" = true ]; then
        echo ""
        echo "All services are healthy!"
        return 0
    else
        echo ""
        echo "Some services are not healthy!"
        return 1
    fi
}

# Main execution
case "$ACTION" in
    deploy)
        case "$COMPONENT" in
            website)
                deploy_website
                ;;
            nginx)
                deploy_nginx
                ;;
            monitoring)
                deploy_monitoring
                ;;
            ghost)
                deploy_ghost
                ;;
            all)
                deploy_website
                deploy_nginx
                deploy_monitoring
                ;;
            *)
                echo "Unknown component: $COMPONENT"
                exit 1
                ;;
        esac
        ;;
    restart)
        ssh -o StrictHostKeyChecking=no azureuser@$VM_IP << EOF
            cd /opt/docker
            sudo docker-compose restart $COMPONENT
EOF
        ;;
    health-check)
        run_health_checks
        ;;
    *)
        echo "Unknown action: $ACTION"
        exit 1
        ;;
esac

echo ""
echo "Deployment completed!"