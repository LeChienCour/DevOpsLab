#!/bin/bash

# CodeDeploy Lab Provisioning Script
# This script provisions CodeDeploy infrastructure with deployment strategies

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

# Get default VPC and subnets
echo "Retrieving default VPC and subnet information..."
DEFAULT_VPC=$(aws ec2 describe-vpcs \
    --filters "Name=is-default,Values=true" \
    --query 'Vpcs[0].VpcId' \
    --output text \
    --region "$REGION")

if [ "$DEFAULT_VPC" = "None" ] || [ -z "$DEFAULT_VPC" ]; then
    echo "Error: No default VPC found. Please create a VPC or specify VPC ID manually."
    exit 1
fi

SUBNET_IDS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$DEFAULT_VPC" \
    --query 'Subnets[*].SubnetId' \
    --output text \
    --region "$REGION")

if [ -z "$SUBNET_IDS" ]; then
    echo "Error: No subnets found in default VPC"
    exit 1
fi

# Convert space-separated subnet IDs to comma-separated
SUBNET_LIST=$(echo $SUBNET_IDS | tr ' ' ',')

echo "Using VPC: $DEFAULT_VPC"
echo "Using Subnets: $SUBNET_LIST"

# Check for existing key pairs
KEY_PAIRS=$(aws ec2 describe-key-pairs --query 'KeyPairs[*].KeyName' --output text --region "$REGION")
if [ -z "$KEY_PAIRS" ]; then
    echo "Warning: No EC2 key pairs found. Creating a new key pair..."
    KEY_PAIR_NAME="${PROJECT_NAME}-keypair"
    aws ec2 create-key-pair \
        --key-name "$KEY_PAIR_NAME" \
        --query 'KeyMaterial' \
        --output text \
        --region "$REGION" > "${KEY_PAIR_NAME}.pem"
    chmod 400 "${KEY_PAIR_NAME}.pem"
    echo "Created key pair: $KEY_PAIR_NAME (saved as ${KEY_PAIR_NAME}.pem)"
else
    # Use the first available key pair
    KEY_PAIR_NAME=$(echo $KEY_PAIRS | cut -d' ' -f1)
    echo "Using existing key pair: $KEY_PAIR_NAME"
fi

# Create sample application for deployment
echo "Creating sample application for deployment..."
mkdir -p sample-app/{scripts,css,js}

# Create main HTML file
cat > sample-app/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CodeDeploy Lab Application</title>
    <link rel="stylesheet" href="css/style.css">
</head>
<body>
    <div class="container">
        <header>
            <h1>🚀 CodeDeploy Lab Application</h1>
            <p class="subtitle">Demonstrating AWS CodeDeploy Deployment Strategies</p>
        </header>
        
        <main>
            <div class="status-card success">
                <h2>✅ Deployment Successful</h2>
                <p>This application was deployed using AWS CodeDeploy</p>
                <div class="deployment-info">
                    <h3>Deployment Information</h3>
                    <ul>
                        <li><strong>Version:</strong> <span id="app-version">2.0.0</span></li>
                        <li><strong>Deployment Time:</strong> <span id="deploy-time">Loading...</span></li>
                        <li><strong>Instance ID:</strong> <span id="instance-id">Loading...</span></li>
                        <li><strong>Deployment Strategy:</strong> <span id="strategy">Blue-Green</span></li>
                    </ul>
                </div>
            </div>
            
            <div class="features">
                <h2>🎯 Lab Features</h2>
                <div class="feature-grid">
                    <div class="feature-card">
                        <h3>Blue-Green Deployment</h3>
                        <p>Zero-downtime deployments with automatic rollback</p>
                    </div>
                    <div class="feature-card">
                        <h3>In-Place Deployment</h3>
                        <p>Rolling updates with health checks</p>
                    </div>
                    <div class="feature-card">
                        <h3>ECS Deployment</h3>
                        <p>Container-based deployments with traffic shifting</p>
                    </div>
                    <div class="feature-card">
                        <h3>Auto Rollback</h3>
                        <p>Automatic rollback on deployment failures</p>
                    </div>
                </div>
            </div>
            
            <div class="health-check">
                <h2>🏥 Health Check</h2>
                <button onclick="performHealthCheck()" id="health-btn">Check Application Health</button>
                <div id="health-result"></div>
            </div>
        </main>
        
        <footer>
            <p>AWS DevOps Professional Certification Lab</p>
            <p>Last Updated: <span id="last-updated"></span></p>
        </footer>
    </div>
    
    <script src="js/app.js"></script>
