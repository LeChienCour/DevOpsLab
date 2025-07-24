#!/bin/bash
# AWS X-Ray Distributed Tracing Lab - Cleanup Script

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
echo "AWS X-Ray Distributed Tracing Lab - Cleanup"
echo "============================================================"
echo "This script will delete the following resources:"
echo "- CloudFormation stack: $STACK_NAME"
echo "- All resources created by the stack:"
echo "  - IAM Roles for Lambda functions"
echo "  - DynamoDB tables"
echo "  - Lambda functions"
echo "  - API Gateway"
echo "  - X-Ray sampling rules"
echo "============================================================"
echo "Region: $REGION"
echo "Stack Name: $STACK_NAME"
echo "============================================================"

# Confirm with user
read -p "Do you want to continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 1
fi

# Check if stack exists
echo "Checking if stack exists..."
if ! aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION &> /dev/null; then
    echo "Stack $STACK_NAME does not exist in region $REGION."
    exit 0
fi

# Delete CloudFormation stack
echo "Deleting CloudFormation stack: $STACK_NAME..."
aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION

echo "Waiting for stack deletion to complete..."
aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $REGION

echo "============================================================"
echo "X-Ray Lab Cleanup Complete!"
echo "============================================================"
echo "All resources have been deleted."
echo "Note: X-Ray trace data will be automatically deleted after 30 days."
echo "============================================================"