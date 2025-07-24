# Rolling Deployment Lab Guide

## Objective
Learn how to implement rolling deployment strategies using AWS Auto Scaling Groups and Application Load Balancers to update applications with minimal downtime. This lab demonstrates how to gradually replace instances in a deployment while maintaining service availability and monitoring the deployment progress.

## Learning Outcomes
By completing this lab, you will:
- Understand rolling deployment concepts and strategies
- Configure Auto Scaling Groups for rolling updates
- Implement instance refresh and deployment policies
- Monitor rolling deployment progress and health
- Practice rollback procedures for failed rolling deployments
- Optimize deployment parameters for different scenarios

## Prerequisites
- AWS Account with administrative access
- AWS CLI configured with appropriate credentials
- Basic understanding of Auto Scaling Groups and launch templates
- Familiarity with Application Load Balancers and target groups
- Knowledge of EC2 instances and health checks

### Required AWS Permissions
Your AWS user/role needs the following permissions:
- EC2: Full access for creating instances, launch templates, and security groups
- Auto Scaling: Full access for managing Auto Scaling Groups and instance refresh
- ELB: Full access for managing Application Load Balancers and target groups
- CloudWatch: Read access for monitoring metrics
- IAM: Read access for service roles

### Time to Complete
Approximately 45-60 minutes

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Internet Gateway                          │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│              Application Load Balancer                      │
│                 (Health Checks)                             │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                Target Group                                 │
│            (All Active Instances)                           │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│              Auto Scaling Group                             │
│             (Rolling Update)                                │
│                                                             │
│  Phase 1: ┌───┐ ┌───┐ ┌───┐ ┌───┐                         │
│           │Old│ │Old│ │Old│ │Old│                         │
│           └───┘ └───┘ └───┘ └───┘                         │
│                                                             │
│  Phase 2: ┌───┐ ┌───┐ ┌───┐ ┌───┐                         │
│           │New│ │New│ │Old│ │Old│                         │
│           └───┘ └───┘ └───┘ └───┘                         │
│                                                             │
│  Phase 3: ┌───┐ ┌───┐ ┌───┐ ┌───┐                         │
│           │New│ │New│ │New│ │New│                         │
│           └───┘ └───┘ └───┘ └───┘                         │
└─────────────────────────────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                CloudWatch                                   │
│            (Deployment Metrics)                             │
└─────────────────────────────────────────────────────────────┘
```

### Resources Created:
- **Application Load Balancer**: Routes traffic to healthy instances during deployment
- **Target Group**: Single target group for all instances
- **Auto Scaling Group**: Manages rolling instance replacement
- **Launch Template**: Versioned configuration for new instances
- **EC2 Instances**: Application servers being updated in batches
- **Security Groups**: Network access control
- **CloudWatch Dashboard**: Deployment monitoring

## Lab Steps

### Step 1: Set Up VPC and Networking

1. **Create VPC and subnets:**
   ```bash
   # Create VPC
   aws ec2 create-vpc --cidr-block 10.0.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=RollingVPC}]'
   VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=RollingVPC" --query "Vpcs[0].VpcId" --output text)
   
   # Create subnets in multiple AZs
   aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone us-east-1a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=RollingSubnet1}]'
   aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --availability-zone us-east-1b --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=RollingSubnet2}]'
   aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.3.0/24 --availability-zone us-east-1c --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=RollingSubnet3}]'
   ```

2. **Create and configure Internet Gateway:**
   ```bash
   # Create Internet Gateway
   aws ec2 create-internet-gateway --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=RollingIGW}]'
   IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=tag:Name,Values=RollingIGW" --query "InternetGateways[0].InternetGatewayId" --output text)
   
   # Attach to VPC
   aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
   
   # Create route table and routes
   aws ec2 create-route-table --vpc-id $VPC_ID --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=RollingRT}]'
   RT_ID=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=RollingRT" --query "RouteTables[0].RouteTableId" --output text)
   aws ec2 create-route --route-table-id $RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
   ```

### Step 2: Create Security Groups

1. **Create security groups:**
   ```bash
   # ALB Security Group
   aws ec2 create-security-group --group-name RollingALB-SG --description "Security group for Rolling ALB" --vpc-id $VPC_ID --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=RollingALB-SG}]'
   ALB_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=RollingALB-SG" --query "SecurityGroups[0].GroupId" --output text)
   
   # EC2 Security Group
   aws ec2 create-security-group --group-name RollingEC2-SG --description "Security group for Rolling EC2 instances" --vpc-id $VPC_ID --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=RollingEC2-SG}]'
   EC2_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=RollingEC2-SG" --query "SecurityGroups[0].GroupId" --output text)
   
   # Configure security group rules
   aws ec2 authorize-security-group-ingress --group-id $ALB_SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0
   aws ec2 authorize-security-group-ingress --group-id $EC2_SG_ID --protocol tcp --port 80 --source-group $ALB_SG_ID
   aws ec2 authorize-security-group-ingress --group-id $EC2_SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0
   ```

### Step 3: Create Application Load Balancer

1. **Create Application Load Balancer:**
   ```bash
   # Get subnet IDs
   SUBNET1_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=RollingSubnet1" --query "Subnets[0].SubnetId" --output text)
   SUBNET2_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=RollingSubnet2" --query "Subnets[0].SubnetId" --output text)
   SUBNET3_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=RollingSubnet3" --query "Subnets[0].SubnetId" --output text)
   
   # Associate subnets with route table
   aws ec2 associate-route-table --subnet-id $SUBNET1_ID --route-table-id $RT_ID
   aws ec2 associate-route-table --subnet-id $SUBNET2_ID --route-table-id $RT_ID
   aws ec2 associate-route-table --subnet-id $SUBNET3_ID --route-table-id $RT_ID
   
   # Create ALB
   aws elbv2 create-load-balancer --name RollingALB --subnets $SUBNET1_ID $SUBNET2_ID $SUBNET3_ID --security-groups $ALB_SG_ID --scheme internet-facing --type application
   ALB_ARN=$(aws elbv2 describe-load-balancers --names RollingALB --query "LoadBalancers[0].LoadBalancerArn" --output text)
   ```

2. **Create target group:**
   ```bash
   # Create target group with health check configuration
   aws elbv2 create-target-group --name RollingTG --protocol HTTP --port 80 --vpc-id $VPC_ID --health-check-path /health --health-check-interval-seconds 30 --health-check-timeout-seconds 5 --healthy-threshold-count 2 --unhealthy-threshold-count 3 --health-check-grace-period-seconds 300
   TG_ARN=$(aws elbv2 describe-target-groups --names RollingTG --query "TargetGroups[0].TargetGroupArn" --output text)
   ```

3. **Create listener:**
   ```bash
   # Create listener
   aws elbv2 create-listener --load-balancer-arn $ALB_ARN --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=$TG_ARN
   ```

### Step 4: Create Initial Launch Template and Auto Scaling Group

1. **Create initial launch template (Version 1.0):**
   ```bash
   cat > user-data-v1.sh << 'EOF'
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd

# Create initial application version
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
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container { 
            background-color: rgba(255,255,255,0.1); 
            padding: 30px; 
            border-radius: 15px; 
            backdrop-filter: blur(10px);
        }
        .version { font-size: 2em; margin: 20px 0; }
        .instance-info { background-color: rgba(255,255,255,0.2); padding: 15px; border-radius: 10px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Rolling Deployment Application</h1>
        <div class="version">Version: 1.0.0</div>
        <div class="instance-info">
            <p><strong>Instance ID:</strong> $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
            <p><strong>Availability Zone:</strong> $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)</p>
            <p><strong>Deployment Time:</strong> $(date)</p>
        </div>
        <p>This is the initial version of the application.</p>
    </div>
</body>
</html>
HTML

# Create health check endpoint
echo "OK" > /var/www/html/health

# Create version endpoint for monitoring
cat > /var/www/html/version << 'HTML'
{
  "version": "1.0.0",
  "deployment_type": "initial",
  "timestamp": "$(date -Iseconds)",
  "instance_id": "$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
}
HTML

# Log deployment
echo "$(date): Version 1.0.0 deployed" >> /var/log/deployment.log
EOF

   # Create launch template
   aws ec2 create-launch-template --launch-template-name RollingTemplate --version-description "Version 1.0.0" --launch-template-data '{
     "ImageId": "ami-0c02fb55956c7d316",
     "InstanceType": "t2.micro",
     "SecurityGroupIds": ["'$EC2_SG_ID'"],
     "UserData": "'$(base64 -w 0 user-data-v1.sh)'",
     "TagSpecifications": [
       {
         "ResourceType": "instance",
         "Tags": [
           {"Key": "Name", "Value": "RollingInstance"},
           {"Key": "Version", "Value": "1.0.0"}
         ]
       }
     ]
   }'
   ```

2. **Create Auto Scaling Group:**
   ```bash
   # Create Auto Scaling Group with initial configuration
   aws autoscaling create-auto-scaling-group --auto-scaling-group-name RollingASG --launch-template LaunchTemplateName=RollingTemplate,Version=1 --min-size 4 --max-size 8 --desired-capacity 4 --target-group-arns $TG_ARN --vpc-zone-identifier "$SUBNET1_ID,$SUBNET2_ID,$SUBNET3_ID" --health-check-type ELB --health-check-grace-period 300 --default-cooldown 300
   ```

3. **Wait for initial deployment to complete:**
   ```bash
   # Monitor Auto Scaling Group status
   echo "Waiting for initial deployment to complete..."
   aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names RollingASG --query "AutoScalingGroups[0].Instances[*].[InstanceId,LifecycleState,HealthStatus]" --output table
   
   # Check target group health
   aws elbv2 describe-target-health --target-group-arn $TG_ARN --query "TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]" --output table
   ```

### Step 5: Test Initial Application

1. **Test the initial application:**
   ```bash
   # Get ALB DNS name
   ALB_DNS=$(aws elbv2 describe-load-balancers --names RollingALB --query "LoadBalancers[0].DNSName" --output text)
   
   # Test application
   echo "Testing initial application version..."
   curl -s http://$ALB_DNS | grep -o "Version: [0-9.]*"
   
   # Test version endpoint
   curl -s http://$ALB_DNS/version | jq .
   ```

### Step 6: Create Updated Launch Template Version

1. **Create new launch template version (Version 2.0):**
   ```bash
   cat > user-data-v2.sh << 'EOF'
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd

# Create updated application version
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
            background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
            color: white;
        }
        .container { 
            background-color: rgba(255,255,255,0.1); 
            padding: 30px; 
            border-radius: 15px; 
            backdrop-filter: blur(10px);
        }
        .version { font-size: 2em; margin: 20px 0; color: #ffeb3b; }
        .instance-info { background-color: rgba(255,255,255,0.2); padding: 15px; border-radius: 10px; margin: 20px 0; }
        .features { background-color: rgba(255,255,255,0.15); padding: 20px; border-radius: 10px; margin: 20px 0; }
        .feature-list { text-align: left; display: inline-block; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Rolling Deployment Application</h1>
        <div class="version">Version: 2.0.0</div>
        <div class="instance-info">
            <p><strong>Instance ID:</strong> $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
            <p><strong>Availability Zone:</strong> $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)</p>
            <p><strong>Deployment Time:</strong> $(date)</p>
        </div>
        <div class="features">
            <h3>✨ New Features in v2.0.0</h3>
            <div class="feature-list">
                <ul>
                    <li>🎨 Enhanced UI with new gradient design</li>
                    <li>⚡ Improved performance and caching</li>
                    <li>🔧 Better error handling</li>
                    <li>📊 Enhanced monitoring capabilities</li>
                    <li>🛡️ Security improvements</li>
                </ul>
            </div>
        </div>
        <p>This version was deployed using rolling deployment strategy!</p>
    </div>
</body>
</html>
HTML

# Create health check endpoint
echo "OK" > /var/www/html/health

# Create version endpoint for monitoring
cat > /var/www/html/version << 'HTML'
{
  "version": "2.0.0",
  "deployment_type": "rolling",
  "timestamp": "$(date -Iseconds)",
  "instance_id": "$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
}
HTML

# Log deployment
echo "$(date): Version 2.0.0 deployed via rolling update" >> /var/log/deployment.log
EOF

   # Create new launch template version
   aws ec2 create-launch-template-version --launch-template-name RollingTemplate --version-description "Version 2.0.0" --launch-template-data '{
     "ImageId": "ami-0c02fb55956c7d316",
     "InstanceType": "t2.micro",
     "SecurityGroupIds": ["'$EC2_SG_ID'"],
     "UserData": "'$(base64 -w 0 user-data-v2.sh)'",
     "TagSpecifications": [
       {
         "ResourceType": "instance",
         "Tags": [
           {"Key": "Name", "Value": "RollingInstance"},
           {"Key": "Version", "Value": "2.0.0"}
         ]
       }
     ]
   }'
   ```

### Step 7: Perform Rolling Deployment

1. **Start instance refresh for rolling deployment:**
   ```bash
   # Start instance refresh with rolling deployment configuration
   aws autoscaling start-instance-refresh --auto-scaling-group-name RollingASG --preferences '{
     "InstanceWarmup": 300,
     "MinHealthyPercentage": 50,
     "CheckpointPercentages": [25, 50, 75],
     "CheckpointDelay": 300
   }' --desired-configuration '{
     "LaunchTemplate": {
       "LaunchTemplateName": "RollingTemplate",
       "Version": "2"
     }
   }'
   
   # Get instance refresh ID
   REFRESH_ID=$(aws autoscaling describe-instance-refreshes --auto-scaling-group-name RollingASG --query "InstanceRefreshes[0].InstanceRefreshId" --output text)
   echo "Instance refresh started with ID: $REFRESH_ID"
   ```

2. **Monitor rolling deployment progress:**
   ```bash
   # Monitor instance refresh status
   echo "Monitoring rolling deployment progress..."
   while true; do
     STATUS=$(aws autoscaling describe-instance-refreshes --auto-scaling-group-name RollingASG --instance-refresh-ids $REFRESH_ID --query "InstanceRefreshes[0].Status" --output text)
     PERCENTAGE=$(aws autoscaling describe-instance-refreshes --auto-scaling-group-name RollingASG --instance-refresh-ids $REFRESH_ID --query "InstanceRefreshes[0].PercentageComplete" --output text)
     
     echo "$(date): Status: $STATUS, Progress: $PERCENTAGE%"
     
     if [ "$STATUS" = "Successful" ] || [ "$STATUS" = "Failed" ] || [ "$STATUS" = "Cancelled" ]; then
       break
     fi
     
     sleep 30
   done
   ```

3. **Monitor application versions during deployment:**
   ```bash
   # Test application during rolling deployment
   echo "Testing application versions during deployment..."
   for i in {1..20}; do
     VERSION=$(curl -s http://$ALB_DNS/version | jq -r .version 2>/dev/null || echo "Error")
     echo "Request $i: Version $VERSION"
     sleep 10
   done
   ```

### Step 8: Validate Rolling Deployment

1. **Check final deployment status:**
   ```bash
   # Check instance refresh final status
   aws autoscaling describe-instance-refreshes --auto-scaling-group-name RollingASG --instance-refresh-ids $REFRESH_ID --query "InstanceRefreshes[0].[Status,StatusReason,PercentageComplete]" --output table
   
   # Check Auto Scaling Group instances
   aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names RollingASG --query "AutoScalingGroups[0].Instances[*].[InstanceId,LifecycleState,HealthStatus]" --output table
   ```

2. **Verify all instances are running new version:**
   ```bash
   # Check instance tags to verify versions
   aws ec2 describe-instances --filters "Name=tag:aws:autoscaling:groupName,Values=RollingASG" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].[InstanceId,Tags[?Key=='Version'].Value|[0]]" --output table
   
   # Test application multiple times to verify consistency
   echo "Testing final application state..."
   for i in {1..10}; do
     curl -s http://$ALB_DNS | grep -o "Version: [0-9.]*"
   done
   ```

### Step 9: Advanced Rolling Deployment Scenarios

1. **Simulate rollback scenario:**
   ```bash
   # Create a problematic version (Version 3.0 with issues)
   cat > user-data-v3-bad.sh << 'EOF'
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd

# Create problematic application version
cat > /var/www/html/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>Rolling Deployment Demo</title>
</head>
<body>
    <h1>Version: 3.0.0 (Problematic)</h1>
    <p>This version has issues!</p>
</body>
</html>
HTML

# Intentionally create a failing health check
echo "FAIL" > /var/www/html/health
EOF

   # Create problematic launch template version
   aws ec2 create-launch-template-version --launch-template-name RollingTemplate --version-description "Version 3.0.0 (Bad)" --launch-template-data '{
     "ImageId": "ami-0c02fb55956c7d316",
     "InstanceType": "t2.micro",
     "SecurityGroupIds": ["'$EC2_SG_ID'"],
     "UserData": "'$(base64 -w 0 user-data-v3-bad.sh)'",
     "TagSpecifications": [
       {
         "ResourceType": "instance",
         "Tags": [
           {"Key": "Name", "Value": "RollingInstance"},
           {"Key": "Version", "Value": "3.0.0"}
         ]
       }
     ]
   }'
   ```

2. **Start problematic deployment and observe rollback:**
   ```bash
   # Start instance refresh with problematic version
   aws autoscaling start-instance-refresh --auto-scaling-group-name RollingASG --preferences '{
     "InstanceWarmup": 180,
     "MinHealthyPercentage": 75,
     "CheckpointPercentages": [25],
     "CheckpointDelay": 180
   }' --desired-configuration '{
     "LaunchTemplate": {
       "LaunchTemplateName": "RollingTemplate",
       "Version": "3"
     }
   }'
   
   # Monitor for automatic rollback due to health check failures
   REFRESH_ID_BAD=$(aws autoscaling describe-instance-refreshes --auto-scaling-group-name RollingASG --query "InstanceRefreshes[0].InstanceRefreshId" --output text)
   echo "Monitoring problematic deployment: $REFRESH_ID_BAD"
   ```

3. **Cancel problematic deployment:**
   ```bash
   # Cancel the problematic deployment
   aws autoscaling cancel-instance-refresh --auto-scaling-group-name RollingASG
   
   # Verify cancellation
   aws autoscaling describe-instance-refreshes --auto-scaling-group-name RollingASG --instance-refresh-ids $REFRESH_ID_BAD --query "InstanceRefreshes[0].[Status,StatusReason]" --output table
   ```

## Troubleshooting Guide

### Common Issues and Solutions

1. **Instance refresh fails to start:**
   - Verify Auto Scaling Group exists and is in a stable state
   - Check that launch template version exists
   - Ensure MinHealthyPercentage allows for instance replacement
   - Verify IAM permissions for Auto Scaling service

2. **Instances fail health checks during deployment:**
   - Check application startup time and adjust InstanceWarmup
   - Verify health check endpoint returns HTTP 200
   - Review application logs on failing instances
   - Check security group rules allow health check traffic

3. **Rolling deployment takes too long:**
   - Reduce CheckpointDelay for faster progression
   - Increase CheckpointPercentages for more frequent validation
   - Adjust MinHealthyPercentage to allow more parallel replacements
   - Optimize application startup time

4. **Application shows mixed versions:**
   - This is expected during rolling deployment
   - Wait for deployment to complete
   - Check if deployment is stuck at a checkpoint
   - Verify all instances are healthy

### Debugging Commands

```bash
# Check instance refresh status
aws autoscaling describe-instance-refreshes --auto-scaling-group-name RollingASG

