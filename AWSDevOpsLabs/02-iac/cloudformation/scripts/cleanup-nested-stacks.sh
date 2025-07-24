#!/bin/bash

# Advanced CloudFormation Lab - Nested Stacks Cleanup Script
# This script cleans up all resources created by the nested stacks lab

set -e

# Configuration
STACK_NAME="devops-lab-nested"
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

# Function to check if stack exists
stack_exists() {
    aws cloudformation describe-stacks --stack-name "$1" &> /dev/null
}

# Function to delete CloudFormation stack
delete_stack() {
    local stack_name=$1
    
    if stack_exists "$stack_name"; then
        print_status "Deleting stack: $stack_name"
        
        # Get stack status
        STACK_STATUS=$(aws cloudformation describe-stacks \
            --stack-name "$stack_name" \
            --query 'Stacks[0].StackStatus' \
            --output text)
        
        if [[ "$STACK_STATUS" == *"IN_PROGRESS"* ]]; then
            print_warning "Stack $stack_name is currently in progress. Waiting for completion..."
            aws cloudformation wait stack-create-complete --stack-name "$stack_name" 2>/dev/null || \
            aws cloudformation wait stack-update-complete --stack-name "$stack_name" 2>/dev/null || \
            aws cloudformation wait stack-delete-complete --stack-name "$stack_name" 2>/dev/null || true
        fi
        
        # Delete the stack
        aws cloudformation delete-stack --stack-name "$stack_name"
        
        print_status "Waiting for stack deletion to complete..."
        if aws cloudformation wait stack-delete-complete --stack-name "$stack_name" 2>/dev/null; then
            print_success "Stack $stack_name deleted successfully"
        else
            print_error "Failed to delete stack $stack_name"
            
            # Show stack events for troubleshooting
            print_status "Recent stack events:"
            aws cloudformation describe-stack-events \
                --stack-name "$stack_name" \
                --query 'StackEvents[0:5].[Timestamp,ResourceStatus,ResourceStatusReason]' \
                --output table 2>/dev/null || true
        fi
    else
        print_status "Stack $stack_name does not exist or already deleted"
    fi
}

# Function to empty and delete S3 bucket
cleanup_s3_bucket() {
    local bucket_name=$1
    
    if aws s3 ls "s3://$bucket_name" &> /dev/null; then
        print_status "Cleaning up S3 bucket: $bucket_name"
        
        # Empty the bucket
        print_status "Emptying S3 bucket..."
        aws s3 rm "s3://$bucket_name" --recursive
        
        # Delete the bucket
        print_status "Deleting S3 bucket..."
        aws s3 rb "s3://$bucket_name"
        
        print_success "S3 bucket $bucket_name deleted successfully"
    else
        print_status "S3 bucket $bucket_name does not exist or already deleted"
    fi
}

# Function to list and clean up orphaned resources
cleanup_orphaned_resources() {
    print_status "Checking for orphaned resources..."
    
    # Check for EC2 instances with our tags
    print_status "Checking for orphaned EC2 instances..."
    INSTANCES=$(aws ec2 describe-instances \
        --filters "Name=tag:Project,Values=DevOpsLab" "Name=instance-state-name,Values=running,stopped" \
        --query 'Reservations[*].Instances[*].InstanceId' \
        --output text)
    
    if [ -n "$INSTANCES" ] && [ "$INSTANCES" != "None" ]; then
        print_warning "Found orphaned EC2 instances: $INSTANCES"
        read -p "Do you want to terminate these instances? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            aws ec2 terminate-instances --instance-ids $INSTANCES
            print_status "Terminating instances..."
        fi
    else
        print_success "No orphaned EC2 instances found"
    fi
    
    # Check for orphaned security groups
    print_status "Checking for orphaned security groups..."
    SECURITY_GROUPS=$(aws ec2 describe-security-groups \
        --filters "Name=tag:Project,Values=DevOpsLab" \
        --query 'SecurityGroups[?GroupName!=`default`].GroupId' \
        --output text)
    
    if [ -n "$SECURITY_GROUPS" ] && [ "$SECURITY_GROUPS" != "None" ]; then
        print_warning "Found orphaned security groups: $SECURITY_GROUPS"
        print_status "These will be cleaned up automatically when the VPC is deleted"
    else
        print_success "No orphaned security groups found"
    fi
    
    # Check for orphaned Load Balancers
    print_status "Checking for orphaned load balancers..."
    LOAD_BALANCERS=$(aws elbv2 describe-load-balancers \
        --query 'LoadBalancers[?contains(LoadBalancerName, `dev-alb`)].LoadBalancerArn' \
        --output text)
    
    if [ -n "$LOAD_BALANCERS" ] && [ "$LOAD_BALANCERS" != "None" ]; then
        print_warning "Found orphaned load balancers"
        print_status "These should be cleaned up by CloudFormation stack deletion"
    else
        print_success "No orphaned load balancers found"
    fi
}

