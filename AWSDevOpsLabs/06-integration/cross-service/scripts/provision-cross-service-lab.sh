#!/bin/bash

# Cross-Service Communication Lab Provisioning Script
# This script provisions AWS App Mesh, SQS/SNS messaging, and circuit breaker infrastructure

set -e

# Configuration
STACK_PREFIX="cross-service-lab"
REGION=${AWS_DEFAULT_REGION:-us-east-1}
VPC_STACK_NAME="${STACK_PREFIX}-vpc"
MESH_STACK_NAME="${STACK_PREFIX}-mesh"
MESSAGING_STACK_NAME="${STACK_PREFIX}-messaging"
CIRCUIT_BREAKER_STACK_NAME="${STACK_PREFIX}-circuit-breaker"
ECS_STACK_NAME="${STACK_PREFIX}-ecs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if AWS CLI is configured
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi

    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS CLI is not configured. Please run 'aws configure' first."
        exit 1
    fi

    log_success "AWS CLI is configured"
}

# Function to check if stack exists
stack_exists() {
    local stack_name=$1
    aws cloudformation describe-stacks --stack-name "$stack_name" --region "$REGION" &> /dev/null
}

# Function to wait for stack operation to complete
wait_for_stack() {
    local stack_name=$1
    local operation=$2
    
    log_info "Waiting for stack $stack_name to $operation..."
    
    aws cloudformation wait "stack-${operation}-complete" \
        --stack-name "$stack_name" \
        --region "$REGION"
    
    if [ $? -eq 0 ]; then
        log_success "Stack $stack_name ${operation}d successfully"
    else
        log_error "Stack $stack_name failed to $operation"
        exit 1
    fi
}

# Function to get stack output
get_stack_output() {
    local stack_name=$1
    local output_key=$2
    
    aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$REGION" \
        --query "Stacks[0].Outputs[?OutputKey=='$output_key'].OutputValue" \
        --output text
}

