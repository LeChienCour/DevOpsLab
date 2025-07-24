# Blue-Green Deployment Lab Guide

## Objective
Learn how to implement blue-green deployment strategies using AWS services to achieve zero-downtime deployments. This lab demonstrates how to maintain two identical production environments (blue and green) and switch traffic between them for seamless application updates.

## Learning Outcomes
By completing this lab, you will:
- Understand blue-green deployment concepts and benefits
- Implement blue-green deployments using Application Load Balancer and target groups
- Configure automated traffic switching between environments
- Practice rollback procedures for failed deployments
- Monitor deployment health and performance metrics

## Prerequisites
- AWS Account with administrative access
- AWS CLI configured with appropriate credentials
- Basic understanding of load balancers and target groups
- Familiarity with EC2 instances and Auto Scaling Groups
- Docker installed locally (for application containerization)

### Required AWS Permissions
Your AWS user/role needs the following permissions:
- EC2: Full access for creating instances, security groups, and load balancers
- Auto Scaling: Full access for managing Auto Scaling Groups
- ELB: Full access for managing Application Load Balancers and target groups
- IAM: Read access for service roles
- CloudWatch: Read access for monitoring metrics

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
│                 (Traffic Router)                            │
└─────────────┬───────────────────────┬───────────────────────┘
              │                       │
    ┌─────────▼─────────┐   ┌─────────▼─────────┐
    │   Blue Target     │   │  Green Target     │
    │     Group         │   │     Group         │
    │   (Production)    │   │   (Staging)       │
    └─────────┬─────────┘   └─────────┬─────────┘
              │                       │
    ┌─────────▼─────────┐   ┌─────────▼─────────┐
    │  Auto Scaling     │   │  Auto Scaling     │
    │  Group (Blue)     │   │  Group (Green)    │
    │                   │   │                   │
    │ ┌───┐ ┌───┐ ┌───┐ │   │ ┌───┐ ┌───┐ ┌───┐ │
    │ │EC2│ │EC2│ │EC2│ │   │ │EC2│ │EC2│ │EC2│ │
    │ └───┘ └───┘ └───┘ │   │ └───┘ └───┘ └───┘ │
    └───────────────────┘   └───────────────────┘
