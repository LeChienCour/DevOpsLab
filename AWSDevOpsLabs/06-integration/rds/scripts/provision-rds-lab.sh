#!/bin/bash

# RDS Database Integration Lab Provisioning Script
# This script provisions the complete RDS integration lab environment with
# infrastructure, RDS Proxy, and backup automation

set -e

# Configuration
STACK_PREFIX="rds-integration-lab"
INFRASTRUCTURE_STACK="${STACK_PREFIX}-infrastructure"
PROXY_STACK="${STACK_PREFIX}-proxy"
BACKUP_STACK="${STACK_PREFIX}-backup"
REGION=${AWS_DEFAULT_REGION:-us-east-1}

# Database configuration
DB_NAME="appdb"
DB_USERNAME="admin"
DB_PASSWORD=""

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

# Function to generate secure password
generate_password() {
    openssl rand -base64 16 | tr -d "=+/" | cut -c1-16
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

# Function to deploy infrastructure stack
deploy_infrastructure() {
    print_status "Deploying RDS infrastructure stack..."
    
    local template_file="templates/rds-infrastructure.yaml"
    
    if [ ! -f "$template_file" ]; then
        print_error "Template file not found: $template_file"
        exit 1
    fi
    
    # Generate password if not provided
    if [ -z "$DB_PASSWORD" ]; then
        DB_PASSWORD=$(generate_password)
        print_status "Generated database password: $DB_PASSWORD"
    fi
    
    local parameters=(
        "ParameterKey=DatabaseName,ParameterValue=$DB_NAME"
        "ParameterKey=DatabaseUsername,ParameterValue=$DB_USERNAME"
        "ParameterKey=DatabasePassword,ParameterValue=$DB_PASSWORD"
        "ParameterKey=DatabaseInstanceClass,ParameterValue=db.t3.micro"
        "ParameterKey=MultiAZ,ParameterValue=false"
    )
    
    if stack_exists "$INFRASTRUCTURE_STACK"; then
        print_warning "Infrastructure stack already exists, updating..."
        aws cloudformation update-stack \
            --stack-name "$INFRASTRUCTURE_STACK" \
            --template-body file://"$template_file" \
            --parameters "${parameters[@]}" \
            --capabilities CAPABILITY_IAM \
            --region "$REGION" || {
                if [[ $? -eq 254 ]]; then
                    print_warning "No updates to be performed on infrastructure stack"
                else
                    print_error "Failed to update infrastructure stack"
                    exit 1
                fi
            }
        
        if [[ $? -ne 254 ]]; then
            wait_for_stack "$INFRASTRUCTURE_STACK" "UPDATE"
        fi
    else
        aws cloudformation create-stack \
            --stack-name "$INFRASTRUCTURE_STACK" \
            --template-body file://"$template_file" \
            --parameters "${parameters[@]}" \
            --capabilities CAPABILITY_IAM \
            --region "$REGION" \
            --tags Key=Project,Value=DevOpsLab Key=Component,Value=RDS-Infrastructure
        
        wait_for_stack "$INFRASTRUCTURE_STACK" "CREATE"
    fi
    
    print_success "Infrastructure stack deployed successfully"
}

# Function to deploy RDS Proxy stack
deploy_rds_proxy() {
    print_status "Deploying RDS Proxy stack..."
    
    local template_file="templates/rds-proxy-integration.yaml"
    
    if [ ! -f "$template_file" ]; then
        print_error "Template file not found: $template_file"
        exit 1
    fi
    
    local parameters=(
        "ParameterKey=InfrastructureStackName,ParameterValue=$INFRASTRUCTURE_STACK"
        "ParameterKey=ProxyName,ParameterValue=rds-proxy"
    )
    
    if stack_exists "$PROXY_STACK"; then
        print_warning "RDS Proxy stack already exists, updating..."
        aws cloudformation update-stack \
            --stack-name "$PROXY_STACK" \
            --template-body file://"$template_file" \
            --parameters "${parameters[@]}" \
            --capabilities CAPABILITY_IAM \
            --region "$REGION" || {
                if [[ $? -eq 254 ]]; then
                    print_warning "No updates to be performed on RDS Proxy stack"
                else
                    print_error "Failed to update RDS Proxy stack"
                    exit 1
                fi
            }
        
        if [[ $? -ne 254 ]]; then
            wait_for_stack "$PROXY_STACK" "UPDATE"
        fi
    else
        aws cloudformation create-stack \
            --stack-name "$PROXY_STACK" \
            --template-body file://"$template_file" \
            --parameters "${parameters[@]}" \
            --capabilities CAPABILITY_IAM \
            --region "$REGION" \
            --tags Key=Project,Value=DevOpsLab Key=Component,Value=RDS-Proxy
        
        wait_for_stack "$PROXY_STACK" "CREATE"
    fi
    
    print_success "RDS Proxy stack deployed successfully"
}

# Function to deploy backup automation stack
deploy_backup_automation() {
    print_status "Deploying backup automation stack..."
    
    local template_file="templates/rds-backup-automation.yaml"
    
    if [ ! -f "$template_file" ]; then
        print_error "Template file not found: $template_file"
        exit 1
    fi
    
    local parameters=(
        "ParameterKey=InfrastructureStackName,ParameterValue=$INFRASTRUCTURE_STACK"
        "ParameterKey=BackupRetentionDays,ParameterValue=30"
        "ParameterKey=BackupSchedule,ParameterValue=cron(0 2 * * ? *)"
    )
    
    if stack_exists "$BACKUP_STACK"; then
        print_warning "Backup automation stack already exists, updating..."
        aws cloudformation update-stack \
            --stack-name "$BACKUP_STACK" \
            --template-body file://"$template_file" \
            --parameters "${parameters[@]}" \
            --capabilities CAPABILITY_IAM \
            --region "$REGION" || {
                if [[ $? -eq 254 ]]; then
                    print_warning "No updates to be performed on backup automation stack"
                else
                    print_error "Failed to update backup automation stack"
                    exit 1
                fi
            }
        
        if [[ $? -ne 254 ]]; then
            wait_for_stack "$BACKUP_STACK" "UPDATE"
        fi
    else
        aws cloudformation create-stack \
            --stack-name "$BACKUP_STACK" \
            --template-body file://"$template_file" \
            --parameters "${parameters[@]}" \
            --capabilities CAPABILITY_IAM \
            --region "$REGION" \
            --tags Key=Project,Value=DevOpsLab Key=Component,Value=RDS-Backup
        
        wait_for_stack "$BACKUP_STACK" "CREATE"
    fi
    
    print_success "Backup automation stack deployed successfully"
}

# Function to create PyMySQL layer for Lambda functions
create_pymysql_layer() {
    print_status "Creating PyMySQL layer for Lambda functions..."
    
    # Create temporary directory for layer
    local layer_dir="/tmp/pymysql-layer"
    rm -rf "$layer_dir"
    mkdir -p "$layer_dir/python"
    
    # Install PyMySQL
    pip install pymysql -t "$layer_dir/python" > /dev/null 2>&1
    
    # Create ZIP file
    cd "$layer_dir"
    zip -r pymysql-layer.zip python > /dev/null 2>&1
    
    # Get S3 bucket name from backup stack
    local bucket_name=$(get_stack_output "$BACKUP_STACK" "BackupBucketName")
    
    if [ -n "$bucket_name" ]; then
        # Upload to S3
        aws s3 cp pymysql-layer.zip "s3://$bucket_name/pymysql-layer.zip" --region "$REGION"
        print_success "PyMySQL layer uploaded to S3"
    else
        print_warning "Could not upload PyMySQL layer - backup bucket not found"
    fi
    
    # Cleanup
    cd - > /dev/null
    rm -rf "$layer_dir"
}

# Function to test database connections
test_database_connections() {
    print_status "Testing database connections..."
    
    # Test direct RDS connection
    print_status "Testing direct RDS connection..."
    aws lambda invoke \
        --function-name "direct-rds-connection" \
        --region "$REGION" \
        --payload '{}' \
        /tmp/direct-response.json > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        print_success "Direct RDS connection test completed"
        cat /tmp/direct-response.json | jq . 2>/dev/null || cat /tmp/direct-response.json
        rm -f /tmp/direct-response.json
    else
        print_warning "Direct RDS connection test failed"
    fi
    
    echo
    
    # Test RDS Proxy connection
    print_status "Testing RDS Proxy connection..."
    aws lambda invoke \
        --function-name "proxy-rds-connection" \
        --region "$REGION" \
        --payload '{}' \
        /tmp/proxy-response.json > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        print_success "RDS Proxy connection test completed"
        cat /tmp/proxy-response.json | jq . 2>/dev/null || cat /tmp/proxy-response.json
        rm -f /tmp/proxy-response.json
    else
        print_warning "RDS Proxy connection test failed"
    fi
}

# Function to test backup automation
test_backup_automation() {
    print_status "Testing backup automation..."
    
    # Trigger manual backup
    aws lambda invoke \
        --function-name "rds-backup-automation" \
        --region "$REGION" \
        --payload '{}' \
        /tmp/backup-response.json > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        print_success "Backup automation test initiated"
        cat /tmp/backup-response.json | jq . 2>/dev/null || cat /tmp/backup-response.json
        rm -f /tmp/backup-response.json
        
        print_status "Note: Backup process will take several minutes to complete"
        print_status "Check CloudWatch logs for progress: /aws/lambda/rds-backup-automation"
    else
        print_warning "Backup automation test failed"
    fi
}

# Function to display lab information
display_lab_info() {
    print_success "RDS Database Integration Lab deployed successfully!"
    echo
    print_status "Lab Resources:"
    
    # Get stack outputs
    local db_endpoint=$(get_stack_output "$INFRASTRUCTURE_STACK" "DatabaseEndpoint")
    local proxy_endpoint=$(get_stack_output "$PROXY_STACK" "RDSProxyEndpoint")
    local backup_bucket=$(get_stack_output "$BACKUP_STACK" "BackupBucketName")
    local dashboard_url=$(get_stack_output "$BACKUP_STACK" "DashboardURL")
    
    echo "  • Database Endpoint: $db_endpoint"
    echo "  • RDS Proxy Endpoint: $proxy_endpoint"
    echo "  • Backup S3 Bucket: $backup_bucket"
    echo "  • Monitoring Dashboard: $dashboard_url"
    echo
    
    print_status "Database Credentials:"
    echo "  • Username: $DB_USERNAME"
    echo "  • Password: $DB_PASSWORD"
    echo "  • Database: $DB_NAME"
    echo "  • Port: 3306"
    echo
    
    print_status "Lambda Functions:"
    echo "  • Direct RDS Connection: direct-rds-connection"
    echo "  • RDS Proxy Connection: proxy-rds-connection"
    echo "  • Connection Pooling Demo: connection-pooling-demo"
    echo "  • Backup Automation: rds-backup-automation"
    echo "  • Restore Automation: rds-restore-automation"
    echo
    
    print_status "Test Commands:"
    echo "  # Test direct RDS connection:"
    echo "  aws lambda invoke --function-name direct-rds-connection --payload '{}' response.json --region $REGION"
    echo
    echo "  # Test RDS Proxy connection:"
    echo "  aws lambda invoke --function-name proxy-rds-connection --payload '{}' response.json --region $REGION"
    echo
    echo "  # Test connection pooling (10 concurrent connections):"
    echo "  aws lambda invoke --function-name connection-pooling-demo --payload '{\"num_connections\": 10}' response.json --region $REGION"
    echo
    echo "  # Trigger manual backup:"
    echo "  aws lambda invoke --function-name rds-backup-automation --payload '{}' response.json --region $REGION"
    echo
    echo "  # Restore from snapshot:"
    echo "  aws lambda invoke --function-name rds-restore-automation --payload '{\"snapshot_id\": \"your-snapshot-id\", \"new_instance_id\": \"restored-instance\"}' response.json --region $REGION"
    echo
    
    print_status "Secrets Manager:"
    echo "  • Secret Name: rds-db-credentials"
    echo "  • Retrieve credentials: aws secretsmanager get-secret-value --secret-id rds-db-credentials --region $REGION"
    echo
    
    print_warning "Important Notes:"
    echo "  • Database password is stored in Secrets Manager"
    echo "  • Backup automation runs daily at 2 AM UTC"
    echo "  • RDS Proxy provides connection pooling for Lambda functions"
    echo "  • All database connections use SSL/TLS encryption"
    echo
    
    print_warning "Remember to clean up resources when done:"
    echo "  ./cleanup-rds-lab.sh"
}

# Function to validate prerequisites
validate_prerequisites() {
    print_status "Validating prerequisites..."
    
    # Check if required tools are installed
    local tools=("aws" "jq" "openssl")
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
    
    # Check if pip is available for PyMySQL layer
    if ! command -v pip &> /dev/null; then
        print_warning "pip is not installed. PyMySQL layer creation will be skipped."
    fi
    
    print_success "Prerequisites validated"
}

# Main execution
main() {
    echo "=========================================="
    echo "RDS Database Integration Lab Provisioning"
    echo "=========================================="
    echo
    
    validate_prerequisites
    check_aws_cli
    
    print_status "Starting deployment in region: $REGION"
    print_status "Stack prefix: $STACK_PREFIX"
    echo
    
    # Deploy stacks in order
    deploy_infrastructure
    deploy_rds_proxy
    deploy_backup_automation
    
    # Create PyMySQL layer if pip is available
    if command -v pip &> /dev/null; then
        create_pymysql_layer
    fi
    
    # Test deployments
    echo
    print_status "Running integration tests..."
    test_database_connections
    test_backup_automation
    
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
        echo "  --password     Database password (default: auto-generated)"
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
    --password)
        DB_PASSWORD="$2"
        shift 2
        ;;
    *)
        ;;
esac

# Run main function
main "$@"