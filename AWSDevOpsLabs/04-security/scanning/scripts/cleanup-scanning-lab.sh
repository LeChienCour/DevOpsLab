#!/bin/bash

# Security Scanning Lab Cleanup Script
# This script cleans up all resources created by the security scanning lab

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
STACK_NAME_PREFIX="security-scanning-lab"
REGION=${AWS_DEFAULT_REGION:-us-east-1}
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
APPLICATION_NAME="scanning-lab"

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

# Function to confirm cleanup
confirm_cleanup() {
    echo "=== Security Scanning Lab Cleanup Confirmation ==="
    echo
    echo "This will delete the following resources:"
    echo "  - CloudFormation stacks (${STACK_NAME_PREFIX}-*)"
    echo "  - CodeGuru Reviewer associations"
    echo "  - ECR repositories and container images"
    echo "  - CodeBuild projects and build artifacts"
    echo "  - S3 buckets with scan results"
    echo "  - Lambda functions and IAM roles"
    echo "  - CloudWatch logs and alarms"
    echo "  - SNS topics and subscriptions"
    echo
    print_warning "This action cannot be undone!"
    echo
    
    read -p "Are you sure you want to proceed? (type 'yes' to confirm): " confirmation
    
    if [ "$confirmation" != "yes" ]; then
        print_status "Cleanup cancelled by user"
        exit 0
    fi
    
    print_status "Proceeding with cleanup..."
}

# Function to delete CloudFormation stack
delete_stack() {
    local stack_name=$1
    
    print_status "Deleting CloudFormation stack: $stack_name"
    
    if aws cloudformation describe-stacks --stack-name "$stack_name" --region "$REGION" &> /dev/null; then
        # Delete the stack
        aws cloudformation delete-stack --stack-name "$stack_name" --region "$REGION"
        
        # Wait for deletion to complete
        print_status "Waiting for stack deletion to complete..."
        aws cloudformation wait stack-delete-complete --stack-name "$stack_name" --region "$REGION"
        
        if [ $? -eq 0 ]; then
            print_success "Stack $stack_name deleted successfully"
        else
            print_error "Failed to delete stack $stack_name"
            return 1
        fi
    else
        print_warning "Stack $stack_name not found"
    fi
}

# Function to cleanup CloudFormation stacks
cleanup_cloudformation_stacks() {
    print_status "Cleaning up CloudFormation stacks..."
    
    # Delete stacks in reverse order (dependencies)
    local stacks=(
        "${STACK_NAME_PREFIX}-sast-dast"
        "${STACK_NAME_PREFIX}-container-scanning"
        "${STACK_NAME_PREFIX}-codeguru"
    )
    
    for stack in "${stacks[@]}"; do
        delete_stack "$stack"
    done
}

