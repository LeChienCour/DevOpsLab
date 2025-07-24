# Canary Deployment Lab Guide

## Objective
Learn how to implement canary deployment strategies using AWS services to gradually roll out new application versions with minimal risk. This lab demonstrates how to route a small percentage of traffic to a new version while monitoring performance and gradually increasing traffic based on success metrics.

## Learning Outcomes
By completing this lab, you will:
- Understand canary deployment concepts and risk mitigation strategies
- Implement weighted traffic routing using Application Load Balancer
- Configure gradual traffic shifting between application versions
- Set up monitoring and automated rollback based on metrics
- Practice safe deployment practices with real-time validation

## Prerequisites
- AWS Account with administrative access
- AWS CLI configured with appropriate credentials
- Basic understanding of load balancers and target groups
- Familiarity with CloudWatch metrics and alarms
- Knowledge of Auto Scaling Groups and EC2 instances

### Required AWS Permissions
Your AWS user/role needs the following permissions:
- EC2: Full access for creating instances, security groups, and load balancers
- Auto Scaling: Full access for managing Auto Scaling Groups
- ELB: Full access for managing Application Load Balancers and target groups
- CloudWatch: Full access for creating alarms and viewing metrics
- IAM: Read access for service roles
- Lambda: Create and execute functions (for automation)

### Time to Complete
Approximately 60-75 minutes

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Internet Gateway                          │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│              Application Load Balancer                      │
│                 (Weighted Routing)                          │
└─────────────┬───────────────────────┬───────────────────────┘
              │ 90% Traffic           │ 10% Traffic (Canary)
    ┌─────────▼─────────┐   ┌─────────▼─────────┐
    │  Production       │   │   Canary          │
    │  Target Group     │   │  Target Group     │
    │   (Stable)        │   │  (New Version)    │
    └─────────┬─────────┘   └─────────┬─────────┘
              │                       │
    ┌─────────▼─────────┐   ┌─────────▼─────────┐
    │  Auto Scaling     │   │  Auto Scaling     │
    │ Group (Prod)      │   │ Group (Canary)    │
    │                   │   │                   │
    │ ┌───┐ ┌───┐ ┌───┐ │   │ ┌───┐             │
    │ │EC2│ │EC2│ │EC2│ │   │ │EC2│             │
    │ └───┘ └───┘ └───┘ │   │ └───┘             │
    └───────────────────┘   └───────────────────┘
              │                       │
    ┌─────────▼─────────┐   ┌─────────▼─────────┐
    │   CloudWatch      │   │   CloudWatch      │
    │   Metrics         │   │   Alarms          │
    │   (Success Rate)  │   │ (Auto Rollback)   │
    └───────────────────┘   └───────────────────┘
