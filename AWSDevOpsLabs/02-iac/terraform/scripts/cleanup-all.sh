#!/bin/bash

# Terraform Complete Cleanup Script
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Destroy environment
destroy_environment() {
    local env=$1
    local env_dir="$SCRIPT_DIR/../environments/$env"
    
    if [ -d "$env_dir" ]; then
        print_status "Destroying $env environment..."
        cd "$env_dir"
        
        if terraform workspace list | grep -q "$env"; then
            terraform workspace select "$env" 2>/dev/null || true
        fi
        
        # Check if state exists
        if terraform show &> /dev/null; then
            terraform destroy -auto-approve
            print_success "$env environment destroyed"
        else
            print_status "$env environment has no resources to destroy"
        fi
    else
        print_warning "$env environment directory not found"
    fi
}

# Destroy backend
destroy_backend() {
    local backend_dir="$SCRIPT_DIR/../backend"
    
    if [ -d "$backend_dir" ]; then
        print_status "Destroying backend infrastructure..."
        cd "$backend_dir"
        
        # Check if state exists
        if terraform show &> /dev/null; then
            terraform destroy -auto-approve
            print_success "Backend infrastructure destroyed"
        else
            print_status "Backend has no resources to destroy"
        fi
    else
        print_warning "Backend directory not found"
    fi
}

# Check for orphaned resources
check_orphaned_resources() {
    print_status "Checking for orphaned resources..."
    
    # Check for S3 buckets
    print_status "Checking for S3 buckets..."
    BUCKETS=$(aws s3api list-buckets \
        --query "Buckets[?contains(Name, 'devops-lab')].Name" \
        --output text)
    
    if [ -n "$BUCKETS" ]; then
        print_warning "Found S3 buckets that may need manual cleanup:"
        for bucket in $BUCKETS; do
            echo "  - $bucket"
        done
        
        echo ""
        read -p "Do you want to delete these buckets? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for bucket in $BUCKETS; do
                print_status "Emptying and deleting bucket: $bucket"
                aws s3 rm "s3://$bucket" --recursive 2>/dev/null || true
                aws s3 rb "s3://$bucket" 2>/dev/null || true
            done
        fi
    else
        print_success "No orphaned S3 buckets found"
    fi
    
    # Check for CloudWatch Log Groups
    print_status "Checking for CloudWatch Log Groups..."
    LOG_GROUPS=$(aws logs describe-log-groups \
        --log-group-name-prefix "/ecs/devops-lab" \
        --query "logGroups[].logGroupName" \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$LOG_GROUPS" ]; then
        print_warning "Found CloudWatch Log Groups that may need manual cleanup:"
        for group in $LOG_GROUPS; do
            echo "  - $group"
        done
        
        echo ""
        read -p "Do you want to delete these log groups? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for group in $LOG_GROUPS; do
                print_status "Deleting log group: $group"
                aws logs delete-log-group --log-group-name "$group" 2>/dev/null || true
            done
        fi
    else
        print_success "No orphaned CloudWatch Log Groups found"
    fi
    
    # Check for ECR repositories
    print_status "Checking for ECR repositories..."
    REPOS=$(aws ecr describe-repositories \
        --query "repositories[?contains(repositoryName, 'devops-lab')].repositoryName" \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$REPOS" ]; then
        print_warning "Found ECR repositories that may need manual cleanup:"
        for repo in $REPOS; do
            echo "  - $repo"
        done
    else
        print_success "No orphaned ECR repositories found"
    fi
}

# Show cost summary
show_cost_summary() {
    print_status "Cost summary information..."
    
    echo ""
    echo "=== Estimated Costs Avoided ==="
    echo "By cleaning up all resources, you've avoided these ongoing costs:"
    echo ""
    echo "Per Environment:"
    echo "- Application Load Balancer: ~$0.0225/hour (~$16.50/month)"
    echo "- NAT Gateway: ~$0.045/hour (~$32.50/month)"
    echo "- ECS Fargate tasks: ~$0.04048/hour per vCPU + $0.004445/hour per GB RAM"
    echo "- CloudWatch Logs: ~$0.50/GB ingested"
    echo "- S3 storage: ~$0.023/GB/month"
    echo ""
    echo "Backend Infrastructure:"
    echo "- S3 bucket: ~$0.023/GB/month (minimal for state files)"
    echo "- DynamoDB: Pay-per-request (minimal for state locking)"
    echo ""
    echo "Total estimated monthly savings: ~$50-150 depending on usage"
    echo ""
    print_warning "Check your AWS billing dashboard to confirm all resources are cleaned up"
}

# Verify complete cleanup
verify_cleanup() {
    print_status "Verifying complete cleanup..."
    
    local cleanup_complete=true
    
    # Check for remaining CloudFormation stacks
    STACKS=$(aws cloudformation list-stacks \
        --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
        --query "StackSummaries[?contains(StackName, 'devops-lab')].StackName" \
        --output text)
    
    if [ -n "$STACKS" ]; then
        print_error "Found remaining CloudFormation stacks:"
        for stack in $STACKS; do
            echo "  - $stack"
        done
        cleanup_complete=false
    fi
    
    # Check for remaining ECS clusters
    CLUSTERS=$(aws ecs list-clusters \
        --query "clusterArns[?contains(@, 'devops-lab')]" \
        --output text)
    
    if [ -n "$CLUSTERS" ]; then
        print_error "Found remaining ECS clusters:"
        for cluster in $CLUSTERS; do
            echo "  - $(basename $cluster)"
        done
        cleanup_complete=false
    fi
    
    # Check for remaining Load Balancers
    LOAD_BALANCERS=$(aws elbv2 describe-load-balancers \
        --query "LoadBalancers[?contains(LoadBalancerName, 'devops-lab')].LoadBalancerName" \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$LOAD_BALANCERS" ]; then
        print_error "Found remaining Load Balancers:"
        for lb in $LOAD_BALANCERS; do
            echo "  - $lb"
        done
        cleanup_complete=false
    fi
    
    if [ "$cleanup_complete" = true ]; then
        print_success "Cleanup verification completed successfully"
        return 0
    else
        print_error "Cleanup verification failed - some resources may still exist"
        return 1
    fi
}

# Main execution
main() {
    echo "=== Terraform Complete Cleanup ==="
    echo "This script will destroy ALL Terraform-managed resources"
    echo ""
    
    print_warning "This will destroy the following:"
    echo "  - All environment resources (dev, staging, prod)"
    echo "  - Backend infrastructure (S3 bucket, DynamoDB table)"
    echo "  - Any orphaned resources"
    echo ""
    print_warning "This action cannot be undone!"
    echo ""
    
    read -p "Are you sure you want to proceed with complete cleanup? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Cleanup cancelled"
        exit 0
    fi
    
    # Destroy environments first
    ENVIRONMENTS=("dev" "staging" "prod")
    for env in "${ENVIRONMENTS[@]}"; do
        destroy_environment "$env"
    done
    
    # Destroy backend last
    destroy_backend
    
    # Check for orphaned resources
    check_orphaned_resources
    
    # Show cost summary
    show_cost_summary
    
    # Verify cleanup
    if verify_cleanup; then
        echo ""
        print_success "Complete cleanup finished successfully!"
        print_status "All Terraform-managed resources have been destroyed"
    else
        echo ""
        print_error "Cleanup completed with warnings"
        print_status "Please manually verify and clean up any remaining resources"
    fi
    
    echo ""
    print_status "Don't forget to:"
    echo "  - Check your AWS billing dashboard"
    echo "  - Remove any local Terraform state files if needed"
    echo "  - Update your documentation"
}

# Run main function
main "$@"