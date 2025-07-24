#!/bin/bash

# IAM Best Practices Lab Provisioning Script
# This script provisions the IAM lab environment with least-privilege policies,
# cross-account roles, and Access Analyzer integration

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

# Function to check if AWS CLI is configured
check_aws_cli() {
    print_status "Checking AWS CLI configuration..."
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI is not configured or credentials are invalid."
        exit 1
    fi
    
    print_success "AWS CLI is properly configured"
}

# Function to check required permissions
check_permissions() {
    print_status "Checking required permissions..."
    
    # Check IAM permissions
    if ! aws iam list-roles --max-items 1 &> /dev/null; then
        print_error "Insufficient IAM permissions. You need IAM full access."
        exit 1
    fi
    
    # Check CloudFormation permissions
    if ! aws cloudformation list-stacks --max-items 1 &> /dev/null; then
        print_error "Insufficient CloudFormation permissions."
        exit 1
    fi
    
    # Check S3 permissions
    if ! aws s3 ls &> /dev/null; then
        print_error "Insufficient S3 permissions."
        exit 1
    fi
    
    print_success "Required permissions verified"
}

# Function to create test S3 bucket
create_test_bucket() {
    print_status "Creating test S3 bucket: ${BUCKET_NAME}"
    
    if aws s3 ls "s3://${BUCKET_NAME}" &> /dev/null; then
        print_warning "Bucket ${BUCKET_NAME} already exists"
    else
        # Create bucket with appropriate region configuration
        if [ "$REGION" = "us-east-1" ]; then
            aws s3 mb "s3://${BUCKET_NAME}"
        else
            aws s3 mb "s3://${BUCKET_NAME}" --region "$REGION"
        fi
        
        # Upload test file
        echo "This is a test file for IAM permissions validation" > /tmp/test-file.txt
        aws s3 cp /tmp/test-file.txt "s3://${BUCKET_NAME}/"
        rm /tmp/test-file.txt
        
        print_success "Test bucket created and test file uploaded"
    fi
}

# Function to deploy CloudFormation stack
deploy_stack() {
    local template_file=$1
    local stack_name=$2
    local parameters=$3
    
    print_status "Deploying stack: ${stack_name}"
    
    # Check if stack exists
    if aws cloudformation describe-stacks --stack-name "$stack_name" &> /dev/null; then
        print_status "Stack exists, updating..."
        aws cloudformation update-stack \
            --stack-name "$stack_name" \
            --template-body "file://$template_file" \
            --parameters "$parameters" \
            --capabilities CAPABILITY_NAMED_IAM \
            --region "$REGION" || {
                if [[ $? -eq 255 ]]; then
                    print_warning "No updates to perform for stack $stack_name"
                else
                    print_error "Failed to update stack $stack_name"
                    return 1
                fi
            }
    else
        print_status "Creating new stack..."
        aws cloudformation create-stack \
            --stack-name "$stack_name" \
            --template-body "file://$template_file" \
            --parameters "$parameters" \
            --capabilities CAPABILITY_NAMED_IAM \
            --region "$REGION"
    fi
    
    # Wait for stack operation to complete
    print_status "Waiting for stack operation to complete..."
    aws cloudformation wait stack-create-complete --stack-name "$stack_name" --region "$REGION" 2>/dev/null || \
    aws cloudformation wait stack-update-complete --stack-name "$stack_name" --region "$REGION" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        print_success "Stack $stack_name deployed successfully"
    else
        print_error "Stack $stack_name deployment failed"
        return 1
    fi
}

# Function to deploy least-privilege policies
deploy_least_privilege_policies() {
    local stack_name="${STACK_NAME_PREFIX}-policies"
    local template_file="templates/least-privilege-policies.yaml"
    
    if [ ! -f "$template_file" ]; then
        print_error "Template file not found: $template_file"
        return 1
    fi
    
    local parameters="ParameterKey=BucketName,ParameterValue=iam-lab-test-bucket ParameterKey=AccountId,ParameterValue=${ACCOUNT_ID}"
    
    deploy_stack "$template_file" "$stack_name" "$parameters"
}

