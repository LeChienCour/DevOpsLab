#!/bin/bash

# Rolling Deployment Lab Provisioning Script
# This script provisions AWS resources for rolling deployment demonstrations

set -e

# Configuration
STACK_PREFIX="rolling-lab"
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

# Function to deploy ECS rolling deployment stack
deploy_ecs_stack() {
    print_status "Deploying ECS Rolling Deployment stack..."
    
    aws cloudformation deploy \
        --template-file ../templates/ecs-rolling-deployment.yaml \
        --stack-name "${STACK_PREFIX}-ecs" \
        --parameter-overrides \
            VpcId=$VPC_ID \
            SubnetIds=$SUBNET_IDS \
            ApplicationName="rolling-ecs-demo" \
            ImageUri="nginx:1.20" \
            DesiredCount=4 \
        --capabilities CAPABILITY_IAM \
        --profile $PROFILE \
        --region $REGION
    
    if [ $? -eq 0 ]; then
        print_status "ECS Rolling Deployment stack deployed successfully"
        
        # Get outputs
        ECS_ALB_DNS=$(aws cloudformation describe-stacks \
            --stack-name "${STACK_PREFIX}-ecs" \
            --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' \
            --output text \
            --profile $PROFILE \
            --region $REGION)
        
        ECS_CLUSTER=$(aws cloudformation describe-stacks \
            --stack-name "${STACK_PREFIX}-ecs" \
            --query 'Stacks[0].Outputs[?OutputKey==`ECSCluster`].OutputValue' \
            --output text \
            --profile $PROFILE \
            --region $REGION)
        
        ECS_SERVICE=$(aws cloudformation describe-stacks \
            --stack-name "${STACK_PREFIX}-ecs" \
            --query 'Stacks[0].Outputs[?OutputKey==`ECSService`].OutputValue' \
            --output text \
            --profile $PROFILE \
            --region $REGION)
        
        ECS_TARGET_GROUP=$(aws cloudformation describe-stacks \
            --stack-name "${STACK_PREFIX}-ecs" \
            --query 'Stacks[0].Outputs[?OutputKey==`TargetGroupArn`].OutputValue' \
            --output text \
            --profile $PROFILE \
            --region $REGION)
        
        print_status "ECS Application URL: http://$ECS_ALB_DNS"
    else
        print_error "Failed to deploy ECS Rolling Deployment stack"
        exit 1
    fi
}

# Function to deploy ASG rolling deployment stack
deploy_asg_stack() {
    print_status "Deploying Auto Scaling Group Rolling Deployment stack..."
    
    aws cloudformation deploy \
        --template-file ../templates/asg-rolling-deployment.yaml \
        --stack-name "${STACK_PREFIX}-asg" \
        --parameter-overrides \
            VpcId=$VPC_ID \
            SubnetIds=$SUBNET_IDS \
            ApplicationName="rolling-asg-demo" \
            InstanceType="t3.micro" \
            MinSize=2 \
            MaxSize=6 \
            DesiredCapacity=4 \
        --capabilities CAPABILITY_IAM \
        --profile $PROFILE \
        --region $REGION
    
    if [ $? -eq 0 ]; then
        print_status "ASG Rolling Deployment stack deployed successfully"
        
        # Get outputs
        ASG_ALB_DNS=$(aws cloudformation describe-stacks \
            --stack-name "${STACK_PREFIX}-asg" \
            --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' \
            --output text \
            --profile $PROFILE \
            --region $REGION)
        
        ASG_NAME=$(aws cloudformation describe-stacks \
            --stack-name "${STACK_PREFIX}-asg" \
            --query 'Stacks[0].Outputs[?OutputKey==`AutoScalingGroupName`].OutputValue' \
            --output text \
            --profile $PROFILE \
            --region $REGION)
        
        ASG_TARGET_GROUP=$(aws cloudformation describe-stacks \
            --stack-name "${STACK_PREFIX}-asg" \
            --query 'Stacks[0].Outputs[?OutputKey==`TargetGroupArn`].OutputValue' \
            --output text \
            --profile $PROFILE \
            --region $REGION)
        
        print_status "ASG Application URL: http://$ASG_ALB_DNS"
    else
        print_error "Failed to deploy ASG Rolling Deployment stack"
        exit 1
    fi
}

# Function to deploy health check automation stack for ECS
deploy_ecs_health_stack() {
    print_status "Deploying ECS Health Check Automation stack..."
    
    # Get ALB ARN from ECS stack
    ECS_ALB_ARN=$(aws cloudformation describe-stack-resources \
        --stack-name "${STACK_PREFIX}-ecs" \
        --logical-resource-id "ApplicationLoadBalancer" \
        --query 'StackResources[0].PhysicalResourceId' \
        --output text \
        --profile $PROFILE \
        --region $REGION)
    
    aws cloudformation deploy \
        --template-file ../templates/health-check-automation.yaml \
        --stack-name "${STACK_PREFIX}-ecs-health" \
        --parameter-overrides \
            ApplicationName="rolling-ecs-demo" \
            LoadBalancerArn=$ECS_ALB_ARN \
            TargetGroupArn=$ECS_TARGET_GROUP \
            ECSClusterName=$ECS_CLUSTER \
            ECSServiceName=$ECS_SERVICE \
        --capabilities CAPABILITY_IAM \
        --profile $PROFILE \
        --region $REGION
    
    if [ $? -eq 0 ]; then
        print_status "ECS Health Check Automation stack deployed successfully"
        
        # Get dashboard URL
        ECS_DASHBOARD_URL=$(aws cloudformation describe-stacks \
            --stack-name "${STACK_PREFIX}-ecs-health" \
            --query 'Stacks[0].Outputs[?OutputKey==`HealthDashboardURL`].OutputValue' \
            --output text \
            --profile $PROFILE \
            --region $REGION)
        
        print_status "ECS Health Dashboard: $ECS_DASHBOARD_URL"
    else
        print_error "Failed to deploy ECS Health Check Automation stack"
        exit 1
    fi
}

# Function to deploy health check automation stack for ASG
deploy_asg_health_stack() {
    print_status "Deploying ASG Health Check Automation stack..."
    
    # Get ALB ARN from ASG stack
    ASG_ALB_ARN=$(aws cloudformation describe-stack-resources \
        --stack-name "${STACK_PREFIX}-asg" \
        --logical-resource-id "ApplicationLoadBalancer" \
        --query 'StackResources[0].PhysicalResourceId' \
        --output text \
        --profile $PROFILE \
        --region $REGION)
    
    aws cloudformation deploy \
        --template-file ../templates/health-check-automation.yaml \
        --stack-name "${STACK_PREFIX}-asg-health" \
        --parameter-overrides \
            ApplicationName="rolling-asg-demo" \
            LoadBalancerArn=$ASG_ALB_ARN \
            TargetGroupArn=$ASG_TARGET_GROUP \
            AutoScalingGroupName=$ASG_NAME \
        --capabilities CAPABILITY_IAM \
        --profile $PROFILE \
        --region $REGION
    
    if [ $? -eq 0 ]; then
        print_status "ASG Health Check Automation stack deployed successfully"
        
        # Get dashboard URL
        ASG_DASHBOARD_URL=$(aws cloudformation describe-stacks \
            --stack-name "${STACK_PREFIX}-asg-health" \
            --query 'Stacks[0].Outputs[?OutputKey==`HealthDashboardURL`].OutputValue' \
            --output text \
            --profile $PROFILE \
            --region $REGION)
        
        print_status "ASG Health Dashboard: $ASG_DASHBOARD_URL"
    else
        print_error "Failed to deploy ASG Health Check Automation stack"
        exit 1
    fi
}

# Function to create helper scripts
create_helper_scripts() {
    print_status "Creating helper scripts..."
    
    # ECS deployment script
    cat > ecs-deploy.sh << 'EOF'
#!/bin/bash

# ECS Rolling Deployment Helper Script
CLUSTER_NAME="rolling-ecs-demo-cluster"
SERVICE_NAME="rolling-ecs-demo-service"
TASK_FAMILY="rolling-ecs-demo-task"
REGION=${AWS_DEFAULT_REGION:-us-east-1}
PROFILE=${AWS_PROFILE:-default}

deploy_new_version() {
    local new_image=$1
    local new_version=${2:-"2.0.0"}
    
    if [ -z "$new_image" ]; then
        echo "Usage: $0 deploy <new_image_uri> [version]"
        exit 1
    fi
    
    echo "Deploying new version with image: $new_image"
    
    # Get current task definition
    aws ecs describe-task-definition \
        --task-definition $TASK_FAMILY \
        --query taskDefinition > current-task-def.json
    
    # Update image and version in task definition
    jq --arg image "$new_image" --arg version "$new_version" '
        .containerDefinitions[0].image = $image |
        .containerDefinitions[0].environment = [
            {"name": "VERSION", "value": $version},
            {"name": "ENVIRONMENT", "value": "production"},
            {"name": "DEPLOYMENT_TYPE", "value": "rolling"}
        ] |
        del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .placementConstraints, .compatibilities, .registeredAt, .registeredBy)
    ' current-task-def.json > new-task-def.json
    
    # Register new task definition
    NEW_TASK_DEF=$(aws ecs register-task-definition \
        --cli-input-json file://new-task-def.json \
        --query 'taskDefinition.taskDefinitionArn' \
        --output text \
        --profile $PROFILE \
        --region $REGION)
    
    echo "New task definition registered: $NEW_TASK_DEF"
    
    # Update service
    aws ecs update-service \
        --cluster $CLUSTER_NAME \
        --service $SERVICE_NAME \
        --task-definition $NEW_TASK_DEF \
        --profile $PROFILE \
        --region $REGION
    
    echo "Service update initiated. Monitor progress with: $0 status"
    
    # Cleanup
    rm -f current-task-def.json new-task-def.json
}

check_status() {
    echo "Checking deployment status..."
    
    aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services $SERVICE_NAME \
        --query 'services[0].deployments[?status==`PRIMARY`].[status,runningCount,pendingCount,desiredCount,rolloutState]' \
        --output table \
        --profile $PROFILE \
        --region $REGION
}

monitor_deployment() {
    echo "Monitoring deployment progress..."
    
    while true; do
        status=$(aws ecs describe-services \
            --cluster $CLUSTER_NAME \
            --services $SERVICE_NAME \
            --query 'services[0].deployments[?status==`PRIMARY`].rolloutState' \
            --output text \
            --profile $PROFILE \
            --region $REGION)
        
        echo "$(date): Deployment status: $status"
        
        if [ "$status" = "COMPLETED" ]; then
            echo "Deployment completed successfully!"
            break
        elif [ "$status" = "FAILED" ]; then
            echo "Deployment failed!"
            break
        fi
        
        sleep 30
    done
}

case "$1" in
    "deploy")
        deploy_new_version $2 $3
        ;;
    "status")
        check_status
        ;;
    "monitor")
        monitor_deployment
        ;;
    *)
        echo "Usage: $0 {deploy|status|monitor}"
        echo "Examples:"
        echo "  $0 deploy nginx:1.21 2.0.0"
        echo "  $0 status"
        echo "  $0 monitor"
        exit 1
        ;;