```

### Resources Created:
- **Application Load Balancer**: Routes traffic with weighted distribution
- **Target Groups**: Production and Canary target groups with different weights
- **Auto Scaling Groups**: Separate ASGs for production and canary environments
- **EC2 Instances**: Application servers for both environments
- **CloudWatch Alarms**: Monitoring for automatic rollback triggers
- **Lambda Function**: Automated traffic shifting and rollback logic
- **Security Groups**: Network access control

## Lab Steps

### Step 1: Set Up VPC and Networking (Reuse from Blue-Green Lab)

1. **Create VPC and subnets (if not already created):**
   ```bash
   # Create VPC
   aws ec2 create-vpc --cidr-block 10.0.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=CanaryVPC}]'
   
   # Get VPC ID
   VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=CanaryVPC" --query "Vpcs[0].VpcId" --output text)
   
   # Create subnets
   aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone us-east-1a --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=CanarySubnet1}]'
   aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --availability-zone us-east-1b --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=CanarySubnet2}]'
   ```

2. **Create and configure Internet Gateway:**
   ```bash
   # Create and attach Internet Gateway
   aws ec2 create-internet-gateway --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=CanaryIGW}]'
   IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=tag:Name,Values=CanaryIGW" --query "InternetGateways[0].InternetGatewayId" --output text)
   aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
   ```

### Step 2: Create Security Groups

1. **Create security groups:**
   ```bash
   # ALB Security Group
   aws ec2 create-security-group --group-name CanaryALB-SG --description "Security group for Canary ALB" --vpc-id $VPC_ID --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=CanaryALB-SG}]'
   ALB_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=CanaryALB-SG" --query "SecurityGroups[0].GroupId" --output text)
   
   # EC2 Security Group
   aws ec2 create-security-group --group-name CanaryEC2-SG --description "Security group for Canary EC2 instances" --vpc-id $VPC_ID --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=CanaryEC2-SG}]'
   EC2_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=CanaryEC2-SG" --query "SecurityGroups[0].GroupId" --output text)
   
   # Configure security group rules
   aws ec2 authorize-security-group-ingress --group-id $ALB_SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0
   aws ec2 authorize-security-group-ingress --group-id $EC2_SG_ID --protocol tcp --port 80 --source-group $ALB_SG_ID
   ```

### Step 3: Create Application Load Balancer with Weighted Target Groups

1. **Create Application Load Balancer:**
   ```bash
   # Get subnet IDs
   SUBNET1_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=CanarySubnet1" --query "Subnets[0].SubnetId" --output text)
   SUBNET2_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=CanarySubnet2" --query "Subnets[0].SubnetId" --output text)
   
   # Create ALB
   aws elbv2 create-load-balancer --name CanaryALB --subnets $SUBNET1_ID $SUBNET2_ID --security-groups $ALB_SG_ID --scheme internet-facing --type application
   ALB_ARN=$(aws elbv2 describe-load-balancers --names CanaryALB --query "LoadBalancers[0].LoadBalancerArn" --output text)
   ```

2. **Create target groups for production and canary:**
   ```bash
   # Production target group
   aws elbv2 create-target-group --name ProductionTG --protocol HTTP --port 80 --vpc-id $VPC_ID --health-check-path /health --health-check-interval-seconds 30 --health-check-timeout-seconds 5 --healthy-threshold-count 2 --unhealthy-threshold-count 2
   PROD_TG_ARN=$(aws elbv2 describe-target-groups --names ProductionTG --query "TargetGroups[0].TargetGroupArn" --output text)
   
   # Canary target group
   aws elbv2 create-target-group --name CanaryTG --protocol HTTP --port 80 --vpc-id $VPC_ID --health-check-path /health --health-check-interval-seconds 30 --health-check-timeout-seconds 5 --healthy-threshold-count 2 --unhealthy-threshold-count 2
   CANARY_TG_ARN=$(aws elbv2 describe-target-groups --names CanaryTG --query "TargetGroups[0].TargetGroupArn" --output text)
   ```

3. **Create listener with weighted routing:**
   ```bash
   # Create listener with weighted target groups (90% production, 10% canary)
   aws elbv2 create-listener --load-balancer-arn $ALB_ARN --protocol HTTP --port 80 --default-actions '[
     {
       "Type": "forward",
       "ForwardConfig": {
         "TargetGroups": [
           {
             "TargetGroupArn": "'$PROD_TG_ARN'",
             "Weight": 90
           },
           {
             "TargetGroupArn": "'$CANARY_TG_ARN'",
             "Weight": 10
           }
         ]
       }
     }
   ]'
   ```

### Step 4: Deploy Production Environment

1. **Create launch template for production:**
   ```bash
   cat > user-data-prod.sh << 'EOF'
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd

# Create production application
cat > /var/www/html/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>Canary Deployment Demo</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background-color: #f0f8ff; }
        .version { background-color: #4CAF50; color: white; padding: 20px; border-radius: 10px; }
    </style>
</head>
<body>
    <div class="version">
        <h1>Production Version</h1>
        <p>Version: 1.0.0</p>
        <p>Environment: Production</p>
        <p>Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
        <p>Timestamp: $(date)</p>
    </div>
</body>
</html>
HTML

# Create health check endpoint
echo "OK" > /var/www/html/health

# Create metrics endpoint for monitoring
cat > /var/www/html/metrics << 'HTML'
{
  "version": "1.0.0",
  "environment": "production",
  "status": "healthy",
  "timestamp": "$(date -Iseconds)"
}
HTML
EOF

   aws ec2 create-launch-template --launch-template-name CanaryProdTemplate --version-description "Production version" --launch-template-data '{
     "ImageId": "ami-0c02fb55956c7d316",
     "InstanceType": "t2.micro",
     "SecurityGroupIds": ["'$EC2_SG_ID'"],
     "UserData": "'$(base64 -w 0 user-data-prod.sh)'"
   }'
   ```

2. **Create Auto Scaling Group for production:**
   ```bash
   aws autoscaling create-auto-scaling-group --auto-scaling-group-name ProductionASG --launch-template LaunchTemplateName=CanaryProdTemplate,Version=1 --min-size 3 --max-size 6 --desired-capacity 3 --target-group-arns $PROD_TG_ARN --vpc-zone-identifier "$SUBNET1_ID,$SUBNET2_ID" --health-check-type ELB --health-check-grace-period 300
   ```

### Step 5: Deploy Canary Environment

1. **Create launch template for canary (new version):**
   ```bash
   cat > user-data-canary.sh << 'EOF'
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd

# Create canary application with new features
cat > /var/www/html/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>Canary Deployment Demo</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background-color: #fff8dc; }
        .version { background-color: #ff6b35; color: white; padding: 20px; border-radius: 10px; }
        .feature { background-color: #ffd700; color: #333; padding: 10px; margin: 10px; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="version">
        <h1>Canary Version</h1>
        <p>Version: 2.0.0</p>
        <p>Environment: Canary</p>
        <p>Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
        <p>Timestamp: $(date)</p>
    </div>
    <div class="feature">
        <h3>🚀 New Features in v2.0.0</h3>
        <ul>
            <li>Enhanced UI Design</li>
            <li>Improved Performance</li>
            <li>Better Error Handling</li>
        </ul>
    </div>
</body>
</html>
HTML

# Create health check endpoint
echo "OK" > /var/www/html/health

# Create metrics endpoint
cat > /var/www/html/metrics << 'HTML'
{
  "version": "2.0.0",
  "environment": "canary",
  "status": "healthy",
  "timestamp": "$(date -Iseconds)"
}
HTML
EOF

   aws ec2 create-launch-template --launch-template-name CanaryNewTemplate --version-description "Canary version" --launch-template-data '{
     "ImageId": "ami-0c02fb55956c7d316",
     "InstanceType": "t2.micro",
     "SecurityGroupIds": ["'$EC2_SG_ID'"],
     "UserData": "'$(base64 -w 0 user-data-canary.sh)'"
   }'
   ```

2. **Create Auto Scaling Group for canary:**
   ```bash
   aws autoscaling create-auto-scaling-group --auto-scaling-group-name CanaryASG --launch-template LaunchTemplateName=CanaryNewTemplate,Version=1 --min-size 1 --max-size 2 --desired-capacity 1 --target-group-arns $CANARY_TG_ARN --vpc-zone-identifier "$SUBNET1_ID,$SUBNET2_ID" --health-check-type ELB --health-check-grace-period 300
   ```

### Step 6: Set Up Monitoring and Alarms

1. **Create CloudWatch alarms for canary monitoring:**
   ```bash
   # Create alarm for high error rate in canary
   aws cloudwatch put-metric-alarm --alarm-name "CanaryHighErrorRate" --alarm-description "High error rate in canary deployment" --metric-name HTTPCode_Target_5XX_Count --namespace AWS/ApplicationELB --statistic Sum --period 300 --threshold 5 --comparison-operator GreaterThanThreshold --evaluation-periods 2 --dimensions Name=TargetGroup,Value=$(echo $CANARY_TG_ARN | cut -d'/' -f2-)
   
   # Create alarm for canary target health
   aws cloudwatch put-metric-alarm --alarm-name "CanaryUnhealthyTargets" --alarm-description "Unhealthy targets in canary group" --metric-name UnHealthyHostCount --namespace AWS/ApplicationELB --statistic Average --period 300 --threshold 0 --comparison-operator GreaterThanThreshold --evaluation-periods 1 --dimensions Name=TargetGroup,Value=$(echo $CANARY_TG_ARN | cut -d'/' -f2-)
   ```

2. **Create Lambda function for automated traffic shifting:**
   ```bash
   cat > canary-controller.py << 'EOF'
import json
import boto3
import os

def lambda_handler(event, context):
    elbv2 = boto3.client('elbv2')
    cloudwatch = boto3.client('cloudwatch')
    
    # Get environment variables
    listener_arn = os.environ['LISTENER_ARN']
    prod_tg_arn = os.environ['PROD_TG_ARN']
    canary_tg_arn = os.environ['CANARY_TG_ARN']
    
    # Get current traffic weights
    response = elbv2.describe_listeners(ListenerArns=[listener_arn])
    current_actions = response['Listeners'][0]['DefaultActions'][0]['ForwardConfig']['TargetGroups']
    
    canary_weight = next((tg['Weight'] for tg in current_actions if tg['TargetGroupArn'] == canary_tg_arn), 0)
    prod_weight = next((tg['Weight'] for tg in current_actions if tg['TargetGroupArn'] == prod_tg_arn), 100)
    
    # Check if we should increase canary traffic
    action = event.get('action', 'increase')
    
    if action == 'increase' and canary_weight < 100:
        new_canary_weight = min(canary_weight + 10, 100)
        new_prod_weight = 100 - new_canary_weight
        
        # Update listener
        elbv2.modify_listener(
            ListenerArn=listener_arn,
            DefaultActions=[{
                'Type': 'forward',
                'ForwardConfig': {
                    'TargetGroups': [
                        {'TargetGroupArn': prod_tg_arn, 'Weight': new_prod_weight},
                        {'TargetGroupArn': canary_tg_arn, 'Weight': new_canary_weight}
                    ]
                }
            }]
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps(f'Traffic shifted: Prod {new_prod_weight}%, Canary {new_canary_weight}%')
        }
    
    elif action == 'rollback':
        # Rollback to 100% production
        elbv2.modify_listener(
            ListenerArn=listener_arn,
            DefaultActions=[{
                'Type': 'forward',
                'ForwardConfig': {
                    'TargetGroups': [
                        {'TargetGroupArn': prod_tg_arn, 'Weight': 100},
                        {'TargetGroupArn': canary_tg_arn, 'Weight': 0}
                    ]
                }
            }]
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps('Rolled back to 100% production')
        }
    
    return {
        'statusCode': 200,
        'body': json.dumps('No action taken')
    }
EOF

   # Create deployment package
   zip canary-controller.zip canary-controller.py
   
   # Create Lambda function
   aws lambda create-function --function-name CanaryController --runtime python3.9 --role arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/lambda-execution-role --handler canary-controller.lambda_handler --zip-file fileb://canary-controller.zip
   ```

### Step 7: Test Canary Deployment

1. **Test traffic distribution:**
   ```bash
   # Get ALB DNS name
   ALB_DNS=$(aws elbv2 describe-load-balancers --names CanaryALB --query "LoadBalancers[0].DNSName" --output text)
   
   # Test traffic distribution (run multiple times to see both versions)
   echo "Testing traffic distribution..."
   for i in {1..20}; do
     curl -s http://$ALB_DNS | grep -o "Version: [0-9.]*" || echo "Request $i failed"
     sleep 1
   done
   ```

2. **Monitor target group health:**
   ```bash
   # Check production target group
   echo "Production Target Group Health:"
   aws elbv2 describe-target-health --target-group-arn $PROD_TG_ARN
   
   # Check canary target group
   echo "Canary Target Group Health:"
   aws elbv2 describe-target-health --target-group-arn $CANARY_TG_ARN
   ```

### Step 8: Gradual Traffic Shifting

1. **Increase canary traffic gradually:**
   ```bash
   # Get listener ARN
   LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn $ALB_ARN --query "Listeners[0].ListenerArn" --output text)
   
   # Shift to 20% canary traffic
   aws elbv2 modify-listener --listener-arn $LISTENER_ARN --default-actions '[
     {
       "Type": "forward",
       "ForwardConfig": {
         "TargetGroups": [
           {
             "TargetGroupArn": "'$PROD_TG_ARN'",
             "Weight": 80
           },
           {
             "TargetGroupArn": "'$CANARY_TG_ARN'",
             "Weight": 20
           }
         ]
       }
     }
   ]'
   
   echo "Traffic shifted to 80% production, 20% canary"
   ```

2. **Monitor metrics after traffic increase:**
   ```bash
   # Wait and test again
   sleep 60
   echo "Testing after traffic increase..."
   for i in {1..20}; do
     curl -s http://$ALB_DNS | grep -o "Version: [0-9.]*" || echo "Request $i failed"
   done
   ```

### Step 9: Complete Deployment or Rollback

1. **If metrics are good, complete the deployment:**
   ```bash
   # Shift to 100% canary (complete deployment)
   aws elbv2 modify-listener --listener-arn $LISTENER_ARN --default-actions '[
     {
       "Type": "forward",
       "ForwardConfig": {
         "TargetGroups": [
           {
             "TargetGroupArn": "'$PROD_TG_ARN'",
             "Weight": 0
           },
           {
             "TargetGroupArn": "'$CANARY_TG_ARN'",
             "Weight": 100
           }
         ]
       }
     }
   ]'
   
   echo "Deployment complete: 100% traffic to canary version"
   ```

2. **If issues detected, perform rollback:**
   ```bash
   # Rollback to 100% production
   aws elbv2 modify-listener --listener-arn $LISTENER_ARN --default-actions '[
     {
       "Type": "forward",
       "ForwardConfig": {
         "TargetGroups": [
           {
             "TargetGroupArn": "'$PROD_TG_ARN'",
             "Weight": 100
           },
           {
             "TargetGroupArn": "'$CANARY_TG_ARN'",
             "Weight": 0
           }
         ]
       }
     }
   ]'
   
   echo "Rolled back to 100% production"
   ```

## Troubleshooting Guide

### Common Issues and Solutions

1. **Canary instances showing as unhealthy:**
   - Check application logs on canary instances
   - Verify health check endpoint returns HTTP 200
   - Ensure security groups allow health check traffic
   - Check if new application version has bugs

2. **Traffic not distributing according to weights:**
   - Verify listener configuration shows correct weights
   - Check that both target groups have healthy instances
   - Allow time for load balancer to distribute traffic evenly
   - Test with sufficient number of requests

3. **CloudWatch alarms not triggering:**
   - Verify alarm thresholds are appropriate
   - Check that metrics are being published
   - Ensure alarm is in the correct region
   - Validate alarm dimensions match target group

4. **Lambda function fails to update traffic:**
   - Check Lambda function has correct IAM permissions
   - Verify environment variables are set correctly
   - Check CloudWatch logs for Lambda execution errors
   - Ensure listener ARN and target group ARNs are valid

### Debugging Commands

```bash
# Check current traffic weights
aws elbv2 describe-listeners --listener-arns $LISTENER_ARN --query "Listeners[0].DefaultActions[0].ForwardConfig.TargetGroups"

