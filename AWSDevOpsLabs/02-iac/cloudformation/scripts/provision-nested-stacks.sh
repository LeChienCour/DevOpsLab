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

# Function to create and upload templates to S3
upload_templates() {
    print_status "Creating S3 bucket for templates..."
    
    # Create bucket if it doesn't exist
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
    aws s3 cp ../templates/network-stack.yaml "s3://$TEMPLATES_BUCKET/"
    aws s3 cp ../templates/security-stack.yaml "s3://$TEMPLATES_BUCKET/"
    aws s3 cp ../templates/application-stack.yaml "s3://$TEMPLATES_BUCKET/"
    
    print_success "Templates uploaded successfully"
}

# Function to deploy the parent stack
deploy_parent_stack() {
    print_status "Deploying parent stack: $STACK_NAME"
    
    aws cloudformation deploy \
        --template-file ../templates/parent-stack.yaml \
        --stack-name "$STACK_NAME" \
        --parameter-overrides \
            Environment="$ENVIRONMENT" \
            VpcCidr="$VPC_CIDR" \
            KeyPairName="$KEY_PAIR_NAME" \
        --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
        --tags \
            Environment="$ENVIRONMENT" \
            Project="DevOpsLab" \
            LabType="NestedStacks"
    
    if [ $? -eq 0 ]; then
        print_success "Parent stack deployed successfully"
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

# Function to demonstrate change sets
demonstrate_change_sets() {
    print_status "Demonstrating change sets..."
    
    CHANGE_SET_NAME="demo-change-set-$(date +%s)"
    
    # Create a change set with a parameter change
    print_status "Creating change set: $CHANGE_SET_NAME"
    aws cloudformation create-change-set \
        --stack-name "$STACK_NAME" \
        --change-set-name "$CHANGE_SET_NAME" \
        --template-body file://../templates/parent-stack.yaml \
        --parameters \
            ParameterKey=Environment,ParameterValue="$ENVIRONMENT" \
            ParameterKey=VpcCidr,ParameterValue="10.1.0.0/16" \
            ParameterKey=KeyPairName,ParameterValue="$KEY_PAIR_NAME" \
        --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM
    
    # Wait for change set to be created
    print_status "Waiting for change set to be created..."
    aws cloudformation wait change-set-create-complete \
        --stack-name "$STACK_NAME" \
        --change-set-name "$CHANGE_SET_NAME"
    
    # Display change set details
    print_status "Change set details:"
    aws cloudformation describe-change-set \
        --stack-name "$STACK_NAME" \
        --change-set-name "$CHANGE_SET_NAME" \
        --query 'Changes[*].[Action,ResourceChange.LogicalResourceId,ResourceChange.ResourceType,ResourceChange.Replacement]' \
        --output table
    
    # Ask user if they want to execute the change set
    echo ""
    read -p "Do you want to execute this change set? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Executing change set..."
        aws cloudformation execute-change-set \
            --stack-name "$STACK_NAME" \
            --change-set-name "$CHANGE_SET_NAME"
        
        print_status "Waiting for stack update to complete..."
        aws cloudformation wait stack-update-complete --stack-name "$STACK_NAME"
        print_success "Change set executed successfully"
    else
        print_status "Deleting change set without execution..."
        aws cloudformation delete-change-set \
            --stack-name "$STACK_NAME" \
            --change-set-name "$CHANGE_SET_NAME"
        print_status "Change set deleted"
    fi
}

# Function to show drift detection
demonstrate_drift_detection() {
    print_status "Demonstrating drift detection..."
    
    # Start drift detection
    DRIFT_DETECTION_ID=$(aws cloudformation detect-stack-drift \
        --stack-name "$STACK_NAME" \
        --query 'StackDriftDetectionId' \
        --output text)
    
    print_status "Drift detection started with ID: $DRIFT_DETECTION_ID"
    print_status "Waiting for drift detection to complete..."
    
    # Wait for drift detection to complete
    while true; do
        STATUS=$(aws cloudformation describe-stack-drift-detection-status \
            --stack-drift-detection-id "$DRIFT_DETECTION_ID" \
            --query 'DetectionStatus' \
            --output text)
        
        if [ "$STATUS" = "DETECTION_COMPLETE" ]; then
            break
        elif [ "$STATUS" = "DETECTION_FAILED" ]; then
            print_error "Drift detection failed"
            return 1
        fi
        
        sleep 5
    done
    
    # Show drift results
    print_status "Drift detection results:"
    aws cloudformation describe-stack-drift-detection-status \
        --stack-drift-detection-id "$DRIFT_DETECTION_ID" \
        --query '[StackDriftStatus,DriftedStackResourceCount]' \
        --output table
    
    # Show drifted resources if any
    DRIFTED_COUNT=$(aws cloudformation describe-stack-drift-detection-status \
        --stack-drift-detection-id "$DRIFT_DETECTION_ID" \
        --query 'DriftedStackResourceCount' \
        --output text)
    
    if [ "$DRIFTED_COUNT" -gt 0 ]; then
        print_warning "Found $DRIFTED_COUNT drifted resources:"
        aws cloudformation describe-stack-resource-drifts \
            --stack-name "$STACK_NAME" \
            --query 'StackResourceDrifts[?StackResourceDriftStatus!=`IN_SYNC`].[LogicalResourceId,ResourceType,StackResourceDriftStatus]' \
            --output table
    else
        print_success "No drift detected - stack is in sync"
    fi
}

# Main execution
main() {
    echo "=== Advanced CloudFormation Lab - Nested Stacks ==="
    echo "This script will deploy a multi-tier application using nested CloudFormation stacks"
    echo ""
    
    check_prerequisites
    upload_templates
    deploy_parent_stack
    display_outputs
    
    echo ""
    read -p "Do you want to demonstrate change sets? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        demonstrate_change_sets
    fi
    
    echo ""
    read -p "Do you want to demonstrate drift detection? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        demonstrate_drift_detection
    fi
    
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