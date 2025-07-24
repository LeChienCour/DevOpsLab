#!/bin/bash

# Blue-Green Deployment Lab Provisioning Script
# This script provisions AWS resources for blue-green deployment demonstrations

set -e

# Configuration
STACK_PREFIX="blue-green-lab"
REGION=${AWS_DEFAULT_REGION:-us-east-1}
PROFILE=${AWS_PROFILE:-default}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if AWS CLI is configured
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! aws sts get-caller-identity --profile $PROFILE &> /dev/null; then
        print_error "AWS CLI is not configured or credentials are invalid."
        exit 1
    fi
    
    print_status "AWS CLI is properly configured"
}

# Function to get default VPC and subnets
get_default_vpc_info() {
    print_status "Getting default VPC information..."
    
    VPC_ID=$(aws ec2 describe-vpcs \
        --filters "Name=is-default,Values=true" \
        --query 'Vpcs[0].VpcId' \
        --output text \
        --profile $PROFILE \
        --region $REGION)
    
    if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
        print_error "No default VPC found. Please create a VPC first."
        exit 1
    fi
    
    SUBNET_IDS=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'Subnets[?MapPublicIpOnLaunch==`true`].SubnetId' \
        --output text \
        --profile $PROFILE \
        --region $REGION)
    
    if [ -z "$SUBNET_IDS" ]; then
        print_error "No public subnets found in default VPC."
        exit 1
    fi
    
    # Convert space-separated to comma-separated
    SUBNET_IDS=$(echo $SUBNET_IDS | tr ' ' ',')
    
    print_status "Using VPC: $VPC_ID"
    print_status "Using Subnets: $SUBNET_IDS"
}

# Function to create S3 bucket for Lambda deployment package
create_lambda_bucket() {
    BUCKET_NAME="blue-green-lambda-deployments-$(date +%s)"
    
    print_status "Creating S3 bucket for Lambda deployments: $BUCKET_NAME"
    
    if [ "$REGION" = "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket $BUCKET_NAME \
            --profile $PROFILE \
            --region $REGION
    else
        aws s3api create-bucket \
            --bucket $BUCKET_NAME \
            --create-bucket-configuration LocationConstraint=$REGION \
            --profile $PROFILE \
            --region $REGION
    fi
    
    # Create sample Lambda function
    cat > /tmp/lambda_function.py << 'EOF'
import json
import os
import boto3

def handler(event, context):
    version = os.environ.get('VERSION', '1.0.0')
    environment = os.environ.get('ENVIRONMENT', 'production')
    
    # Custom CloudWatch metric
    cloudwatch = boto3.client('cloudwatch')
    
    try:
        # Simulate business logic
        response_data = {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Hello from version {version} in {environment}!',
                'timestamp': context.aws_request_id,
                'version': version,
                'environment': environment
            })
        }
        
        # Put custom metric
        cloudwatch.put_metric_data(
            Namespace=f'{context.function_name}/Custom',
            MetricData=[
                {
                    'MetricName': 'BusinessMetric',
                    'Value': 150,  # Simulate successful business metric
                    'Unit': 'Count'
                }
            ]
        )
        
        return response_data
        
    except Exception as e:
        # Put error metric
        cloudwatch.put_metric_data(
            Namespace=f'{context.function_name}/Custom',
            MetricData=[
                {
                    'MetricName': 'BusinessMetric',
                    'Value': 50,  # Simulate failed business metric
                    'Unit': 'Count'
                }
            ]
        )
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'version': version
            })
        }
EOF
    
    # Create deployment package
    cd /tmp
    zip lambda-function.zip lambda_function.py
    
    # Upload to S3
    aws s3 cp lambda-function.zip s3://$BUCKET_NAME/lambda-function.zip \
        --profile $PROFILE \
        --region $REGION
    
    print_status "Lambda deployment package uploaded to s3://$BUCKET_NAME/lambda-function.zip"
    
    # Cleanup
    rm lambda_function.py lambda-function.zip
}

