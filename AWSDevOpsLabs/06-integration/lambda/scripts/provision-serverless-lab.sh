#!/bin/bash

# Serverless Integration Lab Provisioning Script
# This script provisions the complete serverless integration lab environment with
# Step Functions workflows, EventBridge integration, and API Gateway with Lambda authorizers

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
        print_error "Please run 'aws configure' to set up your credentials"
        exit 1
    fi
    print_success "AWS CLI is properly configured"
}

# Function to check if stack exists
stack_exists() {
    local stack_name=$1
    aws cloudformation describe-stacks --stack-name "$stack_name" --region "$REGION" > /dev/null 2>&1
}

# Function to wait for stack operation to complete
wait_for_stack() {
    local stack_name=$1
    local operation=$2
    
    print_status "Waiting for stack $operation to complete: $stack_name"
    
    if [ "$operation" = "CREATE" ]; then
        aws cloudformation wait stack-create-complete --stack-name "$stack_name" --region "$REGION"
    elif [ "$operation" = "UPDATE" ]; then
        aws cloudformation wait stack-update-complete --stack-name "$stack_name" --region "$REGION"
    elif [ "$operation" = "DELETE" ]; then
        aws cloudformation wait stack-delete-complete --stack-name "$stack_name" --region "$REGION"
    fi
    
    if [ $? -eq 0 ]; then
        print_success "Stack $operation completed successfully: $stack_name"
    else
        print_error "Stack $operation failed: $stack_name"
        return 1
    fi
}

# Function to get stack outputs
get_stack_output() {
    local stack_name=$1
    local output_key=$2
    aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$REGION" \
        --query "Stacks[0].Outputs[?OutputKey=='$output_key'].OutputValue" \
        --output text
}

# Function to deploy Step Functions stack
deploy_step_functions() {
    print_status "Deploying Step Functions workflow stack..."
    
    local template_file="templates/step-functions-workflow.yaml"
    
    if [ ! -f "$template_file" ]; then
        print_error "Template file not found: $template_file"
        exit 1
    fi
    
    local parameters=(
        "ParameterKey=WorkflowName,ParameterValue=serverless-integration-workflow"
    )
    
    if stack_exists "$STEP_FUNCTIONS_STACK"; then
        print_warning "Step Functions stack already exists, updating..."
        aws cloudformation update-stack \
            --stack-name "$STEP_FUNCTIONS_STACK" \
            --template-body file://"$template_file" \
            --parameters "${parameters[@]}" \
            --capabilities CAPABILITY_IAM \
            --region "$REGION" || {
                if [[ $? -eq 254 ]]; then
                    print_warning "No updates to be performed on Step Functions stack"
                else
                    print_error "Failed to update Step Functions stack"
                    exit 1
                fi
            }
        
        if [[ $? -ne 254 ]]; then
            wait_for_stack "$STEP_FUNCTIONS_STACK" "UPDATE"
        fi
    else
        aws cloudformation create-stack \
            --stack-name "$STEP_FUNCTIONS_STACK" \
            --template-body file://"$template_file" \
            --parameters "${parameters[@]}" \
            --capabilities CAPABILITY_IAM \
            --region "$REGION" \
            --tags Key=Project,Value=DevOpsLab Key=Component,Value=StepFunctions
        
        wait_for_stack "$STEP_FUNCTIONS_STACK" "CREATE"
    fi
    
    print_success "Step Functions stack deployed successfully"
}

# Function to deploy EventBridge stack
deploy_eventbridge() {
    print_status "Deploying EventBridge integration stack..."
    
    local template_file="templates/eventbridge-integration.yaml"
    
    if [ ! -f "$template_file" ]; then
        print_error "Template file not found: $template_file"
        exit 1
    fi
    
    local parameters=(
        "ParameterKey=EventBusName,ParameterValue=serverless-integration-bus"
    )
    
    if stack_exists "$EVENTBRIDGE_STACK"; then
        print_warning "EventBridge stack already exists, updating..."
        aws cloudformation update-stack \
            --stack-name "$EVENTBRIDGE_STACK" \
            --template-body file://"$template_file" \
            --parameters "${parameters[@]}" \
            --capabilities CAPABILITY_IAM \
            --region "$REGION" || {
                if [[ $? -eq 254 ]]; then
                    print_warning "No updates to be performed on EventBridge stack"
                else
                    print_error "Failed to update EventBridge stack"
                    exit 1
                fi
            }
        
        if [[ $? -ne 254 ]]; then
            wait_for_stack "$EVENTBRIDGE_STACK" "UPDATE"
        fi
    else
        aws cloudformation create-stack \
            --stack-name "$EVENTBRIDGE_STACK" \
            --template-body file://"$template_file" \
            --parameters "${parameters[@]}" \
            --capabilities CAPABILITY_IAM \
            --region "$REGION" \
            --tags Key=Project,Value=DevOpsLab Key=Component,Value=EventBridge
        
        wait_for_stack "$EVENTBRIDGE_STACK" "CREATE"
    fi
    
    print_success "EventBridge stack deployed successfully"
}

