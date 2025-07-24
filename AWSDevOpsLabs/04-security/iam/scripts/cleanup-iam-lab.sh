#!/bin/bash

# IAM Best Practices Lab Cleanup Script
# This script cleans up all resources created by the IAM lab

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
STACK_NAME_PREFIX="iam-lab"
REGION=${AWS_DEFAULT_REGION:-us-east-1}
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="iam-lab-test-bucket-${ACCOUNT_ID}"

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
    echo "=== IAM Lab Cleanup Confirmation ==="
    echo
    echo "This will delete the following resources:"
    echo "  - CloudFormation stacks (${STACK_NAME_PREFIX}-*)"
    echo "  - Test S3 bucket: ${BUCKET_NAME}"
    echo "  - Test IAM users and their access keys"
    echo "  - All IAM roles and policies created by the lab"
    echo "  - Access Analyzer and monitoring resources"
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

# Function to delete test users and their access keys
cleanup_test_users() {
    print_status "Cleaning up test users..."
    
    local users=("test-dev-user" "test-ops-user" "test-audit-user")
    
    for user in "${users[@]}"; do
        if aws iam get-user --user-name "$user" &> /dev/null; then
            print_status "Cleaning up user: $user"
            
            # List and delete access keys
            local access_keys=$(aws iam list-access-keys --user-name "$user" --query 'AccessKeyMetadata[].AccessKeyId' --output text)
            for key in $access_keys; do
                if [ -n "$key" ]; then
                    aws iam delete-access-key --user-name "$user" --access-key-id "$key"
                    print_success "Deleted access key: $key"
                fi
            done
            
            # Detach all user policies
            local attached_policies=$(aws iam list-attached-user-policies --user-name "$user" --query 'AttachedPolicies[].PolicyArn' --output text)
            for policy in $attached_policies; do
                if [ -n "$policy" ]; then
                    aws iam detach-user-policy --user-name "$user" --policy-arn "$policy"
                    print_success "Detached policy: $policy"
                fi
            done
            
            # Delete inline policies
            local inline_policies=$(aws iam list-user-policies --user-name "$user" --query 'PolicyNames' --output text)
            for policy in $inline_policies; do
                if [ -n "$policy" ]; then
                    aws iam delete-user-policy --user-name "$user" --policy-name "$policy"
                    print_success "Deleted inline policy: $policy"
                fi
            done
            
            # Delete user
            aws iam delete-user --user-name "$user"
            print_success "Deleted user: $user"
        else
            print_warning "User $user not found"
        fi
    done
}

# Function to delete S3 bucket and contents
cleanup_s3_bucket() {
    print_status "Cleaning up S3 bucket: $BUCKET_NAME"
    
    if aws s3 ls "s3://${BUCKET_NAME}" &> /dev/null; then
        # Delete all objects in the bucket
        aws s3 rm "s3://${BUCKET_NAME}" --recursive
        
        # Delete the bucket
        aws s3 rb "s3://${BUCKET_NAME}"
        print_success "Deleted S3 bucket: $BUCKET_NAME"
    else
        print_warning "S3 bucket $BUCKET_NAME not found"
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
        "${STACK_NAME_PREFIX}-access-analyzer"
        "${STACK_NAME_PREFIX}-cross-account"
        "${STACK_NAME_PREFIX}-policies"
    )
    
    for stack in "${stacks[@]}"; do
        delete_stack "$stack"
    done
}