# Function to deploy ECS blue-green stack
deploy_ecs_stack() {
    print_status "Deploying ECS Blue-Green stack..."
    
    aws cloudformation deploy \
        --template-file ../templates/ecs-blue-green-codedeploy.yaml \
        --stack-name "${STACK_PREFIX}-ecs" \
        --parameter-overrides \
            VpcId=$VPC_ID \
            SubnetIds=$SUBNET_IDS \
            ServiceName="blue-green-ecs-demo" \
        --capabilities CAPABILITY_IAM \
        --profile $PROFILE \
        --region $REGION
    
    if [ $? -eq 0 ]; then
        print_status "ECS Blue-Green stack deployed successfully"
        
        # Get outputs
        ALB_DNS=$(aws cloudformation describe-stacks \
            --stack-name "${STACK_PREFIX}-ecs" \
            --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' \
            --output text \
            --profile $PROFILE \
            --region $REGION)
        
        print_status "ECS Application URL: http://$ALB_DNS"
        print_status "ECS Test URL: http://$ALB_DNS:8080"
    else
        print_error "Failed to deploy ECS Blue-Green stack"
        exit 1
    fi
}

# Function to deploy Lambda blue-green stack
deploy_lambda_stack() {
    print_status "Deploying Lambda Blue-Green stack..."
    
    aws cloudformation deploy \
        --template-file ../templates/lambda-alias-deployment.yaml \
        --stack-name "${STACK_PREFIX}-lambda" \
        --parameter-overrides \
            FunctionName="blue-green-lambda-demo" \
            S3Bucket=$BUCKET_NAME \
            S3Key="lambda-function.zip" \
        --capabilities CAPABILITY_IAM \
        --profile $PROFILE \
        --region $REGION
    
    if [ $? -eq 0 ]; then
        print_status "Lambda Blue-Green stack deployed successfully"
        
        # Get outputs
        API_URL=$(aws cloudformation describe-stacks \
            --stack-name "${STACK_PREFIX}-lambda" \
            --query 'Stacks[0].Outputs[?OutputKey==`ApiGatewayUrl`].OutputValue' \
            --output text \
            --profile $PROFILE \
            --region $REGION)
        
        print_status "Lambda API URL: $API_URL"
    else
        print_error "Failed to deploy Lambda Blue-Green stack"
        exit 1
    fi
}

# Function to deploy CloudWatch monitoring stack
deploy_monitoring_stack() {
    print_status "Deploying CloudWatch monitoring stack..."
    
    # Get ALB and Target Group full names from ECS stack
    ALB_FULL_NAME=$(aws cloudformation describe-stack-resources \
        --stack-name "${STACK_PREFIX}-ecs" \
        --logical-resource-id "ApplicationLoadBalancer" \
        --query 'StackResources[0].PhysicalResourceId' \
        --output text \
        --profile $PROFILE \
        --region $REGION)
    
    TG_FULL_NAME=$(aws cloudformation describe-stack-resources \
        --stack-name "${STACK_PREFIX}-ecs" \
        --logical-resource-id "BlueTargetGroup" \
        --query 'StackResources[0].PhysicalResourceId' \
        --output text \
        --profile $PROFILE \
        --region $REGION)
    
    aws cloudformation deploy \
        --template-file ../templates/cloudwatch-rollback-automation.yaml \
        --stack-name "${STACK_PREFIX}-monitoring" \
        --parameter-overrides \
            ApplicationName="blue-green-demo" \
            LoadBalancerFullName=$ALB_FULL_NAME \
            TargetGroupFullName=$TG_FULL_NAME \
        --capabilities CAPABILITY_IAM \
        --profile $PROFILE \
        --region $REGION
    
    if [ $? -eq 0 ]; then
        print_status "CloudWatch monitoring stack deployed successfully"
        
        # Get dashboard URL
        DASHBOARD_URL=$(aws cloudformation describe-stacks \
            --stack-name "${STACK_PREFIX}-monitoring" \
            --query 'Stacks[0].Outputs[?OutputKey==`DashboardURL`].OutputValue' \
            --output text \
            --profile $PROFILE \
            --region $REGION)
        
        print_status "CloudWatch Dashboard: $DASHBOARD_URL"
    else
        print_error "Failed to deploy CloudWatch monitoring stack"
        exit 1
    fi
}

# Function to display lab information
display_lab_info() {
    print_status "Blue-Green Deployment Lab Resources Created Successfully!"
    echo ""
    echo "=== Lab Resources ==="
    echo "ECS Application URL: http://$ALB_DNS"
    echo "ECS Test URL: http://$ALB_DNS:8080"
    echo "Lambda API URL: $API_URL"
    echo "CloudWatch Dashboard: $DASHBOARD_URL"
    echo ""
    echo "=== Next Steps ==="
    echo "1. Test the ECS application at the provided URLs"
    echo "2. Test the Lambda function via API Gateway"
    echo "3. Follow the lab guide to perform blue-green deployments"
    echo "4. Monitor metrics in the CloudWatch dashboard"
    echo ""
    echo "=== Cleanup ==="
    echo "Run './cleanup-blue-green-lab.sh' when finished with the lab"
}

# Main execution
main() {
    print_status "Starting Blue-Green Deployment Lab Provisioning..."
    
    check_aws_cli
    get_default_vpc_info
    create_lambda_bucket
    deploy_ecs_stack
    deploy_lambda_stack
    deploy_monitoring_stack
    display_lab_info
    
    print_status "Lab provisioning completed successfully!"
}

# Run main function
main "$@"