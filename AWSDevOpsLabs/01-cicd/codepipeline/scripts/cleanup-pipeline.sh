#!/bin/bash

# CodePipeline Lab Cleanup Script
# This script removes all resources created by the CodePipeline lab

set -e

# Configuration
PROJECT_NAME="devops-pipeline-lab"
STACK_NAME="${PROJECT_NAME}-stack"
REGION=${AWS_DEFAULT_REGION:-us-east-1}

echo "=== CodePipeline Lab Cleanup ==="
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

# Get bucket names from stack outputs before deletion
echo "Retrieving bucket information..."
ARTIFACT_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`ArtifactBucket`].OutputValue' \
    --output text \
    --region "$REGION" 2>/dev/null || echo "")

# Get all S3 buckets created by the stack
BUCKETS=$(aws cloudformation describe-stack-resources \
    --stack-name "$STACK_NAME" \
    --query 'StackResources[?ResourceType==`AWS::S3::Bucket`].PhysicalResourceId' \
    --output text \
    --region "$REGION" 2>/dev/null || echo "")

# Empty S3 buckets before stack deletion
if [ ! -z "$BUCKETS" ]; then
    echo "Emptying S3 buckets..."
    for bucket in $BUCKETS; do
        if aws s3api head-bucket --bucket "$bucket" --region "$REGION" 2>/dev/null; then
            echo "Emptying bucket: $bucket"
            aws s3 rm "s3://$bucket" --recursive --region "$REGION" || true
            
            # Remove versioned objects if versioning is enabled
            aws s3api list-object-versions \
                --bucket "$bucket" \
                --query 'Versions[].{Key:Key,VersionId:VersionId}' \
                --output text \
                --region "$REGION" | while read key version; do
                if [ ! -z "$key" ] && [ ! -z "$version" ]; then
                    aws s3api delete-object \
                        --bucket "$bucket" \
                        --key "$key" \
                        --version-id "$version" \
                        --region "$REGION" || true
                fi
            done
            
            # Remove delete markers
            aws s3api list-object-versions \
                --bucket "$bucket" \
                --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' \
                --output text \
                --region "$REGION" | while read key version; do
                if [ ! -z "$key" ] && [ ! -z "$version" ]; then
                    aws s3api delete-object \
                        --bucket "$bucket" \
                        --key "$key" \
                        --version-id "$version" \
                        --region "$REGION" || true
                fi
            done
        else
            echo "Bucket $bucket not found or already deleted"
        fi
    done
fi

# Delete CloudFormation stack
echo "Deleting CloudFormation stack..."
aws cloudformation delete-stack \
    --stack-name "$STACK_NAME" \
    --region "$REGION"

echo "Waiting for stack deletion to complete..."
aws cloudformation wait stack-delete-complete \
    --stack-name "$STACK_NAME" \
    --region "$REGION"

if [ $? -eq 0 ]; then
    echo "✅ Stack deletion successful!"
else
    echo "❌ Stack deletion failed or timed out"
    echo "Please check the AWS Console for more details"
    exit 1
fi

# Clean up local files
echo "Cleaning up local files..."
rm -f lab-session-info.txt
rm -f initial-code.zip

echo
echo "🎉 CodePipeline Lab Cleanup Complete!"
echo
echo "All AWS resources have been removed."
echo "You can now run the provisioning script again for a fresh lab environment."