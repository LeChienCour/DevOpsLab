#!/bin/bash
# CloudWatch Monitoring Lab - Provisioning Script
# This script deploys CloudFormation templates for CloudWatch monitoring resources

set -e

# Default values
REGION=$(aws configure get region)
STACK_NAME="cloudwatch-monitoring-lab"
LOG_STACK_NAME="cloudwatch-log-aggregation-lab"
EMAIL=""
ENVIRONMENT="Dev"
DEPLOY_DASHBOARD=true

# Display help
function show_help {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -r, --region REGION       AWS region (default: from AWS config)"
    echo "  -s, --stack-name NAME     CloudFormation stack name (default: cloudwatch-monitoring-lab)"
    echo "  -l, --log-stack NAME      Log aggregation stack name (default: cloudwatch-log-aggregation-lab)"
    echo "  -e, --email EMAIL         Email for alarm notifications (required)"
    echo "  -v, --environment ENV     Environment name (default: Dev)"
    echo "  -h, --help                Show this help message"
    echo "  --no-dashboard            Skip dashboard creation"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -s|--stack-name)
            STACK_NAME="$2"
            shift 2
            ;;
        -l|--log-stack)
            LOG_STACK_NAME="$2"
            shift 2
            ;;
        -e|--email)
            EMAIL="$2"
            shift 2
            ;;
        -v|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --no-dashboard)
            DEPLOY_DASHBOARD=false
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
done

# Validate required parameters
if [ -z "$EMAIL" ]; then
    echo "Error: Email address is required for alarm notifications"
    show_help
fi

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TEMPLATE_DIR="$SCRIPT_DIR/../templates"

echo "=== CloudWatch Monitoring Lab - Provisioning ==="
echo "Region: $REGION"
echo "Stack Name: $STACK_NAME"
echo "Log Stack Name: $LOG_STACK_NAME"
echo "Email: $EMAIL"
echo "Environment: $ENVIRONMENT"
echo "Deploy Dashboard: $DEPLOY_DASHBOARD"
echo "================================================"

# Check if templates exist
if [ ! -f "$TEMPLATE_DIR/cloudwatch-monitoring.yaml" ]; then
    echo "Error: Template file not found at $TEMPLATE_DIR/cloudwatch-monitoring.yaml"
    exit 1
fi

if [ ! -f "$TEMPLATE_DIR/log-aggregation.yaml" ]; then
    echo "Error: Template file not found at $TEMPLATE_DIR/log-aggregation.yaml"
    exit 1
fi

# Deploy CloudWatch monitoring stack
echo "Deploying CloudWatch monitoring stack..."
aws cloudformation deploy \
    --region "$REGION" \
    --stack-name "$STACK_NAME" \
    --template-file "$TEMPLATE_DIR/cloudwatch-monitoring.yaml" \
    --parameter-overrides \
        Environment="$ENVIRONMENT" \
        NotificationEmail="$EMAIL" \
        MetricNamespace="CustomApp/Performance" \
        CPUThreshold=80 \
        MemoryThreshold=80 \
        ResponseTimeThreshold=400 \
    --capabilities CAPABILITY_IAM \
    --no-fail-on-empty-changeset

# Deploy log aggregation stack
echo "Deploying log aggregation stack..."
aws cloudformation deploy \
    --region "$REGION" \
    --stack-name "$LOG_STACK_NAME" \
    --template-file "$TEMPLATE_DIR/log-aggregation.yaml" \
    --parameter-overrides \
        Environment="$ENVIRONMENT" \
        RetentionDays=14 \
        CreateDashboard="$DEPLOY_DASHBOARD" \
    --capabilities CAPABILITY_IAM \
    --no-fail-on-empty-changeset

# Get stack outputs
echo "Getting stack outputs..."
OUTPUTS=$(aws cloudformation describe-stacks --region "$REGION" --stack-name "$STACK_NAME" --query "Stacks[0].Outputs" --output json)
DASHBOARD_URL=$(echo "$OUTPUTS" | grep -o '"OutputValue": "https://[^"]*dashboards[^"]*"' | cut -d'"' -f4)
SNS_TOPIC_ARN=$(echo "$OUTPUTS" | grep -o '"OutputValue": "arn:aws:sns:[^"]*"' | cut -d'"' -f4)

echo "=== Deployment Complete ==="
echo "CloudWatch Dashboard URL: $DASHBOARD_URL"
echo "SNS Topic ARN: $SNS_TOPIC_ARN"
echo "=========================="

echo "Important: Check your email and confirm the SNS subscription to receive alarm notifications."

# Generate sample metrics
echo "Generating sample metrics..."

# Force use of AWS CLI method since Python detection is problematic on Windows
PYTHON_AVAILABLE=false
PYTHON_CMD=""

