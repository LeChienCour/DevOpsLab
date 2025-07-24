# ECS Service Integration Lab Guide

## Objective
Learn how to implement ECS orchestration with service discovery, demonstrating how containerized applications can communicate with each other in a scalable and resilient manner using AWS ECS, Service Discovery, and Application Load Balancer.

## Learning Outcomes
By completing this lab, you will:
- Deploy containerized applications using Amazon ECS with Fargate
- Configure AWS Cloud Map for service discovery
- Implement inter-service communication using service discovery
- Set up Application Load Balancer for external access
- Monitor service health and troubleshoot connectivity issues

## Prerequisites
- AWS Account with administrative access
- Docker installed locally
- Basic understanding of containerization and microservices
- Familiarity with AWS networking concepts (VPC, subnets, security groups)

### Required AWS Permissions
Your AWS user/role needs the following permissions:
- ECS: Full access for creating clusters, services, and task definitions
- EC2: Full access for VPC, security groups, and load balancer management
- IAM: CreateRole, AttachRolePolicy for ECS task and execution roles
- CloudMap: Full access for service discovery configuration
- Logs: CreateLogGroup, CreateLogStream for CloudWatch logging

### Time to Complete
Approximately 45-60 minutes

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        Internet                              │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│              Application Load Balancer                      │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                   ECS Cluster                               │
│  ┌─────────────────┐              ┌─────────────────┐       │
│  │   Frontend      │◄────────────►│   Backend       │       │
│  │   Service       │              │   Service       │       │
│  │   (Port 80)     │              │   (Port 3000)   │       │
│  └─────────────────┘              └─────────────────┘       │
│           │                                │                │
│           ▼                                ▼                │
│  ┌─────────────────┐              ┌─────────────────┐       │
│  │ Cloud Map       │              │ Cloud Map       │       │
│  │ frontend.local  │              │ backend.local   │       │
│  └─────────────────┘              └─────────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

### Resources Created:
- **ECS Cluster**: Fargate cluster for running containerized services
- **ECS Services**: Frontend and backend services with auto-scaling
- **Task Definitions**: Container specifications for each service
- **Application Load Balancer**: External access point for the frontend
- **Cloud Map Namespace**: Private DNS namespace for service discovery
- **Security Groups**: Network access controls for services and load balancer
- **IAM Roles**: Task execution and task roles for ECS services

## Lab Steps

### Step 1: Create VPC and Networking Components

1. **Create a VPC for the ECS cluster:**
   ```bash
   # Create VPC
   aws ec2 create-vpc \
     --cidr-block 10.0.0.0/16 \
     --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=ecs-integration-vpc}]'
   ```

2. **Create public and private subnets:**
   ```bash
   # Get VPC ID
   VPC_ID=$(aws ec2 describe-vpcs \
     --filters "Name=tag:Name,Values=ecs-integration-vpc" \
     --query 'Vpcs[0].VpcId' --output text)
   
   # Create public subnet 1
   aws ec2 create-subnet \
     --vpc-id $VPC_ID \
     --cidr-block 10.0.1.0/24 \
     --availability-zone $(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].ZoneName' --output text) \
     --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=ecs-public-subnet-1}]'
   
   # Create public subnet 2
   aws ec2 create-subnet \
     --vpc-id $VPC_ID \
     --cidr-block 10.0.2.0/24 \
     --availability-zone $(aws ec2 describe-availability-zones --query 'AvailabilityZones[1].ZoneName' --output text) \
     --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=ecs-public-subnet-2}]'
   ```

3. **Create and attach Internet Gateway:**
   ```bash
   # Create Internet Gateway
   aws ec2 create-internet-gateway \
     --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=ecs-integration-igw}]'
   
   # Get IGW ID
   IGW_ID=$(aws ec2 describe-internet-gateways \
     --filters "Name=tag:Name,Values=ecs-integration-igw" \
     --query 'InternetGateways[0].InternetGatewayId' --output text)
   
   # Attach IGW to VPC
   aws ec2 attach-internet-gateway \
     --internet-gateway-id $IGW_ID \
     --vpc-id $VPC_ID
   ```

### Step 2: Configure Service Discovery

1. **Create Cloud Map namespace:**
   ```bash
   # Create private DNS namespace
   aws servicediscovery create-private-dns-namespace \
     --name "ecs-integration.local" \
     --vpc $VPC_ID \
     --description "Private namespace for ECS service discovery"
   ```

