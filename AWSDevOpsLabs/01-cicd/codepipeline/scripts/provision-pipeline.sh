#!/bin/bash

# CodePipeline Lab Provisioning Script
# This script provisions the complete CodePipeline infrastructure

set -e

# Configuration
PROJECT_NAME="devops-pipeline-lab"
STACK_NAME="${PROJECT_NAME}-stack"
TEMPLATE_FILE="templates/pipeline-infrastructure.yaml"
REGION=${AWS_DEFAULT_REGION:-us-east-1}

# Generate unique bucket names
TIMESTAMP=$(date +%s)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
SOURCE_BUCKET="${PROJECT_NAME}-source-${ACCOUNT_ID}-${TIMESTAMP}"
ARTIFACT_BUCKET="${PROJECT_NAME}-artifacts-${ACCOUNT_ID}-${TIMESTAMP}"
DEPLOYMENT_BUCKET="${PROJECT_NAME}-deployment-${ACCOUNT_ID}-${TIMESTAMP}"

echo "=== CodePipeline Lab Provisioning ==="
echo "Project Name: $PROJECT_NAME"
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo "Source Bucket: $SOURCE_BUCKET"
echo "Artifact Bucket: $ARTIFACT_BUCKET"
echo "Deployment Bucket: $DEPLOYMENT_BUCKET"
echo

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "Error: AWS CLI is not configured or credentials are invalid"
    echo "Please run 'aws configure' to set up your credentials"
    exit 1
fi

# Check if template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file $TEMPLATE_FILE not found"
    echo "Please ensure you're running this script from the codepipeline directory"
    exit 1
fi

# Create initial code archive for S3 source
echo "Creating initial source code archive..."
mkdir -p temp-repo
cat > temp-repo/README.md << 'EOF'
# DevOps Pipeline Lab

This repository contains a simple web application for demonstrating AWS CodePipeline.

## Files
- `README.md` - This file
- `buildspec.yml` - CodeBuild build specification

The pipeline will automatically build and deploy this application when changes are pushed to the main branch.
EOF

cat > temp-repo/buildspec.yml << 'EOF'
version: 0.2
phases:
  pre_build:
    commands:
      - echo "Build started on $(date)"
      - echo "Preparing build environment..."
  build:
    commands:
      - echo "Build phase started on $(date)"
      - echo "Creating web application files..."
      - mkdir -p dist
      - |
        cat > dist/index.html << 'HTML'
        <html>
        <body>
          <h1>Hello from DevOps Pipeline Lab!</h1>
          <p>Build completed on $(date)</p>
          <p>Build ID: ${CODEBUILD_BUILD_ID}</p>
        </body>
        </html>
        HTML
      - |
        cat > dist/error.html << 'HTML'
        <html>
        <body>
          <h1>Error Page</h1>
          <p>Something went wrong!</p>
        </body>
        </html>
        HTML
  post_build:
    commands:
      - echo "Build completed on $(date)"
artifacts:
  files:
    - '**/*'
  base-directory: dist
EOF

# Create a separate buildspec for the test stage
cat > temp-repo/buildspec-test.yml << 'EOF'
version: 0.2
phases:
  pre_build:
    commands:
      - echo Test phase started on `date`
  build:
    commands:
      - echo Running tests...
      - ls -la
      - test -f index.html && echo 'index.html found' || (echo 'index.html not found' && exit 1)
      - test -f error.html && echo 'error.html found' || (echo 'error.html not found' && exit 1)
      - echo 'Basic file validation passed'
  post_build:
    commands:
      - echo Test phase completed on `date`
artifacts:
  files:
    - '**/*'
EOF

# Create zip file for initial commit
echo "Creating source code archive..."
echo "Files in temp-repo:"
ls -la temp-repo/

cd temp-repo
zip -r ../initial-code.zip .
cd ..

echo "Contents of initial-code.zip:"
unzip -l initial-code.zip

rm -rf temp-repo