esac
EOF
    
    # ASG deployment script
    cat > asg-deploy.sh << 'EOF'
#!/bin/bash

# ASG Rolling Deployment Helper Script
ASG_NAME="rolling-asg-demo-asg"
LAUNCH_TEMPLATE_NAME="rolling-asg-demo-launch-template"
REGION=${AWS_DEFAULT_REGION:-us-east-1}
PROFILE=${AWS_PROFILE:-default}

deploy_new_version() {
    local new_version=${1:-"2.0.0"}
    
    echo "Deploying new version: $new_version"
    
    # Get current launch template
    TEMPLATE_ID=$(aws ec2 describe-launch-templates \
        --launch-template-names $LAUNCH_TEMPLATE_NAME \
        --query 'LaunchTemplates[0].LaunchTemplateId' \
        --output text \
        --profile $PROFILE \
        --region $REGION)
    
    # Create new user data with updated version
    cat > new-user-data.sh << 'USERDATA'
#!/bin/bash
yum update -y
yum install -y httpd awscli

systemctl start httpd
systemctl enable httpd

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)

cat > /var/www/html/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>Rolling Deployment Demo</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            text-align: center; 
            padding: 50px;
            background: linear-gradient(135deg, #ff6b6b 0%, #4ecdc4 100%);
            color: white;
        }
        .container {
            background: rgba(255,255,255,0.1);
            padding: 30px;
            border-radius: 10px;
            backdrop-filter: blur(10px);
        }
        .version { color: #ffeb3b; font-size: 1.2em; }
        .instance { color: #4caf50; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Rolling Deployment Demo - UPDATED!</h1>
        <p class="version">Version: NEW_VERSION_PLACEHOLDER</p>
        <p class="instance">Instance ID: INSTANCE_ID_PLACEHOLDER</p>
        <p>Availability Zone: AZ_PLACEHOLDER</p>
        <p>Deployment Type: Rolling Update</p>
        <p>New Feature: Enhanced UI with gradient background!</p>
        <p>Timestamp: $(date)</p>
    </div>
</body>
</html>
HTML

sed -i "s/NEW_VERSION_PLACEHOLDER/$new_version/g" /var/www/html/index.html
sed -i "s/INSTANCE_ID_PLACEHOLDER/$INSTANCE_ID/g" /var/www/html/index.html
sed -i "s/AZ_PLACEHOLDER/$AZ/g" /var/www/html/index.html

cat > /var/www/html/health << 'HTML'
OK
HTML

cat > /var/www/html/version << 'HTML'
{"version": "NEW_VERSION_PLACEHOLDER", "deployment_type": "rolling"}
HTML

sed -i "s/NEW_VERSION_PLACEHOLDER/$new_version/g" /var/www/html/version

aws cloudwatch put-metric-data \
    --namespace "rolling-asg-demo/Deployment" \
    --metric-data MetricName=InstanceReady,Value=1,Unit=Count \
    --region $REGION
USERDATA
    
    # Replace version placeholder
    sed -i "s/NEW_VERSION_PLACEHOLDER/$new_version/g" new-user-data.sh
    
    # Encode user data
    USER_DATA_ENCODED=$(base64 -w 0 new-user-data.sh)
    
    # Create new launch template version
    NEW_VERSION=$(aws ec2 create-launch-template-version \
        --launch-template-id $TEMPLATE_ID \
        --launch-template-data "{\"UserData\":\"$USER_DATA_ENCODED\"}" \
        --version-description "Updated version $new_version" \
        --query 'LaunchTemplateVersion.VersionNumber' \
        --output text \
        --profile $PROFILE \
        --region $REGION)
    
    echo "New launch template version created: $NEW_VERSION"
    
    # Start instance refresh
    REFRESH_ID=$(aws autoscaling start-instance-refresh \
        --auto-scaling-group-name $ASG_NAME \
        --strategy Rolling \
        --preferences '{
            "InstanceWarmup": 300,
            "MinHealthyPercentage": 50,
            "CheckpointPercentages": [25, 50, 75],
            "CheckpointDelay": 300
        }' \
        --query 'InstanceRefreshId' \
        --output text \
        --profile $PROFILE \
        --region $REGION)
    
    echo "Instance refresh started: $REFRESH_ID"
    echo "Monitor progress with: $0 status"
    
    # Cleanup
    rm -f new-user-data.sh
}

check_status() {
    echo "Checking deployment status..."
    
    aws autoscaling describe-instance-refreshes \
        --auto-scaling-group-name $ASG_NAME \
        --max-records 1 \
        --query 'InstanceRefreshes[0].[Status,PercentageComplete,InstancesToUpdate]' \
        --output table \
        --profile $PROFILE \
        --region $REGION
}

monitor_deployment() {
    echo "Monitoring deployment progress..."
    
    while true; do
        refresh_info=$(aws autoscaling describe-instance-refreshes \
            --auto-scaling-group-name $ASG_NAME \
            --max-records 1 \
            --query 'InstanceRefreshes[0].[Status,PercentageComplete]' \
            --output text \
            --profile $PROFILE \
            --region $REGION)
        
        status=$(echo $refresh_info | cut -d' ' -f1)
        percentage=$(echo $refresh_info | cut -d' ' -f2)
        
        echo "$(date): Status: $status, Progress: $percentage%"
        
        if [ "$status" = "Successful" ]; then
            echo "Deployment completed successfully!"
            break
        elif [ "$status" = "Failed" ] || [ "$status" = "Cancelled" ]; then
            echo "Deployment failed or was cancelled!"
            break
        fi
        
        sleep 30
    done
}

case "$1" in
    "deploy")
        deploy_new_version $2
        ;;
    "status")
        check_status
        ;;
    "monitor")
        monitor_deployment
        ;;
    *)
        echo "Usage: $0 {deploy|status|monitor}"
        echo "Examples:"
        echo "  $0 deploy 2.0.0"
        echo "  $0 status"
        echo "  $0 monitor"
        exit 1
        ;;