2. **Verify namespace creation:**
   ```bash
   # List namespaces
   aws servicediscovery list-namespaces
   ```
   
   Expected output should show your namespace with status "SUCCESS".

### Step 3: Create ECS Cluster and IAM Roles

1. **Create ECS cluster:**
   ```bash
   # Create Fargate cluster
   aws ecs create-cluster \
     --cluster-name ecs-integration-cluster \
     --capacity-providers FARGATE \
     --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1
   ```

2. **Create IAM roles for ECS tasks:**
   ```bash
   # Create task execution role
   aws iam create-role \
     --role-name ecsTaskExecutionRole \
     --assume-role-policy-document '{
       "Version": "2012-10-17",
       "Statement": [
         {
           "Effect": "Allow",
           "Principal": {
             "Service": "ecs-tasks.amazonaws.com"
           },
           "Action": "sts:AssumeRole"
         }
       ]
     }'
   
   # Attach managed policy
   aws iam attach-role-policy \
     --role-name ecsTaskExecutionRole \
     --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
   ```

### Step 4: Create Security Groups

1. **Create security group for ALB:**
   ```bash
   # Create ALB security group
   aws ec2 create-security-group \
     --group-name ecs-alb-sg \
     --description "Security group for ECS Application Load Balancer" \
     --vpc-id $VPC_ID \
     --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=ecs-alb-sg}]'
   
   # Get ALB SG ID
   ALB_SG_ID=$(aws ec2 describe-security-groups \
     --filters "Name=group-name,Values=ecs-alb-sg" \
     --query 'SecurityGroups[0].GroupId' --output text)
   
   # Allow HTTP traffic
   aws ec2 authorize-security-group-ingress \
     --group-id $ALB_SG_ID \
     --protocol tcp \
     --port 80 \
     --cidr 0.0.0.0/0
   ```

2. **Create security group for ECS services:**
   ```bash
   # Create ECS services security group
   aws ec2 create-security-group \
     --group-name ecs-services-sg \
     --description "Security group for ECS services" \
     --vpc-id $VPC_ID \
     --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=ecs-services-sg}]'
   
   # Get services SG ID
   SERVICES_SG_ID=$(aws ec2 describe-security-groups \
     --filters "Name=group-name,Values=ecs-services-sg" \
     --query 'SecurityGroups[0].GroupId' --output text)
   
   # Allow traffic from ALB
   aws ec2 authorize-security-group-ingress \
     --group-id $SERVICES_SG_ID \
     --protocol tcp \
     --port 80 \
     --source-group $ALB_SG_ID
   
   # Allow inter-service communication
   aws ec2 authorize-security-group-ingress \
     --group-id $SERVICES_SG_ID \
     --protocol tcp \
     --port 3000 \
     --source-group $SERVICES_SG_ID
   ```

### Step 5: Create Application Load Balancer

1. **Create Application Load Balancer:**
   ```bash
   # Get subnet IDs
   SUBNET_1_ID=$(aws ec2 describe-subnets \
     --filters "Name=tag:Name,Values=ecs-public-subnet-1" \
     --query 'Subnets[0].SubnetId' --output text)
   
   SUBNET_2_ID=$(aws ec2 describe-subnets \
     --filters "Name=tag:Name,Values=ecs-public-subnet-2" \
     --query 'Subnets[0].SubnetId' --output text)
   
   # Create ALB
   aws elbv2 create-load-balancer \
     --name ecs-integration-alb \
     --subnets $SUBNET_1_ID $SUBNET_2_ID \
     --security-groups $ALB_SG_ID \
     --scheme internet-facing \
     --type application
   ```

2. **Create target group:**
   ```bash
   # Create target group for frontend service
   aws elbv2 create-target-group \
     --name ecs-frontend-tg \
     --protocol HTTP \
     --port 80 \
     --vpc-id $VPC_ID \
     --target-type ip \
     --health-check-path /health
   ```

### Step 6: Deploy Backend Service

