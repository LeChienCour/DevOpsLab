#!/bin/bash

# Secrets Management Lab Provisioning Script
# This script provisions the secrets management lab environment with
# Secrets Manager, Parameter Store, and credential rotation workflows

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
    
    # Check Secrets Manager permissions
    if ! aws secretsmanager list-secrets --max-results 1 &> /dev/null; then
        print_error "Insufficient Secrets Manager permissions."
        exit 1
    fi
    
    # Check Systems Manager permissions
    if ! aws ssm describe-parameters --max-results 1 &> /dev/null; then
        print_error "Insufficient Systems Manager permissions."
        exit 1
    fi
    
    # Check RDS permissions
    if ! aws rds describe-db-instances --max-records 1 &> /dev/null; then
        print_error "Insufficient RDS permissions."
        exit 1
    fi
    
    # Check Lambda permissions
    if ! aws lambda list-functions --max-items 1 &> /dev/null; then
        print_error "Insufficient Lambda permissions."
        exit 1
    fi
    
    print_success "Required permissions verified"
}

# Function to deploy CloudFormation stack
deploy_stack() {
    local template_file=$1
    local stack_name=$2
    local parameters=$3
    
    print_status "Deploying stack: ${stack_name}"
    
    # Check if stack exists
    if aws cloudformation describe-stacks --stack-name "$stack_name" --region "$REGION" &> /dev/null; then
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

# Function to deploy Parameter Store hierarchy
deploy_parameter_store() {
    local stack_name="${STACK_NAME_PREFIX}-parameter-store"
    local template_file="templates/parameter-store-hierarchy.yaml"
    
    if [ ! -f "$template_file" ]; then
        print_error "Template file not found: $template_file"
        return 1
    fi
    
    local parameters="ParameterKey=ApplicationName,ParameterValue=${APPLICATION_NAME} ParameterKey=Environment,ParameterValue=${ENVIRONMENT}"
    
    deploy_stack "$template_file" "$stack_name" "$parameters"
}

# Function to deploy Secrets Manager integration
deploy_secrets_manager() {
    local stack_name="${STACK_NAME_PREFIX}-secrets-manager"
    local template_file="templates/secrets-manager-integration.yaml"
    
    if [ ! -f "$template_file" ]; then
        print_error "Template file not found: $template_file"
        return 1
    fi
    
    # Prompt for database password
    read -s -p "Enter database password (or press Enter for default): " db_password
    echo
    if [ -z "$db_password" ]; then
        db_password="TempPassword123!"
        print_warning "Using default database password"
    fi
    
    local parameters="ParameterKey=ApplicationName,ParameterValue=${APPLICATION_NAME} ParameterKey=Environment,ParameterValue=${ENVIRONMENT} ParameterKey=DatabasePassword,ParameterValue=${db_password}"
    
    deploy_stack "$template_file" "$stack_name" "$parameters"
}

# Function to deploy credential rotation workflows
deploy_rotation_workflows() {
    local stack_name="${STACK_NAME_PREFIX}-rotation"
    local template_file="templates/credential-rotation-workflows.yaml"
    
    if [ ! -f "$template_file" ]; then
        print_error "Template file not found: $template_file"
        return 1
    fi
    
    # Prompt for notification email
    read -p "Enter email address for rotation notifications: " notification_email
    if [ -z "$notification_email" ]; then
        notification_email="admin@example.com"
        print_warning "Using default email: $notification_email"
    fi
    
    # Prompt for rotation schedule
    read -p "Enter rotation schedule in days (default: 30): " rotation_days
    if [ -z "$rotation_days" ]; then
        rotation_days=30
    fi
    
    local parameters="ParameterKey=ApplicationName,ParameterValue=${APPLICATION_NAME} ParameterKey=Environment,ParameterValue=${ENVIRONMENT} ParameterKey=NotificationEmail,ParameterValue=${notification_email} ParameterKey=RotationScheduleDays,ParameterValue=${rotation_days}"
    
    deploy_stack "$template_file" "$stack_name" "$parameters"
}

# Function to create additional Parameter Store parameters
create_additional_parameters() {
    print_status "Creating additional Parameter Store parameters..."
    
    # Create some example parameters for different categories
    local params=(
        "/${APPLICATION_NAME}/${ENVIRONMENT}/app/version:1.0.0:Application version"
        "/${APPLICATION_NAME}/${ENVIRONMENT}/app/debug_mode:false:Debug mode flag"
        "/${APPLICATION_NAME}/${ENVIRONMENT}/app/max_connections:100:Maximum connections"
        "/${APPLICATION_NAME}/${ENVIRONMENT}/monitoring/enabled:true:Monitoring enabled"
        "/${APPLICATION_NAME}/${ENVIRONMENT}/monitoring/interval:60:Monitoring interval"
    )
    
    for param in "${params[@]}"; do
        IFS=':' read -r name value description <<< "$param"
        
        if ! aws ssm get-parameter --name "$name" &> /dev/null; then
            aws ssm put-parameter \
                --name "$name" \
                --value "$value" \
                --type "String" \
                --description "$description" \
                --tags "Key=Application,Value=${APPLICATION_NAME}" "Key=Environment,Value=${ENVIRONMENT}" \
                --region "$REGION"
            print_success "Created parameter: $name"
        else
            print_warning "Parameter already exists: $name"
        fi
    done
    
    # Create some secure parameters
    local secure_params=(
        "/${APPLICATION_NAME}/${ENVIRONMENT}/external/webhook_secret:webhook-secret-change-me:Webhook secret"
        "/${APPLICATION_NAME}/${ENVIRONMENT}/external/oauth_client_secret:oauth-secret-change-me:OAuth client secret"
    )
    
    for param in "${secure_params[@]}"; do
        IFS=':' read -r name value description <<< "$param"
        
        if ! aws ssm get-parameter --name "$name" &> /dev/null; then
            aws ssm put-parameter \
                --name "$name" \
                --value "$value" \
                --type "SecureString" \
                --description "$description" \
                --tags "Key=Application,Value=${APPLICATION_NAME}" "Key=Environment,Value=${ENVIRONMENT}" "Key=Sensitive,Value=true" \
                --region "$REGION"
            print_success "Created secure parameter: $name"
        else
            print_warning "Secure parameter already exists: $name"
        fi
    done
}

# Function to test secret and parameter retrieval
test_secrets_retrieval() {
    print_status "Testing secrets and parameters retrieval..."
    
    # Test Parameter Store retrieval
    print_status "Testing Parameter Store retrieval..."
    
    # Get all parameters for the application
    local params=$(aws ssm get-parameters-by-path \
        --path "/${APPLICATION_NAME}/${ENVIRONMENT}" \
        --recursive \
        --query 'Parameters[*].[Name,Type]' \
        --output table \
        --region "$REGION" 2>/dev/null || echo "No parameters found")
    
    if [ "$params" != "No parameters found" ]; then
        print_success "Parameter Store retrieval test passed"
        echo "$params"
    else
        print_warning "No parameters found in Parameter Store"
    fi
    
    # Test Secrets Manager retrieval
    print_status "Testing Secrets Manager retrieval..."
    
    # List secrets for the application
    local secrets=$(aws secretsmanager list-secrets \
        --filters Key=name,Values="${APPLICATION_NAME}/" \
        --query 'SecretList[*].[Name,Description]' \
        --output table \
        --region "$REGION" 2>/dev/null || echo "No secrets found")
    
    if [ "$secrets" != "No secrets found" ]; then
        print_success "Secrets Manager retrieval test passed"
        echo "$secrets"
    else
        print_warning "No secrets found in Secrets Manager"
    fi
}

# Function to create sample application code
create_sample_application() {
    print_status "Creating sample application code..."
    
    mkdir -p sample-app
    
    # Create Python application that demonstrates secrets usage
    cat > sample-app/secrets_demo.py << 'EOF'
#!/usr/bin/env python3
"""
Secrets Management Demo Application
Demonstrates how to retrieve secrets from AWS Secrets Manager and Parameter Store
"""

import json
import boto3
import logging
from botocore.exceptions import ClientError

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class SecretsManager:
    def __init__(self, region='us-east-1'):
        self.secrets_client = boto3.client('secretsmanager', region_name=region)
        self.ssm_client = boto3.client('ssm', region_name=region)
        self.region = region
    
    def get_secret(self, secret_name):
        """Retrieve secret from AWS Secrets Manager"""
        try:
            logger.info(f"Retrieving secret: {secret_name}")
            response = self.secrets_client.get_secret_value(SecretId=secret_name)
            return json.loads(response['SecretString'])
        except ClientError as e:
            logger.error(f"Error retrieving secret {secret_name}: {e}")
            raise
    
    def get_parameter(self, parameter_name, decrypt=False):
        """Retrieve parameter from Systems Manager Parameter Store"""
        try:
            logger.info(f"Retrieving parameter: {parameter_name}")
            response = self.ssm_client.get_parameter(
                Name=parameter_name,
                WithDecryption=decrypt
            )
            return response['Parameter']['Value']
        except ClientError as e:
            logger.error(f"Error retrieving parameter {parameter_name}: {e}")
            raise
    
    def get_parameters_by_path(self, path, decrypt=False):
        """Retrieve multiple parameters by path"""
        try:
            logger.info(f"Retrieving parameters from path: {path}")
            response = self.ssm_client.get_parameters_by_path(
                Path=path,
                Recursive=True,
                WithDecryption=decrypt
            )
            return {param['Name']: param['Value'] for param in response['Parameters']}
        except ClientError as e:
            logger.error(f"Error retrieving parameters from path {path}: {e}")
            raise
    
    def list_secrets(self, name_filter=None):
        """List available secrets"""
        try:
            filters = []
            if name_filter:
                filters.append({'Key': 'name', 'Values': [name_filter]})
            
            response = self.secrets_client.list_secrets(Filters=filters)
            return [secret['Name'] for secret in response['SecretList']]
        except ClientError as e:
            logger.error(f"Error listing secrets: {e}")
            raise

def demonstrate_secrets_usage():
    """Demonstrate secrets and parameters usage"""
    secrets_manager = SecretsManager()
    app_name = "secrets-lab-app"
    environment = "dev"
    
    try:
        # List available secrets
        logger.info("=== Available Secrets ===")
        secrets = secrets_manager.list_secrets(f"{app_name}/")
        for secret in secrets:
            logger.info(f"Secret: {secret}")
        
        # Retrieve database credentials
        if secrets:
            try:
                db_secret_name = f"{app_name}/{environment}/database/master-credentials"
                logger.info("=== Database Credentials ===")
                db_credentials = secrets_manager.get_secret(db_secret_name)
                logger.info(f"Database host: {db_credentials.get('host', 'N/A')}")
                logger.info(f"Database port: {db_credentials.get('port', 'N/A')}")
                logger.info(f"Database name: {db_credentials.get('dbname', 'N/A')}")
                logger.info(f"Database user: {db_credentials.get('username', 'N/A')}")
                logger.info("Database password: [REDACTED]")
            except ClientError:
                logger.warning(f"Database secret not found: {db_secret_name}")
        
        # Retrieve application configuration from Parameter Store
        logger.info("=== Application Configuration ===")
        try:
            config_path = f"/{app_name}/{environment}"
            app_config = secrets_manager.get_parameters_by_path(config_path, decrypt=True)
            
            for param_name, param_value in sorted(app_config.items()):
                # Redact sensitive values
                if any(keyword in param_name.lower() for keyword in ['password', 'secret', 'key']):
                    logger.info(f"{param_name}: [REDACTED]")
                else:
                    logger.info(f"{param_name}: {param_value}")
        except ClientError:
            logger.warning(f"No parameters found at path: {config_path}")
        
        # Demonstrate secure parameter retrieval
        logger.info("=== Secure Parameters ===")
        secure_params = [
            f"/{app_name}/{environment}/database/password",
            f"/{app_name}/{environment}/api/key",
            f"/{app_name}/{environment}/jwt/secret"
        ]
        
        for param_name in secure_params:
            try:
                value = secrets_manager.get_parameter(param_name, decrypt=True)
                logger.info(f"{param_name}: [REDACTED - Length: {len(value)}]")
            except ClientError:
                logger.warning(f"Secure parameter not found: {param_name}")
        
        logger.info("=== Secrets Demo Completed Successfully ===")
        
    except Exception as e:
        logger.error(f"Demo failed: {e}")
        raise

if __name__ == "__main__":
    demonstrate_secrets_usage()
EOF
    
    # Create requirements file
    cat > sample-app/requirements.txt << 'EOF'
boto3>=1.26.0
botocore>=1.29.0
EOF
    
    # Create Dockerfile
    cat > sample-app/Dockerfile << 'EOF'
FROM python:3.9-slim

# Install required packages
COPY requirements.txt /app/requirements.txt
RUN pip install -r /app/requirements.txt

# Copy application code
COPY secrets_demo.py /app/secrets_demo.py

# Set working directory
WORKDIR /app

# Make script executable
RUN chmod +x secrets_demo.py

# Run the application
CMD ["python", "secrets_demo.py"]
EOF
    
    # Make the Python script executable
    chmod +x sample-app/secrets_demo.py
    
    print_success "Sample application created in sample-app/ directory"
}

# Function to display lab information
display_lab_info() {
    print_success "Secrets Management Lab provisioned successfully!"
    echo
    echo "=== Lab Resources ==="
    echo "CloudFormation Stacks:"
    echo "  - ${STACK_NAME_PREFIX}-parameter-store"
    echo "  - ${STACK_NAME_PREFIX}-secrets-manager"
    echo "  - ${STACK_NAME_PREFIX}-rotation"
    echo
    echo "Parameter Store Hierarchy:"
    echo "  /${APPLICATION_NAME}/${ENVIRONMENT}/"
    echo "    ├── database/ (host, port, name, password)"
    echo "    ├── api/ (base_url, timeout, key)"
    echo "    ├── cache/ (host, port, ttl)"
    echo "    ├── logging/ (level, retention_days)"
    echo "    ├── features/ (feature flags)"
    echo "    └── monitoring/ (metrics, alerting)"
    echo
    echo "Secrets Manager Secrets:"
    echo "  - Database credentials with automatic rotation"
    echo "  - API service credentials"
    echo "  - JWT signing secrets"
    echo
    echo "=== Next Steps ==="
    echo "1. Review the lab guide: lab-guide.md"
    echo "2. Test the sample application: cd sample-app && python secrets_demo.py"
    echo "3. Explore AWS Console:"
    echo "   - Secrets Manager: https://console.aws.amazon.com/secretsmanager/"
    echo "   - Parameter Store: https://console.aws.amazon.com/systems-manager/parameters/"
    echo "4. Monitor rotation workflows in CloudWatch"
    echo
    echo "=== Important Commands ==="
    echo "# Retrieve all parameters:"
    echo "aws ssm get-parameters-by-path --path '/${APPLICATION_NAME}/${ENVIRONMENT}' --recursive --with-decryption"
    echo
    echo "# Retrieve a secret:"
    echo "aws secretsmanager get-secret-value --secret-id '${APPLICATION_NAME}/${ENVIRONMENT}/database/master-credentials'"
    echo
    echo "# Manually trigger rotation:"
    echo "aws secretsmanager rotate-secret --secret-id '${APPLICATION_NAME}/${ENVIRONMENT}/database/master-credentials'"
    echo
    echo "=== Cleanup ==="
    echo "Run cleanup script when finished: scripts/cleanup-secrets-lab.sh"
    echo
}

# Function to validate deployment
validate_deployment() {
    print_status "Validating deployment..."
    
    # Check CloudFormation stacks
    local stacks=("${STACK_NAME_PREFIX}-parameter-store" "${STACK_NAME_PREFIX}-secrets-manager" "${STACK_NAME_PREFIX}-rotation")
    
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
    
    # Check if parameters exist
    local param_count=$(aws ssm get-parameters-by-path \
        --path "/${APPLICATION_NAME}/${ENVIRONMENT}" \
        --recursive \
        --query 'length(Parameters)' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "0")
    
    if [ "$param_count" -gt 0 ]; then
        print_success "Parameter Store contains $param_count parameters"
    else
        print_error "No parameters found in Parameter Store"
        return 1
    fi
    
    # Check if secrets exist
    local secret_count=$(aws secretsmanager list-secrets \
        --filters Key=name,Values="${APPLICATION_NAME}/" \
        --query 'length(SecretList)' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "0")
    
    if [ "$secret_count" -gt 0 ]; then
        print_success "Secrets Manager contains $secret_count secrets"
    else
        print_error "No secrets found in Secrets Manager"
        return 1
    fi
    
    print_success "Deployment validation completed successfully"
}

# Main execution
main() {
    echo "=== Secrets Management Lab Provisioning ==="
    echo
    
    # Pre-flight checks
    check_aws_cli
    check_permissions
    
    # Deploy infrastructure
    deploy_parameter_store
    deploy_secrets_manager
    deploy_rotation_workflows
    
    # Create additional resources
    create_additional_parameters
    create_sample_application
    
    # Test and validate
    test_secrets_retrieval
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
        echo "  --test         Only run retrieval tests"
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
    --test)
        test_secrets_retrieval
        exit 0
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