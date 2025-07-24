#!/bin/bash

# Terraform Backend Setup Script
set -e

# Configuration
BACKEND_DIR="../backend"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed"
        exit 1
    fi
    
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
    
    print_success "Prerequisites check completed"
}

# Setup backend infrastructure
setup_backend() {
    print_status "Setting up Terraform backend infrastructure..."
    
    cd "$SCRIPT_DIR/$BACKEND_DIR"
    
    # Initialize Terraform
    print_status "Initializing Terraform..."
    terraform init
    
    # Plan the deployment
    print_status "Planning backend deployment..."
    terraform plan -out=backend.tfplan
    
    # Apply the plan
    print_status "Creating backend infrastructure..."
    terraform apply backend.tfplan
    
    # Clean up plan file
    rm -f backend.tfplan
    
    print_success "Backend infrastructure created successfully"
}

# Display backend configuration
show_backend_config() {
    print_status "Backend configuration created:"
    
    cd "$SCRIPT_DIR/$BACKEND_DIR"
    
    # Get outputs
    BUCKET_NAME=$(terraform output -raw s3_bucket_name)
    DYNAMODB_TABLE=$(terraform output -raw dynamodb_table_name)
    REGION=$(aws configure get region)
    
    echo ""
    echo "=== Backend Configuration ==="
    echo "S3 Bucket: $BUCKET_NAME"
    echo "DynamoDB Table: $DYNAMODB_TABLE"
    echo "Region: $REGION"
    echo ""
    
    echo "=== Backend Configuration Template ==="
    echo "terraform {"
    echo "  backend \"s3\" {"
    echo "    bucket         = \"$BUCKET_NAME\""
    echo "    key            = \"ENVIRONMENT/terraform.tfstate\""
    echo "    region         = \"$REGION\""
    echo "    dynamodb_table = \"$DYNAMODB_TABLE\""
    echo "    encrypt        = true"
    echo "  }"
    echo "}"
    echo ""
}

# Initialize environment backends
initialize_environments() {
    print_status "Initializing environment backends..."
    
    ENVIRONMENTS=("dev" "staging" "prod")
    
    for env in "${ENVIRONMENTS[@]}"; do
        ENV_DIR="$SCRIPT_DIR/../environments/$env"
        
        if [ -d "$ENV_DIR" ]; then
            print_status "Initializing $env environment..."
            cd "$ENV_DIR"
            
            # Check if backend.tf exists
            if [ -f "backend.tf" ]; then
                terraform init
                print_success "$env environment initialized"
            else
                print_warning "backend.tf not found for $env environment"
            fi
        else
            print_warning "$env environment directory not found"
        fi
    done
}

# Verify backend setup
verify_backend() {
    print_status "Verifying backend setup..."
    
    cd "$SCRIPT_DIR/$BACKEND_DIR"
    
    # Check if resources exist
    BUCKET_NAME=$(terraform output -raw s3_bucket_name)
    DYNAMODB_TABLE=$(terraform output -raw dynamodb_table_name)
    
    # Verify S3 bucket
    if aws s3 ls "s3://$BUCKET_NAME" &> /dev/null; then
        print_success "S3 bucket verified: $BUCKET_NAME"
    else
        print_error "S3 bucket not accessible: $BUCKET_NAME"
        return 1
    fi
    
    # Verify DynamoDB table
    if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" &> /dev/null; then
        print_success "DynamoDB table verified: $DYNAMODB_TABLE"
    else
        print_error "DynamoDB table not accessible: $DYNAMODB_TABLE"
        return 1
    fi
    
    print_success "Backend verification completed"
}

# Main execution
main() {
    echo "=== Terraform Backend Setup ==="
    echo "This script will create S3 bucket and DynamoDB table for Terraform state management"
    echo ""
    
    check_prerequisites
    setup_backend
    show_backend_config
    initialize_environments
    verify_backend
    
    echo ""
    print_success "Backend setup completed successfully!"
    echo ""
    print_status "Next steps:"
    echo "1. Navigate to an environment directory (e.g., cd ../environments/dev)"
    echo "2. Run 'terraform plan' to see what will be created"
    echo "3. Run 'terraform apply' to deploy the infrastructure"
    echo ""
    print_warning "Remember to run cleanup scripts when done to avoid charges!"
}

# Run main function
main "$@"