# Function to cleanup ECR repositories
cleanup_ecr_repositories() {
    print_status "Cleaning up ECR repositories..."
    
    local repositories=$(aws ecr describe-repositories \
        --query "repositories[?contains(repositoryName, '${APPLICATION_NAME}')].repositoryName" \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for repo in $repositories; do
        if [ -n "$repo" ]; then
            print_status "Deleting ECR repository: $repo"
            aws ecr delete-repository --repository-name "$repo" --force --region "$REGION" 2>/dev/null || true
            print_success "Deleted ECR repository: $repo"
        fi
    done
}

# Function to cleanup CodeCommit repositories
cleanup_codecommit_repositories() {
    print_status "Checking for CodeCommit repositories..."
    
    local repositories=$(aws codecommit list-repositories \
        --query "repositories[?contains(repositoryName, '${APPLICATION_NAME}')].repositoryName" \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for repo in $repositories; do
        if [ -n "$repo" ]; then
            print_status "Deleting CodeCommit repository: $repo"
            aws codecommit delete-repository --repository-name "$repo" --region "$REGION" 2>/dev/null || true
            print_success "Deleted CodeCommit repository: $repo"
        fi
    done
}

# Function to cleanup S3 buckets
cleanup_s3_buckets() {
    print_status "Cleaning up S3 buckets..."
    
    local buckets=$(aws s3api list-buckets \
        --query "Buckets[?contains(Name, '${APPLICATION_NAME}')].Name" \
        --output text 2>/dev/null || echo "")
    
    for bucket in $buckets; do
        if [ -n "$bucket" ]; then
            print_status "Deleting S3 bucket: $bucket"
            
            # Delete all objects in the bucket
            aws s3 rm "s3://${bucket}" --recursive --region "$REGION" 2>/dev/null || true
            
            # Delete the bucket
            aws s3 rb "s3://${bucket}" --region "$REGION" 2>/dev/null || true
            print_success "Deleted S3 bucket: $bucket"
        fi
    done
}

# Function to cleanup Lambda functions
cleanup_lambda_functions() {
    print_status "Checking for Lambda functions..."
    
    local functions=$(aws lambda list-functions \
        --query "Functions[?contains(FunctionName, '${APPLICATION_NAME}')].FunctionName" \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for function in $functions; do
        if [ -n "$function" ]; then
            print_status "Deleting Lambda function: $function"
            aws lambda delete-function --function-name "$function" --region "$REGION" 2>/dev/null || true
            print_success "Deleted Lambda function: $function"
        fi
    done
}

# Function to cleanup CodeBuild projects
cleanup_codebuild_projects() {
    print_status "Checking for CodeBuild projects..."
    
    local projects=$(aws codebuild list-projects \
        --query "projects[?contains(@, '${APPLICATION_NAME}')]" \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for project in $projects; do
        if [ -n "$project" ]; then
            print_status "Deleting CodeBuild project: $project"
            aws codebuild delete-project --name "$project" --region "$REGION" 2>/dev/null || true
            print_success "Deleted CodeBuild project: $project"
        fi
    done
}

# Function to cleanup CloudWatch resources
cleanup_cloudwatch_resources() {
    print_status "Cleaning up CloudWatch resources..."
    
    # Delete log groups
    local log_groups=$(aws logs describe-log-groups \
        --log-group-name-prefix "/aws/codebuild/${APPLICATION_NAME}" \
        --query 'logGroups[].logGroupName' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for log_group in $log_groups; do
        if [ -n "$log_group" ]; then
            aws logs delete-log-group --log-group-name "$log_group" --region "$REGION" 2>/dev/null || true
            print_success "Deleted log group: $log_group"
        fi
    done
    
    # Delete additional log groups
    local additional_log_groups=$(aws logs describe-log-groups \
        --query "logGroups[?contains(logGroupName, '${APPLICATION_NAME}')].logGroupName" \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for log_group in $additional_log_groups; do
        if [ -n "$log_group" ]; then
            aws logs delete-log-group --log-group-name "$log_group" --region "$REGION" 2>/dev/null || true
            print_success "Deleted log group: $log_group"
        fi
    done
    
    # Delete alarms
    local alarms=$(aws cloudwatch describe-alarms \
        --alarm-name-prefix "${APPLICATION_NAME}" \
        --query 'MetricAlarms[].AlarmName' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for alarm in $alarms; do
        if [ -n "$alarm" ]; then
            aws cloudwatch delete-alarms --alarm-names "$alarm" --region "$REGION" 2>/dev/null || true
            print_success "Deleted alarm: $alarm"
        fi
    done
    
    # Delete dashboards
    local dashboards=$(aws cloudwatch list-dashboards \
        --query "DashboardEntries[?contains(DashboardName, '${APPLICATION_NAME}')].DashboardName" \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for dashboard in $dashboards; do
        if [ -n "$dashboard" ]; then
            aws cloudwatch delete-dashboards --dashboard-names "$dashboard" --region "$REGION" 2>/dev/null || true
            print_success "Deleted dashboard: $dashboard"
        fi
    done
}

# Function to cleanup SNS topics
cleanup_sns_topics() {
    print_status "Cleaning up SNS topics..."
    
    local topics=$(aws sns list-topics \
        --query "Topics[?contains(TopicArn, '${APPLICATION_NAME}')].TopicArn" \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for topic in $topics; do
        if [ -n "$topic" ]; then
            aws sns delete-topic --topic-arn "$topic" --region "$REGION" 2>/dev/null || true
            print_success "Deleted SNS topic: $topic"
        fi
    done
}

# Function to cleanup IAM resources
cleanup_iam_resources() {
    print_status "Checking for orphaned IAM resources..."
    
    # Look for roles created by the lab
    local lab_roles=$(aws iam list-roles \
        --query "Roles[?contains(RoleName, '${APPLICATION_NAME}')].RoleName" \
        --output text 2>/dev/null || echo "")
    
    for role in $lab_roles; do
        if [ -n "$role" ]; then
            print_warning "Found orphaned role: $role"
            
            # Detach managed policies
            local attached_policies=$(aws iam list-attached-role-policies \
                --role-name "$role" \
                --query 'AttachedPolicies[].PolicyArn' \
                --output text 2>/dev/null || echo "")
            for policy in $attached_policies; do
                if [ -n "$policy" ]; then
                    aws iam detach-role-policy --role-name "$role" --policy-arn "$policy" 2>/dev/null || true
                fi
            done
            
            # Delete inline policies
            local inline_policies=$(aws iam list-role-policies \
                --role-name "$role" \
                --query 'PolicyNames' \
                --output text 2>/dev/null || echo "")
            for policy in $inline_policies; do
                if [ -n "$policy" ]; then
                    aws iam delete-role-policy --role-name "$role" --policy-name "$policy" 2>/dev/null || true
                fi
            done
            
            # Remove from instance profiles
            local instance_profiles=$(aws iam list-instance-profiles-for-role \
                --role-name "$role" \
                --query 'InstanceProfiles[].InstanceProfileName' \
                --output text 2>/dev/null || echo "")
            for profile in $instance_profiles; do
                if [ -n "$profile" ]; then
                    aws iam remove-role-from-instance-profile \
                        --instance-profile-name "$profile" \
                        --role-name "$role" 2>/dev/null || true
                fi
            done
            
            # Delete the role
            aws iam delete-role --role-name "$role" 2>/dev/null || true
            print_success "Cleaned up orphaned role: $role"
        fi
    done
}

# Function to cleanup EventBridge rules
cleanup_eventbridge_rules() {
    print_status "Checking for EventBridge rules..."
    
    local rules=$(aws events list-rules \
        --query "Rules[?contains(Name, '${APPLICATION_NAME}')].Name" \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for rule in $rules; do
        if [ -n "$rule" ]; then
            # Remove targets first
            local targets=$(aws events list-targets-by-rule \
                --rule "$rule" \
                --query 'Targets[].Id' \
                --output text \
                --region "$REGION" 2>/dev/null || echo "")
            
            if [ -n "$targets" ]; then
                aws events remove-targets --rule "$rule" --ids $targets --region "$REGION" 2>/dev/null || true
            fi
            
            # Delete the rule
            aws events delete-rule --name "$rule" --region "$REGION" 2>/dev/null || true
            print_success "Deleted EventBridge rule: $rule"
        fi
    done
}

# Function to cleanup local files
cleanup_local_files() {
    print_status "Cleaning up local files..."
    
    local files_to_remove=(
        "sample-code/"
        "*.json"
        "*.zip"
        "*.log"
    )
    
    for file_pattern in "${files_to_remove[@]}"; do
        if ls $file_pattern 1> /dev/null 2>&1; then
            rm -rf $file_pattern
            print_success "Removed local files: $file_pattern"
        fi
    done
}

# Function to verify cleanup
verify_cleanup() {
    print_status "Verifying cleanup completion..."
    
    local issues=0
    
    # Check CloudFormation stacks
    local stacks=("${STACK_NAME_PREFIX}-codeguru" "${STACK_NAME_PREFIX}-container-scanning" "${STACK_NAME_PREFIX}-sast-dast")
    for stack in "${stacks[@]}"; do
        if aws cloudformation describe-stacks --stack-name "$stack" --region "$REGION" &> /dev/null; then
            print_error "Stack still exists: $stack"
            ((issues++))
        fi
    done
    
    # Check S3 buckets
    local remaining_buckets=$(aws s3api list-buckets \
        --query "Buckets[?contains(Name, '${APPLICATION_NAME}')].Name" \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$remaining_buckets" ]; then
        print_error "S3 buckets still exist: $remaining_buckets"
        ((issues++))
    fi
    
    # Check ECR repositories
    local remaining_repos=$(aws ecr describe-repositories \
        --query "repositories[?contains(repositoryName, '${APPLICATION_NAME}')].repositoryName" \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    if [ -n "$remaining_repos" ]; then
        print_error "ECR repositories still exist: $remaining_repos"
        ((issues++))
    fi
    
    if [ $issues -eq 0 ]; then
        print_success "Cleanup verification completed successfully"
        return 0
    else
        print_error "Cleanup verification found $issues issues"
        return 1
    fi
}

# Function to display cleanup summary
display_cleanup_summary() {
    echo
    print_success "Security Scanning Lab cleanup completed!"
    echo
    echo "=== Cleanup Summary ==="
    echo "✓ CloudFormation stacks deleted"
    echo "✓ ECR repositories and images removed"
    echo "✓ CodeCommit repositories deleted"
    echo "✓ S3 buckets and scan results removed"
    echo "✓ Lambda functions cleaned up"
    echo "✓ CodeBuild projects deleted"
    echo "✓ CloudWatch resources removed"
    echo "✓ SNS topics deleted"
    echo "✓ IAM resources cleaned up"
    echo "✓ EventBridge rules removed"
    echo "✓ Local files cleaned up"
    echo
    echo "=== Cost Impact ==="
    echo "All billable resources have been removed."
    echo "You should not incur any further charges from this lab."
    echo
    echo "=== Next Steps ==="
    echo "1. Verify no unexpected charges appear on your AWS bill"
    echo "2. Check AWS Console to confirm all resources are removed"
    echo "3. Consider running other DevOps certification labs"
    echo
}

# Function to handle partial cleanup
handle_partial_cleanup() {
    print_warning "Some resources could not be cleaned up automatically."
    echo
    echo "Manual cleanup may be required for:"
    echo "1. Check AWS Console for any remaining resources"
    echo "2. Look for resources with '${APPLICATION_NAME}' in the name"
    echo "3. Verify CloudFormation stacks are fully deleted"
    echo "4. Check ECR, CodeCommit, and S3 for remaining resources"
    echo
    echo "If you continue to see charges, contact AWS Support."
}

# Main execution
main() {
    echo "=== Security Scanning Lab Cleanup ==="
    echo
    
    # Confirm cleanup
    confirm_cleanup
    
    # Cleanup resources in order
    cleanup_cloudformation_stacks
    cleanup_ecr_repositories
    cleanup_codecommit_repositories
    cleanup_s3_buckets
    cleanup_lambda_functions
    cleanup_codebuild_projects
    cleanup_cloudwatch_resources
    cleanup_sns_topics
    cleanup_iam_resources
    cleanup_eventbridge_rules
    cleanup_local_files
    
    # Verify cleanup
    if verify_cleanup; then
        display_cleanup_summary
    else
        handle_partial_cleanup
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
        echo "  --verify       Only run cleanup verification"
        echo "  --force        Skip confirmation prompt"
        echo
        echo "Environment Variables:"
        echo "  AWS_DEFAULT_REGION    AWS region (default: us-east-1)"
        echo
        exit 0
        ;;
    --verify)
        verify_cleanup
        exit $?
        ;;
    --force)
        print_status "Force cleanup mode - skipping confirmation"
        # Skip confirmation and run cleanup
        cleanup_cloudformation_stacks
        cleanup_ecr_repositories
        cleanup_codecommit_repositories
        cleanup_s3_buckets
        cleanup_lambda_functions
        cleanup_codebuild_projects
        cleanup_cloudwatch_resources
        cleanup_sns_topics
        cleanup_iam_resources
        cleanup_eventbridge_rules
        cleanup_local_files
        verify_cleanup && display_cleanup_summary || handle_partial_cleanup
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac