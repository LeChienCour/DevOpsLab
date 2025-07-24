#!/bin/bash

# ECS Orchestration Lab Provisioning Script
# This script provisions the complete ECS lab environment with Cloud Map service discovery,
# ALB integration, and advanced auto-scaling policies

set -e

# Configuration
STACK_PREFIX="ecs-lab"
INFRASTRUCTURE_STACK="${STACK_PREFIX}-infrastructure"
SERVICE_STACK="${STACK_PREFIX}-web-service"
AUTOSCALING_STACK="${STACK_PREFIX}-autoscaling"
REGION=${AWS_DEFAULT_REGION:-us-east-1}
CLUSTER_NAME="devops-lab-cluster"
SERVICE_NAME="web-service"

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

# Function to deploy infrastructure stack
deploy_infrastructure() {
    print_status "Deploying ECS infrastructure stack..."
    
    local template_file="templates/ecs-cluster-infrastructure.yaml"
    
    if [ ! -f "$template_file" ]; then
        print_error "Template file not found: $template_file"
        exit 1
    fi
    
    local parameters=(
        "ParameterKey=ClusterName,ParameterValue=$CLUSTER_NAME"
        "ParameterKey=ServiceDiscoveryNamespace,ParameterValue=devops-lab.local"
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
            --tags Key=Project,Value=DevOpsLab Key=Component,Value=ECS-Infrastructure
        
        wait_for_stack "$INFRASTRUCTURE_STACK" "CREATE"
    fi
    
    print_success "Infrastructure stack deployed successfully"
}

# Function to deploy ECS service
deploy_service() {
    print_status "Deploying ECS service stack..."
    
    local template_file="templates/ecs-service-with-discovery.yaml"
    
    if [ ! -f "$template_file" ]; then
        print_error "Template file not found: $template_file"
        exit 1
    fi
    
    local parameters=(
        "ParameterKey=InfrastructureStackName,ParameterValue=$INFRASTRUCTURE_STACK"
        "ParameterKey=ServiceName,ParameterValue=$SERVICE_NAME"
        "ParameterKey=ContainerImage,ParameterValue=nginx:latest"
        "ParameterKey=ContainerPort,ParameterValue=80"
        "ParameterKey=DesiredCount,ParameterValue=2"
        "ParameterKey=MinCapacity,ParameterValue=1"
        "ParameterKey=MaxCapacity,ParameterValue=10"
        "ParameterKey=TargetCPUUtilization,ParameterValue=70"
        "ParameterKey=TargetMemoryUtilization,ParameterValue=80"
    )
    
    if stack_exists "$SERVICE_STACK"; then
        print_warning "Service stack already exists, updating..."
        aws cloudformation update-stack \
            --stack-name "$SERVICE_STACK" \
            --template-body file://"$template_file" \
            --parameters "${parameters[@]}" \
            --capabilities CAPABILITY_IAM \
            --region "$REGION" || {
                if [[ $? -eq 254 ]]; then
                    print_warning "No updates to be performed on service stack"
                else
                    print_error "Failed to update service stack"
                    exit 1
                fi
            }
        
        if [[ $? -ne 254 ]]; then
            wait_for_stack "$SERVICE_STACK" "UPDATE"
        fi
    else
        aws cloudformation create-stack \
            --stack-name "$SERVICE_STACK" \
            --template-body file://"$template_file" \
            --parameters "${parameters[@]}" \
            --capabilities CAPABILITY_IAM \
            --region "$REGION" \
            --tags Key=Project,Value=DevOpsLab Key=Component,Value=ECS-Service
        
        wait_for_stack "$SERVICE_STACK" "CREATE"
    fi
    
    print_success "Service stack deployed successfully"
}

# Function to deploy advanced auto-scaling
deploy_autoscaling() {
    print_status "Deploying advanced auto-scaling stack..."
    
    local template_file="templates/ecs-autoscaling-advanced.yaml"
    
    if [ ! -f "$template_file" ]; then
        print_error "Template file not found: $template_file"
        exit 1
    fi
    
    local parameters=(
        "ParameterKey=ServiceStackName,ParameterValue=$SERVICE_STACK"
        "ParameterKey=ServiceName,ParameterValue=$SERVICE_NAME"
        "ParameterKey=ClusterName,ParameterValue=$CLUSTER_NAME"
    )
    
    if stack_exists "$AUTOSCALING_STACK"; then
        print_warning "Auto-scaling stack already exists, updating..."
        aws cloudformation update-stack \
            --stack-name "$AUTOSCALING_STACK" \
            --template-body file://"$template_file" \
            --parameters "${parameters[@]}" \
            --capabilities CAPABILITY_IAM \
            --region "$REGION" || {
                if [[ $? -eq 254 ]]; then
                    print_warning "No updates to be performed on auto-scaling stack"
                else
                    print_error "Failed to update auto-scaling stack"
                    exit 1
                fi
            }
        
        if [[ $? -ne 254 ]]; then
            wait_for_stack "$AUTOSCALING_STACK" "UPDATE"
        fi
    else
        aws cloudformation create-stack \
            --stack-name "$AUTOSCALING_STACK" \
            --template-body file://"$template_file" \
            --parameters "${parameters[@]}" \
            --capabilities CAPABILITY_IAM \
            --region "$REGION" \
            --tags Key=Project,Value=DevOpsLab Key=Component,Value=ECS-AutoScaling
        
        wait_for_stack "$AUTOSCALING_STACK" "CREATE"
    fi
    
    print_success "Auto-scaling stack deployed successfully"
}

# Function to display lab information
display_lab_info() {
    print_success "ECS Orchestration Lab deployed successfully!"
    echo
    print_status "Lab Resources:"
    
    # Get ALB DNS name
    local alb_dns=$(get_stack_output "$INFRASTRUCTURE_STACK" "ApplicationLoadBalancerDNS")
    local service_url=$(get_stack_output "$SERVICE_STACK" "ServiceURL")
    local dashboard_url=$(get_stack_output "$AUTOSCALING_STACK" "DashboardURL")
    
    echo "  • ECS Cluster: $CLUSTER_NAME"
    echo "  • Service Name: $SERVICE_NAME"
    echo "  • Load Balancer: $alb_dns"
    echo "  • Service URL: $service_url"
    echo "  • CloudWatch Dashboard: $dashboard_url"
    echo
    
    print_status "Next Steps:"
    echo "  1. Test the service by accessing: $service_url"
    echo "  2. Monitor metrics in the CloudWatch dashboard"
    echo "  3. Generate load to test auto-scaling:"
    echo "     ab -n 1000 -c 10 $service_url"
    echo "  4. Check service discovery:"
    echo "     aws servicediscovery list-services --region $REGION"
    echo "  5. View ECS service details:"
    echo "     aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $REGION"
    echo
    
    print_warning "Remember to clean up resources when done:"
    echo "  ./cleanup-ecs-lab.sh"
}

# Function to validate prerequisites
validate_prerequisites() {
    print_status "Validating prerequisites..."
    
    # Check if required tools are installed
    local tools=("aws" "jq")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            print_error "$tool is not installed. Please install it first."
            exit 1
        fi
    done
    
    # Check AWS CLI version
    local aws_version=$(aws --version 2>&1 | cut -d/ -f2 | cut -d' ' -f1)
    print_status "AWS CLI version: $aws_version"
    
    print_success "All prerequisites validated"
}

# Main execution
main() {
    echo "=========================================="
    echo "ECS Orchestration Lab Provisioning"
    echo "=========================================="
    echo
    
    validate_prerequisites
    check_aws_cli
    
    print_status "Starting deployment in region: $REGION"
    print_status "Stack prefix: $STACK_PREFIX"
    echo
    
    # Deploy stacks in order
    deploy_infrastructure
    deploy_service
    deploy_autoscaling
    
    # Display lab information
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