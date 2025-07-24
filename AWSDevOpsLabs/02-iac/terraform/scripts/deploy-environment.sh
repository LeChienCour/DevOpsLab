#!/bin/bash

# Terraform Environment Deployment Script
set -e

# Configuration
ENVIRONMENT="${1:-dev}"
ACTION="${2:-apply}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="$SCRIPT_DIR/../environments/$ENVIRONMENT"

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

# Show usage
show_usage() {
    echo "Usage: $0 [ENVIRONMENT] [ACTION]"
    echo ""
    echo "ENVIRONMENT: dev, staging, prod (default: dev)"
    echo "ACTION: plan, apply, destroy, output (default: apply)"
    echo ""
    echo "Examples:"
    echo "  $0 dev plan      # Plan development environment"
    echo "  $0 dev apply     # Deploy development environment"
    echo "  $0 prod destroy  # Destroy production environment"
    echo "  $0 staging output # Show staging outputs"
}

# Validate inputs
validate_inputs() {
    # Check if environment is valid
    if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
        print_error "Invalid environment: $ENVIRONMENT"
        print_error "Valid environments: dev, staging, prod"
        show_usage
        exit 1
    fi
    
    # Check if action is valid
    if [[ ! "$ACTION" =~ ^(plan|apply|destroy|output|init|validate|fmt|refresh)$ ]]; then
        print_error "Invalid action: $ACTION"
        print_error "Valid actions: plan, apply, destroy, output, init, validate, fmt, refresh"
        show_usage
        exit 1
    fi
    
    # Check if environment directory exists
    if [ ! -d "$ENV_DIR" ]; then
        print_error "Environment directory not found: $ENV_DIR"
        exit 1
    fi
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

# Initialize Terraform
terraform_init() {
    print_status "Initializing Terraform for $ENVIRONMENT environment..."
    cd "$ENV_DIR"
    
    terraform init -upgrade
    print_success "Terraform initialized"
}

# Validate Terraform configuration
terraform_validate() {
    print_status "Validating Terraform configuration..."
    cd "$ENV_DIR"
    
    terraform validate
    print_success "Terraform configuration is valid"
}

# Format Terraform files
terraform_fmt() {
    print_status "Formatting Terraform files..."
    cd "$ENV_DIR"
    
    terraform fmt -recursive
    print_success "Terraform files formatted"
}

# Plan Terraform deployment
terraform_plan() {
    print_status "Planning Terraform deployment for $ENVIRONMENT..."
    cd "$ENV_DIR"
    
    terraform plan -out="$ENVIRONMENT.tfplan"
    print_success "Terraform plan completed"
    
    echo ""
    print_status "Plan saved as: $ENVIRONMENT.tfplan"
    print_status "Review the plan above before applying"
}

# Apply Terraform deployment
terraform_apply() {
    print_status "Applying Terraform deployment for $ENVIRONMENT..."
    cd "$ENV_DIR"
    
    # Check if plan file exists
    if [ -f "$ENVIRONMENT.tfplan" ]; then
        print_status "Using existing plan file: $ENVIRONMENT.tfplan"
        terraform apply "$ENVIRONMENT.tfplan"
        rm -f "$ENVIRONMENT.tfplan"
    else
        print_warning "No plan file found, creating new plan..."
        terraform plan -out="$ENVIRONMENT.tfplan"
        
        echo ""
        read -p "Do you want to apply this plan? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            terraform apply "$ENVIRONMENT.tfplan"
            rm -f "$ENVIRONMENT.tfplan"
        else
            print_status "Apply cancelled"
            rm -f "$ENVIRONMENT.tfplan"
            exit 0
        fi
    fi
    
    print_success "Terraform apply completed"
}

# Destroy Terraform deployment
terraform_destroy() {
    print_status "Planning destruction of $ENVIRONMENT environment..."
    cd "$ENV_DIR"
    
    terraform plan -destroy
    
    echo ""
    print_warning "This will destroy all resources in the $ENVIRONMENT environment!"
    print_warning "This action cannot be undone!"
    echo ""
    read -p "Are you sure you want to destroy the $ENVIRONMENT environment? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        terraform destroy -auto-approve
        print_success "Environment destroyed"
    else
        print_status "Destroy cancelled"
    fi
}

# Show Terraform outputs
terraform_output() {
    print_status "Showing Terraform outputs for $ENVIRONMENT..."
    cd "$ENV_DIR"
    
    terraform output
}

# Refresh Terraform state
terraform_refresh() {
    print_status "Refreshing Terraform state for $ENVIRONMENT..."
    cd "$ENV_DIR"
    
    terraform refresh
    print_success "Terraform state refreshed"
}

# Show deployment summary
show_deployment_summary() {
    print_status "Deployment Summary for $ENVIRONMENT:"
    cd "$ENV_DIR"
    
    echo ""
    echo "=== Environment Information ==="
    echo "Environment: $ENVIRONMENT"
    echo "Region: $(aws configure get region)"
    echo "Account: $(aws sts get-caller-identity --query Account --output text)"
    echo "Terraform Workspace: $(terraform workspace show)"
    echo ""
    
    if terraform output application_url &> /dev/null; then
        echo "=== Application Access ==="
        echo "Application URL: $(terraform output -raw application_url)"
        echo ""
    fi
    
    if terraform output cloudwatch_dashboard_url &> /dev/null; then
        echo "=== Monitoring ==="
        echo "CloudWatch Dashboard: $(terraform output -raw cloudwatch_dashboard_url)"
        echo ""
    fi
    
    echo "=== Cost Optimization ==="
    case $ENVIRONMENT in
        "dev")
            echo "- Single NAT Gateway for cost savings"
            echo "- Minimal ECS task count"
            echo "- No deletion protection"
            echo "- Short log retention"
            ;;
        "staging")
            echo "- Balanced configuration for testing"
            echo "- Auto-scaling enabled"
            echo "- Moderate retention periods"
            ;;
        "prod")
            echo "- High availability configuration"
            echo "- Multi-AZ deployment"
            echo "- Deletion protection enabled"
            echo "- Extended retention periods"
            ;;
    esac
    echo ""
    
    print_warning "Remember to destroy resources when done to avoid charges!"
}

# Main execution
main() {
    echo "=== Terraform Environment Deployment ==="
    echo "Environment: $ENVIRONMENT"
    echo "Action: $ACTION"
    echo ""
    
    validate_inputs
    check_prerequisites
    
    case $ACTION in
        "init")
            terraform_init
            ;;
        "validate")
            terraform_init
            terraform_validate
            ;;
        "fmt")
            terraform_fmt
            ;;
        "plan")
            terraform_init
            terraform_validate
            terraform_plan
            ;;
        "apply")
            terraform_init
            terraform_validate
            terraform_apply
            show_deployment_summary
            ;;
        "destroy")
            terraform_destroy
            ;;
        "output")
            terraform_output
            ;;
        "refresh")
            terraform_refresh
            ;;
        *)
            print_error "Unknown action: $ACTION"
            show_usage
            exit 1
            ;;
    esac
    
    print_success "Operation completed successfully!"
}

# Show usage if no arguments
if [ $# -eq 0 ]; then
    show_usage
    exit 1
fi

# Run main function
main "$@"