# Monitor Auto Scaling Group activity
aws autoscaling describe-scaling-activities --auto-scaling-group-name RollingASG --max-items 10

# Check target group health
aws elbv2 describe-target-health --target-group-arn $TG_ARN

# View instance system logs
aws ec2 get-console-output --instance-id <instance-id>

# Check CloudWatch metrics for ASG
aws cloudwatch get-metric-statistics --namespace AWS/AutoScaling --metric-name GroupDesiredCapacity --dimensions Name=AutoScalingGroupName,Value=RollingASG --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 300 --statistics Average

# Monitor ALB request distribution
aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name RequestCount --dimensions Name=LoadBalancer,Value=$(echo $ALB_ARN | cut -d'/' -f2-) --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S) --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 300 --statistics Sum
```

## Resources Created

This lab creates the following AWS resources:

### Networking
- **VPC**: Custom VPC with 10.0.0.0/16 CIDR block
- **Subnets**: Three public subnets across different AZs
- **Internet Gateway**: For public internet access
- **Route Table**: Custom route table with internet route
- **Security Groups**: ALB and EC2 security groups

### Load Balancing
- **Application Load Balancer**: Internet-facing ALB for traffic distribution
- **Target Group**: Single target group for all instances
- **Listener**: HTTP listener for routing traffic

### Compute
- **Launch Template**: Versioned instance configuration (multiple versions)
- **Auto Scaling Group**: Manages rolling instance replacement
- **EC2 Instances**: 4 t2.micro instances (replaced during rolling deployment)

### Estimated Costs
- Application Load Balancer: ~$0.54/day ($0.0225/hour)
- EC2 Instances (4 x t2.micro): $0.00/day (Free Tier) or ~$1.16/day
- EBS Volumes (4 x 8GB): ~$0.32/day
- Data Transfer: Minimal for testing
- **Total estimated cost**: $0.86-$2.02/day (partially Free Tier eligible)

## Cleanup

When you're finished with the lab, follow these steps to avoid ongoing charges:

1. **Cancel any active instance refresh:**
   ```bash
   aws autoscaling cancel-instance-refresh --auto-scaling-group-name RollingASG
   ```

2. **Delete Auto Scaling Group:**
   ```bash
   aws autoscaling delete-auto-scaling-group --auto-scaling-group-name RollingASG --force-delete
   ```

3. **Delete Load Balancer and Target Group:**
   ```bash
   aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN
   aws elbv2 delete-target-group --target-group-arn $TG_ARN
   ```

4. **Delete Launch Template:**
   ```bash
   aws ec2 delete-launch-template --launch-template-name RollingTemplate
   ```

5. **Delete Security Groups:**
   ```bash
   aws ec2 delete-security-group --group-id $ALB_SG_ID
   aws ec2 delete-security-group --group-id $EC2_SG_ID
   ```

6. **Delete VPC and networking components:**
   ```bash
   aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
   aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID
   aws ec2 delete-subnet --subnet-id $SUBNET1_ID
   aws ec2 delete-subnet --subnet-id $SUBNET2_ID
   aws ec2 delete-subnet --subnet-id $SUBNET3_ID
   aws ec2 delete-route-table --route-table-id $RT_ID
   aws ec2 delete-vpc --vpc-id $VPC_ID
   ```

> **Important**: Failure to delete resources may result in unexpected charges to your AWS account.

## Next Steps

After completing this lab, consider:

1. **Implement automated rolling deployments** using AWS CodeDeploy with rolling deployment configuration
2. **Add custom health checks** for application-specific validation
3. **Integrate with CI/CD pipelines** for automated rolling deployments
4. **Explore AWS Systems Manager** for more advanced deployment orchestration

## Certification Exam Tips

This lab covers several key areas for the AWS DevOps Professional exam:

- **Domain 2**: Configuration Management and Infrastructure as Code (Rolling deployment patterns)
- **Domain 3**: Monitoring and Logging (Deployment monitoring and health checks)
- **Domain 4**: Policies and Standards Automation (Automated deployment strategies)
- **Domain 5**: Incident and Event Response (Deployment rollback procedures)

Key concepts to remember:
- Rolling deployments provide gradual updates with configurable risk tolerance
- Instance refresh allows fine-grained control over deployment parameters
- Health checks are critical for automatic rollback during failed deployments
- MinHealthyPercentage controls the balance between deployment speed and availability
- Checkpoints provide validation points during the deployment process

## Additional Resources

- [AWS Auto Scaling Instance Refresh](https://docs.aws.amazon.com/autoscaling/ec2/userguide/asg-instance-refresh.html)
- [Rolling Deployments with AWS CodeDeploy](https://docs.aws.amazon.com/codedeploy/latest/userguide/applications-create-in-place.html)
- [Auto Scaling Group Health Checks](https://docs.aws.amazon.com/autoscaling/ec2/userguide/healthcheck.html)
- [Application Load Balancer Health Checks](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html)
- [Best Practices for Rolling Deployments](https://aws.amazon.com/builders-library/automating-safe-hands-off-deployments/)## La
b Approaches

This lab provides an automated CloudFormation approach for comprehensive rolling deployment testing with both ECS and Auto Scaling Group implementations.

### Quick Start

1. **Navigate to the lab directory:**
   ```bash
   cd AWSDevOpsLabs/05-deployment/rolling
   ```

2. **Run the provisioning script:**
   ```bash
   ./scripts/provision-rolling-lab.sh
   ```

3. **Follow the lab exercises below to test deployments**

4. **Clean up when finished:**
   ```bash
   ./scripts/cleanup-rolling-lab.sh
   ```

### What Gets Created

The automated provisioning creates:

#### ECS Rolling Deployment Infrastructure
- **ECS Cluster**: Fargate-based cluster with Container Insights enabled
- **ECS Service**: Configured for rolling deployments with circuit breaker
- **Task Definition**: Containerized application with health checks
- **Application Load Balancer**: With comprehensive health checking
- **Deployment Automation**: Lambda function for automated deployment management

#### Auto Scaling Group Rolling Deployment Infrastructure
- **Auto Scaling Group**: With rolling update policy and instance refresh capability
- **Launch Template**: EC2 instance configuration with user data for application setup
- **Application Load Balancer**: With target group health checking
- **Rolling Update Automation**: Lambda function for instance refresh management

#### Health Monitoring and Recovery Systems
- **CloudWatch Dashboards**: Real-time monitoring of deployment health and application metrics
- **Health Check Lambda**: Automated health monitoring with custom metrics
- **CloudWatch Alarms**: Multi-dimensional monitoring including health percentage, availability, and target health
- **EventBridge Rules**: Scheduled health checks every 5 minutes
- **Auto Recovery Lambda**: Automated recovery actions based on alarm triggers
- **SNS Topics**: Notifications for health alerts and recovery actions

### Lab Exercises

#### Exercise 1: ECS Rolling Deployment

1. **Test the initial ECS deployment:**
   ```bash
   # Get the ECS load balancer DNS from the script output
   ECS_ALB_DNS="<ECS_ALB_DNS_NAME>"
   
   # Test the application
   curl http://$ECS_ALB_DNS
   curl http://$ECS_ALB_DNS/health
   curl http://$ECS_ALB_DNS/version
   
   # Test multiple times to see different task responses
   for i in {1..10}; do
     curl -s http://$ECS_ALB_DNS | grep -o "Instance ID: [a-z0-9-]*" || echo "No instance ID found"
     sleep 1
   done
   ```

2. **Monitor ECS service status:**
   ```bash
   # Check ECS service details
   aws ecs describe-services \
     --cluster rolling-ecs-demo-cluster \
     --services rolling-ecs-demo-service \
     --query 'services[0].[serviceName,status,runningCount,pendingCount,desiredCount]' \
     --output table
   
   # Check task health
   aws ecs list-tasks \
     --cluster rolling-ecs-demo-cluster \
     --service-name rolling-ecs-demo-service
   ```

3. **Perform ECS rolling deployment:**
   ```bash
   # Deploy a new version using the helper script
   ./ecs-deploy.sh deploy nginx:1.21 2.0.0
   
   # Monitor deployment progress
   ./ecs-deploy.sh monitor
   
   # Check deployment status
   ./ecs-deploy.sh status
   ```

4. **Observe zero-downtime deployment:**
   ```bash
   # Monitor application availability during deployment
   while true; do
     response=$(curl -s -o /dev/null -w "%{http_code}" http://$ECS_ALB_DNS)
     version=$(curl -s http://$ECS_ALB_DNS/version | jq -r '.version' 2>/dev/null || echo "unknown")
     echo "$(date): HTTP $response, Version: $version"
     sleep 2
   done
   ```

#### Exercise 2: Auto Scaling Group Rolling Deployment

1. **Test the initial ASG deployment:**
   ```bash
   # Get the ASG load balancer DNS from the script output
   ASG_ALB_DNS="<ASG_ALB_DNS_NAME>"
   
   # Test the application
   curl http://$ASG_ALB_DNS
   curl http://$ASG_ALB_DNS/health
   curl http://$ASG_ALB_DNS/version
   
   # Test multiple times to see different instance responses
   for i in {1..10}; do
     curl -s http://$ASG_ALB_DNS | grep -o "Instance ID: [a-z0-9-]*" || echo "No instance ID found"
     sleep 1
   done
   ```

2. **Monitor Auto Scaling Group status:**
   ```bash
   # Check ASG details
   aws autoscaling describe-auto-scaling-groups \
     --auto-scaling-group-names rolling-asg-demo-asg \
     --query 'AutoScalingGroups[0].[AutoScalingGroupName,DesiredCapacity,MinSize,MaxSize]' \
     --output table
   
   # Check instance health
   aws autoscaling describe-auto-scaling-groups \
     --auto-scaling-group-names rolling-asg-demo-asg \
     --query 'AutoScalingGroups[0].Instances[*].[InstanceId,LifecycleState,HealthStatus]' \
     --output table
   ```

3. **Perform ASG rolling deployment:**
   ```bash
   # Deploy a new version using the helper script
   ./asg-deploy.sh deploy 2.0.0
   
   # Monitor deployment progress
   ./asg-deploy.sh monitor
   
   # Check deployment status
   ./asg-deploy.sh status
   ```

4. **Observe instance refresh process:**
   ```bash
   # Monitor application availability during instance refresh
   while true; do
     response=$(curl -s -o /dev/null -w "%{http_code}" http://$ASG_ALB_DNS)
     version=$(curl -s http://$ASG_ALB_DNS/version | jq -r '.version' 2>/dev/null || echo "unknown")
     instance_count=$(aws elbv2 describe-target-health --target-group-arn <ASG_TARGET_GROUP_ARN> --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`]' --output json | jq length)
     echo "$(date): HTTP $response, Version: $version, Healthy Instances: $instance_count"
     sleep 5
   done
   ```

#### Exercise 3: Health Monitoring and Automated Recovery

1. **Access health dashboards:**
   ```bash
   # Get dashboard URLs from the provisioning output
   echo "ECS Health Dashboard: <ECS_DASHBOARD_URL>"
   echo "ASG Health Dashboard: <ASG_DASHBOARD_URL>"
   
   # Open dashboards in browser to monitor:
   # - Load balancer metrics (response time, request count, error rates)
   # - Target health (healthy/unhealthy host counts)
   # - Application health metrics (health percentage, availability)
   ```

2. **Test health check automation:**
   ```bash
   # Manually trigger health check for ECS
   aws lambda invoke \
     --function-name rolling-ecs-demo-health-monitor \
     --payload '{
       "action": "health_check",
       "target_group_arn": "<ECS_TARGET_GROUP_ARN>",
       "load_balancer_dns": "<ECS_ALB_DNS>"
     }' \
     /tmp/ecs-health-response.json
   
   cat /tmp/ecs-health-response.json | jq '.'
   
   # Manually trigger health check for ASG
   aws lambda invoke \
     --function-name rolling-asg-demo-health-monitor \
     --payload '{
       "action": "health_check",
       "target_group_arn": "<ASG_TARGET_GROUP_ARN>",
       "load_balancer_dns": "<ASG_ALB_DNS>"
     }' \
     /tmp/asg-health-response.json
   
   cat /tmp/asg-health-response.json | jq '.'
   ```

3. **Test availability monitoring:**
   ```bash
   # Check availability over the last hour
   aws lambda invoke \
     --function-name rolling-ecs-demo-health-monitor \
     --payload '{
       "action": "availability_check",
       "target_group_arn": "<ECS_TARGET_GROUP_ARN>",
       "time_window_minutes": 60
     }' \
     /tmp/availability-response.json
   
   cat /tmp/availability-response.json | jq '.'
   ```

4. **Simulate health issues and observe recovery:**
   ```bash
   # Simulate unhealthy targets by stopping ECS tasks
   TASK_ARNS=$(aws ecs list-tasks \
     --cluster rolling-ecs-demo-cluster \
     --service-name rolling-ecs-demo-service \
     --query 'taskArns[0]' \
     --output text)
   
   # Stop one task to trigger unhealthy target alarm
   aws ecs stop-task \
     --cluster rolling-ecs-demo-cluster \
     --task $TASK_ARNS \
     --reason "Testing health monitoring"
   
   # Monitor alarm state changes
   aws cloudwatch describe-alarms \
     --alarm-names rolling-ecs-demo-UnhealthyTargets \
     --query 'MetricAlarms[0].[AlarmName,StateValue,StateReason]' \
     --output table
   ```

#### Exercise 4: Deployment Circuit Breaker Testing

1. **Test ECS deployment circuit breaker:**
   ```bash
   # Create a failing task definition
   aws ecs describe-task-definition \
     --task-definition rolling-ecs-demo-task \
     --query taskDefinition > failing-task-def.json
   
   # Modify to use a non-existent image
   jq '.containerDefinitions[0].image = "nginx:nonexistent-tag"' failing-task-def.json > modified-task-def.json
   jq 'del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .placementConstraints, .compatibilities, .registeredAt, .registeredBy)' modified-task-def.json > final-task-def.json
   
   # Register failing task definition
   FAILING_TASK_DEF=$(aws ecs register-task-definition \
     --cli-input-json file://final-task-def.json \
     --query 'taskDefinition.taskDefinitionArn' \
     --output text)
   
   # Deploy failing version to trigger circuit breaker
   aws ecs update-service \
     --cluster rolling-ecs-demo-cluster \
     --service rolling-ecs-demo-service \
     --task-definition $FAILING_TASK_DEF
   
   # Monitor circuit breaker activation
   ./ecs-deploy.sh monitor
   ```

2. **Observe automatic rollback:**
   ```bash
   # Check service events for circuit breaker activation
   aws ecs describe-services \
     --cluster rolling-ecs-demo-cluster \
     --services rolling-ecs-demo-service \
     --query 'services[0].events[0:5].[createdAt,message]' \
     --output table
   
   # Verify service returns to stable state
   ./ecs-deploy.sh status
   ```

## Troubleshooting Guide

### Common Issues and Solutions

1. **ECS tasks failing to start:**
   - Check task definition for correct image URI and resource allocation
   - Verify security group rules allow traffic from ALB
   - Check CloudWatch logs for container startup errors
   - Ensure task execution role has proper permissions

2. **ASG instances failing health checks:**
   - Verify user data script executes successfully
   - Check security group rules allow ALB health check traffic
   - Ensure application starts correctly and responds on health check path
   - Review CloudWatch logs for application errors

3. **Rolling deployment stuck:**
   - Check minimum healthy percentage configuration
   - Verify health check settings (path, timeout, thresholds)
   - Monitor CloudWatch alarms for deployment issues
   - Check for resource constraints (CPU, memory, network)

4. **Circuit breaker not triggering:**
   - Verify deployment configuration has circuit breaker enabled
   - Check alarm thresholds and evaluation periods
   - Ensure proper IAM permissions for circuit breaker actions
   - Review deployment events for circuit breaker status

### Debugging Commands

```bash
# Check ECS service events
aws ecs describe-services --cluster <cluster> --services <service> --query 'services[0].events[0:10]'

# Check ASG activity history
aws autoscaling describe-scaling-activities --auto-scaling-group-name <asg-name> --max-items 10

# Check target group health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>

# Check CloudWatch logs
aws logs filter-log-events --log-group-name <log-group> --start-time <timestamp>

# Check instance refresh status
aws autoscaling describe-instance-refreshes --auto-scaling-group-name <asg-name> --max-records 5
```

## Resources Created

This lab creates the following AWS resources:

### ECS Infrastructure
- **ECS Cluster**: Fargate cluster with Container Insights
- **ECS Service**: Rolling deployment configuration with circuit breaker
- **Task Definition**: Containerized application with health checks
- **Application Load Balancer**: Internet-facing ALB with health checking
- **Target Group**: ECS service target group with health check configuration

### Auto Scaling Group Infrastructure
- **Auto Scaling Group**: Rolling update policy with instance refresh
- **Launch Template**: EC2 instance configuration with versioning
- **Application Load Balancer**: Internet-facing ALB for ASG instances
- **Target Group**: ASG target group with health check configuration
- **Scaling Policies**: CPU-based auto scaling policies

### Monitoring and Automation
- **CloudWatch Dashboards**: Health monitoring dashboards for both deployments
- **CloudWatch Alarms**: Health, availability, and performance monitoring
- **Lambda Functions**: Deployment automation and health monitoring
- **EventBridge Rules**: Scheduled health checks
- **SNS Topics**: Health alert notifications

### Estimated Costs
- ECS Fargate Tasks (4 tasks): ~$1.44/day
- EC2 Instances (4 x t3.micro): ~$1.16/day
- Application Load Balancers (2): ~$1.08/day
- Lambda Functions: ~$0.02/day
- CloudWatch: ~$0.50/day
- **Total estimated cost**: ~$4.20/day

## Cleanup

When you're finished with the lab, run the cleanup script:

```bash
./scripts/cleanup-rolling-lab.sh
```

This will remove all created resources including:
- CloudFormation stacks
- CloudWatch log groups, alarms, and dashboards
- Lambda functions
- EventBridge rules
- SNS topics
- Local helper scripts

> **Important**: Failure to clean up resources may result in unexpected charges to your AWS account.

## Next Steps

After completing this lab, consider:

1. **Implement blue-green deployments** for instant traffic switching
2. **Add canary deployments** for gradual traffic shifting
3. **Integrate with CI/CD pipelines** for automated rolling deployments
4. **Explore advanced health checks** with custom metrics
5. **Add multi-region rolling deployments** for global applications

## Certification Exam Tips

This lab covers several key areas for the AWS DevOps Professional exam:

- **Domain 2**: Configuration Management and Infrastructure as Code (Rolling deployment patterns)
- **Domain 3**: Monitoring and Logging (Application monitoring and health checks)
- **Domain 4**: Policies and Standards Automation (Automated deployment strategies)
- **Domain 5**: Incident and Event Response (Circuit breakers and automated recovery)

Key concepts to remember:
- Rolling deployments provide zero-downtime updates by gradually replacing instances/tasks
- Circuit breakers automatically rollback failed deployments
- Health checks are critical for determining deployment success
- Instance refresh provides modern rolling update capabilities for Auto Scaling Groups
- ECS deployment configuration controls rolling update behavior

## Additional Resources

- [ECS Rolling Deployments](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-types.html)
- [Auto Scaling Group Instance Refresh](https://docs.aws.amazon.com/autoscaling/ec2/userguide/asg-instance-refresh.html)
- [ECS Deployment Circuit Breaker](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-circuit-breaker.html)
- [Application Load Balancer Health Checks](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html)
- [CloudWatch Container Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights.html)