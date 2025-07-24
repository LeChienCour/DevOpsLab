#!/bin/bash

# Blue-Green Deployment Lab Cleanup Script
# This script removes all AWS resources created for the blue-green deployment lab

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
        print_error "AWS CLI is not installed."
        exit 1
    fi
    
    if ! aws sts get-caller-identity --profile $PROFILE &> /dev/null; then
        print_error "AWS CLI is not configured or credentials are invalid."
        exit 1
    fi
    
    print_status "AWS CLI is properly configured"
}

# Function to delete CloudFormation stack
delete_stack() {
    local stack_name=$1
    
    print_status "Checking if stack $stack_name exists..."
    
    if aws cloudformation describe-stacks --stack-name $stack_name --profile $PROFILE --region $REGION &> /dev/null; then
        print_status "Deleting stack: $stack_name"
        
        aws cloudformation delete-stack \
            --stack-name $stack_name \
            --profile $PROFILE \
            --region $REGION
        
        print_status "Waiting for stack deletion to complete: $stack_name"
        aws cloudformation wait stack-delete-complete \
            --stack-name $stack_name \
            --profile $PROFILE \
            --region $REGION
        
        if [ $? -eq 0 ]; then
            print_status "Stack $stack_name deleted successfully"
        else
            print_error "Failed to delete stack $stack_name"
            return 1
        fi
    else
        print_warning "Stack $stack_name does not exist or already deleted"
    fi
}

# Function to find and delete S3 buckets created by the lab
cleanup_s3_buckets() {
    print_status "Looking for lab-created S3 buckets..."
    
    # Find buckets with the lab prefix
    BUCKETS=$(aws s3api list-buckets \
        --query 'Buckets[?starts_with(Name, `blue-green-lambda-deployments`)].Name' \
        --output text \
        --profile $PROFILE \
        --region $REGION)
    
    if [ -n "$BUCKETS" ]; then
        for bucket in $BUCKETS; do
            print_status "Emptying and deleting S3 bucket: $bucket"
            
            # Empty the bucket first
            aws s3 rm s3://$bucket --recursive --profile $PROFILE --region $REGION
            
            # Delete the bucket
            aws s3api delete-bucket --bucket $bucket --profile $PROFILE --region $REGION
            
            if [ $? -eq 0 ]; then
                print_status "S3 bucket $bucket deleted successfully"
            else
                print_warning "Failed to delete S3 bucket $bucket"
            fi
        done
    else
        print_status "No lab-created S3 buckets found"
    fi
}

# Function to cleanup any orphaned resources
cleanup_orphaned_resources() {
    print_status "Checking for orphaned resources..."
    
    # Check for any remaining CodeDeploy applications
    CODEDEPLOY_APPS=$(aws deploy list-applications \
        --query 'applications[?starts_with(@, `blue-green-`) || contains(@, `blue-green`)]' \
        --output text \
        --profile $PROFILE \
        --region $REGION)
    
    if [ -n "$CODEDEPLOY_APPS" ]; then
        for app in $CODEDEPLOY_APPS; do
            print_warning "Found orphaned CodeDeploy application: $app"
            print_status "Deleting CodeDeploy application: $app"
            
            aws deploy delete-application \
                --application-name $app \
                --profile $PROFILE \
                --region $REGION
        done
    fi
    
    # Check for any remaining Lambda functions
    LAMBDA_FUNCTIONS=$(aws lambda list-functions \
        --query 'Functions[?starts_with(FunctionName, `blue-green-`)].FunctionName' \
        --output text \
        --profile $PROFILE \
        --region $REGION)
    
    if [ -n "$LAMBDA_FUNCTIONS" ]; then
        for func in $LAMBDA_FUNCTIONS; do
            print_warning "Found orphaned Lambda function: $func"
            print_status "Deleting Lambda function: $func"
            
            aws lambda delete-function \
                --function-name $func \
                --profile $PROFILE \
                --region $REGION
        done
    fi
}

# Function to display cleanup summary
display_cleanup_summary() {
    print_status "Blue-Green Deployment Lab Cleanup Completed!"
    echo ""
    echo "=== Cleaned Up Resources ==="
    echo "✓ CloudFormation stacks deleted"
    echo "✓ S3 buckets emptied and deleted"
    echo "✓ Orphaned resources cleaned up"
    echo ""
    echo "=== Verification ==="
    echo "You can verify cleanup by checking:"
    echo "1. CloudFormation console - no blue-green-lab stacks"
    echo "2. S3 console - no blue-green-lambda-deployments buckets"
    echo "3. ECS console - no blue-green clusters or services"
    echo "4. Lambda console - no blue-green functions"
    echo "5. CodeDeploy console - no blue-green applications"
    echo ""
    print_status "All lab resources have been cleaned up successfully!"
}

# Function to confirm cleanup
confirm_cleanup() {
    echo ""
    print_warning "This will delete ALL resources created by the Blue-Green Deployment Lab."
    print_warning "This action cannot be undone."
    echo ""
    read -p "Are you sure you want to proceed? (yes/no): " confirmation
    
    if [ "$confirmation" != "yes" ]; then
        print_status "Cleanup cancelled by user"
        exit 0
    fi
}

# Main execution
main() {
    print_status "Starting Blue-Green Deployment Lab Cleanup..."
    
    check_aws_cli
    confirm_cleanup
    
    # Delete stacks in reverse order (monitoring first, then lambda, then ecs)
    delete_stack "${STACK_PREFIX}-monitoring"
    delete_stack "${STACK_PREFIX}-lambda"
    delete_stack "${STACK_PREFIX}-ecs"
    
    # Cleanup additional resources
    cleanup_s3_buckets
    cleanup_orphaned_resources
    
    display_cleanup_summary
    
    print_status "Lab cleanup completed successfully!"
}

# Run main function
main "$@"