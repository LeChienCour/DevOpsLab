#!/bin/bash

# CodeDeploy Lab Provisioning Script
# This script provisions basic CodeDeploy infrastructure with EC2 instances

set -e

# Configuration
PROJECT_NAME="codedeploy-lab"
STACK_NAME="${PROJECT_NAME}-stack"
TEMPLATE_FILE="templates/codedeploy-infrastructure.yaml"
REGION=${AWS_DEFAULT_REGION:-us-east-1}

# Generate unique bucket name
TIMESTAMP=$(date +%s)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ARTIFACT_BUCKET="${PROJECT_NAME}-artifacts-${ACCOUNT_ID}-${TIMESTAMP}"

echo "=== CodeDeploy Lab Provisioning ==="
echo "Project Name: $PROJECT_NAME"
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
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
    echo "Please ensure you're running this script from the codedeploy directory"
    exit 1
fi

# Create sample application for deployment
echo "Creating sample application for deployment..."
mkdir -p temp-app/scripts

# Create simple HTML file
cat > temp-app/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CodeDeploy Lab Application</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            margin: 40px; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
        }
        .container { 
            max-width: 800px; 
            margin: 0 auto; 
            background: rgba(255,255,255,0.1);
            padding: 40px;
            border-radius: 15px;
            backdrop-filter: blur(10px);
        }
        .status { 
            background: rgba(255,255,255,0.2); 
            padding: 20px; 
            border-radius: 10px; 
            margin: 20px 0; 
        }
        .version { 
            font-size: 2rem; 
            font-weight: bold; 
            color: #ffd700; 
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 CodeDeploy Lab Application</h1>
        <div class="status">
            <h2>✅ CodeDeploy Deployment Successful!</h2>
            <p class="version">Version 2.0.0</p>
            <p>This version was deployed via CodeDeploy from S3.</p>
            <p><strong>Deployment Time:</strong> <span id="deploy-time"></span></p>
            <p><strong>Instance ID:</strong> <span id="instance-id"></span></p>
        </div>
    </div>
    <script>
        fetch('http://169.254.169.254/latest/meta-data/instance-id')
            .then(response => response.text())
            .then(data => document.getElementById('instance-id').textContent = data)
            .catch(() => document.getElementById('instance-id').textContent = 'Unknown');
        
        document.getElementById('deploy-time').textContent = new Date().toLocaleString();
    </script>
</body>
</html>
EOF

# Copy deployment scripts and make them executable
cp -r deployment-configs/scripts temp-app/
chmod +x temp-app/scripts/*.sh

# Copy appspec.yml
cp deployment-configs/appspec-ec2.yml temp-app/appspec.yml

# Create deployment package
echo "Creating deployment package..."
cd temp-app && zip -r ../sample-app-deployment.zip . && cd ..

echo "Deploying CloudFormation stack..."
aws cloudformation deploy \
    --template-file "$TEMPLATE_FILE" \
    --stack-name "$STACK_NAME" \
    --parameter-overrides \
        ProjectName="$PROJECT_NAME" \
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

# Upload sample application to S3
echo "Uploading sample application to S3..."
aws s3 cp sample-app-deployment.zip "s3://$ARTIFACT_BUCKET/" --region "$REGION"

# Get stack outputs
echo "Retrieving stack outputs..."
EC2_APP=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`EC2Application`].OutputValue' \
    --output text \
    --region "$REGION")

DEPLOYMENT_GROUP=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`DeploymentGroup`].OutputValue' \
    --output text \
    --region "$REGION")

INSTANCE1_IP=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`Instance1IP`].OutputValue' \
    --output text \
    --region "$REGION")

INSTANCE2_IP=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`Instance2IP`].OutputValue' \
    --output text \
    --region "$REGION")

# Create lab session info file
cat > lab-session-info.txt << EOF
=== CodeDeploy Lab Session Information ===
Created: $(date)
Stack Name: $STACK_NAME
Region: $REGION

Application Access:
- Instance 1: http://$INSTANCE1_IP
- Instance 2: http://$INSTANCE2_IP

CodeDeploy Resources:
- EC2 Application: $EC2_APP
- Deployment Group: $DEPLOYMENT_GROUP

Resources:
- Artifact Bucket: $ARTIFACT_BUCKET

Sample Deployment Command:
aws deploy create-deployment \\
  --application-name $EC2_APP \\
  --deployment-group-name $DEPLOYMENT_GROUP \\
  --s3-location bucket=$ARTIFACT_BUCKET,key=sample-app-deployment.zip,bundleType=zip

Next Steps:
1. Wait for EC2 instances to be ready (3-5 minutes)
2. Access the application at: http://$INSTANCE1_IP or http://$INSTANCE2_IP
3. Try deployments using the AWS Console or CLI
4. Monitor deployments and test rollback scenarios

Cleanup:
Run './cleanup-codedeploy.sh' to remove all resources when done.
EOF

# Clean up temporary files
rm -rf temp-app
rm -f sample-app-deployment.zip

echo
echo "🎉 CodeDeploy Lab Environment Ready!"
echo
cat lab-session-info.txt
echo
echo "Lab session information saved to: lab-session-info.txt"
echo
echo "⏳ Note: It may take 3-5 minutes for EC2 instances to be ready."
echo "You can monitor the instances in the AWS Console."