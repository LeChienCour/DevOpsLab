#!/bin/bash

# Canary Deployment Lab Cleanup Script
# This script removes all AWS resources created for the canary deployment lab

set -e

# Configuration
STACK_PREFIX="canary-lab"
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

# Function to cleanup DynamoDB tables (if they exist outside CloudFormation)
cleanup_dynamodb_tables() {
    print_status "Checking for orphaned DynamoDB tables..."
    
    # List tables with canary-demo-app prefix
    TABLES=$(aws dynamodb list-tables \
        --query 'TableNames[?starts_with(@, `canary-demo-app`)]' \
        --output text \
        --profile $PROFILE \
        --region $REGION)
    
    if [ -n "$TABLES" ]; then
        for table in $TABLES; do
            print_warning "Found orphaned DynamoDB table: $table"
            print_status "Deleting DynamoDB table: $table"
            
            aws dynamodb delete-table \
                --table-name $table \
                --profile $PROFILE \
                --region $REGION
            
            if [ $? -eq 0 ]; then
                print_status "DynamoDB table $table deleted successfully"
            else
                print_warning "Failed to delete DynamoDB table $table"
            fi
        done
    else
        print_status "No orphaned DynamoDB tables found"
    fi
}

# Function to cleanup Step Functions state machines
cleanup_step_functions() {
    print_status "Checking for orphaned Step Functions state machines..."
    
    # List state machines with canary-demo-app prefix
    STATE_MACHINES=$(aws stepfunctions list-state-machines \
        --query 'stateMachines[?starts_with(name, `canary-demo-app`)].stateMachineArn' \
        --output text \
        --profile $PROFILE \
        --region $REGION)
    
    if [ -n "$STATE_MACHINES" ]; then
        for sm_arn in $STATE_MACHINES; do
            print_warning "Found orphaned Step Functions state machine: $sm_arn"
            print_status "Deleting Step Functions state machine: $sm_arn"
            
            aws stepfunctions delete-state-machine \
                --state-machine-arn $sm_arn \
                --profile $PROFILE \
                --region $REGION
            
            if [ $? -eq 0 ]; then
                print_status "Step Functions state machine deleted successfully"
            else
                print_warning "Failed to delete Step Functions state machine"
            fi
        done
    else
        print_status "No orphaned Step Functions state machines found"
    fi
}

# Function to cleanup Lambda functions
cleanup_lambda_functions() {
    print_status "Checking for orphaned Lambda functions..."
    
    # List Lambda functions with canary-demo-app prefix
    FUNCTIONS=$(aws lambda list-functions \
        --query 'Functions[?starts_with(FunctionName, `canary-demo-app`)].FunctionName' \
        --output text \
        --profile $PROFILE \
        --region $REGION)
    
    if [ -n "$FUNCTIONS" ]; then
        for func in $FUNCTIONS; do
            print_warning "Found orphaned Lambda function: $func"
            print_status "Deleting Lambda function: $func"
            
            aws lambda delete-function \
                --function-name $func \
                --profile $PROFILE \
                --region $REGION
            
            if [ $? -eq 0 ]; then
                print_status "Lambda function $func deleted successfully"
            else
                print_warning "Failed to delete Lambda function $func"
            fi
        done
    else
        print_status "No orphaned Lambda functions found"
    fi
}

# Function to cleanup CloudWatch dashboards
cleanup_cloudwatch_dashboards() {
    print_status "Checking for orphaned CloudWatch dashboards..."
    
    # List dashboards with canary-demo-app prefix
    DASHBOARDS=$(aws cloudwatch list-dashboards \
        --query 'DashboardEntries[?starts_with(DashboardName, `canary-demo-app`)].DashboardName' \
        --output text \
        --profile $PROFILE \
        --region $REGION)
    
    if [ -n "$DASHBOARDS" ]; then
        for dashboard in $DASHBOARDS; do
            print_warning "Found orphaned CloudWatch dashboard: $dashboard"
            print_status "Deleting CloudWatch dashboard: $dashboard"
            
            aws cloudwatch delete-dashboards \
                --dashboard-names $dashboard \
                --profile $PROFILE \
                --region $REGION
            
            if [ $? -eq 0 ]; then
                print_status "CloudWatch dashboard $dashboard deleted successfully"
            else
                print_warning "Failed to delete CloudWatch dashboard $dashboard"
            fi
        done
    else
        print_status "No orphaned CloudWatch dashboards found"
    fi
}

