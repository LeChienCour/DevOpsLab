#!/bin/bash

# CodeBuild Lab Cleanup Script
# This script removes all resources created by the CodeBuild lab

# Configuration
PROJECT_NAME="codebuild-lab"
STACK_NAME="${PROJECT_NAME}-stack"
REGION=${AWS_DEFAULT_REGION:-us-east-1}

echo "=== CodeBuild Lab Cleanup ==="
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

# Function to safely empty an S3 bucket
empty_s3_bucket() {
    local bucket_name=$1
    echo "Processing bucket: $bucket_name"
    
    # Check if bucket exists
    if ! aws s3api head-bucket --bucket "$bucket_name" --region "$REGION" 2>/dev/null; then
        echo "  Bucket $bucket_name not found or already deleted"
        return 0
    fi
    
    # Remove bucket policy first to avoid permission issues
    echo "  Removing bucket policy..."
    aws s3api delete-bucket-policy --bucket "$bucket_name" --region "$REGION" 2>/dev/null || true
    
    # Remove public access block to allow deletion
    echo "  Removing public access block..."
    aws s3api delete-public-access-block --bucket "$bucket_name" --region "$REGION" 2>/dev/null || true
    
    # Simple object deletion for non-versioned buckets
    echo "  Removing all objects..."
    aws s3 rm "s3://$bucket_name" --recursive --region "$REGION" 2>/dev/null || true
    
    # Clean up any incomplete multipart uploads
    echo "  Cleaning up incomplete multipart uploads..."
    aws s3api list-multipart-uploads \
        --bucket "$bucket_name" \
        --region "$REGION" \
        --query 'Uploads[].[Key,UploadId]' \
        --output text 2>/dev/null | \
    while IFS=$'\t' read -r key upload_id; do
        if [ ! -z "$key" ] && [ ! -z "$upload_id" ]; then
            echo "    Aborting multipart upload: $key ($upload_id)"
            aws s3api abort-multipart-upload \
                --bucket "$bucket_name" \
                --key "$key" \
                --upload-id "$upload_id" \
                --region "$REGION" 2>/dev/null || true
        fi
    done
    
    echo "  Bucket $bucket_name emptied successfully"
}

# Get all S3 buckets created by the stack
echo "Retrieving bucket information..."
BUCKETS=$(aws cloudformation describe-stack-resources \
    --stack-name "$STACK_NAME" \
    --query 'StackResources[?ResourceType==`AWS::S3::Bucket`].PhysicalResourceId' \
    --output text \
    --region "$REGION" 2>/dev/null || echo "")

# Empty S3 buckets before stack deletion
if [ ! -z "$BUCKETS" ]; then
    echo "Emptying S3 buckets..."
    for bucket in $BUCKETS; do
        empty_s3_bucket "$bucket"
    done
    echo "All buckets processed."
else
    echo "No S3 buckets found in stack."
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
rm -f nodejs-app-source.zip
rm -rf temp-nodejs-app

echo
echo "🎉 CodeBuild Lab Cleanup Complete!"
echo
echo "All AWS resources have been removed."
echo "You can now run the provisioning script again for a fresh lab environment."