echo "Using AWS CLI method for generating sample metrics
if command -v python3 >/dev/null 2>&1; then
    if python3 --version >/dev/null 2>&1; then
        PYTHON_AVAILABLE=true
        PYTHON_CMD="python3"
    fi
fi

# If python3 doesn't work, test python
if [ "$PYTHON_AVAILABLE" = false ] && command -v python >/dev/null 2>&1; then
    if python --version >/dev/null 2>&1 && python --version 2>&1 | grep -q "Python 3"; then
        PYTHON_AVAILABLE=true
        PYTHON_CMD="python"
    fi
fi

echo "Python detection: PYTHON_AVAILABLE=$PYTHON_AVAILABLE, PYTHON_CMD=$PYTHON_CMD"

if [ "$PYTHON_AVAILABLE" = true ]; then
    cat > "$SCRIPT_DIR/generate-metrics.py" << 'EOF'
#!/usr/bin/env python3
import boto3
import random
import time
from datetime import datetime

cloudwatch = boto3.client('cloudwatch')

def publish_custom_metrics(namespace):
    # Simulate application metrics
    cpu_usage = random.uniform(10, 90)
    memory_usage = random.uniform(20, 80)
    request_count = random.randint(50, 200)
    response_time = random.uniform(100, 500)
    
    # Publish metrics to CloudWatch
    cloudwatch.put_metric_data(
        Namespace=namespace,
        MetricData=[
            {
                'MetricName': 'CPUUsage',
                'Value': cpu_usage,
                'Unit': 'Percent',
                'Timestamp': datetime.utcnow()
            },
            {
                'MetricName': 'MemoryUsage',
                'Value': memory_usage,
                'Unit': 'Percent',
                'Timestamp': datetime.utcnow()
            },
            {
                'MetricName': 'RequestCount',
                'Value': request_count,
                'Unit': 'Count',
                'Timestamp': datetime.utcnow()
            },
            {
                'MetricName': 'ResponseTime',
                'Value': response_time,
                'Unit': 'Milliseconds',
                'Timestamp': datetime.utcnow()
            }
        ]
    )
    
    print(f"Published metrics: CPU={cpu_usage:.1f}%, Memory={memory_usage:.1f}%, Requests={request_count}, ResponseTime={response_time:.1f}ms")

if __name__ == "__main__":
    import sys
    namespace = sys.argv[1] if len(sys.argv) > 1 else "CustomApp/Performance"
    iterations = int(sys.argv[2]) if len(sys.argv) > 2 else 5
    
    print(f"Publishing {iterations} sets of metrics to namespace {namespace}")
    for i in range(iterations):
        publish_custom_metrics(namespace)
        time.sleep(5)  # Wait 5 seconds between metric publications
EOF

    chmod +x "$SCRIPT_DIR/generate-metrics.py"
    $PYTHON_CMD "$SCRIPT_DIR/generate-metrics.py" "CustomApp/Performance" 5
else
    echo "Python3 not found. Generating sample metrics using AWS CLI instead..."
    
    # Generate sample metrics using AWS CLI
    NAMESPACE="CustomApp/Performance"
    
    for i in {1..5}; do
        # Generate random values (using RANDOM which is available in bash)
        CPU_USAGE=$((RANDOM % 80 + 10))
        MEMORY_USAGE=$((RANDOM % 60 + 20))
        REQUEST_COUNT=$((RANDOM % 150 + 50))
        RESPONSE_TIME=$((RANDOM % 400 + 100))
        
        echo "Publishing metrics set $i: CPU=${CPU_USAGE}%, Memory=${MEMORY_USAGE}%, Requests=${REQUEST_COUNT}, ResponseTime=${RESPONSE_TIME}ms"
        
        # Publish metrics using AWS CLI
        aws cloudwatch put-metric-data --region "$REGION" --namespace "$NAMESPACE" --metric-data \
            MetricName=CPUUsage,Value=$CPU_USAGE,Unit=Percent \
            MetricName=MemoryUsage,Value=$MEMORY_USAGE,Unit=Percent \
            MetricName=RequestCount,Value=$REQUEST_COUNT,Unit=Count \
            MetricName=ResponseTime,Value=$RESPONSE_TIME,Unit=Milliseconds
        
        sleep 5
    done
fi

echo "Setup complete! You can now explore the CloudWatch monitoring lab."

if [ "$PYTHON_AVAILABLE" = true ]; then
    echo "To generate more sample metrics, run: $PYTHON_CMD $SCRIPT_DIR/generate-metrics.py"
else
    echo "To generate more sample metrics manually, use AWS CLI commands like:"
    echo "aws cloudwatch put-metric-data --region $REGION --namespace CustomApp/Performance --metric-data MetricName=CPUUsage,Value=75,Unit=Percent"
fi