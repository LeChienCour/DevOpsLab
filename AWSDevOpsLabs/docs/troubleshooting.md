# Troubleshooting Guide

This comprehensive troubleshooting guide covers common issues you may encounter while working with AWS DevOps Labs, along with detailed solutions and debugging techniques.

## 🚨 Quick Diagnostic Commands

Run these commands first to quickly identify common issues:

```bash
# System health check
python lab-manager.py health-check

# Verify AWS connectivity
aws sts get-caller-identity

# Check active sessions
python lab-manager.py sessions

# Verify cleanup status
python lab-manager.py verify-cleanup --all

# Check for orphaned resources
python lab-manager.py orphaned-resources
```

## 🔧 Lab Manager Issues

### "Lab not found" Error
**Symptoms**: Error message when trying to start a lab
```bash
Error: Lab 'invalid-lab-id' not found
```

**Causes**:
- Incorrect lab ID
- Lab configuration not loaded
- Typo in lab name

**Solutions**:
```bash
# List all available labs
python lab-manager.py list

# Search for labs by keyword
python lab-manager.py list --filter codepipeline

# Get detailed lab information
python lab-manager.py info <correct-lab-id>

# Reload lab configurations
python lab-manager.py reload-config
```

### "Session already running" Error
**Symptoms**: Cannot start new lab session
```bash
Error: Session already running for lab 'codepipeline-basic'
```

**Solutions**:
```bash
# List active sessions
python lab-manager.py sessions

# Stop existing session
python lab-manager.py stop <session-id>

# Force cleanup if needed
python lab-manager.py cleanup <session-id> --force

# Start new session
python lab-manager.py start <lab-id>
```

### Permission Errors
**Symptoms**: Access denied errors during lab operations
```bash
Error: User: arn:aws:iam::123456789012:user/devops-user is not authorized to perform: cloudformation:CreateStack
```

**Diagnosis**:
```bash
# Check current AWS identity
aws sts get-caller-identity

# List attached policies
aws iam list-attached-user-policies --user-name <your-username>

# Test specific permissions
aws iam simulate-principal-policy \
  --policy-source-arn <your-user-arn> \
  --action-names cloudformation:CreateStack \
  --resource-arns "*"
```

**Solutions**:
1. **Add required policies to IAM user**:
   - PowerUserAccess (recommended)
   - Or specific service policies listed in README

2. **Check policy boundaries**:
   ```bash
   aws iam get-user --user-name <your-username>
   ```

3. **Verify region permissions**:
   ```bash
   aws ec2 describe-regions --region <your-region>
   ```

### Lab Manager Configuration Issues
**Symptoms**: Lab manager fails to initialize or load configuration

**Solutions**:
```bash
# Reinitialize lab manager
python lab-manager.py init --force

# Check configuration file
cat config/lab-config.yaml

# Validate configuration syntax
python -c "import yaml; yaml.safe_load(open('config/lab-config.yaml'))"

# Reset to default configuration
python lab-manager.py reset-config
```

## ☁️ AWS Service Issues

### CloudFormation Stack Creation Failed

#### Template Validation Errors
**Symptoms**: Stack creation fails with template errors
```bash
ValidationError: Template format error: JSON not well-formed
```

**Solutions**:
```bash
# Validate template syntax
aws cloudformation validate-template --template-body file://template.yaml

# Check YAML syntax
python -c "import yaml; yaml.safe_load(open('template.yaml'))"

# Use AWS CLI to deploy with better error messages
aws cloudformation create-stack \
  --stack-name test-stack \
  --template-body file://template.yaml \
  --capabilities CAPABILITY_IAM
```

#### Resource Limit Errors
**Symptoms**: Stack creation fails due to service limits
```bash
LimitExceeded: Cannot exceed quota for InstancesPerRegion: 20
```