# Function to cleanup orphaned IAM resources
cleanup_orphaned_iam_resources() {
    print_status "Checking for orphaned IAM resources..."
    
    # Look for roles created by the lab that might not be in CloudFormation
    local lab_roles=$(aws iam list-roles --query 'Roles[?contains(RoleName, `iam-lab`) || contains(RoleName, `DevRole`) || contains(RoleName, `OpsRole`) || contains(RoleName, `AuditRole`)].RoleName' --output text)
    
    for role in $lab_roles; do
        if [ -n "$role" ]; then
            print_warning "Found orphaned role: $role"
            
            # Detach managed policies
            local attached_policies=$(aws iam list-attached-role-policies --role-name "$role" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null || echo "")
            for policy in $attached_policies; do
                if [ -n "$policy" ]; then
                    aws iam detach-role-policy --role-name "$role" --policy-arn "$policy" 2>/dev/null || true
                fi
            done
            
            # Delete inline policies
            local inline_policies=$(aws iam list-role-policies --role-name "$role" --query 'PolicyNames' --output text 2>/dev/null || echo "")
            for policy in $inline_policies; do
                if [ -n "$policy" ]; then
                    aws iam delete-role-policy --role-name "$role" --policy-name "$policy" 2>/dev/null || true
                fi
            done
            
            # Remove from instance profiles
            local instance_profiles=$(aws iam list-instance-profiles-for-role --role-name "$role" --query 'InstanceProfiles[].InstanceProfileName' --output text 2>/dev/null || echo "")
            for profile in $instance_profiles; do
                if [ -n "$profile" ]; then
                    aws iam remove-role-from-instance-profile --instance-profile-name "$profile" --role-name "$role" 2>/dev/null || true
                fi
            done
            
            # Delete the role
            aws iam delete-role --role-name "$role" 2>/dev/null || true
            print_success "Cleaned up orphaned role: $role"
        fi
    done
    
    # Look for orphaned policies
    local lab_policies=$(aws iam list-policies --scope Local --query 'Policies[?contains(PolicyName, `iam-lab`) || contains(PolicyName, `DevLimited`) || contains(PolicyName, `OpsElevated`) || contains(PolicyName, `AuditReadOnly`)].Arn' --output text)
    
    for policy in $lab_policies; do
        if [ -n "$policy" ]; then
            print_warning "Found orphaned policy: $policy"
            
            # Get policy versions
            local versions=$(aws iam list-policy-versions --policy-arn "$policy" --query 'Versions[?!IsDefaultVersion].VersionId' --output text 2>/dev/null || echo "")
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

# Function to cleanup CloudWatch resources
cleanup_cloudwatch_resources() {
    print_status "Cleaning up CloudWatch resources..."
    
    # Delete log groups
    local log_groups=$(aws logs describe-log-groups --log-group-name-prefix "CloudTrail/IAMEvents" --query 'logGroups[].logGroupName' --output text 2>/dev/null || echo "")
    for log_group in $log_groups; do
        if [ -n "$log_group" ]; then
            aws logs delete-log-group --log-group-name "$log_group" 2>/dev/null || true
            print_success "Deleted log group: $log_group"
        fi
    done
    
    # Delete alarms
    local alarms=$(aws cloudwatch describe-alarms --alarm-name-prefix "Root-Account-Usage" --query 'MetricAlarms[].AlarmName' --output text 2>/dev/null || echo "")
    for alarm in $alarms; do
        if [ -n "$alarm" ]; then
            aws cloudwatch delete-alarms --alarm-names "$alarm" 2>/dev/null || true
            print_success "Deleted alarm: $alarm"
        fi
    done
}

# Function to cleanup SNS topics
cleanup_sns_topics() {
    print_status "Cleaning up SNS topics..."
    
    local topics=$(aws sns list-topics --query 'Topics[?contains(TopicArn, `iam-security-alerts`) || contains(TopicArn, `AccessAnalyzer`)].TopicArn' --output text 2>/dev/null || echo "")
    for topic in $topics; do
        if [ -n "$topic" ]; then
            aws sns delete-topic --topic-arn "$topic" 2>/dev/null || true
            print_success "Deleted SNS topic: $topic"
        fi
    done
}

# Function to cleanup temporary files
cleanup_temp_files() {
    print_status "Cleaning up temporary files..."
    
    local temp_files=(
        "/tmp/iam-lab-external-id.txt"
        "/tmp/test-file.txt"
        "dev-policy.json"
        "ops-policy.json"
        "audit-policy.json"
        "ec2-trust-policy.json"
        "cross-account-trust-policy.json"
    )
    
    for file in "${temp_files[@]}"; do
        if [ -f "$file" ]; then
            rm -f "$file"
            print_success "Deleted temporary file: $file"
        fi
    done
}

# Function to verify cleanup
verify_cleanup() {
    print_status "Verifying cleanup completion..."
    
    local issues=0
    
    # Check CloudFormation stacks
    local stacks=("${STACK_NAME_PREFIX}-policies" "${STACK_NAME_PREFIX}-cross-account" "${STACK_NAME_PREFIX}-access-analyzer")
    for stack in "${stacks[@]}"; do
        if aws cloudformation describe-stacks --stack-name "$stack" --region "$REGION" &> /dev/null; then
            print_error "Stack still exists: $stack"
            ((issues++))
        fi
    done
    
    # Check S3 bucket
    if aws s3 ls "s3://${BUCKET_NAME}" &> /dev/null; then
        print_error "S3 bucket still exists: $BUCKET_NAME"
        ((issues++))
    fi
    
    # Check test users
    local users=("test-dev-user" "test-ops-user" "test-audit-user")
    for user in "${users[@]}"; do
        if aws iam get-user --user-name "$user" &> /dev/null; then
            print_error "Test user still exists: $user"
            ((issues++))
        fi
    done
    
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
    print_success "IAM Best Practices Lab cleanup completed!"
    echo
    echo "=== Cleanup Summary ==="
    echo "✓ CloudFormation stacks deleted"
    echo "✓ Test S3 bucket and contents removed"
    echo "✓ Test IAM users and access keys deleted"
    echo "✓ IAM roles and policies cleaned up"
    echo "✓ CloudWatch resources removed"
    echo "✓ SNS topics deleted"
    echo "✓ Temporary files cleaned up"
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
    echo "2. Look for resources with 'iam-lab' in the name"
    echo "3. Verify CloudFormation stacks are fully deleted"
    echo "4. Check for any remaining IAM policies or roles"
    echo
    echo "If you continue to see charges, contact AWS Support."
}

# Main execution
main() {
    echo "=== IAM Best Practices Lab Cleanup ==="
    echo
    
    # Confirm cleanup
    confirm_cleanup
    
    # Cleanup resources in order
    cleanup_test_users
    cleanup_s3_bucket
    cleanup_cloudformation_stacks
    cleanup_orphaned_iam_resources
    cleanup_cloudwatch_resources
    cleanup_sns_topics
    cleanup_temp_files
    
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
        cleanup_test_users
        cleanup_s3_bucket
        cleanup_cloudformation_stacks
        cleanup_orphaned_iam_resources
        cleanup_cloudwatch_resources
        cleanup_sns_topics
        cleanup_temp_files
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