</body>
</html>
EOF

# Create CSS file
cat > sample-app/css/style.css << 'EOF'
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    line-height: 1.6;
    color: #333;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    min-height: 100vh;
}

.container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 20px;
}

header {
    text-align: center;
    color: white;
    margin-bottom: 40px;
}

header h1 {
    font-size: 3rem;
    margin-bottom: 10px;
    text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
}

.subtitle {
    font-size: 1.2rem;
    opacity: 0.9;
}

main {
    background: white;
    border-radius: 15px;
    padding: 40px;
    box-shadow: 0 10px 30px rgba(0,0,0,0.2);
    margin-bottom: 20px;
}

.status-card {
    padding: 30px;
    border-radius: 10px;
    margin-bottom: 30px;
    text-align: center;
}

.status-card.success {
    background: linear-gradient(135deg, #4CAF50, #45a049);
    color: white;
}

.status-card h2 {
    font-size: 2rem;
    margin-bottom: 15px;
}

.deployment-info {
    background: rgba(255,255,255,0.1);
    padding: 20px;
    border-radius: 8px;
    margin-top: 20px;
}

.deployment-info ul {
    list-style: none;
    text-align: left;
    max-width: 400px;
    margin: 0 auto;
}

.deployment-info li {
    padding: 8px 0;
    border-bottom: 1px solid rgba(255,255,255,0.2);
}

.features h2 {
    text-align: center;
    margin-bottom: 30px;
    color: #333;
}

.feature-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: 20px;
    margin-bottom: 30px;
}

.feature-card {
    background: #f8f9fa;
    padding: 25px;
    border-radius: 10px;
    text-align: center;
    border: 2px solid #e9ecef;
    transition: transform 0.3s ease;
}

.feature-card:hover {
    transform: translateY(-5px);
    border-color: #667eea;
}

.feature-card h3 {
    color: #667eea;
    margin-bottom: 15px;
}

.health-check {
    text-align: center;
    padding: 30px;
    background: #f8f9fa;
    border-radius: 10px;
}

.health-check h2 {
    margin-bottom: 20px;
    color: #333;
}

#health-btn {
    background: linear-gradient(135deg, #667eea, #764ba2);
    color: white;
    border: none;
    padding: 15px 30px;
    font-size: 1.1rem;
    border-radius: 25px;
    cursor: pointer;
    transition: transform 0.3s ease;
}

#health-btn:hover {
    transform: scale(1.05);
}

#health-result {
    margin-top: 20px;
    padding: 15px;
    border-radius: 8px;
    display: none;
}

#health-result.success {
    background: #d4edda;
    color: #155724;
    border: 1px solid #c3e6cb;
    display: block;
}

#health-result.error {
    background: #f8d7da;
    color: #721c24;
    border: 1px solid #f5c6cb;
    display: block;
}

footer {
    text-align: center;
    color: white;
    opacity: 0.8;
    padding: 20px;
}

@media (max-width: 768px) {
    header h1 {
        font-size: 2rem;
    }
    
    .container {
        padding: 10px;
    }
    
    main {
        padding: 20px;
    }
    
    .feature-grid {
        grid-template-columns: 1fr;
    }
}
EOF