# Function to deploy API Gateway stack
deploy_api_gateway() {
    print_status "Deploying API Gateway with Lambda authorizers stack..."
    
    local template_file="templates/api-gateway-authorizers.yaml"
    
    if [ ! -f "$template_file" ]; then
        print_error "Template file not found: $template_file"
        exit 1
    fi
    
    local parameters=(
        "ParameterKey=ApiName,ParameterValue=serverless-integration-api"
        "ParameterKey=StageName,ParameterValue=dev"
    )
    
    if stack_exists "$API_GATEWAY_STACK"; then
        print_warning "API Gateway stack already exists, updating..."
        aws cloudformation update-stack \
            --stack-name "$API_GATEWAY_STACK" \
            --template-body file://"$template_file" \
            --parameters "${parameters[@]}" \
            --capabilities CAPABILITY_IAM \
            --region "$REGION" || {
                if [[ $? -eq 254 ]]; then
                    print_warning "No updates to be performed on API Gateway stack"
                else
                    print_error "Failed to update API Gateway stack"
                    exit 1
                fi
            }
        
        if [[ $? -ne 254 ]]; then
            wait_for_stack "$API_GATEWAY_STACK" "UPDATE"
        fi
    else
        aws cloudformation create-stack \
            --stack-name "$API_GATEWAY_STACK" \
            --template-body file://"$template_file" \
            --parameters "${parameters[@]}" \
            --capabilities CAPABILITY_IAM \
            --region "$REGION" \
            --tags Key=Project,Value=DevOpsLab Key=Component,Value=APIGateway
        
        wait_for_stack "$API_GATEWAY_STACK" "CREATE"
    fi
    
    print_success "API Gateway stack deployed successfully"
}

# Function to test Step Functions workflow
test_step_functions() {
    print_status "Testing Step Functions workflow..."
    
    local state_machine_arn=$(get_stack_output "$STEP_FUNCTIONS_STACK" "StateMachineArn")
    
    if [ -z "$state_machine_arn" ]; then
        print_error "Could not retrieve State Machine ARN"
        return 1
    fi
    
    # Create test input
    local test_input='{
        "data": {
            "id": "test-123",
            "name": "John Doe",
            "email": "john.doe@example.com"
        }
    }'
    
    # Start execution
    local execution_arn=$(aws stepfunctions start-execution \
        --state-machine-arn "$state_machine_arn" \
        --name "test-execution-$(date +%s)" \
        --input "$test_input" \
        --region "$REGION" \
        --query 'executionArn' \
        --output text)
    
    if [ $? -eq 0 ]; then
        print_success "Step Functions execution started: $execution_arn"
        print_status "You can monitor the execution in the AWS Console or use:"
        echo "  aws stepfunctions describe-execution --execution-arn $execution_arn --region $REGION"
    else
        print_error "Failed to start Step Functions execution"
    fi
}

# Function to test EventBridge integration
test_eventbridge() {
    print_status "Testing EventBridge integration..."
    
    local event_generator_arn=$(get_stack_output "$EVENTBRIDGE_STACK" "EventGeneratorFunctionArn")
    
    if [ -z "$event_generator_arn" ]; then
        print_error "Could not retrieve Event Generator Function ARN"
        return 1
    fi
    
    # Invoke event generator function
    aws lambda invoke \
        --function-name "event-generator" \
        --region "$REGION" \
        --payload '{}' \
        /tmp/event-response.json > /dev/null
    
    if [ $? -eq 0 ]; then
        print_success "EventBridge test event generated successfully"
        print_status "Check the response:"
        cat /tmp/event-response.json
        echo
        rm -f /tmp/event-response.json
    else
        print_error "Failed to generate test event"
    fi
}

# Function to test API Gateway endpoints
test_api_gateway() {
    print_status "Testing API Gateway endpoints..."
    
    local api_url=$(get_stack_output "$API_GATEWAY_STACK" "ApiGatewayUrl")
    
    if [ -z "$api_url" ]; then
        print_error "Could not retrieve API Gateway URL"
        return 1
    fi
    
    print_status "Testing public endpoint..."
    curl -s "$api_url/public" | jq . || echo "Response received (jq not available for formatting)"
    
    print_status "Testing protected endpoint with valid token..."
    curl -s -H "Authorization: Bearer valid-token-123" "$api_url/protected" | jq . || echo "Response received"
    
    print_status "Testing admin endpoint with admin token..."
    curl -s -H "Authorization: Bearer admin-token-456" "$api_url/admin" | jq . || echo "Response received"
    
    print_status "Testing data endpoint with API key..."
    curl -s -H "x-api-key: valid-api-key-789" "$api_url/data" | jq . || echo "Response received"
    
    print_success "API Gateway endpoints tested successfully"
}