# Function to create VPC if it doesn't exist
create_vpc_stack() {
    if stack_exists "$VPC_STACK_NAME"; then
        log_info "VPC stack already exists, skipping creation"
        return
    fi

    log_info "Creating VPC stack..."
    
    cat > /tmp/vpc-template.yaml << 'EOF'
AWSTemplateFormatVersion: '2010-09-09'
Description: 'VPC infrastructure for cross-service communication lab'

Resources:
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: 10.0.0.0/16
      EnableDnsHostnames: true
      EnableDnsSupport: true
      Tags:
        - Key: Name
          Value: cross-service-vpc

  InternetGateway:
    Type: AWS::EC2::InternetGateway
    Properties:
      Tags:
        - Key: Name
          Value: cross-service-igw

  AttachGateway:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      VpcId: !Ref VPC
      InternetGatewayId: !Ref InternetGateway

  PublicSubnet1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.1.0/24
      AvailabilityZone: !Select [0, !GetAZs '']
      MapPublicIpOnLaunch: true
      Tags:
        - Key: Name
          Value: cross-service-public-1

  PublicSubnet2:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.2.0/24
      AvailabilityZone: !Select [1, !GetAZs '']
      MapPublicIpOnLaunch: true
      Tags:
        - Key: Name
          Value: cross-service-public-2

  PrivateSubnet1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.3.0/24
      AvailabilityZone: !Select [0, !GetAZs '']
      Tags:
        - Key: Name
          Value: cross-service-private-1

  PrivateSubnet2:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.4.0/24
      AvailabilityZone: !Select [1, !GetAZs '']
      Tags:
        - Key: Name
          Value: cross-service-private-2

  NATGateway1EIP:
    Type: AWS::EC2::EIP
    DependsOn: AttachGateway
    Properties:
      Domain: vpc

  NATGateway2EIP:
    Type: AWS::EC2::EIP
    DependsOn: AttachGateway
    Properties:
      Domain: vpc

  NATGateway1:
    Type: AWS::EC2::NatGateway
    Properties:
      AllocationId: !GetAtt NATGateway1EIP.AllocationId
      SubnetId: !Ref PublicSubnet1

  NATGateway2:
    Type: AWS::EC2::NatGateway
    Properties:
      AllocationId: !GetAtt NATGateway2EIP.AllocationId
      SubnetId: !Ref PublicSubnet2

  PublicRouteTable:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC
      Tags:
        - Key: Name
          Value: cross-service-public-rt

  DefaultPublicRoute:
    Type: AWS::EC2::Route
    DependsOn: AttachGateway
    Properties:
      RouteTableId: !Ref PublicRouteTable
      DestinationCidrBlock: 0.0.0.0/0
      GatewayId: !Ref InternetGateway

  PublicSubnet1RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      RouteTableId: !Ref PublicRouteTable
      SubnetId: !Ref PublicSubnet1

  PublicSubnet2RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      RouteTableId: !Ref PublicRouteTable
      SubnetId: !Ref PublicSubnet2

  PrivateRouteTable1:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC
      Tags:
        - Key: Name
          Value: cross-service-private-rt-1

  DefaultPrivateRoute1:
    Type: AWS::EC2::Route
    Properties:
      RouteTableId: !Ref PrivateRouteTable1
      DestinationCidrBlock: 0.0.0.0/0
      NatGatewayId: !Ref NATGateway1

  PrivateSubnet1RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      RouteTableId: !Ref PrivateRouteTable1
      SubnetId: !Ref PrivateSubnet1

  PrivateRouteTable2:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC
      Tags:
        - Key: Name
          Value: cross-service-private-rt-2

  DefaultPrivateRoute2:
    Type: AWS::EC2::Route
    Properties:
      RouteTableId: !Ref PrivateRouteTable2
      DestinationCidrBlock: 0.0.0.0/0
      NatGatewayId: !Ref NATGateway2

  PrivateSubnet2RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      RouteTableId: !Ref PrivateRouteTable2
      SubnetId: !Ref PrivateSubnet2

Outputs:
  VpcId:
    Description: VPC ID
    Value: !Ref VPC
    Export:
      Name: !Sub ${AWS::StackName}-VpcId

  PrivateSubnetIds:
    Description: Private subnet IDs
    Value: !Join [',', [!Ref PrivateSubnet1, !Ref PrivateSubnet2]]
    Export:
      Name: !Sub ${AWS::StackName}-PrivateSubnetIds

  PublicSubnetIds:
    Description: Public subnet IDs
    Value: !Join [',', [!Ref PublicSubnet1, !Ref PublicSubnet2]]
    Export:
      Name: !Sub ${AWS::StackName}-PublicSubnetIds
EOF

    aws cloudformation create-stack \
        --stack-name "$VPC_STACK_NAME" \
        --template-body file:///tmp/vpc-template.yaml \
        --region "$REGION" \
        --tags Key=Project,Value=CrossServiceLab Key=Environment,Value=Lab

    wait_for_stack "$VPC_STACK_NAME" "create"
    rm /tmp/vpc-template.yaml
}

# Function to deploy App Mesh infrastructure
deploy_mesh_stack() {
    local vpc_id=$(get_stack_output "$VPC_STACK_NAME" "VpcId")
    local private_subnets=$(get_stack_output "$VPC_STACK_NAME" "PrivateSubnetIds")
    
    log_info "Deploying App Mesh infrastructure..."
    
    if stack_exists "$MESH_STACK_NAME"; then
        log_info "Updating existing App Mesh stack..."
        aws cloudformation update-stack \
            --stack-name "$MESH_STACK_NAME" \
            --template-body file://templates/app-mesh-infrastructure.yaml \
            --parameters ParameterKey=VpcId,ParameterValue="$vpc_id" \
                        ParameterKey=PrivateSubnetIds,ParameterValue="$private_subnets" \
            --region "$REGION" \
            --tags Key=Project,Value=CrossServiceLab Key=Environment,Value=Lab
        
        wait_for_stack "$MESH_STACK_NAME" "update"
    else
        aws cloudformation create-stack \
            --stack-name "$MESH_STACK_NAME" \
            --template-body file://templates/app-mesh-infrastructure.yaml \
            --parameters ParameterKey=VpcId,ParameterValue="$vpc_id" \
                        ParameterKey=PrivateSubnetIds,ParameterValue="$private_subnets" \
            --region "$REGION" \
            --tags Key=Project,Value=CrossServiceLab Key=Environment,Value=Lab
        
        wait_for_stack "$MESH_STACK_NAME" "create"
    fi
}