```

### Resources Created:
- **Application Load Balancer**: Routes traffic between blue and green environments
- **Target Groups**: Blue and Green target groups for environment separation
- **Auto Scaling Groups**: Separate ASGs for blue and green environments
- **EC2 Instances**: Application servers in both environments
- **Security Groups**: Network access control for instances and load balancer
- **Launch Template**: Configuration template for EC2 instances

## Lab Steps

### Step 1: Create VPC and Networking Components

1. **Create a VPC for the deployment:**
   ```bash
   # Create VPC
   aws ec2 create-vpc --cidr-block 10.0.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=BlueGreenVPC}]'
   ```

2. **Create public subnets in different availability zones:**
   ```bash
   # Get VPC ID
   VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=BlueGreenVPC" --query "Vpcs[0].VpcId" --output text)
   
   # Create first subnet
   aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone us-east-1a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=BlueGreenSubnet1}]'
   
   # Create second subnet
   aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --availability-zone us-east-1b --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=BlueGreenSubnet2}]'
   ```

3. **Create and attach Internet Gateway:**
   ```bash
   # Create Internet Gateway
   aws ec2 create-internet-gateway --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=BlueGreenIGW}]'
   
   # Get IGW ID
   IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=tag:Name,Values=BlueGreenIGW" --query "InternetGateways[0].InternetGatewayId" --output text)
   
   # Attach to VPC
   aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
   ```

### Step 2: Create Security Groups

1. **Create security group for the load balancer:**
   ```bash
   aws ec2 create-security-group --group-name BlueGreenALB-SG --description "Security group for Blue-Green ALB" --vpc-id $VPC_ID --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=BlueGreenALB-SG}]'
   ```

2. **Add inbound rules for HTTP traffic:**
   ```bash
   # Get ALB security group ID
   ALB_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=BlueGreenALB-SG" --query "SecurityGroups[0].GroupId" --output text)
   
   # Allow HTTP traffic
   aws ec2 authorize-security-group-ingress --group-id $ALB_SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0
   ```

3. **Create security group for EC2 instances:**
   ```bash
   aws ec2 create-security-group --group-name BlueGreenEC2-SG --description "Security group for Blue-Green EC2 instances" --vpc-id $VPC_ID --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=BlueGreenEC2-SG}]'
   
   # Get EC2 security group ID
   EC2_SG_ID=$(aws ec2 describe-security-group --filters "Name=group-name,Values=BlueGreenEC2-SG" --query "SecurityGroups[0].GroupId" --output text)
   
   # Allow traffic from ALB
   aws ec2 authorize-security-group-ingress --group-id $EC2_SG_ID --protocol tcp --port 80 --source-group $ALB_SG_ID
   ```

### Step 3: Create Application Load Balancer

1. **Create the Application Load Balancer:**
   ```bash
   # Get subnet IDs
   SUBNET1_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=BlueGreenSubnet1" --query "Subnets[0].SubnetId" --output text)
   SUBNET2_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=BlueGreenSubnet2" --query "Subnets[0].SubnetId" --output text)
   
   # Create ALB
   aws elbv2 create-load-balancer --name BlueGreenALB --subnets $SUBNET1_ID $SUBNET2_ID --security-groups $ALB_SG_ID --scheme internet-facing --type application --ip-address-type ipv4
   ```

2. **Create target groups for blue and green environments:**
   ```bash
   # Create Blue target group
   aws elbv2 create-target-group --name BlueTargetGroup --protocol HTTP --port 80 --vpc-id $VPC_ID --health-check-path /health --health-check-interval-seconds 30 --health-check-timeout-seconds 5 --healthy-threshold-count 2 --unhealthy-threshold-count 3
   
   # Create Green target group
   aws elbv2 create-target-group --name GreenTargetGroup --protocol HTTP --port 80 --vpc-id $VPC_ID --health-check-path /health --health-check-interval-seconds 30 --health-check-timeout-seconds 5 --healthy-threshold-count 2 --unhealthy-threshold-count 3
   ```

3. **Create listener and default rule:**
   ```bash
   # Get ALB ARN
   ALB_ARN=$(aws elbv2 describe-load-balancers --names BlueGreenALB --query "LoadBalancers[0].LoadBalancerArn" --output text)
   
   # Get Blue target group ARN
   BLUE_TG_ARN=$(aws elbv2 describe-target-groups --names BlueTargetGroup --query "TargetGroups[0].TargetGroupArn" --output text)
   
   # Create listener (initially pointing to Blue)
   aws elbv2 create-listener --load-balancer-arn $ALB_ARN --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=$BLUE_TG_ARN
   ```

### Step 4: Create Launch Template and Auto Scaling Groups

1. **Create launch template for the application:**
   ```bash
   # Create launch template with user data script
   cat > user-data.sh << 'EOF'
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd

# Create a simple web application
cat > /var/www/html/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>Blue-Green Deployment Demo</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        .blue { background-color: #4CAF50; color: white; }
        .green { background-color: #2196F3; color: white; }
    </style>
</head>
<body class="blue">
    <h1>Blue Environment</h1>
    <p>Version: 1.0</p>
    <p>Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
</body>
</html>
HTML

# Create health check endpoint
cat > /var/www/html/health << 'HTML'
OK
HTML
EOF

   # Create launch template
   aws ec2 create-launch-template --launch-template-name BlueGreenTemplate --version-description "Initial version" --launch-template-data '{
     "ImageId": "ami-0c02fb55956c7d316",
     "InstanceType": "t2.micro",
     "SecurityGroupIds": ["'$EC2_SG_ID'"],
     "UserData": "'$(base64 -w 0 user-data.sh)'"
   }'
   ```

2. **Create Auto Scaling Group for Blue environment:**
   ```bash
   aws autoscaling create-auto-scaling-group --auto-scaling-group-name BlueASG --launch-template LaunchTemplateName=BlueGreenTemplate,Version=1 --min-size 2 --max-size 4 --desired-capacity 2 --target-group-arns $BLUE_TG_ARN --vpc-zone-identifier "$SUBNET1_ID,$SUBNET2_ID" --health-check-type ELB --health-check-grace-period 300
   ```

3. **Verify Blue environment is healthy:**
   ```bash
   # Check target group health
   aws elbv2 describe-target-health --target-group-arn $BLUE_TG_ARN
   ```

### Step 5: Deploy Green Environment

1. **Create user data for Green environment (updated version):**
   ```bash
   cat > user-data-green.sh << 'EOF'
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd

# Create updated web application
cat > /var/www/html/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>Blue-Green Deployment Demo</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        .blue { background-color: #4CAF50; color: white; }
        .green { background-color: #2196F3; color: white; }
    </style>
</head>
<body class="green">
    <h1>Green Environment</h1>
    <p>Version: 2.0</p>
    <p>Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
    <p>New Feature: Enhanced UI!</p>
</body>
</html>
HTML

# Create health check endpoint
cat > /var/www/html/health << 'HTML'
OK
HTML
EOF

   # Create new launch template version
   aws ec2 create-launch-template-version --launch-template-name BlueGreenTemplate --version-description "Green version" --launch-template-data '{
     "ImageId": "ami-0c02fb55956c7d316",
     "InstanceType": "t2.micro",
     "SecurityGroupIds": ["'$EC2_SG_ID'"],
     "UserData": "'$(base64 -w 0 user-data-green.sh)'"
   }'
   ```

2. **Create Auto Scaling Group for Green environment:**
   ```bash
   # Get Green target group ARN
   GREEN_TG_ARN=$(aws elbv2 describe-target-groups --names GreenTargetGroup --query "TargetGroups[0].TargetGroupArn" --output text)
   
   aws autoscaling create-auto-scaling-group --auto-scaling-group-name GreenASG --launch-template LaunchTemplateName=BlueGreenTemplate,Version=2 --min-size 2 --max-size 4 --desired-capacity 2 --target-group-arns $GREEN_TG_ARN --vpc-zone-identifier "$SUBNET1_ID,$SUBNET2_ID" --health-check-type ELB --health-check-grace-period 300
   ```

3. **Wait for Green environment to be healthy:**
   ```bash
   # Monitor Green target group health
   aws elbv2 describe-target-health --target-group-arn $GREEN_TG_ARN
   ```

### Step 6: Perform Blue-Green Switch

1. **Test Green environment before switching:**
   ```bash
   # Get ALB DNS name
   ALB_DNS=$(aws elbv2 describe-load-balancers --names BlueGreenALB --query "LoadBalancers[0].DNSName" --output text)
   
   # Test current (Blue) environment
   curl http://$ALB_DNS
   ```

2. **Switch traffic to Green environment:**
   ```bash
   # Get listener ARN
   LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn $ALB_ARN --query "Listeners[0].ListenerArn" --output text)
   
   # Update listener to point to Green target group
   aws elbv2 modify-listener --listener-arn $LISTENER_ARN --default-actions Type=forward,TargetGroupArn=$GREEN_TG_ARN
   ```

3. **Verify the switch:**
   ```bash
   # Test new (Green) environment
   curl http://$ALB_DNS
   
   # Monitor both target groups
   echo "Blue Target Group Health:"
   aws elbv2 describe-target-health --target-group-arn $BLUE_TG_ARN
   echo "Green Target Group Health:"
   aws elbv2 describe-target-health --target-group-arn $GREEN_TG_ARN
   ```

### Step 7: Monitor and Validate Deployment

1. **Monitor application metrics:**
   ```bash
   # Check ALB metrics
   aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name RequestCount --dimensions Name=LoadBalancer,Value=$(echo $ALB_ARN | cut -d'/' -f2-) --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 300 --statistics Sum
   ```

2. **Perform load testing (optional):**
   ```bash
   # Simple load test
   for i in {1..10}; do
     curl -s http://$ALB_DNS | grep -o "Version: [0-9.]*"
     sleep 1
   done
   ```

### Step 8: Rollback Procedure (if needed)

1. **Quick rollback to Blue environment:**
   ```bash
   # Switch back to Blue if issues are detected
   aws elbv2 modify-listener --listener-arn $LISTENER_ARN --default-actions Type=forward,TargetGroupArn=$BLUE_TG_ARN
   ```

2. **Verify rollback:**
   ```bash
   curl http://$ALB_DNS
   ```

## Troubleshooting Guide

### Common Issues and Solutions

1. **Target group shows unhealthy instances:**
   - Check security group rules allow traffic from ALB to instances
   - Verify health check path (/health) returns HTTP 200
   - Ensure instances are in the correct subnets
   - Check instance user data script executed successfully

2. **Load balancer returns 503 Service Unavailable:**
   - Verify target group has healthy instances
   - Check if Auto Scaling Group has launched instances
   - Ensure instances are registered with the target group

3. **Cannot access application through ALB:**
   - Verify ALB security group allows inbound HTTP traffic
   - Check route table has route to Internet Gateway
   - Ensure subnets are public and have Internet Gateway route

4. **Auto Scaling Group instances not launching:**
   - Check IAM permissions for Auto Scaling service
   - Verify launch template configuration
   - Check if instance type is available in selected AZs

### Debugging Commands

```bash
# Check ALB status
aws elbv2 describe-load-balancers --names BlueGreenALB

# Check target group health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>

# Check Auto Scaling Group status
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names BlueASG GreenASG

# Check instance status
aws ec2 describe-instances --filters "Name=tag:aws:autoscaling:groupName,Values=BlueASG"

# View CloudWatch logs for debugging
aws logs describe-log-groups --log-group-name-prefix /aws/ec2
```

## Resources Created

This lab creates the following AWS resources:

### Networking
- **VPC**: Custom VPC with 10.0.0.0/16 CIDR block
- **Subnets**: Two public subnets in different AZs
- **Internet Gateway**: For public internet access
- **Security Groups**: ALB and EC2 security groups

### Load Balancing
- **Application Load Balancer**: Internet-facing ALB for traffic distribution
- **Target Groups**: Blue and Green target groups for environment separation
- **Listener**: HTTP listener with routing rules

### Compute
- **Launch Template**: EC2 instance configuration template
- **Auto Scaling Groups**: Blue and Green ASGs with 2 instances each
- **EC2 Instances**: 4 t2.micro instances total (2 per environment)

### Estimated Costs
- Application Load Balancer: ~$0.54/day ($0.0225/hour)
- EC2 Instances (4 x t2.micro): $0.00/day (Free Tier) or ~$1.16/day
- EBS Volumes (4 x 8GB): ~$0.32/day
- Data Transfer: Minimal for testing
- **Total estimated cost**: $0.86-$2.02/day (partially Free Tier eligible)

## Cleanup

When you're finished with the lab, follow these steps to avoid ongoing charges:

1. **Delete Auto Scaling Groups:**
   ```bash
   aws autoscaling delete-auto-scaling-group --auto-scaling-group-name BlueASG --force-delete
   aws autoscaling delete-auto-scaling-group --auto-scaling-group-name GreenASG --force-delete
   ```

2. **Delete Load Balancer and Target Groups:**
   ```bash
   aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN
   aws elbv2 delete-target-group --target-group-arn $BLUE_TG_ARN
   aws elbv2 delete-target-group --target-group-arn $GREEN_TG_ARN
   ```

3. **Delete Launch Template:**
   ```bash
   aws ec2 delete-launch-template --launch-template-name BlueGreenTemplate
   ```

4. **Delete Security Groups:**
   ```bash
   aws ec2 delete-security-group --group-id $ALB_SG_ID
   aws ec2 delete-security-group --group-id $EC2_SG_ID
   ```

5. **Delete VPC and networking components:**
   ```bash
   aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
   aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID
   aws ec2 delete-subnet --subnet-id $SUBNET1_ID
   aws ec2 delete-subnet --subnet-id $SUBNET2_ID
   aws ec2 delete-vpc --vpc-id $VPC_ID
   ```

> **Important**: Failure to delete resources may result in unexpected charges to your AWS account.

## Next Steps

After completing this lab, consider:

1. **Implement automated blue-green deployments** using AWS CodeDeploy with blue-green deployment configuration
2. **Add monitoring and alerting** using CloudWatch alarms for automatic rollback triggers
3. **Explore canary deployments** for more gradual traffic shifting
4. **Integrate with CI/CD pipelines** using AWS CodePipeline for automated deployments

## Certification Exam Tips

This lab covers several key areas for the AWS DevOps Professional exam:

- **Domain 2**: Configuration Management and Infrastructure as Code (Blue-green deployment patterns)
- **Domain 3**: Monitoring and Logging (Application and infrastructure monitoring)
- **Domain 4**: Policies and Standards Automation (Automated deployment strategies)
- **Domain 5**: Incident and Event Response (Rollback procedures and monitoring)

Key concepts to remember:
- Blue-green deployments provide zero-downtime deployments with instant rollback capability
- Target groups enable traffic routing between different application versions
- Auto Scaling Groups ensure high availability and scalability for both environments
- Health checks are critical for determining when to switch traffic
- Monitoring is essential for detecting issues and triggering rollbacks

## Additional Resources

- [AWS Application Load Balancer Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [Blue/Green Deployments on AWS](https://docs.aws.amazon.com/whitepapers/latest/blue-green-deployments/welcome.html)
- [AWS Auto Scaling Documentation](https://docs.aws.amazon.com/autoscaling/)
- [AWS CodeDeploy Blue-Green Deployments](https://docs.aws.amazon.com/codedeploy/latest/userguide/applications-create-blue-green.html)
- [Implementing Blue-Green Deployments with AWS CodeDeploy and Auto Scaling Groups](https://aws.amazon.com/blogs/compute/bluegreen-deployments-with-amazon-ecs/)