1. **Create backend task definition:**
   ```bash
   # Create backend task definition
   cat > backend-task-def.json << EOF
   {
     "family": "backend-service",
     "networkMode": "awsvpc",
     "requiresCompatibilities": ["FARGATE"],
     "cpu": "256",
     "memory": "512",
     "executionRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ecsTaskExecutionRole",
     "containerDefinitions": [
       {
         "name": "backend",
         "image": "nginx:alpine",
         "portMappings": [
           {
             "containerPort": 3000,
             "protocol": "tcp"
           }
         ],
         "essential": true,
         "logConfiguration": {
           "logDriver": "awslogs",
           "options": {
             "awslogs-group": "/ecs/backend-service",
             "awslogs-region": "$(aws configure get region)",
             "awslogs-stream-prefix": "ecs"
           }
         },
         "command": [
           "sh", "-c",
           "echo 'server { listen 3000; location / { return 200 \"Backend Service Running\"; add_header Content-Type text/plain; } location /health { return 200 \"OK\"; add_header Content-Type text/plain; } }' > /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"
         ]
       }
     ]
   }
   EOF
   
   # Register task definition
   aws ecs register-task-definition --cli-input-json file://backend-task-def.json
   ```

2. **Create CloudWatch log group:**
   ```bash
   # Create log group for backend
   aws logs create-log-group --log-group-name /ecs/backend-service
   ```

3. **Create backend service with service discovery:**
   ```bash
   # Get namespace ID
   NAMESPACE_ID=$(aws servicediscovery list-namespaces \
     --filters Name=NAME,Values=ecs-integration.local \
     --query 'Namespaces[0].Id' --output text)
   
   # Create service discovery service for backend
   aws servicediscovery create-service \
     --name backend \
     --dns-config NamespaceId=$NAMESPACE_ID,DnsRecords=[{Type=A,TTL=60}] \
     --health-check-custom-config FailureThreshold=1
   
   # Get service discovery service ID
   BACKEND_SD_ID=$(aws servicediscovery list-services \
     --filters Name=NAMESPACE_ID,Values=$NAMESPACE_ID \
     --query 'Services[?Name==`backend`].Id' --output text)
   
   # Create ECS service
   aws ecs create-service \
     --cluster ecs-integration-cluster \
     --service-name backend-service \
     --task-definition backend-service \
     --desired-count 2 \
     --launch-type FARGATE \
     --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_1_ID,$SUBNET_2_ID],securityGroups=[$SERVICES_SG_ID],assignPublicIp=ENABLED}" \
     --service-registries registryArn=arn:aws:servicediscovery:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):service/$BACKEND_SD_ID
   ```

### Step 7: Deploy Frontend Service

1. **Create frontend task definition:**
   ```bash
   # Create frontend task definition
   cat > frontend-task-def.json << EOF
   {
     "family": "frontend-service",
     "networkMode": "awsvpc",
     "requiresCompatibilities": ["FARGATE"],
     "cpu": "256",
     "memory": "512",
     "executionRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ecsTaskExecutionRole",
     "containerDefinitions": [
       {
         "name": "frontend",
         "image": "nginx:alpine",
         "portMappings": [
           {
             "containerPort": 80,
             "protocol": "tcp"
           }
         ],
         "essential": true,
         "logConfiguration": {
           "logDriver": "awslogs",
           "options": {
             "awslogs-group": "/ecs/frontend-service",
             "awslogs-region": "$(aws configure get region)",
             "awslogs-stream-prefix": "ecs"
           }
         },
         "command": [
           "sh", "-c",
           "echo 'server { listen 80; location / { proxy_pass http://backend.ecs-integration.local:3000; proxy_set_header Host \\$host; proxy_set_header X-Real-IP \\$remote_addr; } location /health { return 200 \"Frontend OK\"; add_header Content-Type text/plain; } }' > /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"
         ]
       }
     ]
   }
   EOF
   
   # Register task definition
   aws ecs register-task-definition --cli-input-json file://frontend-task-def.json
   ```

2. **Create log group and service discovery for frontend:**
   ```bash
   # Create log group for frontend
   aws logs create-log-group --log-group-name /ecs/frontend-service
   
   # Create service discovery service for frontend
   aws servicediscovery create-service \
     --name frontend \
     --dns-config NamespaceId=$NAMESPACE_ID,DnsRecords=[{Type=A,TTL=60}] \
     --health-check-custom-config FailureThreshold=1
   
   # Get frontend service discovery ID
   FRONTEND_SD_ID=$(aws servicediscovery list-services \
     --filters Name=NAMESPACE_ID,Values=$NAMESPACE_ID \
     --query 'Services[?Name==`frontend`].Id' --output text)
   ```