**Diagnosis**:
```bash
# Check EC2 limits
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-1216C47A

# List current instances
aws ec2 describe-instances --query 'Reservations[].Instances[].State.Name' | grep running | wc -l

# Check VPC limits
aws service-quotas get-service-quota \
  --service-code vpc \
  --quota-code L-F678F1CE
```

**Solutions**:
1. **Request quota increase**:
   ```bash
   aws service-quotas request-service-quota-increase \
     --service-code ec2 \
     --quota-code L-1216C47A \
     --desired-value 40
   ```

2. **Clean up unused resources**:
   ```bash
   # Stop unused EC2 instances
   aws ec2 describe-instances \
     --filters Name=instance-state-name,Values=running \
     --query 'Reservations[].Instances[].InstanceId' \
     --output text | xargs aws ec2 stop-instances --instance-ids
   ```

3. **Use different instance types or regions**

#### Stack Rollback Issues
**Symptoms**: Stack gets stuck in rollback state
```bash
Stack is in ROLLBACK_IN_PROGRESS state and can not be updated
```

**Solutions**:
```bash
# Check stack events for root cause
aws cloudformation describe-stack-events --stack-name <stack-name>

# Continue rollback if stuck
aws cloudformation continue-update-rollback --stack-name <stack-name>

# Delete stack if rollback fails
aws cloudformation delete-stack --stack-name <stack-name>

# Force delete with retain resources
aws cloudformation delete-stack \
  --stack-name <stack-name> \
  --retain-resources <resource-logical-id>
```

### EC2 Instance Issues

#### Instance Launch Failures
**Symptoms**: EC2 instances fail to launch
```bash
InsufficientInstanceCapacity: We currently do not have sufficient t3.micro capacity
```

**Solutions**:
```bash
# Try different instance types
aws ec2 describe-instance-type-offerings \
  --location-type availability-zone \
  --filters Name=instance-type,Values=t3.micro,t3.small,t2.micro

# Try different availability zones
aws ec2 describe-availability-zones --region <your-region>

# Use Spot instances for cost savings
aws ec2 request-spot-instances \
  --spot-price "0.05" \
  --instance-count 1 \
  --type "one-time" \
  --launch-specification file://spot-specification.json
```

#### Instance Connection Issues
**Symptoms**: Cannot connect to EC2 instances via SSH or RDP

**Diagnosis**:
```bash
# Check instance status
aws ec2 describe-instance-status --instance-ids <instance-id>

# Check security groups
aws ec2 describe-security-groups --group-ids <security-group-id>

# Check network ACLs
aws ec2 describe-network-acls --filters Name=association.subnet-id,Values=<subnet-id>
```

**Solutions**:
1. **Fix security group rules**:
   ```bash
   # Allow SSH access
   aws ec2 authorize-security-group-ingress \
     --group-id <security-group-id> \
     --protocol tcp \
     --port 22 \
     --cidr 0.0.0.0/0
   ```

2. **Check key pair**:
   ```bash
   # List key pairs
   aws ec2 describe-key-pairs
   
   # Create new key pair if needed
   aws ec2 create-key-pair --key-name lab-key-pair --output text --query 'KeyMaterial' > lab-key.pem
   chmod 400 lab-key.pem
   ```

### CodePipeline and CodeBuild Issues

#### Build Failures
**Symptoms**: CodeBuild projects fail to build
```bash
BUILD_FAILED: Command did not exit successfully
```

**Diagnosis**:
```bash
# Check build logs
aws logs get-log-events \
  --log-group-name /aws/codebuild/<project-name> \
  --log-stream-name <log-stream-name>

# Check build project configuration
aws codebuild batch-get-projects --names <project-name>
```

**Solutions**:
1. **Fix buildspec.yml syntax**:
   ```yaml
   version: 0.2
   phases:
     install:
       runtime-versions:
         python: 3.9
     pre_build:
       commands:
         - echo Logging in to Amazon ECR...
     build:
       commands:
         - echo Build started on `date`
         - echo Building the application...
     post_build:
       commands:
         - echo Build completed on `date`
   ```

