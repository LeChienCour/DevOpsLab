#!/bin/bash

# Canary Deployment Lab Provisioning Script
# This script provisions AWS resources for canary deployment demonstrations

set -e

# Configuration
STACK_PREFIX="canary-lab"
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
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! aws sts get-caller-identity --profile $PROFILE &> /dev/null; then
        print_error "AWS CLI is not configured or credentials are invalid."
        exit 1
    fi
    
    print_status "AWS CLI is properly configured"
}

# Function to get default VPC and subnets
get_default_vpc_info() {
    print_status "Getting default VPC information..."
    
    VPC_ID=$(aws ec2 describe-vpcs \
        --filters "Name=is-default,Values=true" \
        --query 'Vpcs[0].VpcId' \
        --output text \
        --profile $PROFILE \
        --region $REGION)
    
    if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
        print_error "No default VPC found. Please create a VPC first."
        exit 1
    fi
    
    SUBNET_IDS=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'Subnets[?MapPublicIpOnLaunch==`true`].SubnetId' \
        --output text \
        --profile $PROFILE \
        --region $REGION)
    
    if [ -z "$SUBNET_IDS" ]; then
        print_error "No public subnets found in default VPC."
        exit 1
    fi
    
    # Convert space-separated to comma-separated
    SUBNET_IDS=$(echo $SUBNET_IDS | tr ' ' ',')
    
    print_status "Using VPC: $VPC_ID"
    print_status "Using Subnets: $SUBNET_IDS"
}