# Function to deploy cross-account roles
deploy_cross_account_roles() {
    local stack_name="${STACK_NAME_PREFIX}-cross-account"
    local template_file="templates/cross-account-roles.yaml"
    
    if [ ! -f "$template_file" ]; then
        print_error "Template file not found: $template_file"
        return 1
    fi
    
    # Prompt for trusted account ID
    read -p "Enter trusted AWS Account ID for cross-account access (or press Enter to use current account): " trusted_account
    if [ -z "$trusted_account" ]; then
        trusted_account=$ACCOUNT_ID
    fi
    
    # Generate external ID
    external_id="iam-lab-external-id-$(date +%s)"
    
    local parameters="ParameterKey=TrustedAccountId,ParameterValue=${trusted_account} ParameterKey=ExternalId,ParameterValue=${external_id} ParameterKey=RequireMFA,ParameterValue=true"
    
    deploy_stack "$template_file" "$stack_name" "$parameters"
    
    # Save external ID for later use
    echo "$external_id" > /tmp/iam-lab-external-id.txt
    print_success "External ID saved to /tmp/iam-lab-external-id.txt: $external_id"
}

# Function to deploy Access Analyzer integration
deploy_access_analyzer() {
    local stack_name="${STACK_NAME_PREFIX}-access-analyzer"
    local template_file="templates/access-analyzer-integration.yaml"
    
    if [ ! -f "$template_file" ]; then
        print_error "Template file not found: $template_file"
        return 1
    fi
    
    # Prompt for notification email
    read -p "Enter email address for Access Analyzer notifications: " notification_email
    if [ -z "$notification_email" ]; then
        notification_email="admin@example.com"
        print_warning "Using default email: $notification_email"
    fi
    
    local parameters="ParameterKey=NotificationEmail,ParameterValue=${notification_email} ParameterKey=EnableArchiveRules,ParameterValue=true"
    
    deploy_stack "$template_file" "$stack_name" "$parameters"
}

# Function to create test users
create_test_users() {
    print_status "Creating test users for policy validation..."
    
    # Get policy ARNs from CloudFormation outputs
    local dev_policy_arn=$(aws cloudformation describe-stacks \
        --stack-name "${STACK_NAME_PREFIX}-policies" \
        --query 'Stacks[0].Outputs[?OutputKey==`DeveloperPolicyArn`].OutputValue' \
        --output text \
        --region "$REGION")
    
    local ops_policy_arn=$(aws cloudformation describe-stacks \
        --stack-name "${STACK_NAME_PREFIX}-policies" \
        --query 'Stacks[0].Outputs[?OutputKey==`OperationsPolicyArn`].OutputValue' \
        --output text \
        --region "$REGION")
    
    local audit_policy_arn=$(aws cloudformation describe-stacks \
        --stack-name "${STACK_NAME_PREFIX}-policies" \
        --query 'Stacks[0].Outputs[?OutputKey==`AuditPolicyArn`].OutputValue' \
        --output text \
        --region "$REGION")
    
    # Create test users
    local users=("test-dev-user" "test-ops-user" "test-audit-user")
    local policies=("$dev_policy_arn" "$ops_policy_arn" "$audit_policy_arn")
    
    for i in "${!users[@]}"; do
        local user="${users[$i]}"
        local policy="${policies[$i]}"
        
        # Create user if it doesn't exist
        if ! aws iam get-user --user-name "$user" &> /dev/null; then
            aws iam create-user --user-name "$user"
            print_success "Created user: $user"
        else
            print_warning "User $user already exists"
        fi
        
        # Attach policy
        aws iam attach-user-policy --user-name "$user" --policy-arn "$policy"
        print_success "Attached policy to user: $user"
    done
}

# Function to run policy simulations
run_policy_simulations() {
    print_status "Running policy simulations for validation..."
    
    local users=("test-dev-user" "test-ops-user" "test-audit-user")
    
    for user in "${users[@]}"; do
        print_status "Testing permissions for user: $user"
        
        # Test S3 GetObject permission
        local result=$(aws iam simulate-principal-policy \
            --policy-source-arn "arn:aws:iam::${ACCOUNT_ID}:user/${user}" \
            --action-names s3:GetObject \
            --resource-arns "arn:aws:s3:::${BUCKET_NAME}/test-file.txt" \
            --query 'EvaluationResults[0].EvalDecision' \
            --output text)
        
        echo "  S3 GetObject: $result"
        
        # Test EC2 TerminateInstances permission (should be denied for dev/audit)
        result=$(aws iam simulate-principal-policy \
            --policy-source-arn "arn:aws:iam::${ACCOUNT_ID}:user/${user}" \
            --action-names ec2:TerminateInstances \
            --resource-arns "*" \
            --query 'EvaluationResults[0].EvalDecision' \
            --output text)
        
        echo "  EC2 TerminateInstances: $result"
        echo
    done
}

