#!/bin/bash

# Cross-Service Communication Lab Cleanup Script
# This script removes all resources created for the cross-service communication lab

set -e

# Configuration
STACK_PREFIX="cross-service-lab"
REGION=${AWS_DEFAULT_REGION:-us-east-1}
VPC_STACK_NAME="${STACK_PREFIX}-vpc"
MESH_STACK_NAME="${STACK_PREFIX}-mesh"
MESSAGING_STACK_NAME="${STACK_PREFIX}-messaging"
CIRCUIT_BREAKER_STACK_NAME="${STACK_PREFIX}-circuit-breaker"
ECS_STACK_NAME="${STACK_PREFIX}-ecs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if AWS CLI is configured
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi

    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS CLI is not configured. Please run 'aws configure' first."
        exit 1
    fi

    log_success "AWS CLI is configured"
}

# Function to check if stack exists
stack_exists() {
    local stack_name=$1
    aws cloudformation describe-stacks --stack-name "$stack_name" --region "$REGION" &> /dev/null
}

# Function to wait for stack deletion to complete
wait_for_stack_deletion() {
    local stack_name=$1
    
    log_info "Waiting for stack $stack_name to be deleted..."
    
    aws cloudformation wait stack-delete-complete \
        --stack-name "$stack_name" \
        --region "$REGION"
    
    if [ $? -eq 0 ]; then
        log_success "Stack $stack_name deleted successfully"
    else
        log_error "Stack $stack_name failed to delete"
        return 1
    fi
}

# Function to delete stack with retry logic
delete_stack_with_retry() {
    local stack_name=$1
    local max_retries=3
    local retry_count=0
    
    if ! stack_exists "$stack_name"; then
        log_info "Stack $stack_name does not exist, skipping deletion"
        return 0
    fi
    
    while [ $retry_count -lt $max_retries ]; do
        log_info "Deleting stack $stack_name (attempt $((retry_count + 1))/$max_retries)..."
        
        aws cloudformation delete-stack \
            --stack-name "$stack_name" \
            --region "$REGION"
        
        if wait_for_stack_deletion "$stack_name"; then
            return 0
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                log_warning "Retrying stack deletion in 30 seconds..."
                sleep 30
            fi
        fi
    done
    
    log_error "Failed to delete stack $stack_name after $max_retries attempts"
    return 1
}

# Function to empty and delete S3 buckets
cleanup_s3_buckets() {
    log_info "Checking for S3 buckets to clean up..."
    
    # Find buckets with the lab prefix
    local buckets=$(aws s3api list-buckets --query "Buckets[?contains(Name, 'cross-service-lab')].Name" --output text --region "$REGION" 2>/dev/null || true)
    
    if [ -n "$buckets" ]; then
        for bucket in $buckets; do
            log_info "Emptying and deleting S3 bucket: $bucket"
            aws s3 rm "s3://$bucket" --recursive --region "$REGION" 2>/dev/null || true
            aws s3api delete-bucket --bucket "$bucket" --region "$REGION" 2>/dev/null || true
        done
    else
        log_info "No S3 buckets found to clean up"
    fi
}

# Function to clean up CloudWatch Log Groups
cleanup_log_groups() {
    log_info "Cleaning up CloudWatch Log Groups..."
    
    local log_groups=(
        "/ecs/user-service"
        "/ecs/order-service"
        "/ecs/inventory-service"
        "/ecs/notification-service"
        "/ecs/envoy"
        "/ecs/xray"
        "/aws/lambda/circuit-breaker-manager"
        "/aws/lambda/service-health-checker"
    )
    
    for log_group in "${log_groups[@]}"; do
        if aws logs describe-log-groups --log-group-name-prefix "$log_group" --region "$REGION" --query 'logGroups[0]' --output text &> /dev/null; then
            log_info "Deleting log group: $log_group"
            aws logs delete-log-group --log-group-name "$log_group" --region "$REGION" 2>/dev/null || true
        fi
    done
}