# Function to deploy ALB canary stack
deploy_alb_canary_stack() {
    print_status "Deploying ALB Canary Deployment stack..."
    
    aws cloudformation deploy \
        --template-file ../templates/alb-canary-deployment.yaml \
        --stack-name "${STACK_PREFIX}-alb" \
        --parameter-overrides \
            VpcId=$VPC_ID \
            SubnetIds=$SUBNET_IDS \
            ApplicationName="canary-demo-app" \
            ProductionImageUri="nginx:1.20" \
            CanaryImageUri="nginx:1.21" \
        --capabilities CAPABILITY_IAM \
        --profile $PROFILE \
        --region $REGION
    
    if [ $? -eq 0 ]; then
        print_status "ALB Canary stack deployed successfully"
        
        # Get outputs
        ALB_DNS=$(aws cloudformation describe-stacks \
            --stack-name "${STACK_PREFIX}-alb" \
            --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' \
            --output text \
            --profile $PROFILE \
            --region $REGION)
        
        TRAFFIC_FUNCTION_ARN=$(aws cloudformation describe-stacks \
            --stack-name "${STACK_PREFIX}-alb" \
            --query 'Stacks[0].Outputs[?OutputKey==`TrafficShiftingFunctionArn`].OutputValue' \
            --output text \
            --profile $PROFILE \
            --region $REGION)
        
        print_status "Application URL: http://$ALB_DNS"
    else
        print_error "Failed to deploy ALB Canary stack"
        exit 1
    fi
}

# Function to deploy canary automation stack
deploy_automation_stack() {
    print_status "Deploying Canary Automation stack..."
    
    # Get ALB and Target Group full names from ALB stack
    ALB_FULL_NAME=$(aws cloudformation describe-stack-resources \
        --stack-name "${STACK_PREFIX}-alb" \
        --logical-resource-id "ApplicationLoadBalancer" \
        --query 'StackResources[0].PhysicalResourceId' \
        --output text \
        --profile $PROFILE \
        --region $REGION)
    
    PROD_TG_FULL_NAME=$(aws cloudformation describe-stack-resources \
        --stack-name "${STACK_PREFIX}-alb" \
        --logical-resource-id "ProductionTargetGroup" \
        --query 'StackResources[0].PhysicalResourceId' \
        --output text \
        --profile $PROFILE \
        --region $REGION)
    
    CANARY_TG_FULL_NAME=$(aws cloudformation describe-stack-resources \
        --stack-name "${STACK_PREFIX}-alb" \
        --logical-resource-id "CanaryTargetGroup" \
        --query 'StackResources[0].PhysicalResourceId' \
        --output text \
        --profile $PROFILE \
        --region $REGION)
    
    aws cloudformation deploy \
        --template-file ../templates/canary-automation.yaml \
        --stack-name "${STACK_PREFIX}-automation" \
        --parameter-overrides \
            ApplicationName="canary-demo-app" \
            LoadBalancerFullName=$ALB_FULL_NAME \
            ProductionTargetGroupFullName=$PROD_TG_FULL_NAME \
            CanaryTargetGroupFullName=$CANARY_TG_FULL_NAME \
            TrafficShiftingFunctionArn=$TRAFFIC_FUNCTION_ARN \
        --capabilities CAPABILITY_IAM \
        --profile $PROFILE \
        --region $REGION
    
    if [ $? -eq 0 ]; then
        print_status "Canary Automation stack deployed successfully"
        
        # Get dashboard URL
        DASHBOARD_URL=$(aws cloudformation describe-stacks \
            --stack-name "${STACK_PREFIX}-automation" \
            --query 'Stacks[0].Outputs[?OutputKey==`DashboardURL`].OutputValue' \
            --output text \
            --profile $PROFILE \
            --region $REGION)
        
        STATE_MACHINE_ARN=$(aws cloudformation describe-stacks \
            --stack-name "${STACK_PREFIX}-automation" \
            --query 'Stacks[0].Outputs[?OutputKey==`StateMachineArn`].OutputValue' \
            --output text \
            --profile $PROFILE \
            --region $REGION)
        
        print_status "CloudWatch Dashboard: $DASHBOARD_URL"
    else
        print_error "Failed to deploy Canary Automation stack"
        exit 1
    fi
}

# Function to deploy A/B testing stack
deploy_ab_testing_stack() {
    print_status "Deploying A/B Testing with Feature Flags stack..."
    
    aws cloudformation deploy \
        --template-file ../templates/ab-testing-feature-flags.yaml \
        --stack-name "${STACK_PREFIX}-ab-testing" \
        --parameter-overrides \
            ApplicationName="canary-demo-app" \
            VpcId=$VPC_ID \
            SubnetIds=$SUBNET_IDS \
        --capabilities CAPABILITY_IAM \
        --profile $PROFILE \
        --region $REGION
    
    if [ $? -eq 0 ]; then
        print_status "A/B Testing stack deployed successfully"
        
        # Get outputs
        API_URL=$(aws cloudformation describe-stacks \
            --stack-name "${STACK_PREFIX}-ab-testing" \
            --query 'Stacks[0].Outputs[?OutputKey==`FeatureFlagAPIUrl`].OutputValue' \
            --output text \
            --profile $PROFILE \
            --region $REGION)
        
        AB_DASHBOARD_URL=$(aws cloudformation describe-stacks \
            --stack-name "${STACK_PREFIX}-ab-testing" \
            --query 'Stacks[0].Outputs[?OutputKey==`ABTestDashboardURL`].OutputValue' \
            --output text \
            --profile $PROFILE \
            --region $REGION)
        
        print_status "Feature Flag API URL: $API_URL"
        print_status "A/B Testing Dashboard: $AB_DASHBOARD_URL"
    else
        print_error "Failed to deploy A/B Testing stack"
        exit 1
    fi
}

# Function to initialize feature flags and A/B tests
initialize_ab_tests() {
    print_status "Initializing feature flags and A/B tests..."
    
    # Set up initial feature flags
    aws lambda invoke \
        --function-name "canary-demo-app-feature-flags" \
        --payload '{
            "action": "set_flag",
            "flag_name": "new_ui_design",
            "user_segment": "default",
            "enabled": true,
            "rollout_percentage": 10,
            "variant": "B"
        }' \
        --profile $PROFILE \
        --region $REGION \
        /tmp/response.json
    
    if [ $? -eq 0 ]; then
        print_status "Feature flag 'new_ui_design' created with 10% rollout"
    fi
    
    # Set up canary feature flag
    aws lambda invoke \
        --function-name "canary-demo-app-feature-flags" \
        --payload '{
            "action": "set_flag",
            "flag_name": "canary_deployment",
            "user_segment": "default",
            "enabled": true,
            "rollout_percentage": 5,
            "variant": "canary"
        }' \
        --profile $PROFILE \
        --region $REGION \
        /tmp/response.json
    
    if [ $? -eq 0 ]; then
        print_status "Feature flag 'canary_deployment' created with 5% rollout"
    fi
    
    # Clean up temp file
    rm -f /tmp/response.json
}

