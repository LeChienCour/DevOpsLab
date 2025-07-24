#!/bin/bash

# RDS Database Integration Lab Cleanup Script
# This script safely removes all resources created by the RDS integration lab

set -e

# Configuration
STACK_PREFIX="rds-integration-lab"
INFRASTRUCTURE_STACK="${STACK_PREFIX}-infrastructure"
PROXY_STACK="${STACK_PREFIX}-proxy"
BACKUP_STACK="${STACK_PREFIX}-backup"
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

# Function to disable RDS deletion protection
disable_rds_deletion_protection() {
    print_status "Disabling RDS deletion protection..."
    
    local db_instances=("rds-mysql-instance")
    
    for instance in "${db_instances[@]}"; do
        if aws rds describe-db-instances --db-instance-identifier "$instance" --region "$REGION" > /dev/null 2>&1; then
            print_status "Disabling deletion protection for: $instance"
            aws rds modify-db-instance \
                --db-instance-identifier "$instance" \
                --no-deletion-protection \
                --apply-immediately \
                --region "$REGION" || true
        fi
    done
    
    print_success "RDS deletion protection disabled"
}

# Function to clean up S3 backup bucket
cleanup_backup_bucket() {
    print_status "Cleaning up backup S3 bucket..."
    
    # Get backup bucket name from stack if it exists
    if stack_exists "$BACKUP_STACK"; then
        local bucket_name=$(aws cloudformation describe-stacks \
            --stack-name "$BACKUP_STACK" \
            --region "$REGION" \
            --query "Stacks[0].Outputs[?OutputKey=='BackupBucketName'].OutputValue" \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$bucket_name" ] && [ "$bucket_name" != "None" ]; then
            print_status "Found backup bucket: $bucket_name"
            
            # Empty the bucket
            print_status "Emptying S3 bucket: $bucket_name"
            aws s3 rm "s3://$bucket_name" --recursive --region "$REGION" || true
            
            # Delete all object versions (for versioned buckets)
            aws s3api list-object-versions \
                --bucket "$bucket_name" \
                --region "$REGION" \
                --query 'Versions[].{Key:Key,VersionId:VersionId}' \
                --output text | while read key version_id; do
                    if [ -n "$key" ] && [ -n "$version_id" ]; then
                        aws s3api delete-object \
                            --bucket "$bucket_name" \
                            --key "$key" \
                            --version-id "$version_id" \
                            --region "$REGION" || true
                    fi
                done
            
            # Delete delete markers
            aws s3api list-object-versions \
                --bucket "$bucket_name" \
                --region "$REGION" \
                --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' \
                --output text | while read key version_id; do
                    if [ -n "$key" ] && [ -n "$version_id" ]; then
                        aws s3api delete-object \
                            --bucket "$bucket_name" \
                            --key "$key" \
                            --version-id "$version_id" \
                            --region "$REGION" || true
                    fi
                done
        fi
    fi
    
    print_success "Backup bucket cleanup completed"
}

# Function to clean up RDS snapshots
cleanup_rds_snapshots() {
    print_status "Cleaning up RDS snapshots..."
    
    # Get manual snapshots for the lab instance
    local snapshots=$(aws rds describe-db-snapshots \
        --db-instance-identifier "rds-mysql-instance" \
        --snapshot-type manual \
        --region "$REGION" \
        --query 'DBSnapshots[].DBSnapshotIdentifier' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$snapshots" ] && [ "$snapshots" != "None" ]; then
        for snapshot in $snapshots; do
            print_status "Deleting snapshot: $snapshot"
            aws rds delete-db-snapshot \
                --db-snapshot-identifier "$snapshot" \
                --region "$REGION" || true
        done
    else
        print_status "No manual snapshots found to delete"
    fi
    
    print_success "RDS snapshots cleanup completed"
}

# Function to clean up CloudWatch resources
cleanup_cloudwatch_resources() {
    print_status "Cleaning up CloudWatch resources..."
    
    # Delete custom log groups
    local log_groups=(
        "/aws/lambda/rds-backup-automation"
        "/aws/lambda/rds-restore-automation"
        "/aws/lambda/rds-backup-notification"
        "/aws/lambda/direct-rds-connection"
        "/aws/lambda/proxy-rds-connection"
        "/aws/lambda/connection-pooling-demo"
    )
    
    for log_group in "${log_groups[@]}"; do
        if aws logs describe-log-groups --log-group-name-prefix "$log_group" --region "$REGION" --query 'logGroups[0]' --output text > /dev/null 2>&1; then
            print_status "Deleting log group: $log_group"
            aws logs delete-log-group --log-group-name "$log_group" --region "$REGION" || true
        fi
    done
    
    # Delete custom dashboards
    local dashboards=(
        "rds-backup-monitoring"
        "rds-proxy-monitoring"
    )
    
    for dashboard in "${dashboards[@]}"; do
        if aws cloudwatch get-dashboard --dashboard-name "$dashboard" --region "$REGION" > /dev/null 2>&1; then
            print_status "Deleting dashboard: $dashboard"
            aws cloudwatch delete-dashboards --dashboard-names "$dashboard" --region "$REGION" || true
        fi
    done
    
    print_success "CloudWatch resources cleanup completed"
}

# Function to clean up Secrets Manager secrets
cleanup_secrets() {
    print_status "Cleaning up Secrets Manager secrets..."
    
    local secrets=(
        "rds-db-credentials"
    )
    
    for secret in "${secrets[@]}"; do
        if aws secretsmanager describe-secret --secret-id "$secret" --region "$REGION" > /dev/null 2>&1; then
            print_status "Deleting secret: $secret"
            aws secretsmanager delete-secret \
                --secret-id "$secret" \
                --force-delete-without-recovery \
                --region "$REGION" || true
        fi
    done
    
    print_success "Secrets Manager cleanup completed"
}

# Function to stop running Step Functions executions
stop_step_functions_executions() {
    print_status "Stopping running Step Functions executions..."
    
    # Get state machine ARN from backup stack if it exists
    if stack_exists "$BACKUP_STACK"; then
        local state_machine_arn=$(aws cloudformation describe-stacks \
            --stack-name "$BACKUP_STACK" \
            --region "$REGION" \
            --query "Stacks[0].Outputs[?OutputKey=='BackupStateMachineArn'].OutputValue" \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$state_machine_arn" ] && [ "$state_machine_arn" != "None" ]; then
            print_status "Found state machine: $state_machine_arn"
            
            # List running executions
            local running_executions=$(aws stepfunctions list-executions \
                --state-machine-arn "$state_machine_arn" \
                --status-filter RUNNING \
                --region "$REGION" \
                --query 'executions[].executionArn' \
                --output text 2>/dev/null || echo "")
            
            if [ -n "$running_executions" ] && [ "$running_executions" != "None" ]; then
                for execution_arn in $running_executions; do
                    print_status "Stopping execution: $execution_arn"
                    aws stepfunctions stop-execution \
                        --execution-arn "$execution_arn" \
                        --region "$REGION" || true
                done
            else
                print_status "No running executions found"
            fi
        fi
    fi
    
    print_success "Step Functions executions cleanup completed"
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
    
    # Check for RDS instances
    local rds_instances=$(aws rds describe-db-instances \
        --region "$REGION" \
        --query 'DBInstances[?contains(DBInstanceIdentifier, `rds-mysql`)].DBInstanceIdentifier' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$rds_instances" ] && [ "$rds_instances" != "None" ]; then
        print_warning "Remaining RDS instances found:"
        echo "$rds_instances"
        found_resources=true
    fi
    
    # Check for Lambda functions
    local lambda_functions=$(aws lambda list-functions \
        --region "$REGION" \
        --query 'Functions[?contains(FunctionName, `rds-`) || contains(FunctionName, `direct-rds`) || contains(FunctionName, `proxy-rds`) || contains(FunctionName, `connection-pooling`)].FunctionName' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$lambda_functions" ] && [ "$lambda_functions" != "None" ]; then
        print_warning "Remaining Lambda functions found:"
        echo "$lambda_functions"
        found_resources=true
    fi
    
    # Check for S3 buckets
    local s3_buckets=$(aws s3api list-buckets \
        --region "$REGION" \
        --query 'Buckets[?contains(Name, `rds-backups`) || contains(Name, `rds-lambda-layers`)].Name' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$s3_buckets" ] && [ "$s3_buckets" != "None" ]; then
        print_warning "Remaining S3 buckets found:"
        echo "$s3_buckets"
        found_resources=true
    fi
    
    # Check for RDS Proxy
    local rds_proxies=$(aws rds describe-db-proxies \
        --region "$REGION" \
        --query 'DBProxies[?contains(DBProxyName, `rds-proxy`)].DBProxyName' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$rds_proxies" ] && [ "$rds_proxies" != "None" ]; then
        print_warning "Remaining RDS Proxies found:"
        echo "$rds_proxies"
        found_resources=true
    fi
    
    # Check for Step Functions state machines
    local state_machines=$(aws stepfunctions list-state-machines \
        --region "$REGION" \
        --query 'stateMachines[?contains(name, `rds-backup`)].name' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$state_machines" ] && [ "$state_machines" != "None" ]; then
        print_warning "Remaining Step Functions state machines found:"
        echo "$state_machines"
        found_resources=true
    fi
    
    if [ "$found_resources" = false ]; then
        print_success "No remaining lab resources found"
    else
        print_warning "Some resources may require manual cleanup"
        print_warning "Check the AWS Console for any remaining resources with 'rds-' prefix"
    fi
}

# Function to confirm deletion
confirm_deletion() {
    echo
    print_warning "This will delete ALL resources created by the RDS Database Integration Lab"
    print_warning "This action cannot be undone!"
    echo
    print_status "The following stacks will be deleted:"
    echo "  • $BACKUP_STACK"
    echo "  • $PROXY_STACK"
    echo "  • $INFRASTRUCTURE_STACK"
    echo
    print_warning "This will also delete:"
    echo "  • RDS database instance and all data"
    echo "  • All database snapshots"
    echo "  • S3 backup bucket and all backups"
    echo "  • Lambda functions and logs"
    echo "  • Secrets Manager secrets"
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
    echo "RDS Database Integration Lab Cleanup"
    echo "=========================================="
    echo
    
    check_aws_cli
    
    # Check if any stacks exist
    local stacks_exist=false
    for stack in "$BACKUP_STACK" "$PROXY_STACK" "$INFRASTRUCTURE_STACK"; do
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
    
    # Disable RDS deletion protection first
    disable_rds_deletion_protection
    
    # Stop running Step Functions executions
    stop_step_functions_executions
    
    # Clean up additional resources before deleting stacks
    cleanup_backup_bucket
    cleanup_rds_snapshots
    
    # Delete stacks in reverse order (dependencies)
    local cleanup_success=true
    
    # Delete backup stack first
    if stack_exists "$BACKUP_STACK"; then
        if ! delete_stack_with_retry "$BACKUP_STACK"; then
            cleanup_success=false
        fi
    fi
    
    # Delete proxy stack
    if stack_exists "$PROXY_STACK"; then
        if ! delete_stack_with_retry "$PROXY_STACK"; then
            cleanup_success=false
        fi
    fi
    
    # Delete infrastructure stack last
    if stack_exists "$INFRASTRUCTURE_STACK"; then
        if ! delete_stack_with_retry "$INFRASTRUCTURE_STACK"; then
            cleanup_success=false
        fi
    fi
    
    # Clean up additional resources
    cleanup_cloudwatch_resources
    cleanup_secrets
    
    # Final check for remaining resources
    list_remaining_resources
    
    if [ "$cleanup_success" = true ]; then
        print_success "RDS Database Integration Lab cleanup completed successfully!"
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