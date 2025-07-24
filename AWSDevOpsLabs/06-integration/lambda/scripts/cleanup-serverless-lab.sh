#!/bin/bash

# Serverless Integration Lab Cleanup Script
# This script safely removes all resources created by the serverless integration lab

set -e

# Configuration
STACK_PREFIX="serverless-integration-lab"
STEP_FUNCTIONS_STACK="${STACK_PREFIX}-step-functions"
EVENTBRIDGE_STACK="${STACK_PREFIX}-eventbridge"
API_GATEWAY_STACK="${STACK_PREFIX}-api-gateway"
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

# Function to stop running Step Functions executions
stop_step_functions_executions() {
    print_status "Stopping running Step Functions executions..."
    
    # Get state machine ARN from stack if it exists
    if stack_exists "$STEP_FUNCTIONS_STACK"; then
        local state_machine_arn=$(aws cloudformation describe-stacks \
            --stack-name "$STEP_FUNCTIONS_STACK" \
            --region "$REGION" \
            --query "Stacks[0].Outputs[?OutputKey=='StateMachineArn'].OutputValue" \
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

# Function to clean up CloudWatch resources
cleanup_cloudwatch_resources() {
    print_status "Cleaning up CloudWatch resources..."
    
    # Delete custom log groups
    local log_groups=(
        "/aws/stepfunctions/serverless-integration-workflow"
        "/aws/lambda/serverless-integration-workflow-data-validation"
        "/aws/lambda/serverless-integration-workflow-data-processing"
        "/aws/lambda/serverless-integration-workflow-notification"
        "/aws/lambda/serverless-integration-workflow-error-handler"
        "/aws/lambda/order-processor"
        "/aws/lambda/inventory-updater"
        "/aws/lambda/payment-processor"
        "/aws/lambda/notification-service"
        "/aws/lambda/event-generator"
        "/aws/lambda/token-authorizer"
        "/aws/lambda/request-authorizer"
        "/aws/lambda/public-endpoint"
        "/aws/lambda/protected-endpoint"
        "/aws/lambda/admin-endpoint"
        "/aws/lambda/data-processor-endpoint"
    )
    
    for log_group in "${log_groups[@]}"; do
        if aws logs describe-log-groups --log-group-name-prefix "$log_group" --region "$REGION" --query 'logGroups[0]' --output text > /dev/null 2>&1; then
            print_status "Deleting log group: $log_group"
            aws logs delete-log-group --log-group-name "$log_group" --region "$REGION" || true
        fi
    done
    
    print_success "CloudWatch resources cleanup completed"
}

# Function to clean up EventBridge resources
cleanup_eventbridge_resources() {
    print_status "Cleaning up EventBridge resources..."
    
    # Check if EventBridge stack exists and get event bus name
    if stack_exists "$EVENTBRIDGE_STACK"; then
        local event_bus_name=$(aws cloudformation describe-stacks \
            --stack-name "$EVENTBRIDGE_STACK" \
            --region "$REGION" \
            --query "Stacks[0].Outputs[?OutputKey=='CustomEventBusName'].OutputValue" \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$event_bus_name" ] && [ "$event_bus_name" != "None" ]; then
            print_status "Found custom event bus: $event_bus_name"
            
            # List and delete rules on the custom event bus
            local rules=$(aws events list-rules \
                --event-bus-name "$event_bus_name" \
                --region "$REGION" \
                --query 'Rules[].Name' \
                --output text 2>/dev/null || echo "")
            
            if [ -n "$rules" ] && [ "$rules" != "None" ]; then
                for rule in $rules; do
                    print_status "Removing targets from rule: $rule"
                    # Remove targets first
                    local targets=$(aws events list-targets-by-rule \
                        --rule "$rule" \
                        --event-bus-name "$event_bus_name" \
                        --region "$REGION" \
                        --query 'Targets[].Id' \
                        --output text 2>/dev/null || echo "")
                    
                    if [ -n "$targets" ] && [ "$targets" != "None" ]; then
                        aws events remove-targets \
                            --rule "$rule" \
                            --event-bus-name "$event_bus_name" \
                            --ids $targets \
                            --region "$REGION" || true
                    fi
                done
            fi
        fi
    fi
    
    print_success "EventBridge resources cleanup completed"
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
    
    # Check for Lambda functions
    local lambda_functions=$(aws lambda list-functions \
        --region "$REGION" \
        --query 'Functions[?contains(FunctionName, `serverless-integration`) || contains(FunctionName, `order-processor`) || contains(FunctionName, `inventory-updater`) || contains(FunctionName, `payment-processor`) || contains(FunctionName, `notification-service`) || contains(FunctionName, `event-generator`) || contains(FunctionName, `token-authorizer`) || contains(FunctionName, `request-authorizer`) || contains(FunctionName, `public-endpoint`) || contains(FunctionName, `protected-endpoint`) || contains(FunctionName, `admin-endpoint`) || contains(FunctionName, `data-processor-endpoint`)].FunctionName' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$lambda_functions" ] && [ "$lambda_functions" != "None" ]; then
        print_warning "Remaining Lambda functions found:"
        echo "$lambda_functions"
        found_resources=true
    fi
    
    # Check for DynamoDB tables
    local dynamodb_tables=$(aws dynamodb list-tables \
        --region "$REGION" \
        --query 'TableNames[?contains(@, `serverless-integration`) || contains(@, `serverless-inventory`) || contains(@, `api-gateway-data`)]' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$dynamodb_tables" ] && [ "$dynamodb_tables" != "None" ]; then
        print_warning "Remaining DynamoDB tables found:"
        echo "$dynamodb_tables"
        found_resources=true
    fi
    
    # Check for Step Functions state machines
    local state_machines=$(aws stepfunctions list-state-machines \
        --region "$REGION" \
        --query 'stateMachines[?contains(name, `serverless-integration`)].name' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$state_machines" ] && [ "$state_machines" != "None" ]; then
        print_warning "Remaining Step Functions state machines found:"
        echo "$state_machines"
        found_resources=true
    fi
    
    # Check for API Gateway APIs
    local api_gateways=$(aws apigateway get-rest-apis \
        --region "$REGION" \
        --query 'items[?contains(name, `serverless-integration`)].name' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$api_gateways" ] && [ "$api_gateways" != "None" ]; then
        print_warning "Remaining API Gateway APIs found:"
        echo "$api_gateways"
        found_resources=true
    fi
    
    # Check for EventBridge custom event buses
    local event_buses=$(aws events list-event-buses \
        --region "$REGION" \
        --query 'EventBuses[?contains(Name, `serverless-integration`)].Name' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$event_buses" ] && [ "$event_buses" != "None" ]; then
        print_warning "Remaining EventBridge event buses found:"
        echo "$event_buses"
        found_resources=true
    fi
    
    if [ "$found_resources" = false ]; then
        print_success "No remaining lab resources found"
    else
        print_warning "Some resources may require manual cleanup"
        print_warning "Check the AWS Console for any remaining resources with 'serverless-integration' in the name"
    fi
}

# Function to confirm deletion
confirm_deletion() {
    echo
    print_warning "This will delete ALL resources created by the Serverless Integration Lab"
    print_warning "This action cannot be undone!"
    echo
    print_status "The following stacks will be deleted:"
    echo "  • $API_GATEWAY_STACK"
    echo "  • $EVENTBRIDGE_STACK"
    echo "  • $STEP_FUNCTIONS_STACK"
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
    echo "Serverless Integration Lab Cleanup"
    echo "=========================================="
    echo
    
    check_aws_cli
    
    # Check if any stacks exist
    local stacks_exist=false
    for stack in "$API_GATEWAY_STACK" "$EVENTBRIDGE_STACK" "$STEP_FUNCTIONS_STACK"; do
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
    
    # Stop running executions first
    stop_step_functions_executions
    
    # Delete stacks in reverse order (dependencies)
    local cleanup_success=true
    
    # Delete API Gateway stack first
    if stack_exists "$API_GATEWAY_STACK"; then
        if ! delete_stack_with_retry "$API_GATEWAY_STACK"; then
            cleanup_success=false
        fi
    fi
    
    # Delete EventBridge stack
    if stack_exists "$EVENTBRIDGE_STACK"; then
        # Clean up EventBridge resources before deleting stack
        cleanup_eventbridge_resources
        
        if ! delete_stack_with_retry "$EVENTBRIDGE_STACK"; then
            cleanup_success=false
        fi
    fi
    
    # Delete Step Functions stack last
    if stack_exists "$STEP_FUNCTIONS_STACK"; then
        if ! delete_stack_with_retry "$STEP_FUNCTIONS_STACK"; then
            cleanup_success=false
        fi
    fi
    
    # Clean up additional resources
    cleanup_cloudwatch_resources
    
    # Final check for remaining resources
    list_remaining_resources
    
    if [ "$cleanup_success" = true ]; then
        print_success "Serverless Integration Lab cleanup completed successfully!"
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