# Function to deploy messaging infrastructure
deploy_messaging_stack() {
    log_info "Deploying messaging infrastructure..."
    
    if stack_exists "$MESSAGING_STACK_NAME"; then
        log_info "Updating existing messaging stack..."
        aws cloudformation update-stack \
            --stack-name "$MESSAGING_STACK_NAME" \
            --template-body file://templates/messaging-infrastructure.yaml \
            --capabilities CAPABILITY_NAMED_IAM \
            --region "$REGION" \
            --tags Key=Project,Value=CrossServiceLab Key=Environment,Value=Lab
        
        wait_for_stack "$MESSAGING_STACK_NAME" "update"
    else
        aws cloudformation create-stack \
            --stack-name "$MESSAGING_STACK_NAME" \
            --template-body file://templates/messaging-infrastructure.yaml \
            --capabilities CAPABILITY_NAMED_IAM \
            --region "$REGION" \
            --tags Key=Project,Value=CrossServiceLab Key=Environment,Value=Lab
        
        wait_for_stack "$MESSAGING_STACK_NAME" "create"
    fi
}

# Function to deploy circuit breaker functions
deploy_circuit_breaker_stack() {
    local vpc_id=$(get_stack_output "$VPC_STACK_NAME" "VpcId")
    local private_subnets=$(get_stack_output "$VPC_STACK_NAME" "PrivateSubnetIds")
    
    log_info "Deploying circuit breaker functions..."
    
    if stack_exists "$CIRCUIT_BREAKER_STACK_NAME"; then
        log_info "Updating existing circuit breaker stack..."
        aws cloudformation update-stack \
            --stack-name "$CIRCUIT_BREAKER_STACK_NAME" \
            --template-body file://templates/circuit-breaker-functions.yaml \
            --parameters ParameterKey=VpcId,ParameterValue="$vpc_id" \
                        ParameterKey=PrivateSubnetIds,ParameterValue="$private_subnets" \
            --capabilities CAPABILITY_NAMED_IAM \
            --region "$REGION" \
            --tags Key=Project,Value=CrossServiceLab Key=Environment,Value=Lab
        
        wait_for_stack "$CIRCUIT_BREAKER_STACK_NAME" "update"
    else
        aws cloudformation create-stack \
            --stack-name "$CIRCUIT_BREAKER_STACK_NAME" \
            --template-body file://templates/circuit-breaker-functions.yaml \
            --parameters ParameterKey=VpcId,ParameterValue="$vpc_id" \
                        ParameterKey=PrivateSubnetIds,ParameterValue="$private_subnets" \
            --capabilities CAPABILITY_NAMED_IAM \
            --region "$REGION" \
            --tags Key=Project,Value=CrossServiceLab Key=Environment,Value=Lab
        
        wait_for_stack "$CIRCUIT_BREAKER_STACK_NAME" "create"
    fi
}

# Function to deploy ECS services
deploy_ecs_stack() {
    local vpc_id=$(get_stack_output "$VPC_STACK_NAME" "VpcId")
    local private_subnets=$(get_stack_output "$VPC_STACK_NAME" "PrivateSubnetIds")
    local mesh_name=$(get_stack_output "$MESH_STACK_NAME" "MeshName")
    local namespace_id=$(get_stack_output "$MESH_STACK_NAME" "ServiceDiscoveryNamespaceId")
    local messaging_role=$(get_stack_output "$MESSAGING_STACK_NAME" "MessagingServiceRoleArn")
    
    log_info "Deploying ECS services..."
    
    if stack_exists "$ECS_STACK_NAME"; then
        log_info "Updating existing ECS stack..."
        aws cloudformation update-stack \
            --stack-name "$ECS_STACK_NAME" \
            --template-body file://templates/ecs-services-with-mesh.yaml \
            --parameters ParameterKey=VpcId,ParameterValue="$vpc_id" \
                        ParameterKey=PrivateSubnetIds,ParameterValue="$private_subnets" \
                        ParameterKey=MeshName,ParameterValue="$mesh_name" \
                        ParameterKey=ServiceDiscoveryNamespaceId,ParameterValue="$namespace_id" \
                        ParameterKey=MessagingRoleArn,ParameterValue="$messaging_role" \
            --capabilities CAPABILITY_NAMED_IAM \
            --region "$REGION" \
            --tags Key=Project,Value=CrossServiceLab Key=Environment,Value=Lab
        
        wait_for_stack "$ECS_STACK_NAME" "update"
    else
        aws cloudformation create-stack \
            --stack-name "$ECS_STACK_NAME" \
            --template-body file://templates/ecs-services-with-mesh.yaml \
            --parameters ParameterKey=VpcId,ParameterValue="$vpc_id" \
                        ParameterKey=PrivateSubnetIds,ParameterValue="$private_subnets" \
                        ParameterKey=MeshName,ParameterValue="$mesh_name" \
                        ParameterKey=ServiceDiscoveryNamespaceId,ParameterValue="$namespace_id" \
                        ParameterKey=MessagingRoleArn,ParameterValue="$messaging_role" \
            --capabilities CAPABILITY_NAMED_IAM \
            --region "$REGION" \
            --tags Key=Project,Value=CrossServiceLab Key=Environment,Value=Lab
        
        wait_for_stack "$ECS_STACK_NAME" "create"
    fi
}