# Function to clean up ECR repositories
cleanup_ecr_repositories() {
    log_info "Checking for ECR repositories to clean up..."
    
    local repositories=$(aws ecr describe-repositories --query "repositories[?contains(repositoryName, 'cross-service')].repositoryName" --output text --region "$REGION" 2>/dev/null || true)
    
    if [ -n "$repositories" ]; then
        for repo in $repositories; do
            log_info "Deleting ECR repository: $repo"
            aws ecr delete-repository --repository-name "$repo" --force --region "$REGION" 2>/dev/null || true
        done
    else
        log_info "No ECR repositories found to clean up"
    fi
}

# Function to clean up orphaned ENIs
cleanup_enis() {
    log_info "Checking for orphaned ENIs..."
    
    # Find ENIs with cross-service lab tags
    local enis=$(aws ec2 describe-network-interfaces \
        --filters "Name=tag:Project,Values=CrossServiceLab" \
        --query "NetworkInterfaces[?Status=='available'].NetworkInterfaceId" \
        --output text --region "$REGION" 2>/dev/null || true)
    
    if [ -n "$enis" ]; then
        for eni in $enis; do
            log_info "Deleting orphaned ENI: $eni"
            aws ec2 delete-network-interface --network-interface-id "$eni" --region "$REGION" 2>/dev/null || true
        done
    else
        log_info "No orphaned ENIs found"
    fi
}

# Function to clean up DynamoDB tables
cleanup_dynamodb_tables() {
    log_info "Checking for DynamoDB tables to clean up..."
    
    local tables=$(aws dynamodb list-tables --query "TableNames[?contains(@, 'circuit-breaker')]" --output text --region "$REGION" 2>/dev/null || true)
    
    if [ -n "$tables" ]; then
        for table in $tables; do
            log_info "Deleting DynamoDB table: $table"
            aws dynamodb delete-table --table-name "$table" --region "$REGION" 2>/dev/null || true
        done
    else
        log_info "No DynamoDB tables found to clean up"
    fi
}

# Function to display cleanup summary
display_cleanup_summary() {
    log_success "Cross-Service Communication Lab cleanup completed!"
    echo
    echo "Cleaned up resources:"
    echo "===================="
    echo "• ECS Services and Tasks"
    echo "• App Mesh (Virtual Services, Nodes, Routes)"
    echo "• SQS Queues and SNS Topics"
    echo "• Lambda Functions and DynamoDB Tables"
    echo "• CloudWatch Log Groups and Dashboards"
    echo "• VPC and Networking Components"
    echo "• IAM Roles and Policies"
    echo
    log_info "All lab resources have been removed to avoid ongoing charges."
    echo
    log_warning "Please verify in the AWS Console that all resources have been properly deleted."
    echo "If you notice any remaining resources, please delete them manually."
}

# Function to confirm cleanup
confirm_cleanup() {
    echo
    log_warning "This will delete ALL resources created for the Cross-Service Communication Lab."
    log_warning "This action cannot be undone!"
    echo
    read -p "Are you sure you want to proceed? (yes/no): " -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Cleanup cancelled by user."
        exit 0
    fi
}

# Main cleanup function
main() {
    log_info "Starting Cross-Service Communication Lab cleanup..."
    
    # Check prerequisites
    check_aws_cli
    
    # Confirm cleanup
    confirm_cleanup
    
    # Delete stacks in reverse order of creation
    log_info "Deleting CloudFormation stacks..."
    
    # Delete ECS stack first (has dependencies on other stacks)
    delete_stack_with_retry "$ECS_STACK_NAME"
    
    # Delete circuit breaker stack
    delete_stack_with_retry "$CIRCUIT_BREAKER_STACK_NAME"
    
    # Delete messaging stack
    delete_stack_with_retry "$MESSAGING_STACK_NAME"
    
    # Delete App Mesh stack
    delete_stack_with_retry "$MESH_STACK_NAME"
    
    # Delete VPC stack last
    delete_stack_with_retry "$VPC_STACK_NAME"
    
    # Clean up additional resources
    log_info "Cleaning up additional resources..."
    cleanup_s3_buckets
    cleanup_log_groups
    cleanup_ecr_repositories
    cleanup_enis
    cleanup_dynamodb_tables
    
    # Display summary
    display_cleanup_summary
}

# Handle script interruption
trap 'log_error "Cleanup interrupted. Some resources may still exist."; exit 1' INT TERM

# Run main function
main "$@"