2. **Check IAM service role permissions**:
   ```bash
   aws iam get-role --role-name CodeBuildServiceRole
   aws iam list-attached-role-policies --role-name CodeBuildServiceRole
   ```

#### Pipeline Execution Failures
**Symptoms**: CodePipeline stages fail
```bash
The pipeline execution failed in the Build stage
```

**Solutions**:
```bash
# Get pipeline execution details
aws codepipeline get-pipeline-execution \
  --pipeline-name <pipeline-name> \
  --pipeline-execution-id <execution-id>

# Check pipeline configuration
aws codepipeline get-pipeline --name <pipeline-name>

# Retry failed stage
aws codepipeline retry-stage-execution \
  --pipeline-name <pipeline-name> \
  --stage-name <stage-name> \
  --pipeline-execution-id <execution-id>
```

## 💰 Cost and Billing Issues

### Unexpected Charges
**Symptoms**: Higher than expected AWS bills

**Investigation**:
```bash
# Check current costs by service
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# List all resources with costs
python lab-manager.py costs --detailed

# Find expensive resources
aws ce get-rightsizing-recommendation
```

**Solutions**:
1. **Identify and clean up orphaned resources**:
   ```bash
   # Find untagged resources
   aws resourcegroupstaggingapi get-resources \
     --resource-type-filters EC2:Instance \
     --tag-filters Key=LabSession,Values=

   # Clean up old lab sessions
   python lab-manager.py cleanup --older-than 24h
   ```

2. **Set up cost alerts**:
   ```bash
   # Create budget alert
   aws budgets create-budget \
     --account-id <account-id> \
     --budget file://budget.json \
     --notifications-with-subscribers file://notifications.json
   ```

### Resource Cleanup Failed
**Symptoms**: Resources remain after cleanup attempts

**Diagnosis**:
```bash
# Check CloudFormation stack status
aws cloudformation describe-stacks --stack-name <stack-name>

# List stack resources
aws cloudformation list-stack-resources --stack-name <stack-name>

# Check for dependencies
aws cloudformation describe-stack-resources --stack-name <stack-name>
```

**Solutions**:
1. **Manual resource cleanup**:
   ```bash
   # Delete in dependency order
   # 1. EC2 instances
   aws ec2 terminate-instances --instance-ids <instance-id>
   
   # 2. Load balancers
   aws elbv2 delete-load-balancer --load-balancer-arn <lb-arn>
   
   # 3. Security groups
   aws ec2 delete-security-group --group-id <sg-id>
   
   # 4. VPC components
   aws ec2 delete-subnet --subnet-id <subnet-id>
   aws ec2 delete-vpc --vpc-id <vpc-id>
   ```

2. **Force stack deletion**:
   ```bash
   # Skip resources that can't be deleted
   aws cloudformation delete-stack \
     --stack-name <stack-name> \
     --retain-resources <resource-logical-id>
   ```

## 🌐 Network and Connectivity Issues

### VPC and Subnet Issues
**Symptoms**: VPC creation fails or networking doesn't work

**Common Causes**:
- CIDR block conflicts
- Insufficient IP addresses
- Route table misconfigurations
- NAT Gateway issues

**Solutions**:
```bash
# Check existing VPCs and CIDR blocks
aws ec2 describe-vpcs --query 'Vpcs[].CidrBlock'

# Find available CIDR blocks
python -c "
import ipaddress
existing = ['10.0.0.0/16', '172.31.0.0/16']
for i in range(1, 255):
    cidr = f'10.{i}.0.0/16'
    if cidr not in existing:
        print(f'Available: {cidr}')
        break
"

# Check route tables
aws ec2 describe-route-tables --filters Name=vpc-id,Values=<vpc-id>

# Test connectivity
aws ec2 describe-nat-gateways --filter Name=vpc-id,Values=<vpc-id>
```