# Function to display lab information
display_lab_info() {
    log_success "Cross-Service Communication Lab deployed successfully!"
    echo
    echo "Lab Resources:"
    echo "=============="
    
    local mesh_name=$(get_stack_output "$MESH_STACK_NAME" "MeshName")
    local alb_dns=$(get_stack_output "$ECS_STACK_NAME" "LoadBalancerDNS")
    local dashboard_url=$(get_stack_output "$CIRCUIT_BREAKER_STACK_NAME" "CircuitBreakerDashboardUrl")
    
    echo "• App Mesh Name: $mesh_name"
    echo "• Load Balancer DNS: $alb_dns"
    echo "• Circuit Breaker Dashboard: $dashboard_url"
    echo
    echo "SNS Topics:"
    local order_topic=$(get_stack_output "$MESSAGING_STACK_NAME" "OrderEventsTopicArn")
    local user_topic=$(get_stack_output "$MESSAGING_STACK_NAME" "UserEventsTopicArn")
    local inventory_topic=$(get_stack_output "$MESSAGING_STACK_NAME" "InventoryEventsTopicArn")
    
    echo "• Order Events: $order_topic"
    echo "• User Events: $user_topic"
    echo "• Inventory Events: $inventory_topic"
    echo
    echo "SQS Queues:"
    local order_queue=$(get_stack_output "$MESSAGING_STACK_NAME" "OrderProcessingQueueUrl")
    local inventory_queue=$(get_stack_output "$MESSAGING_STACK_NAME" "InventoryUpdateQueueUrl")
    local notification_queue=$(get_stack_output "$MESSAGING_STACK_NAME" "NotificationQueueUrl")
    local analytics_queue=$(get_stack_output "$MESSAGING_STACK_NAME" "AnalyticsQueueUrl")
    
    echo "• Order Processing: $order_queue"
    echo "• Inventory Update: $inventory_queue"
    echo "• Notifications: $notification_queue"
    echo "• Analytics: $analytics_queue"
    echo
    echo "Test Commands:"
    echo "=============="
    echo "# Test user service"
    echo "curl -X GET http://$alb_dns:8080/users/123"
    echo
    echo "# Test order service"
    echo "curl -X POST http://$alb_dns:8080/orders -H 'Content-Type: application/json' -d '{\"user_id\": 123, \"items\": [{\"product_id\": \"prod-123\", \"quantity\": 2}]}'"
    echo
    echo "# Publish test message to SNS"
    echo "aws sns publish --topic-arn $order_topic --message '{\"orderId\": \"12345\", \"userId\": \"123\", \"status\": \"created\"}' --message-attributes eventType='{\"DataType\":\"String\",\"StringValue\":\"order_created\"}'"
    echo
    echo "# Check circuit breaker state"
    echo "aws lambda invoke --function-name circuit-breaker-manager --payload '{\"service_name\": \"user-service\", \"action\": \"check\"}' /tmp/response.json && cat /tmp/response.json"
    echo
    log_info "Lab is ready for use! Follow the lab guide for detailed exercises."
}

# Main execution
main() {
    log_info "Starting Cross-Service Communication Lab provisioning..."
    
    # Check prerequisites
    check_aws_cli
    
    # Change to the script directory
    cd "$(dirname "$0")"
    
    # Deploy infrastructure components
    create_vpc_stack
    deploy_mesh_stack
    deploy_messaging_stack
    deploy_circuit_breaker_stack
    deploy_ecs_stack
    
    # Display lab information
    display_lab_info
}

# Run main function
main "$@"