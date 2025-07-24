#!/bin/bash

# Advanced CloudFormation Lab - StackSets Management Script
# This script demonstrates StackSet creation, deployment, and management

set -e

# Configuration
STACKSET_NAME="devops-lab-stackset"
TEMPLATE_FILE="../templates/stackset-template.yaml"
ADMIN_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region)

# Default parameters
ENVIRONMENT="dev"
BUCKET_PREFIX="devops-lab"
ENABLE_LOGGING="true"

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

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  create      Create a new StackSet"
    echo "  deploy      Deploy StackSet to accounts/regions"
    echo "  update      Update existing StackSet"
    echo "  delete      Delete StackSet and all instances"
    echo "  status      Show StackSet status and instances"
    echo "  drift       Detect drift in StackSet instances"
    echo ""
    echo "Options:"
    echo "  --accounts ACCOUNT_IDS    Comma-separated list of account IDs"
    echo "  --regions REGIONS         Comma-separated list of regions"
    echo "  --environment ENV         Environment name (default: dev)"
    echo "  --help                    Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 create"
    echo "  $0 deploy --accounts 123456789012 --regions us-east-1,us-west-2"
    echo "  $0 status"
    echo "  $0 delete"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured"
        exit 1
    fi
    
    # Check if template file exists
    if [ ! -f "$TEMPLATE_FILE" ]; then
        print_error "Template file not found: $TEMPLATE_FILE"
        exit 1
    fi
    
    # Check StackSets permissions
    print_status "Checking StackSets permissions..."
    if ! aws cloudformation list-stack-sets &> /dev/null; then
        print_error "Insufficient permissions for StackSets operations"
        print_error "Ensure you have the necessary IAM permissions for CloudFormation StackSets"
        exit 1
    fi
    
    print_success "Prerequisites check completed"
}

# Function to create StackSet
create_stackset() {
    print_status "Creating StackSet: $STACKSET_NAME"
    
    # Check if StackSet already exists
    if aws cloudformation describe-stack-set --stack-set-name "$STACKSET_NAME" &> /dev/null; then
        print_warning "StackSet $STACKSET_NAME already exists"
        return 0
    fi
    
    # Create the StackSet
    aws cloudformation create-stack-set \
        --stack-set-name "$STACKSET_NAME" \
        --template-body file://"$TEMPLATE_FILE" \
        --parameters \
            ParameterKey=Environment,ParameterValue="$ENVIRONMENT" \
            ParameterKey=BucketPrefix,ParameterValue="$BUCKET_PREFIX" \
            ParameterKey=EnableLogging,ParameterValue="$ENABLE_LOGGING" \
        --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
        --description "DevOps Lab StackSet for multi-account deployment" \
        --tags \
            Key=Project,Value=DevOpsLab \
            Key=Environment,Value="$ENVIRONMENT" \
            Key=ManagedBy,Value=StackSet
    
    if [ $? -eq 0 ]; then
        print_success "StackSet created successfully"
    else
        print_error "Failed to create StackSet"
        exit 1
    fi
}

# Function to deploy StackSet instances
deploy_stackset() {
    local accounts="$1"
    local regions="$2"
    
    if [ -z "$accounts" ] || [ -z "$regions" ]; then
        print_error "Both accounts and regions must be specified for deployment"
        print_status "Using current account and region as defaults"
        accounts="$ADMIN_ACCOUNT_ID"
        regions="$REGION"
    fi
    
    print_status "Deploying StackSet instances..."
    print_status "Accounts: $accounts"
    print_status "Regions: $regions"
    
    # Convert comma-separated values to arrays
    IFS=',' read -ra ACCOUNT_ARRAY <<< "$accounts"
    IFS=',' read -ra REGION_ARRAY <<< "$regions"
    
    # Create stack instances
    OPERATION_ID=$(aws cloudformation create-stack-instances \
        --stack-set-name "$STACKSET_NAME" \
        --accounts "${ACCOUNT_ARRAY[@]}" \
        --regions "${REGION_ARRAY[@]}" \
        --parameter-overrides \
            ParameterKey=Environment,ParameterValue="$ENVIRONMENT" \
            ParameterKey=BucketPrefix,ParameterValue="$BUCKET_PREFIX" \
            ParameterKey=EnableLogging,ParameterValue="$ENABLE_LOGGING" \
        --operation-preferences \
            RegionConcurrencyType=PARALLEL,MaxConcurrentPercentage=100 \
        --query 'OperationId' \
        --output text)
    
    print_status "Stack instances creation started with Operation ID: $OPERATION_ID"
    print_status "Waiting for deployment to complete..."
    
    # Wait for operation to complete
    while true; do
        STATUS=$(aws cloudformation describe-stack-set-operation \
            --stack-set-name "$STACKSET_NAME" \
            --operation-id "$OPERATION_ID" \
            --query 'StackSetOperation.Status' \
            --output text)
        
        case $STATUS in
            "SUCCEEDED")
                print_success "StackSet deployment completed successfully"
                break
                ;;
            "FAILED"|"STOPPED")
                print_error "StackSet deployment failed with status: $STATUS"
                show_operation_results "$OPERATION_ID"
                exit 1
                ;;
            "RUNNING")
                print_status "Deployment in progress..."
                sleep 10
                ;;
            *)
                print_status "Current status: $STATUS"
                sleep 10
                ;;
        esac
    done
    
    show_operation_results "$OPERATION_ID"
}

