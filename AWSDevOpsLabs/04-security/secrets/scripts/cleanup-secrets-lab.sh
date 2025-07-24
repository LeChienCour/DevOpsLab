#!/bin/bash

# Secrets Management Lab Cleanup Script
# This script cleans up all resources created by the secrets management lab

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
STACK_NAME_PREFIX="secrets-lab"
REGION=${AWS_DEFAULT_REGION:-us-east-1}
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
APPLICATION_NAME="secrets-lab-app"
ENVIRONMENT="dev"

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
    echo "=== Secrets Management Lab Cleanup Confirmation ==="
    echo
    echo "This will delete the following resources:"
    echo "  - CloudFormation stacks (${STACK_NAME_PREFIX}-*)"
    echo "  - All Parameter Store parameters under /${APPLICATION_NAME}/"
    echo "  - All Secrets Manager secrets for ${APPLICATION_NAME}"
    echo "  - RDS database instances"
    echo "  - Lambda functions for rotation"
    echo "  - VPC and networking resources"
    echo "  - IAM roles and policies"
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

# Function to delete Parameter Store parameters
cleanup_parameter_store() {
    print_status "Cleaning up Parameter Store parameters..."
    
    # Get all parameters for the application
    local parameters=$(aws ssm get-parameters-by-path \
        --path "/${APPLICATION_NAME}" \
        --recursive \
        --query 'Parameters[].Name' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    if [ -n "$parameters" ]; then
        for param in $parameters; do
            if [ -n "$param" ]; then
                aws ssm delete-parameter --name "$param" --region "$REGION" 2>/dev/null || true
                print_success "Deleted parameter: $param"
            fi
        done
    else
        print_warning "No parameters found to delete"
    fi
    
    # Clean up additional parameters that might have been created manually
    local additional_params=(
        "/${APPLICATION_NAME}/${ENVIRONMENT}/external/webhook_secret"
        "/${APPLICATION_NAME}/${ENVIRONMENT}/external/oauth_client_secret"
        "/${APPLICATION_NAME}/${ENVIRONMENT}/app/version"
        "/${APPLICATION_NAME}/${ENVIRONMENT}/app/debug_mode"
        "/${APPLICATION_NAME}/${ENVIRONMENT}/app/max_connections"
        "/${APPLICATION_NAME}/${ENVIRONMENT}/monitoring/enabled"
        "/${APPLICATION_NAME}/${ENVIRONMENT}/monitoring/interval"
    )
    
    for param in "${additional_params[@]}"; do
        aws ssm delete-parameter --name "$param" --region "$REGION" 2>/dev/null || true
    done
}

# Function to delete Secrets Manager secrets
cleanup_secrets_manager() {
    print_status "Cleaning up Secrets Manager secrets..."
    
    # Get all secrets for the application
    local secrets=$(aws secretsmanager list-secrets \
        --filters Key=name,Values="${APPLICATION_NAME}/" \
        --query 'SecretList[].Name' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    if [ -n "$secrets" ]; then
        for secret in $secrets; do
            if [ -n "$secret" ]; then
                # Cancel any pending rotation
                aws secretsmanager cancel-rotate-secret --secret-id "$secret" --region "$REGION" 2>/dev/null || true
                
                # Delete the secret (with immediate deletion for lab cleanup)
                aws secretsmanager delete-secret \
                    --secret-id "$secret" \
                    --force-delete-without-recovery \
                    --region "$REGION" 2>/dev/null || true
                print_success "Deleted secret: $secret"
            fi
        done
    else
        print_warning "No secrets found to delete"
    fi
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
        "${STACK_NAME_PREFIX}-rotation"
        "${STACK_NAME_PREFIX}-secrets-manager"
        "${STACK_NAME_PREFIX}-parameter-store"
    )
    
    for stack in "${stacks[@]}"; do
        delete_stack "$stack"
    done
}

# Function to cleanup Lambda functions (in case they weren't deleted by CloudFormation)
cleanup_lambda_functions() {
    print_status "Checking for orphaned Lambda functions..."
    
    local functions=$(aws lambda list-functions \
        --query "Functions[?contains(FunctionName, '${APPLICATION_NAME}')].FunctionName" \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    if [ -n "$functions" ]; then
        for function in $functions; do
            if [ -n "$function" ]; then
                aws lambda delete-function --function-name "$function" --region "$REGION" 2>/dev/null || true
                print_success "Deleted Lambda function: $function"
            fi
        done
    else
        print_warning "No orphaned Lambda functions found"
    fi
}

# Function to cleanup CloudWatch resources
cleanup_cloudwatch_resources() {
    print_status "Cleaning up CloudWatch resources..."
    
    # Delete log groups
    local log_groups=$(aws logs describe-log-groups \
        --log-group-name-prefix "/aws/lambda/${APPLICATION_NAME}" \
        --query 'logGroups[].logGroupName' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for log_group in $log_groups; do
        if [ -n "$log_group" ]; then
            aws logs delete-log-group --log-group-name "$log_group" --region "$REGION" 2>/dev/null || true
            print_success "Deleted log group: $log_group"
        fi
    done
    
    # Delete application log group
    aws logs delete-log-group --log-group-name "/aws/application/${APPLICATION_NAME}" --region "$REGION" 2>/dev/null || true
    
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

# Function to cleanup IAM resources (orphaned)
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
    
    # Look for orphaned policies
    local lab_policies=$(aws iam list-policies --scope Local \
        --query "Policies[?contains(PolicyName, '${APPLICATION_NAME}')].Arn" \
        --output text 2>/dev/null || echo "")
    
    for policy in $lab_policies; do
        if [ -n "$policy" ]; then
            print_warning "Found orphaned policy: $policy"
            
            # Get policy versions
            local versions=$(aws iam list-policy-versions \
                --policy-arn "$policy" \
                --query 'Versions[?!IsDefaultVersion].VersionId' \
                --output text 2>/dev/null || echo "")
            for version in $versions; do
                if [ -n "$version" ]; then
                    aws iam delete-policy-version --policy-arn "$policy" --version-id "$version" 2>/dev/null || true
                fi
            done
            
            # Delete the policy
            aws iam delete-policy --policy-arn "$policy" 2>/dev/null || true
            print_success "Cleaned up orphaned policy: $policy"
        fi
    done
}

# Function to cleanup ECR repositories (if any were created)
cleanup_ecr_repositories() {
    print_status "Checking for ECR repositories..."
    
    local repositories=$(aws ecr describe-repositories \
        --query "repositories[?contains(repositoryName, '${APPLICATION_NAME}')].repositoryName" \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    for repo in $repositories; do
        if [ -n "$repo" ]; then
            aws ecr delete-repository --repository-name "$repo" --force --region "$REGION" 2>/dev/null || true
            print_success "Deleted ECR repository: $repo"
        fi
    done
}

# Function to cleanup local files
cleanup_local_files() {
    print_status "Cleaning up local files..."
    
    local files_to_remove=(
        "sample-app/"
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
    local stacks=("${STACK_NAME_PREFIX}-parameter-store" "${STACK_NAME_PREFIX}-secrets-manager" "${STACK_NAME_PREFIX}-rotation")
    for stack in "${stacks[@]}"; do
        if aws cloudformation describe-stacks --stack-name "$stack" --region "$REGION" &> /dev/null; then
            print_error "Stack still exists: $stack"
            ((issues++))
        fi
    done
    
    # Check Parameter Store parameters
    local param_count=$(aws ssm get-parameters-by-path \
        --path "/${APPLICATION_NAME}" \
        --recursive \
        --query 'length(Parameters)' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "0")
    
    if [ "$param_count" -gt 0 ]; then
        print_error "Parameter Store still contains $param_count parameters"
        ((issues++))
    fi
    
    # Check Secrets Manager secrets
    local secret_count=$(aws secretsmanager list-secrets \
        --filters Key=name,Values="${APPLICATION_NAME}/" \
        --query 'length(SecretList)' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "0")
    
    if [ "$secret_count" -gt 0 ]; then
        print_error "Secrets Manager still contains $secret_count secrets"
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
    print_success "Secrets Management Lab cleanup completed!"
    echo
    echo "=== Cleanup Summary ==="
    echo "✓ CloudFormation stacks deleted"
    echo "✓ Parameter Store parameters removed"
    echo "✓ Secrets Manager secrets deleted"
    echo "✓ Lambda functions cleaned up"
    echo "✓ CloudWatch resources removed"
    echo "✓ SNS topics deleted"
    echo "✓ IAM resources cleaned up"
    echo "✓ Local files removed"
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
    echo "4. Check Parameter Store and Secrets Manager for remaining items"
    echo
    echo "If you continue to see charges, contact AWS Support."
}

# Main execution
main() {
    echo "=== Secrets Management Lab Cleanup ==="
    echo
    
    # Confirm cleanup
    confirm_cleanup
    
    # Cleanup resources in order
    cleanup_parameter_store
    cleanup_secrets_manager
    cleanup_cloudformation_stacks
    cleanup_lambda_functions
    cleanup_cloudwatch_resources
    cleanup_sns_topics
    cleanup_iam_resources
    cleanup_ecr_repositories
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
        cleanup_parameter_store
        cleanup_secrets_manager
        cleanup_cloudformation_stacks
        cleanup_lambda_functions
        cleanup_cloudwatch_resources
        cleanup_sns_topics
        cleanup_iam_resources
        cleanup_ecr_repositories
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