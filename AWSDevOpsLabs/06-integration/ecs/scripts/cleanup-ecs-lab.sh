#!/bin/bash

# ECS Orchestration Lab Cleanup Script
# This script safely removes all resources created by the ECS lab

set -e

# Configuration
STACK_PREFIX="ecs-lab"
INFRASTRUCTURE_STACK="${STACK_PREFIX}-infrastructure"
SERVICE_STACK="${STACK_PREFIX}-web-service"
AUTOSCALING_STACK="${STACK_PREFIX}-autoscaling"
REGION=${AWS_DEFAULT_REGION:-us-east-1}

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

# Function to check if AWS CLI is configured
check_aws_cli() {
    print_status "Checking AWS CLI configuration..."
    if ! aws sts get-caller-identity > /dev/null 2>&1; then
        print_error "AWS CLI is not configured or credentials are invalid"
        exit 1
    fi
    print_success "AWS CLI is properly configured"
}

# Function to check if stack exists
stack_exists() {
    local stack_name=$1
    aws cloudformation describe-stacks --stack-name "$stack_name" --region "$REGION" > /dev/null 2>&1
}

# Function to wait for stack deletion
wait_for_stack_deletion() {
    local stack_name=$1
    
    print_status "Waiting for stack deletion to complete: $stack_name"
    aws cloudformation wait stack-delete-complete --stack-name "$stack_name" --region "$REGION"
    
    if [ $? -eq 0 ]; then
        print_success "Stack deleted successfully: $stack_name"
    else
        print_error "Stack deletion failed: $stack_name"
        return 1
    fi
}

# Function to force delete ECS service
force_delete_ecs_service() {
    local cluster_name="devops-lab-cluster"
    local service_name="web-service"
    
    print_status "Checking for ECS service to force deletion..."
    
    # Check if service exists
    if aws ecs describe-services --cluster "$cluster_name" --services "$service_name" --region "$REGION" > /dev/null 2>&1; then
        print_warning "Forcing ECS service deletion..."
        
        # Scale service to 0
        aws ecs update-service \
            --cluster "$cluster_name" \
            --service "$service_name" \
            --desired-count 0 \
            --region "$REGION" > /dev/null 2>&1 || true
        
        # Wait for tasks to stop
        print_status "Waiting for tasks to stop..."
        sleep 30
        
        # Delete service
        aws ecs delete-service \
            --cluster "$cluster_name" \
            --service "$service_name" \
            --force \
            --region "$REGION" > /dev/null 2>&1 || true
        
        print_success "ECS service deletion initiated"
    fi
}

# Function to clean up CloudWatch resources
cleanup_cloudwatch_resources() {
    print_status "Cleaning up CloudWatch resources..."
    
    # Delete custom log groups
    local log_groups=(
        "/ecs/web-service"
        "/aws/lambda/web-service-custom-scaling"
    )
    
    for log_group in "${log_groups[@]}"; do
        if aws logs describe-log-groups --log-group-name-prefix "$log_group" --region "$REGION" --query 'logGroups[0]' --output text > /dev/null 2>&1; then
            print_status "Deleting log group: $log_group"
            aws logs delete-log-group --log-group-name "$log_group" --region "$REGION" || true
        fi
    done
    
    # Delete custom dashboards
    local dashboards=(
        "web-service-metrics"
    )
    
    for dashboard in "${dashboards[@]}"; do
        if aws cloudwatch get-dashboard --dashboard-name "$dashboard" --region "$REGION" > /dev/null 2>&1; then
            print_status "Deleting dashboard: $dashboard"
            aws cloudwatch delete-dashboards --dashboard-names "$dashboard" --region "$REGION" || true
        fi
    done
    
    print_success "CloudWatch resources cleanup completed"
}

# Function to clean up Service Discovery resources
cleanup_service_discovery() {
    print_status "Cleaning up Service Discovery resources..."
    
    # List and delete services in the namespace
    local namespace_name="devops-lab.local"
    
    # Get namespace ID
    local namespace_id=$(aws servicediscovery list-namespaces \
        --region "$REGION" \
        --query "Namespaces[?Name=='$namespace_name'].Id" \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$namespace_id" ] && [ "$namespace_id" != "None" ]; then
        print_status "Found namespace: $namespace_id"
        
        # List services in namespace
        local services=$(aws servicediscovery list-services \
            --region "$REGION" \
            --query "Services[?NamespaceId=='$namespace_id'].Id" \
            --output text 2>/dev/null || echo "")
        
        # Delete services
        if [ -n "$services" ] && [ "$services" != "None" ]; then
            for service_id in $services; do
                print_status "Deleting service discovery service: $service_id"
                aws servicediscovery delete-service --id "$service_id" --region "$REGION" || true
            done
        fi
    fi
    
    print_success "Service Discovery cleanup completed"
}

# Function to delete stack with retry
delete_stack_with_retry() {
    local stack_name=$1
    local max_retries=3
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        if stack_exists "$stack_name"; then
            print_status "Deleting stack: $stack_name (attempt $((retry_count + 1)))"
            
            aws cloudformation delete-stack --stack-name "$stack_name" --region "$REGION"
            
            if wait_for_stack_deletion "$stack_name"; then
                return 0
            else
                retry_count=$((retry_count + 1))
                if [ $retry_count -lt $max_retries ]; then
                    print_warning "Retrying stack deletion in 30 seconds..."
                    sleep 30
                fi
            fi
        else
            print_warning "Stack does not exist: $stack_name"
            return 0
        fi
    done
    
    print_error "Failed to delete stack after $max_retries attempts: $stack_name"
    return 1
}

# Function to list remaining resources
list_remaining_resources() {
    print_status "Checking for remaining resources..."
    
    local found_resources=false
    
    # Check for ECS clusters
    local clusters=$(aws ecs list-clusters --region "$REGION" --query 'clusterArns[?contains(@, `devops-lab`)]' --output text 2>/dev/null || echo "")
    if [ -n "$clusters" ] && [ "$clusters" != "None" ]; then
        print_warning "Remaining ECS clusters found:"
        echo "$clusters"
        found_resources=true
    fi
    
    # Check for Load Balancers
    local load_balancers=$(aws elbv2 describe-load-balancers --region "$REGION" --query 'LoadBalancers[?contains(LoadBalancerName, `ecs-lab`)].LoadBalancerArn' --output text 2>/dev/null || echo "")
    if [ -n "$load_balancers" ] && [ "$load_balancers" != "None" ]; then
        print_warning "Remaining Load Balancers found:"
        echo "$load_balancers"
        found_resources=true
    fi
    
    # Check for VPCs
    local vpcs=$(aws ec2 describe-vpcs --region "$REGION" --filters "Name=tag:Name,Values=*devops-lab*" --query 'Vpcs[].VpcId' --output text 2>/dev/null || echo "")
    if [ -n "$vpcs" ] && [ "$vpcs" != "None" ]; then
        print_warning "Remaining VPCs found:"
        echo "$vpcs"
        found_resources=true
    fi
    
    if [ "$found_resources" = false ]; then
        print_success "No remaining lab resources found"
    else
        print_warning "Some resources may require manual cleanup"
        print_warning "Check the AWS Console for any remaining resources with 'devops-lab' or 'ecs-lab' tags"
    fi
}

# Function to confirm deletion
confirm_deletion() {
    echo
    print_warning "This will delete ALL resources created by the ECS Orchestration Lab"
    print_warning "This action cannot be undone!"
    echo
    print_status "The following stacks will be deleted:"
    echo "  • $AUTOSCALING_STACK"
    echo "  • $SERVICE_STACK"
    echo "  • $INFRASTRUCTURE_STACK"
    echo
    
    read -p "Are you sure you want to continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_status "Cleanup cancelled by user"
        exit 0
    fi
}

# Main cleanup function
main() {
    echo "=========================================="
    echo "ECS Orchestration Lab Cleanup"
    echo "=========================================="
    echo
    
    check_aws_cli
    
    # Check if any stacks exist
    local stacks_exist=false
    for stack in "$AUTOSCALING_STACK" "$SERVICE_STACK" "$INFRASTRUCTURE_STACK"; do
        if stack_exists "$stack"; then
            stacks_exist=true
            break
        fi
    done
    
    if [ "$stacks_exist" = false ]; then
        print_warning "No lab stacks found to delete"
        list_remaining_resources
        exit 0
    fi
    
    # Confirm deletion unless --force flag is used
    if [[ "${1:-}" != "--force" ]]; then
        confirm_deletion
    fi
    
    print_status "Starting cleanup process..."
    
    # Force delete ECS service first to avoid dependency issues
    force_delete_ecs_service
    
    # Delete stacks in reverse order (dependencies)
    local cleanup_success=true
    
    # Delete auto-scaling stack first
    if stack_exists "$AUTOSCALING_STACK"; then
        if ! delete_stack_with_retry "$AUTOSCALING_STACK"; then
            cleanup_success=false
        fi
    fi
    
    # Delete service stack
    if stack_exists "$SERVICE_STACK"; then
        if ! delete_stack_with_retry "$SERVICE_STACK"; then
            cleanup_success=false
        fi
    fi
    
    # Clean up additional resources
    cleanup_service_discovery
    cleanup_cloudwatch_resources
    
    # Delete infrastructure stack last
    if stack_exists "$INFRASTRUCTURE_STACK"; then
        if ! delete_stack_with_retry "$INFRASTRUCTURE_STACK"; then
            cleanup_success=false
        fi
    fi
    
    # Final check for remaining resources
    list_remaining_resources
    
    if [ "$cleanup_success" = true ]; then
        print_success "ECS Orchestration Lab cleanup completed successfully!"
    else
        print_error "Some cleanup operations failed. Please check the AWS Console for remaining resources."
        exit 1
    fi
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --force        Skip confirmation prompt"
        echo "  --region       AWS region (default: us-east-1)"
        echo
        exit 0
        ;;
    --region)
        REGION="$2"
        shift 2
        ;;
    --force)
        shift
        ;;
    *)
        ;;
esac

# Run main function
main "$@"