# Function to show operation results
show_operation_results() {
    local operation_id="$1"
    
    print_status "Operation results:"
    aws cloudformation list-stack-set-operation-results \
        --stack-set-name "$STACKSET_NAME" \
        --operation-id "$operation_id" \
        --query 'Summaries[*].[Account,Region,Status,StatusReason]' \
        --output table
}

# Function to update StackSet
update_stackset() {
    print_status "Updating StackSet: $STACKSET_NAME"
    
    OPERATION_ID=$(aws cloudformation update-stack-set \
        --stack-set-name "$STACKSET_NAME" \
        --template-body file://"$TEMPLATE_FILE" \
        --parameters \
            ParameterKey=Environment,ParameterValue="$ENVIRONMENT" \
            ParameterKey=BucketPrefix,ParameterValue="$BUCKET_PREFIX" \
            ParameterKey=EnableLogging,ParameterValue="$ENABLE_LOGGING" \
        --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
        --operation-preferences \
            RegionConcurrencyType=PARALLEL,MaxConcurrentPercentage=100 \
        --query 'OperationId' \
        --output text)
    
    print_status "StackSet update started with Operation ID: $OPERATION_ID"
    print_status "Waiting for update to complete..."
    
    # Wait for operation to complete
    while true; do
        STATUS=$(aws cloudformation describe-stack-set-operation \
            --stack-set-name "$STACKSET_NAME" \
            --operation-id "$OPERATION_ID" \
            --query 'StackSetOperation.Status' \
            --output text)
        
        case $STATUS in
            "SUCCEEDED")
                print_success "StackSet update completed successfully"
                break
                ;;
            "FAILED"|"STOPPED")
                print_error "StackSet update failed with status: $STATUS"
                show_operation_results "$OPERATION_ID"
                exit 1
                ;;
            "RUNNING")
                print_status "Update in progress..."
                sleep 10
                ;;
            *)
                print_status "Current status: $STATUS"
                sleep 10
                ;;
        esac
    done
    
    show_operation_results "$OPERATION_ID"
}

# Function to show StackSet status
show_status() {
    print_status "StackSet Status:"
    
    # Show StackSet details
    aws cloudformation describe-stack-set \
        --stack-set-name "$STACKSET_NAME" \
        --query 'StackSet.[StackSetName,Status,Description]' \
        --output table
    
    echo ""
    print_status "Stack Instances:"
    aws cloudformation list-stack-instances \
        --stack-set-name "$STACKSET_NAME" \
        --query 'Summaries[*].[Account,Region,Status,StatusReason]' \
        --output table
    
    echo ""
    print_status "Recent Operations:"
    aws cloudformation list-stack-set-operations \
        --stack-set-name "$STACKSET_NAME" \
        --max-results 5 \
        --query 'Summaries[*].[OperationId,Action,Status,CreationTimestamp]' \
        --output table
}