# Function to show cost summary
show_cost_summary() {
    print_status "Generating cost summary for the last 24 hours..."
    
    # Get yesterday's date
    YESTERDAY=$(date -d "yesterday" '+%Y-%m-%d' 2>/dev/null || date -v-1d '+%Y-%m-%d' 2>/dev/null || echo "2024-01-01")
    TODAY=$(date '+%Y-%m-%d')
    
    # Get cost data (this requires Cost Explorer API access)
    print_status "Note: Cost data may take up to 24 hours to appear in AWS Cost Explorer"
    print_status "Check your AWS Billing Dashboard for the most current cost information"
    
    # Show estimated costs for common resources
    echo ""
    echo "=== Estimated Resource Costs (per hour) ==="
    echo "t3.micro EC2 instances: ~$0.0104/hour each"
    echo "Application Load Balancer: ~$0.0225/hour"
    echo "NAT Gateway: ~$0.045/hour"
    echo "S3 storage: ~$0.023/GB/month"
    echo "CloudWatch logs: ~$0.50/GB ingested"
    echo ""
    print_warning "Actual costs may vary based on usage and region"
}

# Function to verify cleanup completion
verify_cleanup() {
    print_status "Verifying cleanup completion..."
    
    local cleanup_complete=true
    
    # Check if main stack still exists
    if stack_exists "$STACK_NAME"; then
        print_error "Main stack $STACK_NAME still exists"
        cleanup_complete=false
    fi
    
    # Check if S3 bucket still exists
    if aws s3 ls "s3://$TEMPLATES_BUCKET" &> /dev/null; then
        print_error "S3 bucket $TEMPLATES_BUCKET still exists"
        cleanup_complete=false
    fi
    
    if [ "$cleanup_complete" = true ]; then
        print_success "Cleanup verification completed successfully"
    else
        print_error "Cleanup verification failed - some resources may still exist"
        return 1
    fi
}

# Main cleanup function
main() {
    echo "=== Advanced CloudFormation Lab - Cleanup ==="
    echo "This script will clean up all resources created by the nested stacks lab"
    echo ""
    
    print_warning "This will delete the following resources:"
    echo "  - CloudFormation stack: $STACK_NAME"
    echo "  - All nested stacks and their resources"
    echo "  - S3 bucket: $TEMPLATES_BUCKET"
    echo "  - EC2 instances, Load Balancers, VPC, etc."
    echo ""
    
    read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Cleanup cancelled"
        exit 0
    fi
    
    # Start cleanup process
    print_status "Starting cleanup process..."
    
    # Delete the main stack (this will cascade to nested stacks)
    delete_stack "$STACK_NAME"
    
    # Clean up S3 bucket
    cleanup_s3_bucket "$TEMPLATES_BUCKET"
    
    # Check for orphaned resources
    cleanup_orphaned_resources
    
    # Show cost summary
    show_cost_summary
    
    # Verify cleanup
    if verify_cleanup; then
        echo ""
        print_success "Cleanup completed successfully!"
        print_status "All resources have been removed"
        print_status "Please check your AWS billing dashboard to confirm no unexpected charges"
    else
        echo ""
        print_error "Cleanup completed with warnings"
        print_status "Please manually verify and clean up any remaining resources"
    fi
}

# Run main function
main "$@"