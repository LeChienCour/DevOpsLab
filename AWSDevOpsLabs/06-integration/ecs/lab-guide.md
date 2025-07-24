# ECS Orchestration Lab

## Overview

This comprehensive lab demonstrates advanced ECS orchestration patterns including Cloud Map service discovery, Application Load Balancer integration, and sophisticated auto-scaling policies based on custom CloudWatch metrics. You'll learn how to build production-ready containerized applications with AWS ECS Fargate.

## Learning Objectives

By completing this lab, you will:
- Deploy ECS clusters with Fargate capacity providers
- Implement Cloud Map service discovery for microservices communication
- Configure Application Load Balancer with target groups and health checks
- Set up advanced auto-scaling policies using multiple metrics
- Create custom CloudWatch dashboards and alarms
- Implement time-based and custom metric scaling logic
- Monitor distributed applications with comprehensive observability

## Prerequisites

- AWS CLI configured with appropriate permissions
- Basic understanding of containerization and Docker
- Familiarity with ECS, VPC, and Load Balancer concepts
- Understanding of CloudWatch metrics and alarms

## Architecture Overview

The lab creates a complete ECS environment with:
- VPC with public and private subnets across multiple AZs
- ECS Fargate cluster with mixed capacity providers (Fargate + Spot)
- Application Load Balancer for external traffic distribution
- Cloud Map private DNS namespace for service discovery
- Auto-scaling policies based on CPU, memory, and custom metrics
- CloudWatch dashboards and custom Lambda-based scaling logic

## Lab Components

### Infrastructure Stack
- **VPC and Networking**: Multi-AZ setup with NAT Gateway
- **Security Groups**: Properly configured for ALB and ECS communication
- **ECS Cluster**: Fargate-enabled with container insights
- **Cloud Map**: Private DNS namespace for service discovery
- **IAM Roles**: Task execution and task roles with appropriate permissions

### Service Stack
- **Task Definition**: Fargate-compatible with logging and health checks
- **ECS Service**: With service discovery registration and ALB integration
- **Target Group**: Health check configuration and deregistration delay
- **Auto-scaling Target**: Configurable min/max capacity with multiple policies

### Advanced Auto-scaling Stack
- **Custom Metrics**: Log-based metrics for error count and latency
- **Step Scaling**: Multi-threshold scaling for rapid response
- **Target Tracking**: CPU, memory, and request-based scaling
- **Custom Lambda**: Time-aware scaling logic for business hours
- **CloudWatch Dashboard**: Comprehensive metrics visualization

## Lab Steps

### Step 1: Provision the Lab Environment

Navigate to the ECS lab directory and run the provisioning script:

```bash
cd AWSDevOpsLabs/06-integration/ecs
./scripts/provision-ecs-lab.sh
```

The script will deploy three CloudFormation stacks in sequence:
1. **Infrastructure Stack**: VPC, ECS cluster, ALB, and foundational resources
2. **Service Stack**: ECS service with Cloud Map integration and basic auto-scaling
3. **Auto-scaling Stack**: Advanced metrics, custom scaling logic, and monitoring

### Step 2: Verify Service Discovery

Test the Cloud Map service discovery functionality:

```bash
# List service discovery namespaces
aws servicediscovery list-namespaces

# List services in the namespace
aws servicediscovery list-services

# Get service discovery details
aws servicediscovery get-service --id <service-id>
```

### Step 3: Test Load Balancer Integration

Access your service through the Application Load Balancer:

```bash
# Get the ALB DNS name from stack outputs
ALB_DNS=$(aws cloudformation describe-stacks \
  --stack-name ecs-lab-infrastructure \
  --query 'Stacks[0].Outputs[?OutputKey==`ApplicationLoadBalancerDNS`].OutputValue' \
  --output text)

# Test the service endpoint
curl http://$ALB_DNS/web-service

# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>
```

### Step 4: Monitor Auto-scaling Behavior

Generate load to trigger auto-scaling policies:

```bash
# Install Apache Bench for load testing
# On Amazon Linux/CentOS: sudo yum install httpd-tools
# On Ubuntu/Debian: sudo apt-get install apache2-utils

# Generate sustained load
ab -n 10000 -c 50 -t 300 http://$ALB_DNS/web-service/

# Monitor scaling activity
aws ecs describe-services \
  --cluster devops-lab-cluster \
  --services web-service \
  --query 'services[0].{DesiredCount:desiredCount,RunningCount:runningCount,PendingCount:pendingCount}'

# Check auto-scaling activities
aws application-autoscaling describe-scaling-activities \
  --service-namespace ecs \
  --resource-id service/devops-lab-cluster/web-service
```

### Step 5: Explore Custom Metrics and Scaling

View the custom CloudWatch dashboard:

```bash
# Get dashboard URL from stack outputs
DASHBOARD_URL=$(aws cloudformation describe-stacks \
  --stack-name ecs-lab-autoscaling \
  --query 'Stacks[0].Outputs[?OutputKey==`DashboardURL`].OutputValue' \
  --output text)

echo "Dashboard URL: $DASHBOARD_URL"
```

Test custom scaling logic by examining the Lambda function:

```bash
# View Lambda function logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/web-service-custom-scaling"

# Manually invoke the custom scaling function
aws lambda invoke \
  --function-name web-service-custom-scaling \
  --payload '{}' \
  response.json && cat response.json
```

