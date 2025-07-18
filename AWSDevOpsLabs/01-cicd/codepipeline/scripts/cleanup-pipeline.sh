#!/bin/bash

# CodePipeline Lab Cleanup Script
# This script removes all resources created by the CodePipeline lab

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
    
    # Check if this is the source bucket (which has versioning enabled)
    if [[ "$bucket_name" == *"-source-"* ]]; then
        echo "  Handling versioned source bucket..."
        
        # Remove current objects first
        echo "  Removing current objects..."
        aws s3 rm "s3://$bucket_name" --recursive --region "$REGION" 2>/dev/null || true
        
        # Remove versioned objects
        echo "  Removing versioned objects..."
        aws s3api list-object-versions \
            --bucket "$bucket_name" \
            --region "$REGION" \
            --query 'Versions[].[Key,VersionId]' \
            --output text 2>/dev/null | \
        while IFS=$'\t' read -r key version_id; do
            if [ ! -z "$key" ] && [ ! -z "$version_id" ] && [ "$version_id" != "null" ]; then
                echo "    Deleting version: $key ($version_id)"
                aws s3api delete-object \
                    --bucket "$bucket_name" \
                    --key "$key" \
                    --version-id "$version_id" \
                    --region "$REGION" 2>/dev/null || true
            fi
        done
        
        # Remove delete markers
        echo "  Removing delete markers..."
        aws s3api list-object-versions \
            --bucket "$bucket_name" \
            --region "$REGION" \
            --query 'DeleteMarkers[].[Key,VersionId]' \
            --output text 2>/dev/null | \
        while IFS=$'\t' read -r key version_id; do
            if [ ! -z "$key" ] && [ ! -z "$version_id" ] && [ "$version_id" != "null" ]; then
                echo "    Deleting delete marker: $key ($version_id)"
                aws s3api delete-object \
                    --bucket "$bucket_name" \
                    --key "$key" \
                    --version-id "$version_id" \
                    --region "$REGION" 2>/dev/null || true
            fi
        done
    else
        echo "  Handling non-versioned bucket..."
        # Simple object deletion for non-versioned buckets
        echo "  Removing all objects..."
        aws s3 rm "s3://$bucket_name" --recursive --region "$REGION" 2>/dev/null || true
    fi
    
    # Clean up any incomplete multipart uploads (for all buckets)
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
echo "This may take several minutes..."

# Wait for stack deletion with timeout
if timeout 900 aws cloudformation wait stack-delete-complete \
    --stack-name "$STACK_NAME" \
    --region "$REGION"; then
    echo "✅ Stack deletion successful!"
else
    echo "❌ Stack deletion failed or timed out"
    echo "Checking stack status..."
    
    STACK_STATUS=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --query 'Stacks[0].StackStatus' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "STACK_NOT_FOUND")
    
    if [ "$STACK_STATUS" = "STACK_NOT_FOUND" ]; then
        echo "✅ Stack was successfully deleted (not found)"
    else
        echo "Current stack status: $STACK_STATUS"
        echo
        echo "Checking for stack events to identify the issue..."
        aws cloudformation describe-stack-events \
            --stack-name "$STACK_NAME" \
            --query 'StackEvents[?ResourceStatus==`DELETE_FAILED`].[LogicalResourceId,ResourceType,ResourceStatusReason]' \
            --output table \
            --region "$REGION" 2>/dev/null || true
        
        echo
        echo "Attempting to force delete remaining resources..."
        
        # Try to delete any remaining S3 buckets manually
        echo "Checking for any remaining S3 buckets..."
        REMAINING_BUCKETS=$(aws cloudformation describe-stack-resources \
            --stack-name "$STACK_NAME" \
            --query 'StackResources[?ResourceType==`AWS::S3::Bucket` && ResourceStatus!=`DELETE_COMPLETE`].PhysicalResourceId' \
            --output text \
            --region "$REGION" 2>/dev/null || echo "")
        
        if [ ! -z "$REMAINING_BUCKETS" ]; then
            echo "Found remaining S3 buckets, attempting manual deletion..."
            for bucket in $REMAINING_BUCKETS; do
                echo "  Force deleting bucket: $bucket"
                # Try to delete the bucket directly
                aws s3api delete-bucket --bucket "$bucket" --region "$REGION" 2>/dev/null || true
            done
        fi
        
        # Try stack deletion one more time
        echo "Retrying stack deletion..."
        aws cloudformation delete-stack \
            --stack-name "$STACK_NAME" \
            --region "$REGION" 2>/dev/null || true
        
        # Wait a bit and check final status
        sleep 30
        FINAL_STATUS=$(aws cloudformation describe-stacks \
            --stack-name "$STACK_NAME" \
            --query 'Stacks[0].StackStatus' \
            --output text \
            --region "$REGION" 2>/dev/null || echo "STACK_NOT_FOUND")
        
        if [ "$FINAL_STATUS" = "STACK_NOT_FOUND" ]; then
            echo "✅ Stack deletion completed after retry"
        elif [ "$FINAL_STATUS" = "DELETE_COMPLETE" ]; then
            echo "✅ Stack deletion completed successfully"
        else
            echo "❌ Stack deletion still failed. Final status: $FINAL_STATUS"
            echo "Please manually delete the stack and remaining resources in the AWS Console"
            echo "You can also try running this script again"
            exit 1
        fi
    fi
fi

# Clean up local files
echo "Cleaning up local files..."
rm -f lab-session-info.txt
rm -f initial-code.zip
rm -f source-code.zip
rm -f updated-source-code.zip
rm -f broken-source-code.zip
rm -rf updated-source
rm -rf broken-source

echo
echo "🎉 CodePipeline Lab Cleanup Complete!"
echo
echo "All AWS resources have been removed."
echo "You can now run the provisioning script again for a fresh lab environment."