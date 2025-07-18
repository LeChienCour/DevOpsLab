#!/bin/bash

# CodeDeploy Lab Cleanup Script
# This script removes all resources created by the CodeDeploy lab

set -e

# Configuration
PROJECT_NAME="codedeploy-lab"
STACK_NAME="${PROJECT_NAME}-stack"
REGION=${AWS_DEFAULT_REGION:-us-east-1}

echo "=== CodeDeploy Lab Cleanup ==="
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "Error: AWS CLI is not configured or credentials are invalid"
    echo "Please run 'aws configure' to set up your credentials"
    exit 1
fi

# Check if stack exists
if ! aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" > /dev/null 2>&1; then
    echo "Stack $STACK_NAME not found. Nothing to clean up."
    exit 0
fi

echo "Found stack: $STACK_NAME"

# Get CodeDeploy application name for stopping deployments
echo "Checking for running deployments..."
EC2_APP=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`EC2Application`].OutputValue' \
    --output text \
    --region "$REGION" 2>/dev/null || echo "")

# Stop any running deployments
if [ ! -z "$EC2_APP" ]; then
    echo "Checking for running deployments in application: $EC2_APP"
    RUNNING_DEPLOYMENTS=$(aws deploy list-deployments \
        --application-name "$EC2_APP" \
        --include-only-statuses "InProgress" "Queued" "Ready" \
        --query 'deployments' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    if [ ! -z "$RUNNING_DEPLOYMENTS" ] && [ "$RUNNING_DEPLOYMENTS" != "None" ]; then
        for deployment_id in $RUNNING_DEPLOYMENTS; do
            echo "Stopping deployment: $deployment_id"
            aws deploy stop-deployment \
                --deployment-id "$deployment_id" \
                --auto-rollback-enabled \
                --region "$REGION" || true
        done
        
        echo "Waiting for deployments to stop..."
        sleep 30
    fi
fi

# Empty S3 artifact bucket
echo "Emptying S3 artifact bucket..."
ARTIFACT_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`ArtifactBucket`].OutputValue' \
    --output text \
    --region "$REGION" 2>/dev/null || echo "")

if [ ! -z "$ARTIFACT_BUCKET" ]; then
    if aws s3api head-bucket --bucket "$ARTIFACT_BUCKET" --region "$REGION" 2>/dev/null; then
        echo "Emptying bucket: $ARTIFACT_BUCKET"
        aws s3 rm "s3://$ARTIFACT_BUCKET" --recursive --region "$REGION" || true
    else
        echo "Bucket $ARTIFACT_BUCKET not found or already deleted"
    fi
fi

# Delete CloudFormation stack
echo "Deleting CloudFormation stack..."
aws cloudformation delete-stack \
    --stack-name "$STACK_NAME" \
    --region "$REGION"

echo "Waiting for stack deletion to complete..."
echo "This may take 5-10 minutes..."

# Wait for stack deletion with timeout
TIMEOUT=900  # 15 minutes
ELAPSED=0
INTERVAL=30

while [ $ELAPSED -lt $TIMEOUT ]; do
    if ! aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" > /dev/null 2>&1; then
        echo "✅ Stack deletion successful!"
        break
    fi
    
    echo "Still deleting... (${ELAPSED}s elapsed)"
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
    
    if [ $ELAPSED -ge $TIMEOUT ]; then
        echo "⚠️  Stack deletion is taking longer than expected."
        echo "Please check the AWS Console for the current status."
        echo "The stack may still be deleting in the background."
        break
    fi
done

# Clean up local files
echo "Cleaning up local files..."
rm -f lab-session-info.txt
rm -f sample-app-deployment.zip

echo
echo "🎉 CodeDeploy Lab Cleanup Complete!"
echo
echo "All AWS resources have been removed (or are in the process of being removed)."
echo "You can now run the provisioning script again for a fresh lab environment."
echo
echo "If you encounter any issues, please check the AWS Console for:"
echo "- CloudFormation stack status"
echo "- Any remaining EC2 instances"