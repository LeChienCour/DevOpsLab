#!/bin/bash

# Advanced CloudFormation Lab - Nested Stacks Provisioning Script
# This script demonstrates nested stack deployment with cross-stack references

set -e

# Configuration
STACK_NAME="devops-lab-nested"
ENVIRONMENT="dev"
VPC_CIDR="10.0.0.0/16"
KEY_PAIR_NAME=""
REGION=$(aws configure get region)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
TEMPLATES_BUCKET="${STACK_NAME}-templates-${ACCOUNT_ID}-${REGION}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured"
        exit 1
    fi
    
    # Check for key pair
    if [ -z "$KEY_PAIR_NAME" ]; then
        print_warning "No key pair specified. Checking for existing key pairs..."
        KEY_PAIRS=$(aws ec2 describe-key-pairs --query 'KeyPairs[0].KeyName' --output text 2>/dev/null || echo "None")
        if [ "$KEY_PAIRS" != "None" ]; then
            KEY_PAIR_NAME=$KEY_PAIRS
            print_status "Using existing key pair: $KEY_PAIR_NAME"
        else
            print_error "No EC2 key pairs found. Please create one first:"
            print_error "aws ec2 create-key-pair --key-name devops-lab-key --query 'KeyMaterial' --output text > devops-lab-key.pem"
            exit 1
        fi
    fi
    
    print_success "Prerequisites check completed"
}

# Function to create bucket and upload templates
prepare_templates() {
    print_status "Creating S3 bucket for templates..."
    
    # Create bucket if it doesn't exist (separate from stack)
    if ! aws s3 ls "s3://$TEMPLATES_BUCKET" &> /dev/null; then
        if [ "$REGION" = "us-east-1" ]; then
            aws s3 mb "s3://$TEMPLATES_BUCKET"
        else
            aws s3 mb "s3://$TEMPLATES_BUCKET" --region "$REGION"
        fi
        print_success "Created S3 bucket: $TEMPLATES_BUCKET"
    else
        print_status "S3 bucket already exists: $TEMPLATES_BUCKET"
    fi
    
    # Upload nested stack templates
    print_status "Uploading nested stack templates..."
    
    # Get the script directory to build correct paths
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    TEMPLATES_DIR="$SCRIPT_DIR/../templates"
    
    aws s3 cp "$TEMPLATES_DIR/network-stack.yaml" "s3://$TEMPLATES_BUCKET/"
    aws s3 cp "$TEMPLATES_DIR/security-stack.yaml" "s3://$TEMPLATES_BUCKET/"
    aws s3 cp "$TEMPLATES_DIR/application-stack.yaml" "s3://$TEMPLATES_BUCKET/"
    
    print_success "Templates uploaded successfully"
}

# Function to deploy the parent stack with nested stacks
deploy_parent_stack() {
    print_status "Deploying parent stack with nested stacks: $STACK_NAME"
    
    # Get the script directory to build correct paths
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    TEMPLATES_DIR="$SCRIPT_DIR/../templates"
    
    aws cloudformation deploy \
        --template-file "$TEMPLATES_DIR/parent-stack.yaml" \
        --stack-name "$STACK_NAME" \
        --parameter-overrides \
            Environment="$ENVIRONMENT" \
            VpcCidr="$VPC_CIDR" \
            KeyPairName="$KEY_PAIR_NAME" \
            TemplatesBucket="$TEMPLATES_BUCKET" \
        --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
        --tags \
            Environment="$ENVIRONMENT" \
            Project="DevOpsLab" \
            LabType="NestedStacks"
    
    if [ $? -eq 0 ]; then
        print_success "Parent stack with nested stacks deployed successfully"
    else
        print_error "Failed to deploy parent stack"
        exit 1
    fi
}

# Function to display stack outputs
display_outputs() {
    print_status "Retrieving stack outputs..."
    
    echo ""
    echo "=== Stack Outputs ==="
    aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue,Description]' \
        --output table
    
    echo ""
    echo "=== Nested Stack Information ==="
    aws cloudformation list-stack-resources \
        --stack-name "$STACK_NAME" \
        --query 'StackResourceSummaries[?ResourceType==`AWS::CloudFormation::Stack`].[LogicalResourceId,PhysicalResourceId,ResourceStatus]' \
        --output table
}



# Main execution
main() {
    echo "=== Advanced CloudFormation Lab - Nested Stacks ==="
    echo "This script will deploy a multi-tier application using nested CloudFormation stacks"
    echo ""
    
    check_prerequisites
    prepare_templates
    deploy_parent_stack
    display_outputs
    

    
    echo ""
    print_success "Lab deployment completed!"
    print_status "Stack Name: $STACK_NAME"
    print_status "Region: $REGION"
    print_status "Templates Bucket: $TEMPLATES_BUCKET"
    echo ""
    print_warning "Remember to run cleanup-nested-stacks.sh when you're done to avoid charges!"
}

# Run main function
main "$@"