esac
EOF
    
    chmod +x ecs-deploy.sh asg-deploy.sh
    print_status "Helper scripts created: ecs-deploy.sh, asg-deploy.sh"
}

# Function to display lab information
display_lab_info() {
    print_status "Rolling Deployment Lab Resources Created Successfully!"
    echo ""
    echo "=== Lab Resources ==="
    echo "ECS Application URL: http://$ECS_ALB_DNS"
    echo "ASG Application URL: http://$ASG_ALB_DNS"
    echo "ECS Health Dashboard: $ECS_DASHBOARD_URL"
    echo "ASG Health Dashboard: $ASG_DASHBOARD_URL"
    echo ""
    echo "=== Deployment Scripts ==="
    echo "ECS Rolling Deployment:"
    echo "  ./ecs-deploy.sh deploy nginx:1.21 2.0.0"
    echo "  ./ecs-deploy.sh status"
    echo "  ./ecs-deploy.sh monitor"
    echo ""
    echo "ASG Rolling Deployment:"
    echo "  ./asg-deploy.sh deploy 2.0.0"
    echo "  ./asg-deploy.sh status"
    echo "  ./asg-deploy.sh monitor"
    echo ""
    echo "=== Testing Commands ==="
    echo "Test ECS application:"
    echo "  curl http://$ECS_ALB_DNS"
    echo "  curl http://$ECS_ALB_DNS/version"
    echo ""
    echo "Test ASG application:"
    echo "  curl http://$ASG_ALB_DNS"
    echo "  curl http://$ASG_ALB_DNS/version"
    echo ""
    echo "=== Next Steps ==="
    echo "1. Test both applications at the provided URLs"
    echo "2. Monitor health dashboards for baseline metrics"
    echo "3. Perform rolling deployments using the helper scripts"
    echo "4. Observe zero-downtime deployment behavior"
    echo "5. Test health check and recovery automation"
    echo ""
    echo "=== Cleanup ==="
    echo "Run './cleanup-rolling-lab.sh' when finished with the lab"
}

# Main execution
main() {
    print_status "Starting Rolling Deployment Lab Provisioning..."
    
    check_aws_cli
    get_default_vpc_info
    deploy_ecs_stack
    deploy_asg_stack
    deploy_ecs_health_stack
    deploy_asg_health_stack
    create_helper_scripts
    display_lab_info
    
    print_status "Lab provisioning completed successfully!"
}

# Run main function
main "$@"