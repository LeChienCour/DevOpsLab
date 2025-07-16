#!/bin/bash

# CodeDeploy ValidateService Hook Script
# This script validates that the deployment was successful

set -e

echo "Starting ValidateService hook..."
echo "Timestamp: $(date)"

# Configuration
MAX_ATTEMPTS=30
SLEEP_INTERVAL=5
HEALTH_CHECK_ENDPOINT="http://localhost/"
EXPECTED_HTTP_CODE=200

# Function to perform HTTP health check
http_health_check() {
    local url=$1
    local expected_code=$2
    
    echo "Performing HTTP health check on $url"
    
    # Use curl to check the endpoint
    local response_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" || echo "000")
    
    if [ "$response_code" = "$expected_code" ]; then
        echo "✅ HTTP health check passed (HTTP $response_code)"
        return 0
    else
        echo "❌ HTTP health check failed (HTTP $response_code, expected $expected_code)"
        return 1
    fi
}

# Function to check service status
check_service_status() {
    local service_name=$1
    
    echo "Checking $service_name service status..."
    
    if systemctl is-active --quiet $service_name; then
        echo "✅ $service_name is running"
        return 0
    else
        echo "❌ $service_name is not running"
        systemctl status $service_name || true
        return 1
    fi
}

# Function to validate file permissions
validate_file_permissions() {
    echo "Validating file permissions..."
    
    # Check if web root exists and has correct permissions
    if [ ! -d "/var/www/html" ]; then
        echo "❌ Web root directory /var/www/html does not exist"
        return 1
    fi
    
    # Check ownership
    local owner=$(stat -c '%U:%G' /var/www/html)
    if [ "$owner" != "apache:apache" ]; then
        echo "❌ Incorrect ownership for /var/www/html (found: $owner, expected: apache:apache)"
        return 1
    fi
    
    echo "✅ File permissions are correct"
    return 0
}

# Function to validate application content
validate_application_content() {
    echo "Validating application content..."
    
    # Check if main index file exists
    if [ ! -f "/var/www/html/index.html" ]; then
        echo "❌ Main index.html file is missing"
        return 1
    fi
    
    # Check if deployment info file exists
    if [ ! -f "/var/www/html/deployment-info.json" ]; then
        echo "❌ Deployment info file is missing"
        return 1
    fi
    
    # Validate JSON format of deployment info
    if ! python3 -m json.tool /var/www/html/deployment-info.json > /dev/null 2>&1; then
        echo "❌ Deployment info JSON is invalid"
        return 1
    fi
    
    echo "✅ Application content is valid"
    return 0
}

# Function to perform comprehensive validation
comprehensive_validation() {
    local attempt=$1
    
    echo "--- Validation Attempt $attempt ---"
    
    # Check Apache service
    if ! check_service_status httpd; then
        return 1
    fi
    
    # Validate file permissions
    if ! validate_file_permissions; then
        return 1
    fi
    
    # Validate application content
    if ! validate_application_content; then
        return 1
    fi
    
    # Perform HTTP health check
    if ! http_health_check "$HEALTH_CHECK_ENDPOINT" "$EXPECTED_HTTP_CODE"; then
        return 1
    fi
    
    # Additional health checks
    echo "Performing additional health checks..."
    
    # Check if Apache is listening on port 80
    if ! netstat -tlnp | grep :80 | grep httpd > /dev/null; then
        echo "❌ Apache is not listening on port 80"
        return 1
    fi
    echo "✅ Apache is listening on port 80"
    
    # Check Apache error log for recent errors
    if [ -f "/var/log/httpd/error_log" ]; then
        local recent_errors=$(tail -50 /var/log/httpd/error_log | grep "$(date '+%a %b %d')" | grep -i error | wc -l)
        if [ "$recent_errors" -gt 5 ]; then
            echo "⚠️  Warning: Found $recent_errors recent errors in Apache error log"
            tail -10 /var/log/httpd/error_log
        else
            echo "✅ No significant errors in Apache error log"
        fi
    fi
    
    # Test specific endpoints
    echo "Testing specific endpoints..."
    
    # Test deployment info endpoint
    if curl -f -s "http://localhost/deployment-info.json" > /dev/null; then
        echo "✅ Deployment info endpoint is accessible"
    else
        echo "❌ Deployment info endpoint is not accessible"
        return 1
    fi
    
    # Test that the page contains expected content
    if curl -s "http://localhost/" | grep -q "CodeDeploy"; then
        echo "✅ Page contains expected CodeDeploy content"
    else
        echo "❌ Page does not contain expected content"
        return 1
    fi
    
    return 0
}

# Main validation loop
echo "Starting comprehensive service validation..."
attempt=1

while [ $attempt -le $MAX_ATTEMPTS ]; do
    if comprehensive_validation $attempt; then
        echo ""
        echo "🎉 All validation checks passed!"
        echo "Service is healthy and ready to serve traffic"
        
        # Log successful validation
        cat >> /var/log/codedeploy/deployment.log << EOF
Validation completed successfully
Timestamp: $(date)
Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo 'unknown')
Validation attempts: $attempt
EOF
        
        # Send success notification (if SNS topic is configured)
        if [ ! -z "${SNS_TOPIC_ARN}" ]; then
            echo "Sending validation success notification..."
            aws sns publish \
                --topic-arn "${SNS_TOPIC_ARN}" \
                --message "CodeDeploy validation completed successfully on instance $(curl -s http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo 'unknown')" \
                --subject "CodeDeploy Validation Success" || true
        fi
        
        echo "ValidateService hook completed successfully"
        echo "Timestamp: $(date)"
        exit 0
    else
        echo ""
        echo "❌ Validation attempt $attempt failed"
        
        if [ $attempt -eq $MAX_ATTEMPTS ]; then
            echo ""
            echo "💥 All validation attempts failed!"
            echo "Service validation failed after $MAX_ATTEMPTS attempts"
            
            # Log validation failure
            cat >> /var/log/codedeploy/deployment.log << EOF
Validation failed after $MAX_ATTEMPTS attempts
Timestamp: $(date)
Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo 'unknown')
EOF
            
            # Collect diagnostic information
            echo ""
            echo "=== DIAGNOSTIC INFORMATION ==="
            echo "Apache status:"
            systemctl status httpd || true
            echo ""
            echo "Apache processes:"
            ps aux | grep httpd | grep -v grep || true
            echo ""
            echo "Network connections:"
            netstat -tlnp | grep :80 || true
            echo ""
            echo "Recent Apache error log:"
            tail -20 /var/log/httpd/error_log 2>/dev/null || echo "No error log found"
            echo ""
            echo "Disk space:"
            df -h
            echo ""
            echo "Memory usage:"
            free -h
            echo "=== END DIAGNOSTIC INFORMATION ==="
            
            # Send failure notification (if SNS topic is configured)
            if [ ! -z "${SNS_TOPIC_ARN}" ]; then
                echo "Sending validation failure notification..."
                aws sns publish \
                    --topic-arn "${SNS_TOPIC_ARN}" \
                    --message "CodeDeploy validation failed on instance $(curl -s http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo 'unknown') after $MAX_ATTEMPTS attempts" \
                    --subject "CodeDeploy Validation Failed" || true
            fi
            
            exit 1
        else
            echo "Waiting $SLEEP_INTERVAL seconds before next attempt..."
            sleep $SLEEP_INTERVAL
            attempt=$((attempt + 1))
        fi
    fi
done