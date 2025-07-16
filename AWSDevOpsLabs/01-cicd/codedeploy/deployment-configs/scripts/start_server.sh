#!/bin/bash

# CodeDeploy ApplicationStart Hook Script
# This script starts the web server and related services

set -e

echo "Starting ApplicationStart hook..."
echo "Timestamp: $(date)"

# Function to check if service is running
check_service() {
    local service_name=$1
    if systemctl is-active --quiet $service_name; then
        echo "$service_name is running"
        return 0
    else
        echo "$service_name is not running"
        return 1
    fi
}

# Function to wait for service to start
wait_for_service() {
    local service_name=$1
    local max_attempts=30
    local attempt=1
    
    echo "Waiting for $service_name to start..."
    while [ $attempt -le $max_attempts ]; do
        if check_service $service_name; then
            echo "$service_name started successfully"
            return 0
        fi
        echo "Attempt $attempt/$max_attempts: $service_name not ready, waiting..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo "Error: $service_name failed to start after $max_attempts attempts"
    return 1
}

# Start Apache HTTP Server
echo "Starting Apache HTTP Server..."
systemctl start httpd

# Enable Apache to start on boot
echo "Enabling Apache to start on boot..."
systemctl enable httpd

# Wait for Apache to start
if ! wait_for_service httpd; then
    echo "Error: Failed to start Apache"
    exit 1
fi

# Check Apache configuration
echo "Testing Apache configuration..."
if ! httpd -t; then
    echo "Error: Apache configuration test failed"
    systemctl status httpd
    exit 1
fi

# Verify web server is responding
echo "Verifying web server is responding..."
max_attempts=10
attempt=1

while [ $attempt -le $max_attempts ]; do
    if curl -f -s http://localhost/ > /dev/null; then
        echo "Web server is responding successfully"
        break
    elif [ $attempt -eq $max_attempts ]; then
        echo "Error: Web server is not responding after $max_attempts attempts"
        echo "Apache status:"
        systemctl status httpd
        echo "Apache error log:"
        tail -20 /var/log/httpd/error_log
        exit 1
    else
        echo "Attempt $attempt/$max_attempts: Web server not responding, waiting..."
        sleep 3
        attempt=$((attempt + 1))
    fi
done

# Create deployment marker file
echo "Creating deployment marker..."
cat > /var/www/html/deployment-info.json << EOF
{
    "deploymentId": "${DEPLOYMENT_ID:-unknown}",
    "deploymentGroupName": "${DEPLOYMENT_GROUP_NAME:-unknown}",
    "applicationName": "${APPLICATION_NAME:-unknown}",
    "deploymentTime": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "instanceId": "$(curl -s http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo 'unknown')",
    "status": "deployed"
}
EOF

chown apache:apache /var/www/html/deployment-info.json

# Update the main index.html with deployment information
if [ -f "/var/www/html/index.html" ]; then
    echo "Updating index.html with deployment information..."
    
    # Add deployment timestamp to the page
    sed -i "s/<span id=\"deploy-time\"><\/span>/<span id=\"deploy-time\">$(date)<\/span>/g" /var/www/html/index.html
    
    # Update deployment status
    sed -i "s/Initial Deployment/CodeDeploy Deployment - $(date)/g" /var/www/html/index.html
fi

# Log deployment success
echo "Deployment completed successfully" >> /var/log/codedeploy/deployment.log
echo "Timestamp: $(date)" >> /var/log/codedeploy/deployment.log
echo "Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo 'unknown')" >> /var/log/codedeploy/deployment.log

# Send deployment notification (if SNS topic is configured)
if [ ! -z "${SNS_TOPIC_ARN}" ]; then
    echo "Sending deployment notification..."
    aws sns publish \
        --topic-arn "${SNS_TOPIC_ARN}" \
        --message "CodeDeploy deployment completed successfully on instance $(curl -s http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo 'unknown')" \
        --subject "CodeDeploy Success" || true
fi

echo "ApplicationStart hook completed successfully"
echo "Timestamp: $(date)"