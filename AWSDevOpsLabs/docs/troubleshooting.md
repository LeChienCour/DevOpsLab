# Troubleshooting Guide

## Common Issues and Solutions

### Lab Manager Issues

#### "Lab not found" Error
- **Cause**: Lab ID doesn't exist in configuration
- **Solution**: Run `python lab-manager.py list` to see available labs

#### "Session already running" Error
- **Cause**: Lab session is already active
- **Solution**: Stop the existing session or use a different lab

#### Permission Errors
- **Cause**: Insufficient IAM permissions
- **Solution**: Ensure your IAM user has the required permissions for the lab

### AWS Service Issues

#### CloudFormation Stack Creation Failed
- **Cause**: Various reasons (permissions, limits, invalid templates)
- **Solution**: 
  1. Check CloudFormation console for detailed error messages
  2. Verify IAM permissions
  3. Check service limits and quotas
  4. Validate template syntax

#### EC2 Instance Launch Failed
- **Cause**: Instance limits, availability zone issues, or AMI problems
- **Solution**:
  1. Check EC2 service limits
  2. Try a different availability zone
  3. Verify AMI availability in your region

#### CodePipeline Build Failed
- **Cause**: Build errors, permission issues, or configuration problems
- **Solution**:
  1. Check CodeBuild logs in CloudWatch
  2. Verify buildspec.yml syntax
  3. Check IAM roles and permissions

### Cost and Billing Issues

#### Unexpected Charges
- **Cause**: Resources not properly cleaned up
- **Solution**:
  1. Run cleanup scripts for all sessions
  2. Check AWS console for orphaned resources
  3. Use cost tracker to identify expensive resources

#### Resource Cleanup Failed
- **Cause**: Dependencies or protection settings
- **Solution**:
  1. Check CloudFormation stack events
  2. Manually delete dependent resources first
  3. Disable termination protection if enabled

### Network and Connectivity Issues

#### VPC Creation Failed
- **Cause**: CIDR conflicts or limits
- **Solution**:
  1. Check existing VPCs for CIDR conflicts
  2. Verify VPC limits in your account
  3. Use different CIDR blocks

#### Security Group Issues
- **Cause**: Rule conflicts or limits
- **Solution**:
  1. Check security group rules
  2. Verify port and protocol settings
  3. Check security group limits

## Debugging Steps

### 1. Check AWS CloudTrail
- Review API calls and errors
- Identify permission issues
- Track resource creation and deletion

### 2. Monitor CloudWatch Logs
- Check application logs
- Review AWS service logs
- Monitor metrics and alarms

### 3. Use AWS CLI for Debugging
```bash
# Check CloudFormation stack events
aws cloudformation describe-stack-events --stack-name <stack-name>

# List resources by tag
aws resourcegroupstaggingapi get-resources --tag-filters Key=LabSession,Values=<session-id>

# Check EC2 instances
aws ec2 describe-instances --filters Name=tag:LabSession,Values=<session-id>
```

### 4. Validate Configurations
- Check YAML/JSON syntax
- Verify parameter values
- Test with minimal configurations first

## Getting Additional Help

### AWS Support
- Use AWS Support Center for account-specific issues
- Check AWS Service Health Dashboard
- Review AWS documentation and best practices

### Community Resources
- AWS Forums and communities
- Stack Overflow for technical questions
- GitHub issues for lab-specific problems

### Lab-Specific Help
- Check individual lab guides for specific troubleshooting
- Review prerequisites and setup requirements
- Verify all dependencies are installed and configured