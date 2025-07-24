#!/bin/bash
# AWS X-Ray Distributed Tracing Lab - Provisioning Script

# Exit on error
set -e

# Configuration
STACK_NAME="xray-lab"
REGION=$(aws configure get region)
if [ -z "$REGION" ]; then
    REGION="us-east-1"
    echo "No AWS region found in configuration. Using default: $REGION"
fi

# Display banner
echo "============================================================"
echo "AWS X-Ray Distributed Tracing Lab - Provisioning"
echo "============================================================"
echo "This script will provision the following resources:"
echo "- IAM Roles for Lambda functions with X-Ray permissions"
echo "- DynamoDB tables for sample microservices"
echo "- Lambda functions with X-Ray tracing enabled"
echo "- API Gateway with X-Ray tracing enabled"
echo "- X-Ray sampling rules for optimized tracing"
echo "============================================================"
echo "Region: $REGION"
echo "Stack Name: $STACK_NAME"
echo "============================================================"

# Confirm with user
read -p "Do you want to continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Provisioning cancelled."
    exit 1
fi

# Create temporary directory for deployment
TEMP_DIR=$(mktemp -d)
echo "Creating temporary directory: $TEMP_DIR"
cd $TEMP_DIR

# Copy CloudFormation template
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TEMPLATE_PATH="$SCRIPT_DIR/../templates/xray-microservices.yaml"
cp $TEMPLATE_PATH $TEMP_DIR/template.yaml

echo "Validating CloudFormation template..."
aws cloudformation validate-template --template-body file://template.yaml

echo "Deploying CloudFormation stack..."
aws cloudformation deploy \
    --template-file template.yaml \
    --stack-name $STACK_NAME \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides EnvironmentName=$STACK_NAME

echo "Waiting for stack creation to complete..."
aws cloudformation wait stack-create-complete --stack-name $STACK_NAME

# Get stack outputs
echo "Getting stack outputs..."
API_ENDPOINT=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ApiEndpoint'].OutputValue" --output text)
USER_ENDPOINT=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='UserServiceEndpoint'].OutputValue" --output text)
ORDER_ENDPOINT=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='OrderServiceEndpoint'].OutputValue" --output text)

echo "API Endpoint: $API_ENDPOINT"
echo "User Service Endpoint: $USER_ENDPOINT"
echo "Order Service Endpoint: $ORDER_ENDPOINT"

# Populate DynamoDB tables with sample data
echo "Populating DynamoDB tables with sample data..."

# Add sample users
echo "Adding sample users..."
aws dynamodb put-item \
    --table-name UserProfiles \
    --item '{
        "userId": {"S": "user123"},
        "name": {"S": "John Doe"},
        "email": {"S": "john@example.com"},
        "preferences": {"S": "theme:dark,notifications:enabled"}
    }'

aws dynamodb put-item \
    --table-name UserProfiles \
    --item '{
        "userId": {"S": "user456"},
        "name": {"S": "Jane Smith"},
        "email": {"S": "jane@example.com"},
        "preferences": {"S": "theme:light,notifications:disabled"}
    }'

# Add sample orders
echo "Adding sample orders..."
aws dynamodb put-item \
    --table-name Orders \
    --item '{
        "orderId": {"S": "order123"},
        "userId": {"S": "user123"},
        "items": {"L": [
            {"M": {"id": {"S": "item1"}, "name": {"S": "Product 1"}, "price": {"N": "29.99"}, "quantity": {"N": "2"}}},
            {"M": {"id": {"S": "item2"}, "name": {"S": "Product 2"}, "price": {"N": "49.99"}, "quantity": {"N": "1"}}}
        ]},
        "total": {"N": "109.97"},
        "status": {"S": "shipped"},
        "createdAt": {"S": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}
    }'

aws dynamodb put-item \
    --table-name Orders \
    --item '{
        "orderId": {"S": "order456"},
        "userId": {"S": "user456"},
        "items": {"L": [
            {"M": {"id": {"S": "item3"}, "name": {"S": "Product 3"}, "price": {"N": "19.99"}, "quantity": {"N": "3"}}}
        ]},
        "total": {"N": "59.97"},
        "status": {"S": "processing"},
        "createdAt": {"S": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}
    }'

# Generate some trace data
echo "Generating initial trace data..."
echo "Sending requests to user service..."
curl -s "${USER_ENDPOINT/\{userId\}/user123}" > /dev/null
curl -s "${USER_ENDPOINT/\{userId\}/user456}" > /dev/null
curl -s "${USER_ENDPOINT/\{userId\}/nonexistent}" > /dev/null

echo "Sending requests to order service..."
curl -s "${ORDER_ENDPOINT/\{orderId\}/order123}" > /dev/null
curl -s "${ORDER_ENDPOINT/\{orderId\}/order456}" > /dev/null
curl -s "${ORDER_ENDPOINT/\{orderId\}/nonexistent}" > /dev/null

# Clean up
echo "Cleaning up temporary files..."
rm -rf $TEMP_DIR

echo "============================================================"
echo "X-Ray Lab Provisioning Complete!"
echo "============================================================"
echo "API Endpoint: $API_ENDPOINT"
echo "User Service Endpoint: $USER_ENDPOINT (replace {userId} with user123 or user456)"
echo "Order Service Endpoint: $ORDER_ENDPOINT (replace {orderId} with order123 or order456)"
echo "============================================================"
echo "To view traces, go to the AWS X-Ray console:"
echo "https://$REGION.console.aws.amazon.com/xray/home?region=$REGION#/service-map"
echo "============================================================"
echo "To clean up resources when finished, run:"
echo "aws cloudformation delete-stack --stack-name $STACK_NAME"
echo "============================================================"