# Create JavaScript file
cat > sample-app/js/app.js << 'EOF'
// Initialize the application
document.addEventListener('DOMContentLoaded', function() {
    loadInstanceMetadata();
    loadDeploymentInfo();
    updateLastUpdated();
});

// Load EC2 instance metadata
async function loadInstanceMetadata() {
    try {
        const response = await fetch('http://169.254.169.254/latest/meta-data/instance-id');
        const instanceId = await response.text();
        document.getElementById('instance-id').textContent = instanceId;
    } catch (error) {
        document.getElementById('instance-id').textContent = 'Not available (not running on EC2)';
    }
}

// Load deployment information
async function loadDeploymentInfo() {
    try {
        const response = await fetch('/deployment-info.json');
        const deploymentInfo = await response.json();
        
        if (deploymentInfo.deploymentTime) {
            const deployTime = new Date(deploymentInfo.deploymentTime);
            document.getElementById('deploy-time').textContent = deployTime.toLocaleString();
        }
        
        if (deploymentInfo.deploymentGroupName) {
            const strategy = deploymentInfo.deploymentGroupName.includes('blue-green') ? 'Blue-Green' : 'In-Place';
            document.getElementById('strategy').textContent = strategy;
        }
    } catch (error) {
        document.getElementById('deploy-time').textContent = 'Information not available';
        console.log('Deployment info not available:', error);
    }
}

// Update last updated timestamp
function updateLastUpdated() {
    document.getElementById('last-updated').textContent = new Date().toLocaleString();
}

// Perform health check
async function performHealthCheck() {
    const button = document.getElementById('health-btn');
    const result = document.getElementById('health-result');
    
    button.textContent = 'Checking...';
    button.disabled = true;
    
    try {
        // Perform multiple health checks
        const checks = await Promise.all([
            fetch('/').then(r => ({ name: 'Main Page', status: r.ok })),
            fetch('/deployment-info.json').then(r => ({ name: 'Deployment Info', status: r.ok })),
            checkServerTime()
        ]);
        
        const allPassed = checks.every(check => check.status);
        
        if (allPassed) {
            result.className = 'success';
            result.innerHTML = `
                <h3>✅ Health Check Passed</h3>
                <p>All systems are operational</p>
                <ul style="text-align: left; margin-top: 10px;">
                    ${checks.map(check => `<li>✅ ${check.name}</li>`).join('')}
                </ul>
            `;
        } else {
            result.className = 'error';
            result.innerHTML = `
                <h3>❌ Health Check Failed</h3>
                <p>Some systems are not responding correctly</p>
                <ul style="text-align: left; margin-top: 10px;">
                    ${checks.map(check => `<li>${check.status ? '✅' : '❌'} ${check.name}</li>`).join('')}
                </ul>
            `;
        }
    } catch (error) {
        result.className = 'error';
        result.innerHTML = `
            <h3>❌ Health Check Error</h3>
            <p>Unable to perform health check: ${error.message}</p>
        `;
    }
    
    button.textContent = 'Check Application Health';
    button.disabled = false;
}

// Check server time (simple connectivity test)
async function checkServerTime() {
    const start = Date.now();
    try {
        await fetch('/', { method: 'HEAD' });
        const responseTime = Date.now() - start;
        return { name: `Server Response (${responseTime}ms)`, status: responseTime < 5000 };
    } catch (error) {
        return { name: 'Server Response', status: false };
    }
}

// Auto-refresh deployment info every 30 seconds
setInterval(loadDeploymentInfo, 30000);
EOF

