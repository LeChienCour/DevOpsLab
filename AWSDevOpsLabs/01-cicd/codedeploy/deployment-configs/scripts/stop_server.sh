#!/bin/bash

# CodeDeploy ApplicationStop Hook Script
# This script gracefully stops the web server

set -e

echo "Starting ApplicationStop hook..."
echo "Timestamp: $(date)"

# Function to check if service is running
check_service() {
    local service_name=$1
    if systemctl is-active --quiet $service_name; then
        return 0
    else
        return 1
    fi
}

# Function to gracefully stop service
graceful_stop() {
    local service_name=$1
    local max_attempts=30
    local attempt=1
    
    echo "Attempting to stop $service_name gracefully..."
    
    if ! check_service $service_name; then
        echo "$service_name is not running, nothing to stop"
        return 0
    fi
    
    # Send graceful stop signal
    systemctl stop $service_name
    
    # Wait for service to stop
    while [ $attempt -le $max_attempts ]; do
        if ! check_service $service_name; then
            echo "$service_name stopped successfully"
            return 0
        fi
        echo "Attempt $attempt/$max_attempts: Waiting for $service_name to stop..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo "Warning: $service_name did not stop gracefully, forcing stop..."
    systemctl kill $service_name || true
    sleep 5
    
    if check_service $service_name; then
        echo "Error: Failed to stop $service_name"
        return 1
    else
        echo "$service_name stopped (forced)"
        return 0
    fi
}

# Create maintenance page
echo "Creating maintenance page..."
cat > /tmp/maintenance.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Maintenance - CodeDeploy Lab</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            margin: 40px; 
            background-color: #f5f5f5;
            text-align: center;
        }
        .container { 
            max-width: 600px; 
            margin: 0 auto; 
            background-color: white;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .maintenance { 
            background-color: #fff3cd; 
            border: 1px solid #ffeaa7; 
            color: #856404;
            padding: 20px; 
            border-radius: 5px; 
            margin: 20px 0; 
        }
        .spinner {
            border: 4px solid #f3f3f3;
            border-top: 4px solid #3498db;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 2s linear infinite;
            margin: 20px auto;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
    </style>
    <meta http-equiv="refresh" content="30">
</head>
<body>
    <div class="container">
        <h1>🔧 Maintenance in Progress</h1>
        <div class="maintenance">
            <h3>CodeDeploy Deployment in Progress</h3>
            <p>We're currently updating the application. This page will automatically refresh.</p>
            <div class="spinner"></div>
            <p><strong>Started:</strong> <span id="maintenance-time"></span></p>
            <p><strong>Expected Duration:</strong> 2-5 minutes</p>
        </div>
        <p>Thank you for your patience!</p>
    </div>
    <script>
        document.getElementById('maintenance-time').textContent = new Date().toLocaleString();
    </script>
</body>
</html>
EOF

# If Apache is running, replace the main page with maintenance page
if check_service httpd; then
    echo "Replacing main page with maintenance page..."
    if [ -f "/var/www/html/index.html" ]; then
        cp /var/www/html/index.html /var/www/html/index.html.backup
    fi
    cp /tmp/maintenance.html /var/www/html/index.html
    chown apache:apache /var/www/html/index.html
    
    # Give users a moment to see the maintenance page
    echo "Allowing time for users to see maintenance page..."
    sleep 10
fi

# Drain connections gracefully
echo "Draining existing connections..."
if check_service httpd; then
    # Send SIGUSR1 to Apache for graceful restart (closes listening sockets but keeps existing connections)
    pkill -USR1 httpd || true
    sleep 5
fi

# Stop Apache HTTP Server
echo "Stopping Apache HTTP Server..."
if check_service httpd; then
    if ! graceful_stop httpd; then
        echo "Error: Failed to stop Apache"
        exit 1
    fi
else
    echo "Apache is not running"
fi

# Clean up any remaining processes
echo "Cleaning up any remaining processes..."
pkill -f "httpd" || true

# Log the stop event
echo "Service stopped for deployment" >> /var/log/codedeploy/deployment.log
echo "Timestamp: $(date)" >> /var/log/codedeploy/deployment.log

# Remove any temporary files
echo "Cleaning up temporary files..."
rm -f /tmp/maintenance.html

# Verify no Apache processes are running
if pgrep httpd > /dev/null; then
    echo "Warning: Some Apache processes are still running"
    ps aux | grep httpd | grep -v grep
else
    echo "All Apache processes stopped successfully"
fi

echo "ApplicationStop hook completed successfully"
echo "Timestamp: $(date)"