# Function to create sample traffic shifting script
create_traffic_script() {
    print_status "Creating traffic shifting helper script..."
    
    cat > traffic-shift.sh << 'EOF'
#!/bin/bash

# Traffic Shifting Helper Script
FUNCTION_NAME="canary-demo-app-traffic-shifting"
REGION=${AWS_DEFAULT_REGION:-us-east-1}
PROFILE=${AWS_PROFILE:-default}

shift_traffic() {
    local action=$1
    local step=${2:-10}
    
    aws lambda invoke \
        --function-name $FUNCTION_NAME \
        --payload "{\"action\": \"$action\", \"step\": $step}" \
        --profile $PROFILE \
        --region $REGION \
        /tmp/traffic-response.json
    
    cat /tmp/traffic-response.json
    rm -f /tmp/traffic-response.json
}

case "$1" in
    "increase")
        shift_traffic "increase" $2
        ;;
    "decrease")
        shift_traffic "decrease" $2
        ;;
    "rollback")
        shift_traffic "rollback"
        ;;
    "promote")
        shift_traffic "promote"
        ;;
    *)
        echo "Usage: $0 {increase|decrease|rollback|promote} [step_percentage]"
        echo "Examples:"
        echo "  $0 increase 10    # Increase canary traffic by 10%"
        echo "  $0 decrease 5     # Decrease canary traffic by 5%"
        echo "  $0 rollback       # Rollback to 0% canary traffic"
        echo "  $0 promote        # Promote canary to 100%"
        exit 1
        ;;
esac
EOF
    
    chmod +x traffic-shift.sh
    print_status "Traffic shifting script created: ./traffic-shift.sh"
}

# Function to display lab information
display_lab_info() {
    print_status "Canary Deployment Lab Resources Created Successfully!"
    echo ""
    echo "=== Lab Resources ==="
    echo "Application URL: http://$ALB_DNS"
    echo "CloudWatch Dashboard: $DASHBOARD_URL"
    echo "A/B Testing Dashboard: $AB_DASHBOARD_URL"
    echo "Feature Flag API: $API_URL"
    echo "Step Functions State Machine: $STATE_MACHINE_ARN"
    echo ""
    echo "=== Traffic Management ==="
    echo "Use the traffic-shift.sh script to manage canary traffic:"
    echo "  ./traffic-shift.sh increase 10   # Increase canary to 20%"
    echo "  ./traffic-shift.sh decrease 5    # Decrease canary by 5%"
    echo "  ./traffic-shift.sh rollback      # Rollback to production"
    echo "  ./traffic-shift.sh promote       # Promote canary to 100%"
    echo ""
    echo "=== Feature Flag Examples ==="
    echo "Get user variant:"
    echo "  curl -X GET '$API_URL/flags?flag_name=new_ui_design&user_id=user123'"
    echo ""
    echo "Record A/B test event:"
    echo "  curl -X POST '$API_URL/ab-test' -d '{\"action\":\"record_event\",\"test_id\":\"ui_test\",\"user_id\":\"user123\",\"variant\":\"B\",\"event_type\":\"conversion\"}'"
    echo ""
    echo "=== Next Steps ==="
    echo "1. Test the application at the provided URL"
    echo "2. Monitor canary metrics in the CloudWatch dashboard"
    echo "3. Use traffic shifting to gradually increase canary traffic"
    echo "4. Test feature flags and A/B testing functionality"
    echo "5. Trigger automated rollback by causing errors"
    echo ""
    echo "=== Cleanup ==="
    echo "Run './cleanup-canary-lab.sh' when finished with the lab"
}

# Main execution
main() {
    print_status "Starting Canary Deployment Lab Provisioning..."
    
    check_aws_cli
    get_default_vpc_info
    deploy_alb_canary_stack
    deploy_automation_stack
    deploy_ab_testing_stack
    initialize_ab_tests
    create_traffic_script
    display_lab_info
    
    print_status "Lab provisioning completed successfully!"
}

# Run main function
main "$@"