# Create error page
cat > sample-app/error.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Error - CodeDeploy Lab</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            margin: 40px; 
            background-color: #f8f9fa;
            text-align: center;
        }
        .container { 
            max-width: 600px; 
            margin: 0 auto; 
            background-color: white;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .error { 
            background-color: #f8d7da; 
            border: 1px solid #f5c6cb; 
            color: #721c24;
            padding: 20px; 
            border-radius: 5px; 
            margin: 20px 0; 
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚫 Error</h1>
        <div class="error">
            <h3>Something went wrong</h3>
            <p>The requested page could not be found or there was an error processing your request.</p>
        </div>
        <p><a href="/">← Return to Home Page</a></p>
    </div>
</body>
</html>
EOF

# Copy deployment scripts and make them executable
cp -r deployment-configs/scripts sample-app/
chmod +x sample-app/scripts/*.sh

# Copy appspec.yml
cp deployment-configs/appspec-ec2.yml sample-app/appspec.yml

# Create deployment package
echo "Creating deployment package..."
cd sample-app && zip -r ../sample-app-deployment.zip . && cd ..

echo "Deploying CloudFormation stack..."
aws cloudformation deploy \
    --template-file "$TEMPLATE_FILE" \
    --stack-name "$STACK_NAME" \
    --parameter-overrides \
        ProjectName="$PROJECT_NAME" \
        VpcId="$DEFAULT_VPC" \
        SubnetIds="$SUBNET_LIST" \
        KeyPairName="$KEY_PAIR_NAME" \
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
ALB_DNS=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`ApplicationLoadBalancerDNS`].OutputValue' \
    --output text \
    --region "$REGION")

EC2_APP=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`CodeDeployApplicationEC2`].OutputValue' \
    --output text \
    --region "$REGION")

ECS_APP=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`CodeDeployApplicationECS`].OutputValue' \
    --output text \
    --region "$REGION")

BLUE_GREEN_DG=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`BlueGreenDeploymentGroup`].OutputValue' \
    --output text \
    --region "$REGION")

IN_PLACE_DG=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`InPlaceDeploymentGroup`].OutputValue' \
    --output text \
    --region "$REGION")

# Create lab session info file
cat > lab-session-info.txt << EOF
=== CodeDeploy Lab Session Information ===
Created: $(date)
Stack Name: $STACK_NAME
Region: $REGION

Application Access:
- Load Balancer URL: http://$ALB_DNS
- ECS Application URL: http://$ALB_DNS/ecs/

CodeDeploy Applications:
- EC2 Application: $EC2_APP
- ECS Application: $ECS_APP

Deployment Groups:
- Blue-Green Deployment Group: $BLUE_GREEN_DG
- In-Place Deployment Group: $IN_PLACE_DG

Resources:
- Artifact Bucket: $ARTIFACT_BUCKET
- Key Pair: $KEY_PAIR_NAME
- VPC: $DEFAULT_VPC

Sample Deployment Commands:
# Blue-Green Deployment
aws deploy create-deployment \\
  --application-name $EC2_APP \\
  --deployment-group-name $BLUE_GREEN_DG \\
  --s3-location bucket=$ARTIFACT_BUCKET,key=sample-app-deployment.zip,bundleType=zip

# In-Place Deployment  
aws deploy create-deployment \\
  --application-name $EC2_APP \\
  --deployment-group-name $IN_PLACE_DG \\
  --s3-location bucket=$ARTIFACT_BUCKET,key=sample-app-deployment.zip,bundleType=zip

Next Steps:
1. Wait for Auto Scaling Group instances to be ready (5-10 minutes)
2. Access the application at: http://$ALB_DNS
3. Try different deployment strategies using the AWS Console or CLI
4. Monitor deployments and test rollback scenarios

Cleanup:
Run './cleanup-codedeploy.sh' to remove all resources when done.
EOF

# Clean up temporary files
rm -rf sample-app
rm -f sample-app-deployment.zip

echo
echo "🎉 CodeDeploy Lab Environment Ready!"
echo
cat lab-session-info.txt
echo
echo "Lab session information saved to: lab-session-info.txt"
echo
echo "⏳ Note: It may take 5-10 minutes for all instances to be ready."
echo "You can monitor the Auto Scaling Group in the AWS Console."