### Security Group Configuration
**Symptoms**: Network traffic blocked unexpectedly

**Diagnosis**:
```bash
# Check security group rules
aws ec2 describe-security-groups --group-ids <sg-id>

# Check network ACLs
aws ec2 describe-network-acls --filters Name=association.subnet-id,Values=<subnet-id>

# Test connectivity
telnet <target-ip> <port>
nc -zv <target-ip> <port>
```

**Solutions**:
```bash
# Add required rules
aws ec2 authorize-security-group-ingress \
  --group-id <sg-id> \
  --protocol tcp \
  --port 80 \
  --source-group <source-sg-id>

# Remove conflicting rules
aws ec2 revoke-security-group-ingress \
  --group-id <sg-id> \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0
```

## 🔍 Advanced Debugging Techniques

### Using AWS CloudTrail for Debugging
```bash
# Find recent API calls
aws logs filter-log-events \
  --log-group-name CloudTrail/APIGatewayExecutionLogs \
  --start-time $(date -d '1 hour ago' +%s)000 \
  --filter-pattern "ERROR"

# Search for specific API calls
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=CreateStack \
  --start-time 2024-01-01 \
  --end-time 2024-01-02
```

### Using AWS Config for Resource Tracking
```bash
# Check resource compliance
aws configservice get-compliance-details-by-resource \
  --resource-type AWS::EC2::Instance \
  --resource-id <instance-id>

# Get resource configuration history
aws configservice get-resource-config-history \
  --resource-type AWS::EC2::Instance \
  --resource-id <instance-id>
```

### Performance Debugging
```bash
# Check CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=<instance-id> \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z \
  --period 3600 \
  --statistics Average

# Check X-Ray traces
aws xray get-trace-summaries \
  --time-range-type TimeRangeByStartTime \
  --start-time 2024-01-01T00:00:00 \
  --end-time 2024-01-01T23:59:59
```

## 📞 Getting Additional Help

### Self-Service Resources
1. **AWS Documentation**: [docs.aws.amazon.com](https://docs.aws.amazon.com)
2. **AWS Service Health**: [status.aws.amazon.com](https://status.aws.amazon.com)
3. **AWS Forums**: [forums.aws.amazon.com](https://forums.aws.amazon.com)
4. **Stack Overflow**: Tag questions with `amazon-web-services`

### AWS Support Options
1. **Basic Support**: Included with all AWS accounts
2. **Developer Support**: $29/month minimum
3. **Business Support**: $100/month minimum
4. **Enterprise Support**: $15,000/month minimum

### Lab-Specific Support
1. **Check individual lab guides** for specific troubleshooting sections
2. **Review prerequisites** and setup requirements
3. **Create issues** in the repository for lab-specific problems
4. **Join community discussions** for peer support

### Emergency Procedures

#### High Cost Alert Response
```bash
# Immediate actions:
# 1. Stop all running instances
aws ec2 describe-instances \
  --filters Name=instance-state-name,Values=running \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text | xargs aws ec2 stop-instances --instance-ids

# 2. Delete expensive resources
python lab-manager.py cleanup --all --force

# 3. Check for data transfer charges
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '7 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=USAGE_TYPE
```

#### Account Compromise Response
```bash
# 1. Change all access keys immediately
aws iam list-access-keys --user-name <username>
aws iam create-access-key --user-name <username>
aws iam delete-access-key --user-name <username> --access-key-id <old-key>

# 2. Review CloudTrail logs
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=UserName,AttributeValue=<username> \
  --start-time $(date -d '24 hours ago' +%Y-%m-%d)

# 3. Check for unauthorized resources
aws ec2 describe-instances --query 'Reservations[].Instances[?LaunchTime>=`2024-01-01`]'
```

---

**Remember**: When in doubt, clean up resources first to avoid unexpected charges, then investigate the issue systematically using the debugging techniques outlined above.