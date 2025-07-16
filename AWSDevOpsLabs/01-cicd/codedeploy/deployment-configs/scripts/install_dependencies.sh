#!/bin/bash

# CodeDeploy BeforeInstall Hook Script
# This script installs dependencies and prepares the environment

set -e

echo "Starting BeforeInstall hook..."
echo "Timestamp: $(date)"

# Update system packages
echo "Updating system packages..."
yum update -y

# Install required packages
echo "Installing required packages..."
yum install -y httpd

# Ensure Apache is installed and configured
if ! command -v httpd &> /dev/null; then
    echo "Error: Apache (httpd) installation failed"
    exit 1
fi

# Create necessary directories
echo "Creating application directories..."
mkdir -p /var/www/html
mkdir -p /var/log/codedeploy

# Set proper permissions
echo "Setting directory permissions..."
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

# Create backup of existing content
if [ -d "/var/www/html" ] && [ "$(ls -A /var/www/html)" ]; then
    echo "Backing up existing content..."
    mkdir -p /var/backups/www
    cp -r /var/www/html/* /var/backups/www/ 2>/dev/null || true
fi

# Configure Apache
echo "Configuring Apache..."
cat > /etc/httpd/conf.d/codedeploy-app.conf << 'EOF'
<VirtualHost *:80>
    DocumentRoot /var/www/html
    ServerName localhost
    
    <Directory /var/www/html>
        AllowOverride All
        Require all granted
    </Directory>
    
    # Health check endpoint
    <Location "/health">
        SetHandler server-status
    </Location>
    
    # Custom error pages
    ErrorDocument 404 /error.html
    ErrorDocument 500 /error.html
    
    # Logging
    ErrorLog /var/log/httpd/codedeploy_error.log
    CustomLog /var/log/httpd/codedeploy_access.log combined
</VirtualHost>
EOF

# Enable Apache modules
echo "Enabling Apache modules..."
echo "LoadModule rewrite_module modules/mod_rewrite.so" >> /etc/httpd/conf/httpd.conf
echo "LoadModule status_module modules/mod_status.so" >> /etc/httpd/conf/httpd.conf

# Create log files with proper permissions
touch /var/log/httpd/codedeploy_error.log
touch /var/log/httpd/codedeploy_access.log
chown apache:apache /var/log/httpd/codedeploy_*.log

# Install CloudWatch agent configuration
echo "Configuring CloudWatch agent..."
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/httpd/codedeploy_access.log",
                        "log_group_name": "/aws/codedeploy/httpd/access",
                        "log_stream_name": "{instance_id}"
                    },
                    {
                        "file_path": "/var/log/httpd/codedeploy_error.log",
                        "log_group_name": "/aws/codedeploy/httpd/error",
                        "log_stream_name": "{instance_id}"
                    },
                    {
                        "file_path": "/var/log/codedeploy-agent/codedeploy-agent.log",
                        "log_group_name": "/aws/codedeploy/agent",
                        "log_stream_name": "{instance_id}"
                    }
                ]
            }
        }
    }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s || true

echo "BeforeInstall hook completed successfully"
echo "Timestamp: $(date)"