### Step 6: Service Discovery Testing

Deploy a second service to test inter-service communication:

```bash
# Create a simple client task definition
cat > client-task.json << EOF
{
  "family": "client-service",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "$(aws cloudformation describe-stacks --stack-name ecs-lab-infrastructure --query 'Stacks[0].Outputs[?OutputKey==`ECSTaskExecutionRoleArn`].OutputValue' --output text)",
  "containerDefinitions": [
    {
      "name": "client",
      "image": "alpine:latest",
      "command": ["sh", "-c", "while true; do nslookup web-service.devops-lab.local && sleep 30; done"],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/client-service",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
EOF

# Register the task definition
aws ecs register-task-definition --cli-input-json file://client-task.json

# Run the client task
aws ecs run-task \
  --cluster devops-lab-cluster \
  --task-definition client-service \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$(aws cloudformation describe-stacks --stack-name ecs-lab-infrastructure --query 'Stacks[0].Outputs[?OutputKey==`PrivateSubnet1Id`].OutputValue' --output text)],securityGroups=[$(aws cloudformation describe-stacks --stack-name ecs-lab-infrastructure --query 'Stacks[0].Outputs[?OutputKey==`ECSSecurityGroupId`].OutputValue' --output text)]}"
```

### Step 7: Advanced Monitoring and Troubleshooting

Explore ECS service metrics and logs:

```bash
# View service events
aws ecs describe-services \
  --cluster devops-lab-cluster \
  --services web-service \
  --query 'services[0].events[0:5]'

# Check task health
aws ecs list-tasks --cluster devops-lab-cluster --service-name web-service

# View container logs
TASK_ARN=$(aws ecs list-tasks --cluster devops-lab-cluster --service-name web-service --query 'taskArns[0]' --output text)
aws logs get-log-events \
  --log-group-name "/ecs/web-service" \
  --log-stream-name "ecs/web-service/$(echo $TASK_ARN | cut -d'/' -f3)"

# Monitor CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=web-service Name=ClusterName,Value=devops-lab-cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

## Key Concepts Demonstrated

### 1. Cloud Map Service Discovery
- Private DNS namespace creation and management
- Automatic service registration and deregistration
- DNS-based service discovery for microservices

### 2. Application Load Balancer Integration
- Target group configuration with health checks
- Path-based routing for multiple services
- Connection draining and deregistration delays

### 3. Advanced Auto-scaling Strategies
- **Target Tracking**: Maintains target CPU/memory utilization
- **Step Scaling**: Multi-threshold scaling for rapid response
- **Custom Metrics**: Application-specific scaling triggers
- **Time-based Scaling**: Business hours vs. off-hours capacity

### 4. Comprehensive Monitoring
- CloudWatch dashboards with multiple metric sources
- Custom log-based metrics extraction
- Composite alarms for complex scaling logic
- SNS notifications for scaling events

### 5. Production Best Practices
- Multi-AZ deployment for high availability
- Proper security group configuration
- IAM roles with least-privilege access
- Container insights for enhanced monitoring
- Circuit breaker patterns with deployment configuration

## Troubleshooting Guide

### Common Issues and Solutions

**Service fails to start:**
- Check task definition resource requirements
- Verify security group allows ALB communication
- Ensure subnets have internet access via NAT Gateway

**Auto-scaling not working:**
- Verify CloudWatch agent is publishing metrics
- Check scaling policy thresholds and cooldown periods
- Ensure service has proper IAM permissions

**Service discovery resolution fails:**
- Confirm Cloud Map namespace and service creation
- Check VPC DNS resolution and hostnames are enabled
- Verify tasks are registering with service discovery

**Load balancer health checks failing:**
- Review target group health check configuration
- Check application health check endpoint
- Verify security group allows health check traffic

## Cost Optimization Tips

1. **Use Fargate Spot**: Configured in the infrastructure template for cost savings
2. **Right-size Resources**: Monitor CPU/memory utilization and adjust task definitions
3. **Optimize Scaling**: Set appropriate min/max values and scaling thresholds
4. **Log Retention**: Configure appropriate CloudWatch log retention periods
5. **Resource Cleanup**: Always run cleanup script when lab is complete

## Cleanup

When you're finished with the lab, clean up all resources to avoid ongoing charges:

```bash
./scripts/cleanup-ecs-lab.sh
```

The cleanup script will:
- Delete all CloudFormation stacks in proper order
- Remove CloudWatch dashboards and custom metrics
- Clean up Service Discovery resources
- Verify no orphaned resources remain

## Next Steps

After completing this lab, consider exploring:
- ECS with AWS App Mesh for advanced service mesh capabilities
- Integration with AWS X-Ray for distributed tracing
- CI/CD pipelines with ECS deployments using CodePipeline
- Multi-region ECS deployments with Route 53 health checks
- ECS with AWS Batch for batch processing workloads

## Additional Resources

- [Amazon ECS Developer Guide](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/)
- [AWS Cloud Map Developer Guide](https://docs.aws.amazon.com/cloud-map/latest/dg/)
- [Application Auto Scaling User Guide](https://docs.aws.amazon.com/autoscaling/application/userguide/)
- [Amazon ECS Best Practices Guide](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)