# Monitor ALB metrics
aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name RequestCount --dimensions Name=LoadBalancer,Value=$(echo $ALB_ARN | cut -d'/' -f2-) --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 300 --statistics Sum

# Check target group metrics
aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name HTTPCode_Target_2XX_Count --dimensions Name=TargetGroup,Value=$(echo $CANARY_TG_ARN | cut -d'/' -f2-) --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 300 --statistics Sum

# View CloudWatch alarms
aws cloudwatch describe-alarms --alarm-names "CanaryHighErrorRate" "CanaryUnhealthyTargets"

# Check Auto Scaling Group status
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ProductionASG CanaryASG
```

## Resources Created

This lab creates the following AWS resources:

### Networking
- **VPC**: Custom VPC with 10.0.0.0/16 CIDR block
- **Subnets**: Two public subnets in different AZs
- **Internet Gateway**: For public internet access
- **Security Groups**: ALB and EC2 security groups

### Load Balancing
- **Application Load Balancer**: Internet-facing ALB with weighted routing
- **Target Groups**: Production and Canary target groups
- **Listener**: HTTP listener with weighted target group routing

### Compute
- **Launch Templates**: Production and Canary instance configurations
- **Auto Scaling Groups**: Production (3 instances) and Canary (1 instance) ASGs
- **EC2 Instances**: 4 t2.micro instances total

### Monitoring and Automation
- **CloudWatch Alarms**: Error rate and health monitoring
- **Lambda Function**: Automated traffic shifting logic

### Estimated Costs
- Application Load Balancer: ~$0.54/day ($0.0225/hour)
- EC2 Instances (4 x t2.micro): $0.00/day (Free Tier) or ~$1.16/day
- EBS Volumes (4 x 8GB): ~$0.32/day
- CloudWatch Alarms: $0.10/alarm/month (~$0.007/day for 2 alarms)
- Lambda Function: Minimal cost for occasional executions
- **Total estimated cost**: $0.86-$2.02/day (partially Free Tier eligible)

## Cleanup

When you're finished with the lab, follow these steps to avoid ongoing charges:

1. **Delete Auto Scaling Groups:**
   ```bash
   aws autoscaling delete-auto-scaling-group --auto-scaling-group-name ProductionASG --force-delete
   aws autoscaling delete-auto-scaling-group --auto-scaling-group-name CanaryASG --force-delete
   ```

2. **Delete Lambda function:**
   ```bash
   aws lambda delete-function --function-name CanaryController
   ```

3. **Delete CloudWatch alarms:**
   ```bash
   aws cloudwatch delete-alarms --alarm-names "CanaryHighErrorRate" "CanaryUnhealthyTargets"
   ```

4. **Delete Load Balancer and Target Groups:**
   ```bash
   aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN
   aws elbv2 delete-target-group --target-group-arn $PROD_TG_ARN
   aws elbv2 delete-target-group --target-group-arn $CANARY_TG_ARN
   ```

5. **Delete Launch Templates:**
   ```bash
   aws ec2 delete-launch-template --launch-template-name CanaryProdTemplate
   aws ec2 delete-launch-template --launch-template-name CanaryNewTemplate
   ```

6. **Delete Security Groups and VPC:**
   ```bash
   aws ec2 delete-security-group --group-id $ALB_SG_ID
   aws ec2 delete-security-group --group-id $EC2_SG_ID
   aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
   aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID
   aws ec2 delete-subnet --subnet-id $SUBNET1_ID
   aws ec2 delete-subnet --subnet-id $SUBNET2_ID
   aws ec2 delete-vpc --vpc-id $VPC_ID
   ```

> **Important**: Failure to delete resources may result in unexpected charges to your AWS account.

## Next Steps

After completing this lab, consider:

1. **Implement automated canary analysis** using AWS CodeDeploy with canary deployment configuration
2. **Add custom metrics** for business-specific success criteria (conversion rates, user engagement)
3. **Integrate with CI/CD pipelines** for fully automated canary deployments
4. **Explore AWS App Mesh** for service mesh-based canary deployments

## Certification Exam Tips

This lab covers several key areas for the AWS DevOps Professional exam:

- **Domain 2**: Configuration Management and Infrastructure as Code (Canary deployment patterns)
- **Domain 3**: Monitoring and Logging (Metrics-based deployment decisions)
- **Domain 4**: Policies and Standards Automation (Automated deployment strategies)
- **Domain 5**: Incident and Event Response (Automated rollback procedures)

Key concepts to remember:
- Canary deployments reduce risk by gradually shifting traffic to new versions
- Weighted routing allows precise control over traffic distribution
- Monitoring and alarms are essential for automated rollback decisions
- CloudWatch metrics provide insights into application health and performance
- Lambda functions can automate complex deployment workflows

## Additional Resources

- [AWS Application Load Balancer Weighted Target Groups](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html#target-group-routing-algorithm)
- [Implementing Canary Deployments of AWS Lambda Functions with Alias Traffic Shifting](https://aws.amazon.com/blogs/compute/implementing-canary-deployments-of-aws-lambda-functions-with-alias-traffic-shifting/)
- [AWS CodeDeploy Canary Deployments](https://docs.aws.amazon.com/codedeploy/latest/userguide/applications-create-lambda-canary.html)
- [CloudWatch Alarms for Application Monitoring](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)
- [Building a Continuous Delivery Pipeline for a Lambda Application with AWS CodePipeline](https://aws.amazon.com/blogs/devops/building-a-continuous-delivery-pipeline-for-a-lambda-application-with-aws-codepipeline/)
## Lab Ap
proaches

This lab provides an automated CloudFormation approach for comprehensive canary deployment testing with advanced features.

### Quick Start

1. **Navigate to the lab directory:**
   ```bash
   cd AWSDevOpsLabs/05-deployment/canary
   ```

2. **Run the provisioning script:**
   ```bash
   ./scripts/provision-canary-lab.sh
   ```

3. **Follow the lab exercises below to test deployments**

4. **Clean up when finished:**
   ```bash
   ./scripts/cleanup-canary-lab.sh
   ```

### What Gets Created

The automated provisioning creates:

#### Canary Deployment Infrastructure
- **ECS Cluster**: Fargate-based cluster with production and canary services
- **Application Load Balancer**: With weighted routing (90% production, 10% canary initially)
- **Target Groups**: Separate health-checked target groups for each environment
- **CloudWatch Monitoring**: Comprehensive dashboards and alarms for deployment health

#### Automation and Orchestration
- **Traffic Shifting Lambda**: Automated traffic distribution management
- **Rollback Lambda**: Automated rollback execution based on alarm triggers
- **Health Check Lambda**: Validates deployment health at each promotion stage
- **Step Functions State Machine**: Orchestrates gradual canary promotion workflow

#### A/B Testing and Feature Flags
- **DynamoDB Tables**: Storage for feature flags and A/B test results
- **Feature Flag API**: RESTful API for managing feature flags and user variants
- **Analytics Lambda**: Real-time analysis of A/B test performance and statistical significance
- **A/B Testing Dashboard**: CloudWatch dashboard for conversion and engagement metrics

### Lab Exercises

#### Exercise 1: Basic Canary Deployment

1. **Test the initial deployment:**
   ```bash
   # Get the load balancer DNS from the script output
   ALB_DNS="<ALB_DNS_NAME>"
   
   # Test traffic distribution (should be ~90% production, ~10% canary)
   for i in {1..20}; do
     curl -s http://$ALB_DNS | grep -o "Version: [0-9.]*" || echo "No version found"
     sleep 0.5
   done | sort | uniq -c
   ```

2. **Monitor target group health:**
   ```bash
   # Check both target groups are healthy
   aws elbv2 describe-target-health --target-group-arn <PRODUCTION_TG_ARN>
   aws elbv2 describe-target-health --target-group-arn <CANARY_TG_ARN>
   ```

3. **Use the traffic shifting helper script:**
   ```bash
   # Increase canary traffic by 10% (to 20% total)
   ./traffic-shift.sh increase 10
   
   # Test the new distribution
   for i in {1..20}; do
     curl -s http://$ALB_DNS | grep -o "Version: [0-9.]*"
     sleep 0.5
   done | sort | uniq -c
   
   # Gradually increase canary traffic
   ./traffic-shift.sh increase 15  # Now 35% canary
   ./traffic-shift.sh increase 15  # Now 50% canary
   ```

#### Exercise 2: Automated Rollback Testing

1. **Simulate a failing canary deployment:**
   ```bash
   # Create a task definition that will cause errors
   aws ecs describe-task-definition \
     --task-definition canary-demo-app-canary \
     --query taskDefinition > failing-task-def.json
   
   # Modify the task definition to use a non-existent image or add failing health checks
   # Then register the new failing task definition
   aws ecs register-task-definition --cli-input-json file://failing-task-def.json
   
   # Update the canary service to use the failing task definition
   aws ecs update-service \
     --cluster canary-demo-app-cluster \
     --service canary-demo-app-canary \
     --task-definition canary-demo-app-canary:LATEST
   ```

2. **Increase canary traffic to trigger alarms:**
   ```bash
   # Increase canary traffic to 30% to trigger error rate alarms
   ./traffic-shift.sh increase 20
   
   # Monitor the application for errors
   for i in {1..30}; do
     response=$(curl -s -o /dev/null -w "%{http_code}" http://$ALB_DNS)
     echo "Response: $response"
     sleep 2
   done
   ```

3. **Monitor automated rollback:**
   - Access the CloudWatch dashboard URL from the provisioning output
   - Watch for alarm triggers on error rates and response times
   - Observe the automated rollback function execution
   - Verify traffic returns to 100% production

4. **Check rollback logs:**
   ```bash
   # View rollback function logs
   aws logs filter-log-events \
     --log-group-name /aws/lambda/canary-demo-app-canary-rollback \
     --start-time $(date -d '10 minutes ago' +%s)000 \
     --query 'events[].message' \
     --output text
   ```

#### Exercise 3: Feature Flags and A/B Testing

1. **Set up feature flags:**
   ```bash
   # Get the Feature Flag API URL from the provisioning output
   API_URL="<FEATURE_FLAG_API_URL>"
   
   # Create a feature flag for a new UI design
   curl -X POST $API_URL/flags \
     -H "Content-Type: application/json" \
     -d '{
       "action": "set_flag",
       "flag_name": "new_ui_design",
       "user_segment": "default",
       "enabled": true,
       "rollout_percentage": 25,
       "variant": "B"
     }'
   
   # Create a feature flag for the canary deployment
   curl -X POST $API_URL/flags \
     -H "Content-Type: application/json" \
     -d '{
       "action": "set_flag",
       "flag_name": "canary_features",
       "user_segment": "beta_users",
       "enabled": true,
       "rollout_percentage": 50,
       "variant": "canary"
     }'
   ```

2. **Test user variant assignment:**
   ```bash
   # Test variant assignment for different users
   for user in user{1..10}; do
     echo "User: $user"
     curl -s -X GET "$API_URL/flags?flag_name=new_ui_design&user_id=$user" | jq -r '.body | fromjson | .variant'
   done
   
   # Test with different user segments
   curl -X GET "$API_URL/flags?flag_name=canary_features&user_id=beta_user_123&user_segment=beta_users" | jq '.'
   ```

3. **Simulate A/B test data collection:**
   ```bash
   # Record conversion events for A/B testing
   for i in {1..100}; do
     user_id="user_$i"
     variant=$([ $((RANDOM % 4)) -eq 0 ] && echo "B" || echo "A")  # 25% get variant B
     
     # Simulate different conversion rates for each variant
     if [ "$variant" = "B" ]; then
       conversion_rate=35  # 35% conversion rate for variant B
     else
       conversion_rate=25  # 25% conversion rate for variant A
     fi
     
     # Record page view
     curl -s -X POST $API_URL/ab-test \
       -H "Content-Type: application/json" \
       -d "{
         \"action\": \"record_event\",
         \"test_id\": \"ui_redesign_test\",
         \"user_id\": \"$user_id\",
         \"variant\": \"$variant\",
         \"event_type\": \"page_view\",
         \"value\": 1
       }" > /dev/null
     
     # Simulate conversion based on variant
     if [ $((RANDOM % 100)) -lt $conversion_rate ]; then
       curl -s -X POST $API_URL/ab-test \
         -H "Content-Type: application/json" \
         -d "{
           \"action\": \"record_event\",
           \"test_id\": \"ui_redesign_test\",
           \"user_id\": \"$user_id\",
           \"variant\": \"$variant\",
           \"event_type\": \"conversion\",
           \"value\": 1
         }" > /dev/null
     fi
     
     # Add some delay to simulate real user behavior
     sleep 0.1
   done
   
   echo "Generated 100 user sessions with A/B test data"
   ```

4. **Analyze A/B test results:**
   ```bash
   # Get aggregated test results
   curl -X GET "$API_URL/ab-test?test_id=ui_redesign_test&hours_back=1" | jq '.'
   
   # Check statistical significance
   curl -X POST $API_URL/ab-test \
     -H "Content-Type: application/json" \
     -d '{
       "action": "analyze_significance",
       "test_id": "ui_redesign_test",
       "metric": "conversion"
     }' | jq '.'
   ```

#### Exercise 4: Orchestrated Canary Promotion

1. **Start automated promotion workflow:**
   ```bash
   # Get the Step Functions state machine ARN from the provisioning output
   STATE_MACHINE_ARN="<STATE_MACHINE_ARN>"
   
   # Start the promotion workflow
   EXECUTION_ARN=$(aws stepfunctions start-execution \
     --state-machine-arn $STATE_MACHINE_ARN \
     --name "canary-promotion-$(date +%s)" \
     --input '{
       "canary_version": "2.0.0",
       "promotion_steps": [25, 50, 75, 100],
       "wait_time_minutes": 2
     }' \
     --query 'executionArn' \
     --output text)
   
   echo "Started promotion workflow: $EXECUTION_ARN"
   ```

2. **Monitor promotion progress:**
   ```bash
   # Watch execution status
   while true; do
     status=$(aws stepfunctions describe-execution \
       --execution-arn $EXECUTION_ARN \
       --query 'status' \
       --output text)
     
     echo "$(date): Execution status: $status"
     
     if [ "$status" = "SUCCEEDED" ] || [ "$status" = "FAILED" ] || [ "$status" = "ABORTED" ]; then
       break
     fi
     
     sleep 30
   done
   
   # Get final execution details
   aws stepfunctions describe-execution --execution-arn $EXECUTION_ARN
   ```

3. **Monitor traffic distribution during promotion:**
   ```bash
   # Watch traffic distribution change over time
   while true; do
     echo "$(date): Current traffic distribution:"
     for i in {1..10}; do
       curl -s http://$ALB_DNS | grep -o "Version: [0-9.]*" 2>/dev/null || echo "Error"
     done | sort | uniq -c
     echo "---"
     sleep 30
   done
   ```

## Troubleshooting Guide

### Common Issues and Solutions

1. **Canary service shows unhealthy targets:**
   - Check ECS service events: `aws ecs describe-services --cluster <cluster> --services <service>`
   - Verify task definition is valid and image exists
   - Check security group rules allow ALB to reach tasks
   - Review CloudWatch logs for container errors

2. **Traffic shifting not working:**
   - Verify Lambda function has correct permissions
   - Check ALB listener rules are properly configured
   - Ensure target groups are healthy before shifting traffic
   - Review Lambda function logs for errors

3. **Alarms not triggering rollback:**
   - Verify CloudWatch alarms are configured with correct thresholds
   - Check SNS topic subscriptions are active
   - Ensure Lambda functions have proper IAM permissions
   - Test alarm triggers manually

4. **Feature flags not working:**
   - Check DynamoDB table permissions
   - Verify API Gateway is properly configured
   - Test Lambda functions individually
   - Check for consistent hashing issues in user assignment

### Debugging Commands

```bash
# Check ECS service status
aws ecs describe-services --cluster canary-demo-app-cluster --services canary-demo-app-production canary-demo-app-canary