# Function to display lab information
display_lab_info() {
    print_success "IAM Best Practices Lab provisioned successfully!"
    echo
    echo "=== Lab Resources ==="
    echo "Test S3 Bucket: $BUCKET_NAME"
    echo "CloudFormation Stacks:"
    echo "  - ${STACK_NAME_PREFIX}-policies"
    echo "  - ${STACK_NAME_PREFIX}-cross-account"
    echo "  - ${STACK_NAME_PREFIX}-access-analyzer"
    echo
    echo "Test Users Created:"
    echo "  - test-dev-user (Developer permissions)"
    echo "  - test-ops-user (Operations permissions)"
    echo "  - test-audit-user (Audit permissions)"
    echo
    echo "=== Next Steps ==="
    echo "1. Review the lab guide: lab-guide.md"
    echo "2. Access AWS Console to explore IAM resources"
    echo "3. Check Access Analyzer findings: https://console.aws.amazon.com/access-analyzer/"
    echo "4. Monitor CloudWatch dashboard for security metrics"
    echo
    echo "=== Important Notes ==="
    echo "- External ID for cross-account access saved to: /tmp/iam-lab-external-id.txt"
    echo "- Remember to run cleanup script when finished to avoid charges"
    echo "- Test users are created for demonstration only - delete after lab completion"
    echo
}

# Function to validate deployment
validate_deployment() {
    print_status "Validating deployment..."
    
    # Check if stacks are in CREATE_COMPLETE or UPDATE_COMPLETE state
    local stacks=("${STACK_NAME_PREFIX}-policies" "${STACK_NAME_PREFIX}-cross-account" "${STACK_NAME_PREFIX}-access-analyzer")
    
    for stack in "${stacks[@]}"; do
        local status=$(aws cloudformation describe-stacks \
            --stack-name "$stack" \
            --query 'Stacks[0].StackStatus' \
            --output text \
            --region "$REGION" 2>/dev/null || echo "NOT_FOUND")
        
        if [[ "$status" == "CREATE_COMPLETE" || "$status" == "UPDATE_COMPLETE" ]]; then
            print_success "Stack $stack: $status"
        else
            print_error "Stack $stack: $status"
            return 1
        fi
    done
    
    # Check if test bucket exists
    if aws s3 ls "s3://${BUCKET_NAME}" &> /dev/null; then
        print_success "Test bucket exists and is accessible"
    else
        print_error "Test bucket not found or not accessible"
        return 1
    fi
    
    # Check if test users exist
    local users=("test-dev-user" "test-ops-user" "test-audit-user")
    for user in "${users[@]}"; do
        if aws iam get-user --user-name "$user" &> /dev/null; then
            print_success "Test user $user exists"
        else
            print_error "Test user $user not found"
            return 1
        fi
    done
    
    print_success "Deployment validation completed successfully"
}

# Main execution
main() {
    echo "=== IAM Best Practices Lab Provisioning ==="
    echo
    
    # Pre-flight checks
    check_aws_cli
    check_permissions
    
    # Create test resources
    create_test_bucket
    
    # Deploy CloudFormation stacks
    deploy_least_privilege_policies
    deploy_cross_account_roles
    deploy_access_analyzer
    
    # Create test users
    create_test_users
    
    # Run validations
    run_policy_simulations
    validate_deployment
    
    # Display information
    display_lab_info
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --validate     Only run validation checks"
        echo "  --cleanup      Run cleanup (use cleanup script instead)"
        echo
        echo "Environment Variables:"
        echo "  AWS_DEFAULT_REGION    AWS region (default: us-east-1)"
        echo
        exit 0
        ;;
    --validate)
        validate_deployment
        exit 0
        ;;
    --cleanup)
        print_warning "Use the cleanup script: scripts/cleanup-iam-lab.sh"
        exit 1
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