# Function to cleanup CloudWatch alarms
cleanup_cloudwatch_alarms() {
    print_status "Checking for orphaned CloudWatch alarms..."
    
    # List alarms with canary-demo-app prefix
    ALARMS=$(aws cloudwatch describe-alarms \
        --query 'MetricAlarms[?starts_with(AlarmName, `canary-demo-app`)].AlarmName' \
        --output text \
        --profile $PROFILE \
        --region $REGION)
    
    if [ -n "$ALARMS" ]; then
        for alarm in $ALARMS; do
            print_warning "Found orphaned CloudWatch alarm: $alarm"
            print_status "Deleting CloudWatch alarm: $alarm"
            
            aws cloudwatch delete-alarms \
                --alarm-names $alarm \
                --profile $PROFILE \
                --region $REGION
            
            if [ $? -eq 0 ]; then
                print_status "CloudWatch alarm $alarm deleted successfully"
            else
                print_warning "Failed to delete CloudWatch alarm $alarm"
            fi
        done
    else
        print_status "No orphaned CloudWatch alarms found"
    fi
}

# Function to cleanup local files
cleanup_local_files() {
    print_status "Cleaning up local files..."
    
    if [ -f "traffic-shift.sh" ]; then
        rm traffic-shift.sh
        print_status "Removed traffic-shift.sh script"
    fi
    
    if [ -f "/tmp/traffic-response.json" ]; then
        rm /tmp/traffic-response.json
        print_status "Removed temporary response files"
    fi
}

# Function to display cleanup summary
display_cleanup_summary() {
    print_status "Canary Deployment Lab Cleanup Completed!"
    echo ""
    echo "=== Cleaned Up Resources ==="
    echo "✓ CloudFormation stacks deleted"
    echo "✓ DynamoDB tables cleaned up"
    echo "✓ Step Functions state machines cleaned up"
    echo "✓ Lambda functions cleaned up"
    echo "✓ CloudWatch dashboards cleaned up"
    echo "✓ CloudWatch alarms cleaned up"
    echo "✓ Local files cleaned up"
    echo ""
    echo "=== Verification ==="
    echo "You can verify cleanup by checking:"
    echo "1. CloudFormation console - no canary-lab stacks"
    echo "2. ECS console - no canary-demo-app clusters or services"
    echo "3. Lambda console - no canary-demo-app functions"
    echo "4. DynamoDB console - no canary-demo-app tables"
    echo "5. Step Functions console - no canary-demo-app state machines"
    echo "6. CloudWatch console - no canary-demo-app dashboards or alarms"
    echo ""
    print_status "All lab resources have been cleaned up successfully!"
}

# Function to confirm cleanup
confirm_cleanup() {
    echo ""
    print_warning "This will delete ALL resources created by the Canary Deployment Lab."
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
    print_status "Starting Canary Deployment Lab Cleanup..."
    
    check_aws_cli
    confirm_cleanup
    
    # Delete stacks in reverse order (automation first, then ab-testing, then alb)
    delete_stack "${STACK_PREFIX}-automation"
    delete_stack "${STACK_PREFIX}-ab-testing"
    delete_stack "${STACK_PREFIX}-alb"
    
    # Cleanup additional resources
    cleanup_dynamodb_tables
    cleanup_step_functions
    cleanup_lambda_functions
    cleanup_cloudwatch_dashboards
    cleanup_cloudwatch_alarms
    cleanup_local_files
    
    display_cleanup_summary
    
    print_status "Lab cleanup completed successfully!"
}

# Run main function
main "$@"