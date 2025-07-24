#!/bin/bash

# Rolling Deployment Lab Cleanup Script
# This script removes all AWS resources created for the rolling deployment lab

set -e

# Configuration
STACK_PREFIX="rolling-lab"
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

# Function to cleanup CloudWatch log groups
cleanup_log_groups() {
    print_status "Cleaning up CloudWatch log groups..."
    
    # Find log groups related to the lab
    LOG_GROUPS=$(aws logs describe-log-groups \
        --query 'logGroups[?starts_with(logGroupName, `/ecs/rolling-`) || starts_with(logGroupName, `/aws/lambda/rolling-`) || starts_with(logGroupName, `/aws/ec2/rolling-`)].logGroupName' \
        --output text \
        --profile $PROFILE \
        --region $REGION)
    
    if [ -n "$LOG_GROUPS" ]; then
        for log_group in $LOG_GROUPS; do
            print_status "Deleting log group: $log_group"
            aws logs delete-log-group \
                --log-group-name $log_group \
                --profile $PROFILE \
                --region $REGION
        done
    else
        print_status "No lab-related log groups found"
    fi
}

# Function to cleanup Lambda functions
cleanup_lambda_functions() {
    print_status "Checking for orphaned Lambda functions..."
    
    # Find Lambda functions with rolling-demo prefix
    FUNCTIONS=$(aws lambda list-functions \
        --query 'Functions[?starts_with(FunctionName, `rolling-`)].FunctionName' \
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

# Function to cleanup CloudWatch alarms
cleanup_cloudwatch_alarms() {
    print_status "Checking for orphaned CloudWatch alarms..."
    
    # Find alarms with rolling-demo prefix
    ALARMS=$(aws cloudwatch describe-alarms \
        --query 'MetricAlarms[?starts_with(AlarmName, `rolling-`)].AlarmName' \
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

# Function to cleanup CloudWatch dashboards
cleanup_cloudwatch_dashboards() {
    print_status "Checking for orphaned CloudWatch dashboards..."
    
    # Find dashboards with rolling-demo prefix
    DASHBOARDS=$(aws cloudwatch list-dashboards \
        --query 'DashboardEntries[?starts_with(DashboardName, `rolling-`)].DashboardName' \
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

# Function to cleanup EventBridge rules
cleanup_eventbridge_rules() {
    print_status "Checking for orphaned EventBridge rules..."
    
    # Find rules with rolling-demo prefix
    RULES=$(aws events list-rules \
        --query 'Rules[?starts_with(Name, `rolling-`)].Name' \
        --output text \
        --profile $PROFILE \
        --region $REGION)
    
    if [ -n "$RULES" ]; then
        for rule in $RULES; do
            print_warning "Found orphaned EventBridge rule: $rule"
            
            # Remove targets first
            aws events remove-targets \
                --rule $rule \
                --ids $(aws events list-targets-by-rule --rule $rule --query 'Targets[].Id' --output text) \
                --profile $PROFILE \
                --region $REGION
            
            # Delete rule
            print_status "Deleting EventBridge rule: $rule"
            aws events delete-rule \
                --name $rule \
                --profile $PROFILE \
                --region $REGION
            
            if [ $? -eq 0 ]; then
                print_status "EventBridge rule $rule deleted successfully"
            else
                print_warning "Failed to delete EventBridge rule $rule"
            fi
        done
    else
        print_status "No orphaned EventBridge rules found"
    fi
}

# Function to cleanup SNS topics
cleanup_sns_topics() {
    print_status "Checking for orphaned SNS topics..."
    
    # Find topics with rolling-demo prefix
    TOPICS=$(aws sns list-topics \
        --query 'Topics[?contains(TopicArn, `rolling-`)].TopicArn' \
        --output text \
        --profile $PROFILE \
        --region $REGION)
    
    if [ -n "$TOPICS" ]; then
        for topic in $TOPICS; do
            print_warning "Found orphaned SNS topic: $topic"
            print_status "Deleting SNS topic: $topic"
            
            aws sns delete-topic \
                --topic-arn $topic \
                --profile $PROFILE \
                --region $REGION
            
            if [ $? -eq 0 ]; then
                print_status "SNS topic $topic deleted successfully"
            else
                print_warning "Failed to delete SNS topic $topic"
            fi
        done
    else
        print_status "No orphaned SNS topics found"
    fi
}

# Function to cleanup local files
cleanup_local_files() {
    print_status "Cleaning up local files..."
    
    local files_to_remove=(
        "ecs-deploy.sh"
        "asg-deploy.sh"
        "current-task-def.json"
        "new-task-def.json"
        "new-user-data.sh"
    )
    
    for file in "${files_to_remove[@]}"; do
        if [ -f "$file" ]; then
            rm "$file"
            print_status "Removed $file"
        fi
    done
}

# Function to display cleanup summary
display_cleanup_summary() {
    print_status "Rolling Deployment Lab Cleanup Completed!"
    echo ""
    echo "=== Cleaned Up Resources ==="
    echo "✓ CloudFormation stacks deleted"
    echo "✓ CloudWatch log groups cleaned up"
    echo "✓ Lambda functions cleaned up"
    echo "✓ CloudWatch alarms cleaned up"
    echo "✓ CloudWatch dashboards cleaned up"
    echo "✓ EventBridge rules cleaned up"
    echo "✓ SNS topics cleaned up"
    echo "✓ Local files cleaned up"
    echo ""
    echo "=== Verification ==="
    echo "You can verify cleanup by checking:"
    echo "1. CloudFormation console - no rolling-lab stacks"
    echo "2. ECS console - no rolling-demo clusters or services"
    echo "3. EC2 console - no rolling-demo Auto Scaling Groups or Launch Templates"
    echo "4. Lambda console - no rolling-demo functions"
    echo "5. CloudWatch console - no rolling-demo dashboards, alarms, or log groups"
    echo "6. EventBridge console - no rolling-demo rules"
    echo "7. SNS console - no rolling-demo topics"
    echo ""
    print_status "All lab resources have been cleaned up successfully!"
}

# Function to confirm cleanup
confirm_cleanup() {
    echo ""
    print_warning "This will delete ALL resources created by the Rolling Deployment Lab."
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
    print_status "Starting Rolling Deployment Lab Cleanup..."
    
    check_aws_cli
    confirm_cleanup
    
    # Delete stacks in reverse order (health stacks first, then main stacks)
    delete_stack "${STACK_PREFIX}-ecs-health"
    delete_stack "${STACK_PREFIX}-asg-health"
    delete_stack "${STACK_PREFIX}-ecs"
    delete_stack "${STACK_PREFIX}-asg"
    
    # Cleanup additional resources
    cleanup_log_groups
    cleanup_lambda_functions
    cleanup_cloudwatch_alarms
    cleanup_cloudwatch_dashboards
    cleanup_eventbridge_rules
    cleanup_sns_topics
    cleanup_local_files
    
    display_cleanup_summary
    
    print_status "Lab cleanup completed successfully!"
}

# Run main function
main "$@"