echo "Deploying CloudFormation stack..."
aws cloudformation deploy \
    --template-file "$TEMPLATE_FILE" \
    --stack-name "$STACK_NAME" \
    --parameter-overrides \
        ProjectName="$PROJECT_NAME" \
        SourceBucketName="$SOURCE_BUCKET" \
        ArtifactBucketName="$ARTIFACT_BUCKET" \
        DeploymentBucketName="$DEPLOYMENT_BUCKET" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "$REGION" \
    --tags Project="$PROJECT_NAME" Environment="Lab"

if [ $? -eq 0 ]; then
    echo "✅ Stack deployment successful!"
else
    echo "❌ Stack deployment failed!"
    exit 1
fi

# Upload initial code to source bucket
echo "Waiting for S3 bucket to be fully available..."
sleep 10  # Wait for 10 seconds before attempting upload

echo "Uploading initial source code to source bucket..."
if aws s3 cp initial-code.zip "s3://$SOURCE_BUCKET/source-code.zip" --region "$REGION"; then
    echo "✅ Initial source code uploaded successfully"
    
    # Verify the upload
    echo "Verifying upload..."
    if aws s3api head-object --bucket "$SOURCE_BUCKET" --key "source-code.zip" --region "$REGION" > /dev/null 2>&1; then
        echo "✅ Upload verified - source-code.zip exists in bucket"
    else
        echo "❌ Upload verification failed - source-code.zip not found in bucket"
        exit 1
    fi
else
    echo "❌ Failed to upload initial source code"
    exit 1
fi

# Keep a copy of the initial code for reference
cp initial-code.zip source-code.zip
rm initial-code.zip

# Wait a bit more for S3 consistency
echo "Waiting for S3 eventual consistency..."
sleep 5

# Get stack outputs
echo "Retrieving stack outputs..."
PIPELINE_NAME=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`PipelineName`].OutputValue' \
    --output text \
    --region "$REGION")

SOURCE_BUCKET_OUTPUT=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`SourceBucket`].OutputValue' \
    --output text \
    --region "$REGION")

DEPLOYMENT_URL=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`DeploymentUrl`].OutputValue' \
    --output text \
    --region "$REGION")

# Create lab session info file
cat > lab-session-info.txt << EOF
=== CodePipeline Lab Session Information ===
Created: $(date)
Stack Name: $STACK_NAME
Region: $REGION

Resources Created:
- Pipeline Name: $PIPELINE_NAME
- Source Bucket: $SOURCE_BUCKET_OUTPUT
- Deployment URL: $DEPLOYMENT_URL
- Artifact Bucket: $ARTIFACT_BUCKET
- Deployment Bucket: $DEPLOYMENT_BUCKET

Next Steps:
1. Upload new source code to S3: aws s3 cp source-code.zip s3://$SOURCE_BUCKET_OUTPUT/source-code.zip
2. Monitor pipeline execution in the AWS Console
3. View deployed application at: $DEPLOYMENT_URL

To trigger a new deployment:
1. Create a new source-code.zip file with your changes
2. Upload it to the source bucket: aws s3 cp source-code.zip s3://$SOURCE_BUCKET_OUTPUT/source-code.zip
3. The pipeline will automatically detect the change and start

Cleanup:
Run './cleanup-pipeline.sh' to remove all resources when done.
EOF

# Manually trigger the pipeline to ensure it starts
echo "Triggering initial pipeline execution..."
aws codepipeline start-pipeline-execution \
    --name "$PIPELINE_NAME" \
    --region "$REGION" > /dev/null 2>&1 || echo "Note: Pipeline may already be running"

echo
echo "🎉 CodePipeline Lab Environment Ready!"
echo
cat lab-session-info.txt
echo
echo "Lab session information saved to: lab-session-info.txt"
echo
echo "Pipeline should be running now. Check the AWS Console:"
echo "https://console.aws.amazon.com/codesuite/codepipeline/pipelines/$PIPELINE_NAME/view"