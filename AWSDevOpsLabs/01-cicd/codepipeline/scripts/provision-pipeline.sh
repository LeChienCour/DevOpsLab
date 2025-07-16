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
ARTIFACT_BUCKET="${PROJECT_NAME}-artifacts-${ACCOUNT_ID}-${TIMESTAMP}"
DEPLOYMENT_BUCKET="${PROJECT_NAME}-deployment-${ACCOUNT_ID}-${TIMESTAMP}"

echo "=== CodePipeline Lab Provisioning ==="
echo "Project Name: $PROJECT_NAME"
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
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

# Create initial code archive for CodeCommit
echo "Creating initial code archive..."
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
      - echo Build started on `date`
      - echo Preparing build environment...
  build:
    commands:
      - echo Build phase started on `date`
      - echo Creating web application files...
      - mkdir -p dist
      - echo "<html><body><h1>Hello from DevOps Pipeline Lab!</h1><p>Build completed on $(date)</p><p>Commit: $CODEBUILD_RESOLVED_SOURCE_VERSION</p></body></html>" > dist/index.html
      - echo "<html><body><h1>Error Page</h1><p>Something went wrong!</p></body></html>" > dist/error.html
  post_build:
    commands:
      - echo Build completed on `date`
artifacts:
  files:
    - '**/*'
  base-directory: dist
EOF

# Create zip file for initial commit
cd temp-repo
zip -r ../initial-code.zip .
cd ..
rm -rf temp-repo

echo "Deploying CloudFormation stack..."
aws cloudformation deploy \
    --template-file "$TEMPLATE_FILE" \
    --stack-name "$STACK_NAME" \
    --parameter-overrides \
        ProjectName="$PROJECT_NAME" \
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

# Upload initial code to artifact bucket
echo "Uploading initial code to artifact bucket..."
aws s3 cp initial-code.zip "s3://$ARTIFACT_BUCKET/initial-code.zip" --region "$REGION"
rm initial-code.zip

# Get stack outputs
echo "Retrieving stack outputs..."
PIPELINE_NAME=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`PipelineName`].OutputValue' \
    --output text \
    --region "$REGION")

REPO_CLONE_URL=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`RepositoryCloneUrl`].OutputValue' \
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
- Repository Clone URL: $REPO_CLONE_URL
- Deployment URL: $DEPLOYMENT_URL
- Artifact Bucket: $ARTIFACT_BUCKET
- Deployment Bucket: $DEPLOYMENT_BUCKET

Next Steps:
1. Clone the repository: git clone $REPO_CLONE_URL
2. Make changes to the code and push to trigger the pipeline
3. Monitor pipeline execution in the AWS Console
4. View deployed application at: $DEPLOYMENT_URL

Cleanup:
Run './cleanup-pipeline.sh' to remove all resources when done.
EOF

echo
echo "🎉 CodePipeline Lab Environment Ready!"
echo
cat lab-session-info.txt
echo
echo "Lab session information saved to: lab-session-info.txt"