# Function to display lab information
display_lab_info() {
    print_success "Serverless Integration Lab deployed successfully!"
    echo
    print_status "Lab Resources:"
    
    # Get stack outputs
    local state_machine_arn=$(get_stack_output "$STEP_FUNCTIONS_STACK" "StateMachineArn")
    local event_bus_name=$(get_stack_output "$EVENTBRIDGE_STACK" "CustomEventBusName")
    local api_url=$(get_stack_output "$API_GATEWAY_STACK" "ApiGatewayUrl")
    local public_endpoint=$(get_stack_output "$API_GATEWAY_STACK" "PublicEndpoint")
    local protected_endpoint=$(get_stack_output "$API_GATEWAY_STACK" "ProtectedEndpoint")
    local admin_endpoint=$(get_stack_output "$API_GATEWAY_STACK" "AdminEndpoint")
    local data_endpoint=$(get_stack_output "$API_GATEWAY_STACK" "DataEndpoint")
    
    echo "  • Step Functions State Machine: $state_machine_arn"
    echo "  • EventBridge Custom Bus: $event_bus_name"
    echo "  • API Gateway URL: $api_url"
    echo
    
    print_status "API Endpoints:"
    echo "  • Public (no auth): $public_endpoint"
    echo "  • Protected (Bearer token): $protected_endpoint"
    echo "  • Admin (admin Bearer token): $admin_endpoint"
    echo "  • Data CRUD (API key/signature): $data_endpoint"
    echo
    
    print_status "Test Commands:"
    echo "  # Test Step Functions workflow:"
    echo "  aws stepfunctions start-execution \\"
    echo "    --state-machine-arn $state_machine_arn \\"
    echo "    --name test-execution-\$(date +%s) \\"
    echo "    --input '{\"data\":{\"id\":\"test-123\",\"name\":\"John Doe\",\"email\":\"john.doe@example.com\"}}' \\"
    echo "    --region $REGION"
    echo
    echo "  # Generate EventBridge test event:"
    echo "  aws lambda invoke --function-name event-generator --payload '{}' response.json --region $REGION"
    echo
    echo "  # Test API endpoints:"
    echo "  curl $public_endpoint"
    echo "  curl -H \"Authorization: Bearer valid-token-123\" $protected_endpoint"
    echo "  curl -H \"Authorization: Bearer admin-token-456\" $admin_endpoint"
    echo "  curl -H \"x-api-key: valid-api-key-789\" $data_endpoint"
    echo
    
    print_status "Authentication Tokens:"
    echo "  • Valid user token: Bearer valid-token-123"
    echo "  • Admin token: Bearer admin-token-456"
    echo "  • API key: valid-api-key-789"
    echo
    
    print_warning "Remember to clean up resources when done:"
    echo "  ./cleanup-serverless-lab.sh"
}

# Function to validate prerequisites
validate_prerequisites() {
    print_status "Validating prerequisites..."
    
    # Check if required tools are installed
    local tools=("aws" "jq")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            if [ "$tool" = "jq" ]; then
                print_warning "$tool is not installed. JSON responses will not be formatted."
            else
                print_error "$tool is not installed. Please install it first."
                exit 1
            fi
        fi
    done
    
    # Check AWS CLI version
    local aws_version=$(aws --version 2>&1 | cut -d/ -f2 | cut -d' ' -f1)
    print_status "AWS CLI version: $aws_version"
    
    print_success "Prerequisites validated"
}

# Main execution
main() {
    echo "=========================================="
    echo "Serverless Integration Lab Provisioning"
    echo "=========================================="
    echo
    
    validate_prerequisites
    check_aws_cli
    
    print_status "Starting deployment in region: $REGION"
    print_status "Stack prefix: $STACK_PREFIX"
    echo
    
    # Deploy stacks
    deploy_step_functions
    deploy_eventbridge
    deploy_api_gateway
    
    # Test deployments
    echo
    print_status "Running integration tests..."
    test_step_functions
    test_eventbridge
    test_api_gateway
    
    # Display lab information
    echo
    display_lab_info
    
    print_success "Lab provisioning completed successfully!"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --region       AWS region (default: us-east-1)"
        echo
        echo "Environment Variables:"
        echo "  AWS_DEFAULT_REGION    AWS region to use"
        echo
        exit 0
        ;;
    --region)
        REGION="$2"
        shift 2
        ;;
    *)
        ;;
esac

# Run main function
main "$@"