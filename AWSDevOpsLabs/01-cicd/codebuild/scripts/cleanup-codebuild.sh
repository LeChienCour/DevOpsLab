#!/bin/bash

# Advanced CodeBuild Lab Cleanup Script
# This script removes all resources created by the CodeBuild lab

set -e

# Configuration
PROJECT_NAME="advanced-codebuild-lab"
STACK_NAME="${PROJECT_NAME}-stack"
REGION=${AWS_DEFAULT_REGION:-us-east-1}

echo "=== Advanced CodeBuild Lab Cleanup ==="
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

# Get bucket names and ECR repository from stack outputs before deletion
echo "Retrieving resource information..."
ARTIFACT_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`ArtifactBucket`].OutputValue' \
    --output text \
    --region "$REGION" 2>/dev/null || echo "")

CACHE_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`CacheBucket`].OutputValue' \
    --output text \
    --region "$REGION" 2>/dev/null || echo "")

ECR_REPO_URI=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`ECRRepository`].OutputValue' \
    --output text \
    --region "$REGION" 2>/dev/null || echo "")

# Extract ECR repository name from URI
ECR_REPO_NAME=""
if [ ! -z "$ECR_REPO_URI" ]; then
    ECR_REPO_NAME=$(echo "$ECR_REPO_URI" | cut -d'/' -f2)
fi

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
                --region "$REGION" 2>/dev/null | while read key version; do
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
                --region "$REGION" 2>/dev/null | while read key version; do
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

# Clean up ECR repository images
if [ ! -z "$ECR_REPO_NAME" ]; then
    echo "Cleaning up ECR repository: $ECR_REPO_NAME"
    if aws ecr describe-repositories --repository-names "$ECR_REPO_NAME" --region "$REGION" > /dev/null 2>&1; then
        echo "Deleting all images in ECR repository..."
        IMAGE_IDS=$(aws ecr list-images \
            --repository-name "$ECR_REPO_NAME" \
            --query 'imageIds[*]' \
            --output json \
            --region "$REGION" 2>/dev/null || echo "[]")
        
        if [ "$IMAGE_IDS" != "[]" ] && [ ! -z "$IMAGE_IDS" ]; then
            aws ecr batch-delete-image \
                --repository-name "$ECR_REPO_NAME" \
                --image-ids "$IMAGE_IDS" \
                --region "$REGION" || true
        fi
    else
        echo "ECR repository $ECR_REPO_NAME not found or already deleted"
    fi
fi

# Stop any running builds before deleting projects
echo "Stopping any running builds..."
BUILD_PROJECTS=$(aws cloudformation describe-stack-resources \
    --stack-name "$STACK_NAME" \
    --query 'StackResources[?ResourceType==`AWS::CodeBuild::Project`].PhysicalResourceId' \
    --output text \
    --region "$REGION" 2>/dev/null || echo "")

for project in $BUILD_PROJECTS; do
    if [ ! -z "$project" ]; then
        echo "Checking for running builds in project: $project"
        RUNNING_BUILDS=$(aws codebuild list-builds-for-project \
            --project-name "$project" \
            --query 'ids[0]' \
            --output text \
            --region "$REGION" 2>/dev/null || echo "")
        
        if [ ! -z "$RUNNING_BUILDS" ] && [ "$RUNNING_BUILDS" != "None" ]; then
            BUILD_STATUS=$(aws codebuild batch-get-builds \
                --ids "$RUNNING_BUILDS" \
                --query 'builds[0].buildStatus' \
                --output text \
                --region "$REGION" 2>/dev/null || echo "")
            
            if [ "$BUILD_STATUS" = "IN_PROGRESS" ]; then
                echo "Stopping running build: $RUNNING_BUILDS"
                aws codebuild stop-build --id "$RUNNING_BUILDS" --region "$REGION" || true
            fi
        fi
    fi
done

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
rm -f *-source.zip
rm -rf sample-projects

echo
echo "🎉 Advanced CodeBuild Lab Cleanup Complete!"
echo
echo "All AWS resources have been removed."
echo "You can now run the provisioning script again for a fresh lab environment."