3. **Create frontend ECS service and configure load balancer:**
   ```bash
   # Get target group ARN
   TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups \
     --names ecs-frontend-tg \
     --query 'TargetGroups[0].TargetGroupArn' --output text)
   
   # Create frontend service
   aws ecs create-service \
     --cluster ecs-integration-cluster \
     --service-name frontend-service \
     --task-definition frontend-service \
     --desired-count 2 \
     --launch-type FARGATE \
     --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_1_ID,$SUBNET_2_ID],securityGroups=[$SERVICES_SG_ID],assignPublicIp=ENABLED}" \
     --load-balancers targetGroupArn=$TARGET_GROUP_ARN,containerName=frontend,containerPort=80 \
     --service-registries registryArn=arn:aws:servicediscovery:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):service/$FRONTEND_SD_ID
   
   # Get ALB ARN and create listener
   ALB_ARN=$(aws elbv2 describe-load-balancers \
     --names ecs-integration-alb \
     --query 'LoadBalancers[0].LoadBalancerArn' --output text)
   
   aws elbv2 create-listener \
     --load-balancer-arn $ALB_ARN \
     --protocol HTTP \
     --port 80 \
     --default-actions Type=forward,TargetGroupArn=$TARGET_GROUP_ARN
   ```

### Step 8: Test Service Integration

1. **Wait for services to stabilize:**
   ```bash
   # Check service status
   aws ecs describe-services \
     --cluster ecs-integration-cluster \
     --services backend-service frontend-service \
     --query 'services[*].[serviceName,runningCount,desiredCount]' \
     --output table
   ```

2. **Get ALB DNS name and test:**
   ```bash
   # Get ALB DNS name
   ALB_DNS=$(aws elbv2 describe-load-balancers \
     --names ecs-integration-alb \
     --query 'LoadBalancers[0].DNSName' --output text)
   
   echo "ALB DNS: http://$ALB_DNS"
   
   # Test the application
   curl http://$ALB_DNS
   ```
   
   Expected output: "Backend Service Running" (proxied through frontend)

3. **Verify service discovery:**
   ```bash
   # List discovered services
   aws servicediscovery list-instances \
     --service-id $BACKEND_SD_ID
   
   aws servicediscovery list-instances \
     --service-id $FRONTEND_SD_ID
   ```

## Troubleshooting Guide

### Common Issues and Solutions

1. **Services not starting or staying in PENDING state:**
   - Check security group rules allow required ports
   - Verify subnets have internet access for image pulling
   - Check IAM role permissions for task execution

2. **Service discovery not working:**
   - Verify Cloud Map namespace is in the same VPC as ECS services
   - Check that service discovery services are properly registered
   - Ensure DNS resolution is working within the VPC

3. **Load balancer health checks failing:**
   - Verify target group health check path matches application endpoint
   - Check security group allows traffic from ALB to ECS services
   - Ensure application is listening on the correct port

### Debugging Commands

```bash
# Check ECS service events
aws ecs describe-services \
  --cluster ecs-integration-cluster \
  --services frontend-service backend-service \
  --query 'services[*].events[0:5]'

# Check task status and logs
aws ecs list-tasks --cluster ecs-integration-cluster --service-name backend-service
aws logs get-log-events \
  --log-group-name /ecs/backend-service \
  --log-stream-name ecs/backend/$(aws ecs list-tasks --cluster ecs-integration-cluster --service-name backend-service --query 'taskArns[0]' --output text | cut -d'/' -f3)

# Check target group health
aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN
```

## Resources Created

This lab creates the following AWS resources:

### Compute
- **ECS Cluster**: Fargate cluster for container orchestration
- **ECS Services**: Frontend and backend services with auto-scaling
- **ECS Task Definitions**: Container specifications and configurations

### Networking
- **VPC**: Virtual private cloud with public subnets
- **Application Load Balancer**: External access point for frontend service
- **Security Groups**: Network access controls for ALB and ECS services
- **Internet Gateway**: Internet access for public subnets

### Service Discovery
- **Cloud Map Namespace**: Private DNS namespace for service discovery
- **Service Discovery Services**: DNS records for frontend and backend services

### Monitoring
- **CloudWatch Log Groups**: Container logs for both services

