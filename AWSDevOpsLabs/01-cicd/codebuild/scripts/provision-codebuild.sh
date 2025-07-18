#!/bin/bash

# CodeBuild Lab Provisioning Script
# This script provisions a single CodeBuild project for learning fundamentals

set -e

# Configuration
PROJECT_NAME="codebuild-lab"
STACK_NAME="${PROJECT_NAME}-stack"
TEMPLATE_FILE="templates/codebuild-infrastructure.yaml"
REGION=${AWS_DEFAULT_REGION:-us-east-1}

# Generate unique bucket names
TIMESTAMP=$(date +%s)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
SOURCE_BUCKET="${PROJECT_NAME}-source-${ACCOUNT_ID}-${TIMESTAMP}"
ARTIFACT_BUCKET="${PROJECT_NAME}-artifacts-${ACCOUNT_ID}-${TIMESTAMP}"

echo "=== CodeBuild Lab Provisioning ==="
echo "Project Name: $PROJECT_NAME"
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo "Source Bucket: $SOURCE_BUCKET"
echo "Artifact Bucket: $ARTIFACT_BUCKET"
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
    echo "Please ensure you're running this script from the codebuild directory"
    exit 1
fi

# Create simple Node.js sample project
echo "Creating sample Node.js application..."
mkdir -p temp-nodejs-app

cat > temp-nodejs-app/package.json << 'EOF'
{
  "name": "codebuild-lab-app",
  "version": "1.0.0",
  "description": "Simple Node.js application for CodeBuild lab",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "test": "echo 'No tests specified'"
  },
  "dependencies": {
    "express": "^4.18.0"
  }
}
EOF

cat > temp-nodejs-app/index.js << 'EOF'
const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.json({ 
    message: 'Hello from CodeBuild Lab!',
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  });
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', uptime: process.uptime() });
});

if (require.main === module) {
  app.listen(port, () => {
    console.log(`Server running on port ${port}`);
  });
}

module.exports = app;
EOF

# Create buildspec.yml for the sample project
cat > temp-nodejs-app/buildspec.yml << 'EOF'
version: 0.2
phases:
  install:
    runtime-versions:
      nodejs: 18
  pre_build:
    commands:
      - echo "Build started on $(date)"
      - echo "Installing dependencies..."
      - npm install
  build:
    commands:
      - echo "Build phase started on $(date)"
      - echo "Running build..."
      - mkdir -p dist
      - cp index.js dist/
      - cp package.json dist/
      - echo "Build completed successfully"
  post_build:
    commands:
      - echo "Build completed on $(date)"
artifacts:
  files:
    - '**/*'
  base-directory: dist
EOF

# Create the source archive
echo "Creating source archive..."
cd temp-nodejs-app && zip -r ../nodejs-app-source.zip . && cd ..

echo "Deploying CloudFormation stack..."
aws cloudformation deploy \
    --template-file "$TEMPLATE_FILE" \
    --stack-name "$STACK_NAME" \
    --parameter-overrides \
        ProjectName="$PROJECT_NAME" \
        SourceBucketName="$SOURCE_BUCKET" \
        ArtifactBucketName="$ARTIFACT_BUCKET" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "$REGION" \
    --tags Project="$PROJECT_NAME" Environment="Lab"

if [ $? -eq 0 ]; then
    echo "✅ Stack deployment successful!"
else
    echo "❌ Stack deployment failed!"
    exit 1
fi

# Upload sample source code to S3
echo "Uploading sample source code to S3..."
aws s3 cp nodejs-app-source.zip "s3://$SOURCE_BUCKET/" --region "$REGION"

# Get stack outputs
echo "Retrieving stack outputs..."
BUILD_PROJECT=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`BuildProject`].OutputValue' \
    --output text \
    --region "$REGION")

SOURCE_BUCKET_OUTPUT=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`SourceBucket`].OutputValue' \
    --output text \
    --region "$REGION")

ARTIFACT_BUCKET_OUTPUT=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`ArtifactBucket`].OutputValue' \
    --output text \
    --region "$REGION")

# Create lab session info file
cat > lab-session-info.txt << EOF
=== CodeBuild Lab Session Information ===
Created: $(date)
Stack Name: $STACK_NAME
Region: $REGION

Resources Created:
- Build Project: $BUILD_PROJECT
- Source Bucket: $SOURCE_BUCKET_OUTPUT
- Artifact Bucket: $ARTIFACT_BUCKET_OUTPUT

Sample Project Available:
- nodejs-app-source.zip (Simple Node.js application)

Next Steps:
1. Start builds using the AWS Console or CLI
2. Monitor build logs and caching behavior
3. Experiment with custom buildspec configurations
4. Test build performance with multiple executions

Example CLI Commands:
aws codebuild start-build --project-name $BUILD_PROJECT --source-location s3://$SOURCE_BUCKET_OUTPUT/nodejs-app-source.zip

Cleanup:
Run './cleanup-codebuild.sh' to remove all resources when done.
EOF

# Clean up temporary files
rm -rf temp-nodejs-app
rm -f nodejs-app-source.zip

echo
echo "🎉 CodeBuild Lab Environment Ready!"
echo
cat lab-session-info.txt
echo
echo "Lab session information saved to: lab-session-info.txt"