# Function to detect drift
detect_drift() {
    print_status "Starting drift detection for StackSet instances..."
    
    # Get all stack instances
    INSTANCES=$(aws cloudformation list-stack-instances \
        --stack-set-name "$STACKSET_NAME" \
        --query 'Summaries[*].[Account,Region]' \
        --output text)
    
    if [ -z "$INSTANCES" ]; then
        print_warning "No stack instances found"
        return 0
    fi
    
    # Start drift detection for each instance
    while IFS=$'\t' read -r account region; do
        print_status "Detecting drift for account $account in region $region..."
        
        OPERATION_ID=$(aws cloudformation detect-stack-set-drift \
            --stack-set-name "$STACKSET_NAME" \
            --query 'OperationId' \
            --output text)
        
        print_status "Drift detection started with Operation ID: $OPERATION_ID"
        
        # Wait for drift detection to complete
        while true; do
            STATUS=$(aws cloudformation describe-stack-set-operation \
                --stack-set-name "$STACKSET_NAME" \
                --operation-id "$OPERATION_ID" \
                --query 'StackSetOperation.Status' \
                --output text)
            
            if [ "$STATUS" = "SUCCEEDED" ]; then
                print_success "Drift detection completed"
                break
            elif [ "$STATUS" = "FAILED" ]; then
                print_error "Drift detection failed"
                break
            else
                sleep 5
            fi
        done
        
        # Show drift results
        aws cloudformation list-stack-set-operation-results \
            --stack-set-name "$STACKSET_NAME" \
            --operation-id "$OPERATION_ID" \
            --query 'Summaries[*].[Account,Region,Status,StatusReason]' \
            --output table
        
    done <<< "$INSTANCES"
}

# Function to delete StackSet
delete_stackset() {
    print_status "Deleting StackSet: $STACKSET_NAME"
    
    # First, delete all stack instances
    print_status "Deleting all stack instances..."
    
    INSTANCES=$(aws cloudformation list-stack-instances \
        --stack-set-name "$STACKSET_NAME" \
        --query 'Summaries[*].[Account,Region]' \
        --output text)
    
    if [ -n "$INSTANCES" ]; then
        # Get unique accounts and regions
        ACCOUNTS=$(echo "$INSTANCES" | cut -f1 | sort -u | tr '\n' ',' | sed 's/,$//')
        REGIONS=$(echo "$INSTANCES" | cut -f2 | sort -u | tr '\n' ',' | sed 's/,$//')
        
        IFS=',' read -ra ACCOUNT_ARRAY <<< "$ACCOUNTS"
        IFS=',' read -ra REGION_ARRAY <<< "$REGIONS"
        
        OPERATION_ID=$(aws cloudformation delete-stack-instances \
            --stack-set-name "$STACKSET_NAME" \
            --accounts "${ACCOUNT_ARRAY[@]}" \
            --regions "${REGION_ARRAY[@]}" \
            --retain-stacks false \
            --operation-preferences \
                RegionConcurrencyType=PARALLEL,MaxConcurrentPercentage=100 \
            --query 'OperationId' \
            --output text)
        
        print_status "Stack instances deletion started with Operation ID: $OPERATION_ID"
        print_status "Waiting for deletion to complete..."
        
        # Wait for operation to complete
        while true; do
            STATUS=$(aws cloudformation describe-stack-set-operation \
                --stack-set-name "$STACKSET_NAME" \
                --operation-id "$OPERATION_ID" \
                --query 'StackSetOperation.Status' \
                --output text)
            
            case $STATUS in
                "SUCCEEDED")
                    print_success "Stack instances deleted successfully"
                    break
                    ;;
                "FAILED"|"STOPPED")
                    print_error "Stack instances deletion failed with status: $STATUS"
                    show_operation_results "$OPERATION_ID"
                    exit 1
                    ;;
                "RUNNING")
                    print_status "Deletion in progress..."
                    sleep 10
                    ;;
                *)
                    print_status "Current status: $STATUS"
                    sleep 10
                    ;;
            esac
        done
    else
        print_status "No stack instances found"
    fi
    
    # Delete the StackSet
    print_status "Deleting StackSet..."
    aws cloudformation delete-stack-set --stack-set-name "$STACKSET_NAME"
    
    print_success "StackSet deletion completed"
}

# Main function
main() {
    local command="$1"
    shift
    
    # Parse command line arguments
    local accounts=""
    local regions=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --accounts)
                accounts="$2"
                shift 2
                ;;
            --regions)
                regions="$2"
                shift 2
                ;;
            --environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Execute command
    case $command in
        "create")
            check_prerequisites
            create_stackset
            ;;
        "deploy")
            check_prerequisites
            deploy_stackset "$accounts" "$regions"
            ;;
        "update")
            check_prerequisites
            update_stackset
            ;;
        "status")
            check_prerequisites
            show_status
            ;;
        "drift")
            check_prerequisites
            detect_drift
            ;;
        "delete")
            check_prerequisites
            delete_stackset
            ;;
        *)
            print_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Check if no arguments provided
if [ $# -eq 0 ]; then
    show_usage
    exit 1
fi

# Run main function
main "$@"