# View ALB target group health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>

# Check CloudWatch alarms
aws cloudwatch describe-alarms --alarm-names canary-demo-app-Canary-HighErrorRate

# View Lambda function logs
aws logs filter-log-events --log-group-name /aws/lambda/canary-demo-app-traffic-shifting

# Check Step Functions execution
aws stepfunctions describe-execution --execution-arn <execution-arn>

# Test feature flag API
curl -X GET "<API_URL>/flags?flag_name=test&user_id=user123"
```

## Resources Created

This lab creates the following AWS resources:

### Compute and Networking
- **ECS Cluster**: Fargate cluster for containerized applications
- **ECS Services**: Production and canary services with different task definitions
- **Application Load Balancer**: Internet-facing ALB with weighted routing
- **Target Groups**: Separate target groups for production and canary traffic
- **Security Groups**: ALB and ECS security groups with proper ingress rules

### Monitoring and Automation
- **CloudWatch Alarms**: Error rate, response time, and custom metric alarms
- **CloudWatch Dashboard**: Real-time monitoring of canary deployment metrics
- **Lambda Functions**: Traffic shifting, rollback, and health check automation
- **Step Functions**: State machine for orchestrated canary promotion
- **SNS Topics**: Notifications for rollback and promotion events

### A/B Testing Infrastructure
- **DynamoDB Tables**: Feature flags and A/B test results storage
- **API Gateway**: RESTful API for feature flag management
- **Lambda Functions**: Feature flag logic and analytics processing

### Estimated Costs
- Application Load Balancer: ~$0.54/day ($0.0225/hour)
- ECS Fargate Tasks (4 tasks): ~$1.44/day ($0.06/day per task)
- Lambda Functions: ~$0.01/day (minimal usage)
- DynamoDB: ~$0.25/day (on-demand pricing)
- CloudWatch: ~$0.30/day (custom metrics and alarms)
- **Total estimated cost**: ~$2.54/day

## Cleanup

When you're finished with the lab, run the cleanup script:

```bash
./scripts/cleanup-canary-lab.sh
```

This will remove all created resources including:
- CloudFormation stacks
- DynamoDB tables
- Step Functions state machines
- Lambda functions
- CloudWatch dashboards and alarms
- Local helper scripts

> **Important**: Failure to clean up resources may result in unexpected charges to your AWS account.

## Next Steps

After completing this lab, consider:

1. **Implement blue-green deployments** for instant traffic switching
2. **Add custom business metrics** for more sophisticated rollback triggers
3. **Integrate with CI/CD pipelines** for automated canary deployments
4. **Explore advanced A/B testing** with statistical significance calculations
5. **Add multi-region canary deployments** for global applications

## Certification Exam Tips

This lab covers several key areas for the AWS DevOps Professional exam:

- **Domain 2**: Configuration Management and Infrastructure as Code (Canary deployment patterns)
- **Domain 3**: Monitoring and Logging (Application monitoring and automated responses)
- **Domain 4**: Policies and Standards Automation (Automated deployment strategies)
- **Domain 5**: Incident and Event Response (Automated rollback and monitoring)

Key concepts to remember:
- Canary deployments reduce risk by gradually shifting traffic to new versions
- Automated monitoring and rollback are essential for production deployments
- Feature flags enable controlled rollouts and A/B testing
- CloudWatch alarms can trigger automated responses to deployment issues
- Step Functions provide orchestration for complex deployment workflows

## Additional Resources

- [AWS Application Load Balancer Weighted Routing](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html#target-group-routing-algorithm)
- [Canary Deployments with AWS App Mesh](https://docs.aws.amazon.com/app-mesh/latest/userguide/canary-deployments.html)
- [AWS Step Functions for Deployment Automation](https://docs.aws.amazon.com/step-functions/latest/dg/welcome.html)
- [Feature Flags Best Practices](https://docs.aws.amazon.com/wellarchitected/latest/operational-excellence-pillar/ops_dev_integ_version_control.html)
- [A/B Testing with AWS](https://aws.amazon.com/blogs/architecture/a-b-testing-ml-models-in-production-using-amazon-sagemaker/)