#!/bin/bash
# AWS X-Ray Sampling Rules Creation Script

# Exit on error
set -e

# Configuration
REGION=$(aws configure get region)
if [ -z "$REGION" ]; then
    REGION="us-east-1"
    echo "No AWS region found in configuration. Using default: $REGION"
fi

# Display banner
echo "============================================================"
echo "AWS X-Ray Sampling Rules Creation"
echo "============================================================"
echo "This script will create custom sampling rules for X-Ray to:"
echo "- Optimize trace collection for different services"
echo "- Reduce costs by sampling less important requests"
echo "- Ensure critical paths are always traced"
echo "============================================================"
echo "Region: $REGION"
echo "============================================================"

# Confirm with user
read -p "Do you want to continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 1
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
echo "Creating temporary directory: $TEMP_DIR"
cd $TEMP_DIR

# Create sampling rules JSON file
cat > sampling-rules.json << 'EOF'
{
  "SamplingRule": {
    "RuleName": "high-priority-services",
    "Priority": 5,
    "FixedRate": 0.5,
    "ReservoirSize": 2,
    "ServiceName": "user-service",
    "ServiceType": "*",
    "Host": "*",
    "HTTPMethod": "*",
    "URLPath": "/users/*",
    "Version": 1,
    "Attributes": {}
  }
}
EOF

echo "Creating high-priority sampling rule for user-service..."
aws xray create-sampling-rule --cli-input-json file://sampling-rules.json --region $REGION

# Create order service sampling rule
cat > sampling-rules.json << 'EOF'
{
  "SamplingRule": {
    "RuleName": "order-service",
    "Priority": 10,
    "FixedRate": 0.3,
    "ReservoirSize": 1,
    "ServiceName": "order-service",
    "ServiceType": "*",
    "Host": "*",
    "HTTPMethod": "*",
    "URLPath": "/orders/*",
    "Version": 1,
    "Attributes": {}
  }
}
EOF

echo "Creating sampling rule for order-service..."
aws xray create-sampling-rule --cli-input-json file://sampling-rules.json --region $REGION

# Create error path sampling rule
cat > sampling-rules.json << 'EOF'
{
  "SamplingRule": {
    "RuleName": "error-paths",
    "Priority": 1,
    "FixedRate": 1.0,
    "ReservoirSize": 5,
    "ServiceName": "*",
    "ServiceType": "*",
    "Host": "*",
    "HTTPMethod": "*",
    "URLPath": "*",
    "Version": 1,
    "Attributes": {
      "http.status": "4*,5*"
    }
  }
}
EOF

echo "Creating sampling rule for error paths..."
aws xray create-sampling-rule --cli-input-json file://sampling-rules.json --region $REGION

# Create health check sampling rule (low priority)
cat > sampling-rules.json << 'EOF'
{
  "SamplingRule": {
    "RuleName": "health-checks",
    "Priority": 100,
    "FixedRate": 0.05,
    "ReservoirSize": 0,
    "ServiceName": "*",
    "ServiceType": "*",
    "Host": "*",
    "HTTPMethod": "GET",
    "URLPath": "/health",
    "Version": 1,
    "Attributes": {}
  }
}
EOF

echo "Creating sampling rule for health checks..."
aws xray create-sampling-rule --cli-input-json file://sampling-rules.json --region $REGION

# List all sampling rules
echo "Listing all sampling rules..."
aws xray get-sampling-rules --region $REGION

# Clean up
echo "Cleaning up temporary files..."
rm -rf $TEMP_DIR

echo "============================================================"
echo "X-Ray Sampling Rules Creation Complete!"
echo "============================================================"
echo "You can view and modify these rules in the AWS X-Ray console:"
echo "https://$REGION.console.aws.amazon.com/xray/home?region=$REGION#/sampling"
echo "============================================================"