### Estimated Costs
- ECS Fargate: ~$0.04048/vCPU/hour + $0.004445/GB/hour (4 tasks total)
- Application Load Balancer: $0.0225/hour + $0.008/LCU-hour
- Cloud Map: $0.50/hosted zone/month + $0.40/million queries
- CloudWatch Logs: $0.50/GB ingested + $0.03/GB stored
- **Total estimated cost**: $2-5/day (not free tier eligible for ALB)

## Cleanup

When you're finished with the lab, follow these steps to avoid ongoing charges:

1. **Delete ECS services:**
   ```bash
   # Scale down services to 0
   aws ecs update-service \
     --cluster ecs-integration-cluster \
     --service frontend-service \
     --desired-count 0
   
   aws ecs update-service \
     --cluster ecs-integration-cluster \
     --service backend-service \
     --desired-count 0
   
   # Delete services
   aws ecs delete-service \
     --cluster ecs-integration-cluster \
     --service frontend-service
   
   aws ecs delete-service \
     --cluster ecs-integration-cluster \
     --service backend-service
   ```

2. **Delete load balancer and target groups:**
   ```bash
   # Delete listener
   LISTENER_ARN=$(aws elbv2 describe-listeners \
     --load-balancer-arn $ALB_ARN \
     --query 'Listeners[0].ListenerArn' --output text)
   aws elbv2 delete-listener --listener-arn $LISTENER_ARN
   
   # Delete load balancer
   aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN
   
   # Delete target group
   aws elbv2 delete-target-group --target-group-arn $TARGET_GROUP_ARN
   ```

3. **Clean up service discovery:**
   ```bash
   # Delete service discovery services
   aws servicediscovery delete-service --id $FRONTEND_SD_ID
   aws servicediscovery delete-service --id $BACKEND_SD_ID
   
   # Delete namespace
   aws servicediscovery delete-namespace --id $NAMESPACE_ID
   ```

4. **Delete ECS cluster and related resources:**
   ```bash
   # Delete cluster
   aws ecs delete-cluster --cluster ecs-integration-cluster
   
   # Delete log groups
   aws logs delete-log-group --log-group-name /ecs/frontend-service
   aws logs delete-log-group --log-group-name /ecs/backend-service
   
   # Delete task definitions (deregister)
   aws ecs deregister-task-definition --task-definition frontend-service:1
   aws ecs deregister-task-definition --task-definition backend-service:1
   ```

5. **Delete networking components:**
   ```bash
   # Delete security groups
   aws ec2 delete-security-group --group-id $SERVICES_SG_ID
   aws ec2 delete-security-group --group-id $ALB_SG_ID
   
   # Detach and delete internet gateway
   aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
   aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID
   
   # Delete subnets
   aws ec2 delete-subnet --subnet-id $SUBNET_1_ID
   aws ec2 delete-subnet --subnet-id $SUBNET_2_ID
   
   # Delete VPC
   aws ec2 delete-vpc --vpc-id $VPC_ID
   ```

> **Important**: Failure to delete resources may result in unexpected charges to your AWS account.

## Next Steps

After completing this lab, consider:

1. **Implement auto-scaling policies** for ECS services based on CPU/memory metrics
2. **Add SSL/TLS termination** at the Application Load Balancer level
3. **Explore ECS Service Connect** as an alternative to Cloud Map for service discovery
4. **Implement blue-green deployments** using ECS and CodeDeploy
5. **Add monitoring and alerting** using CloudWatch and SNS

## Certification Exam Tips

This lab covers several key areas for the AWS DevOps Professional exam:

- **Domain 1**: SDLC Automation (Container orchestration, service discovery)
- **Domain 2**: Configuration Management and IaC (ECS task definitions, service configuration)
- **Domain 3**: Monitoring and Logging (CloudWatch integration, application monitoring)
- **Domain 4**: Policies and Standards Automation (Security groups, IAM roles)

Key concepts to remember:
- ECS Fargate eliminates the need to manage EC2 instances for containers
- Service discovery enables dynamic service-to-service communication
- Application Load Balancers provide Layer 7 routing and health checking
- Security groups act as virtual firewalls for ECS tasks
- Task definitions define container specifications and resource requirements

## Additional Resources

- [Amazon ECS Developer Guide](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/)
- [AWS Cloud Map Developer Guide](https://docs.aws.amazon.com/cloud-map/latest/dg/)
- [Application Load Balancer User Guide](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [ECS Best Practices Guide](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [Microservices on AWS](https://docs.aws.amazon.com/whitepapers/latest/microservices-on-aws/microservices-on-aws.html)