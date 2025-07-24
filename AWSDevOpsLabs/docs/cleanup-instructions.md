# Comprehensive Cleanup Instructions for AWS DevOps Labs

This document provides detailed cleanup instructions for all labs in the AWS DevOps Labs project. Following these instructions carefully will help ensure that all AWS resources are properly terminated to avoid unexpected charges.

## General Cleanup Guidelines

1. **Always run the provided cleanup scripts** when available
2. **Verify resource deletion** after running cleanup scripts
3. **Check for lingering resources** in the AWS Console
4. **Monitor your AWS Billing Dashboard** for unexpected charges
5. **Follow the specific order of cleanup** to avoid dependency issues

> ⚠️ **WARNING**: Failure to properly clean up resources may result in unexpected charges to your AWS account. Some resources like NAT Gateways and Load Balancers can incur significant costs if left running.

## CI/CD Labs Cleanup

### CodeDeploy Lab Cleanup

1. **Run the cleanup script:**
   ```bash
   # Navigate to the CodeDeploy lab directory
   cd AWSDevOpsLabs/01-cicd/codedeploy
   
   # Run the cleanup script
   ./scripts/cleanup-codedeploy.sh
   ```

2. **Verify resource deletion:**
   ```bash
   # Check if EC2 instances were terminated
   aws ec2 describe-instances --filters "Name=tag:Project,Values=codedeploy-lab" --query "Reservations[*].Instances[*].[InstanceId,State.Name]"
   
   # Check if CloudFormation stack was deleted
   aws cloudformation describe-stacks --stack-name codedeploy-lab-stack 2>&1 | grep -q "does not exist" && echo "Stack deleted successfully" || echo "Stack may still exist"
   ```

3. **Manual cleanup if needed:**
   - If any resources remain, delete them manually in the following order:
     1. CodeDeploy applications and deployment groups
     2. EC2 instances
     3. S3 buckets (empty them first)
     4. CloudWatch alarms
     5. IAM roles and policies
     6. CloudFormation stack (if it still exists)

4. **Clean up local files:**
   ```bash
   rm -rf updated-app broken-app
   rm -f *-deployment.zip
   ```

### CodePipeline Lab Cleanup

1. **Run the cleanup script:**
   ```bash
   # Navigate to the CodePipeline lab directory
   cd AWSDevOpsLabs/01-cicd/codepipeline
   
   # Run the cleanup script
   ./scripts/cleanup-pipeline.sh
   ```

2. **Verify resource deletion:**
   ```bash
   # Check if CloudFormation stack was deleted
   aws cloudformation describe-stacks --stack-name devops-pipeline-lab-stack 2>&1 | grep -q "does not exist" && echo "Stack deleted successfully" || echo "Stack may still exist"
   
   # Check if S3 buckets were deleted
   aws s3 ls | grep "devops-pipeline-lab"
   ```

3. **Manual cleanup if needed:**
   - If any resources remain, delete them manually in the following order:
     1. CodePipeline pipelines
     2. CodeBuild projects
     3. S3 buckets (empty them first, especially buckets with versioning enabled)
     4. CloudWatch log groups
     5. IAM roles and policies
     6. CloudFormation stack (if it still exists)

4. **Clean up local files:**
   ```bash
   rm -rf updated-source broken-source
   rm -f *-source-code.zip
   ```

### CodeBuild Lab Cleanup

1. **Run the cleanup script:**
   ```bash
   # Navigate to the CodeBuild lab directory
   cd AWSDevOpsLabs/01-cicd/codebuild
   
   # Run the cleanup script
   ./scripts/cleanup-codebuild.sh
   ```

2. **Verify resource deletion:**
   ```bash
   # Check if CloudFormation stack was deleted
   aws cloudformation describe-stacks --stack-name codebuild-lab-stack 2>&1 | grep -q "does not exist" && echo "Stack deleted successfully" || echo "Stack may still exist"
   
   # Check if S3 buckets were deleted
   aws s3 ls | grep "codebuild-lab"
   ```

3. **Manual cleanup if needed:**
   - If any resources remain, delete them manually in the following order:
     1. CodeBuild projects
     2. S3 buckets (empty them first)
     3. CloudWatch log groups
     4. CloudWatch alarms
     5. IAM roles and policies
     6. CloudFormation stack (if it still exists)

4. **Clean up local files:**
   ```bash
   rm -rf custom-build
   rm -f nodejs-app-source.zip
   ```

## Infrastructure as Code Labs Cleanup

### CloudFormation Lab Cleanup

1. **Run the cleanup script:**
   ```bash
   # Navigate to the CloudFormation lab directory
   cd AWSDevOpsLabs/02-iac/cloudformation
   
   # Run the cleanup script
   ./scripts/cleanup-nested-stacks.sh
   ```

2. **Verify resource deletion:**
   ```bash
   # Check if the parent stack was deleted
   aws cloudformation describe-stacks --stack-name devops-lab-nested 2>&1 | grep -q "does not exist" && echo "Stack successfully deleted" || echo "Stack may still exist"
   
   # Check if the S3 bucket was deleted
   aws s3 ls s3://devops-lab-nested-templates-* 2>&1 | grep -q "NoSuchBucket" && echo "Bucket successfully deleted" || echo "Bucket may still exist"
   ```

3. **Manual cleanup if needed:**
   - If any resources remain, delete them manually in the following order:
     1. Child stacks (Application, Security, Network)
     2. Parent stack
     3. S3 buckets (empty them first)
     4. Lambda functions
     5. EC2 instances
     6. IAM roles and policies

4. **Check for lingering resources:**
   ```bash
   # Check for EC2 instances
   aws ec2 describe-instances --filters "Name=tag:Project,Values=DevOpsLab" --query "Reservations[*].Instances[*].[InstanceId,State.Name]"
   
   # Check for VPCs
   aws ec2 describe-vpcs --filters "Name=tag:Project,Values=DevOpsLab" --query "Vpcs[*].[VpcId]"
   ```

### Terraform Lab Cleanup

1. **Destroy the environment resources:**
   ```bash
   # Navigate to the environment directory
   cd AWSDevOpsLabs/02-iac/terraform/environments/dev
   
   # Destroy all resources
   terraform destroy -auto-approve
   ```

2. **Verify resource cleanup:**
   ```bash
   # Check for any remaining resources
   aws ec2 describe-vpcs --filters "Name=tag:Project,Values=DevOpsLab"
   aws ecs list-clusters
   ```

3. **Clean up the backend (optional):**
   ```bash
   # Navigate to the backend directory
   cd ../../backend
   
   # Destroy backend resources
   terraform destroy -auto-approve
   ```

4. **Manual cleanup if needed:**
   - If any resources remain, delete them manually in the following order:
     1. ECS services and tasks
     2. Load balancers
     3. EC2 instances
     4. NAT Gateways (these are expensive!)
     5. VPC and networking components
     6. S3 buckets (empty them first)
     7. DynamoDB tables

5. **Check for lingering resources:**
   ```bash
   # Check for NAT Gateways (these are expensive!)
   aws ec2 describe-nat-gateways --filter "Name=state,Values=available" --query "NatGateways[*].[NatGatewayId,VpcId]"
   
   # Check for Load Balancers
   aws elbv2 describe-load-balancers --query "LoadBalancers[*].[LoadBalancerArn,VpcId]"
   ```

### AWS CDK Lab Cleanup

1. **Destroy the CDK stacks:**
   ```bash
   # Navigate to the CDK project directory
   cd AWSDevOpsLabs/02-iac/cdk/devops-lab-cdk
   
   # Destroy all stacks
   cdk destroy --all --force
   ```

2. **Verify resource cleanup:**
   ```bash
   # Check that stacks have been removed
   aws cloudformation list-stacks --query "StackSummaries[?contains(StackName, 'dev-')].{Name:StackName,Status:StackStatus}"
   ```
   
   - Ensure all stacks show "DELETE_COMPLETE" status
   - Check the AWS Console for any remaining resources

3. **Clean up local files:**
   ```bash
   # Remove the CDK project directory
   cd ..
   rm -rf devops-lab-cdk
   ```

3. **Manual cleanup if needed:**
   - If any resources remain, delete them manually in the following order:
     1. CloudWatch dashboards and alarms
     2. ECS services and tasks
     3. Load balancers
     4. NAT Gateways (these are expensive!)
     5. VPC and networking components
     6. S3 buckets (empty them first)
     7. IAM roles and policies
     8. CloudFormation stacks

4. **Check for lingering resources:**
   ```bash
   # Check for NAT Gateways (these are expensive!)
   aws ec2 describe-nat-gateways --filter "Name=state,Values=available" --query "NatGateways[*].[NatGatewayId,VpcId]"
   
   # Check for Load Balancers
   aws elbv2 describe-load-balancers --query "LoadBalancers[*].[LoadBalancerArn,VpcId]"
   
   # Check for ECS clusters
   aws ecs list-clusters
   ```

## Verification Steps for All Labs

After running the cleanup procedures for each lab, perform these final verification steps to ensure all resources have been properly removed:

1. **Check for running EC2 instances:**
   ```bash
   aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].[InstanceId,Tags[?Key=='Project'].Value|[0]]"
   ```

2. **Check for active NAT Gateways:**
   ```bash
   aws ec2 describe-nat-gateways --filter "Name=state,Values=available" --query "NatGateways[*].[NatGatewayId,VpcId]"
   ```

3. **Check for active Load Balancers:**
   ```bash
   aws elbv2 describe-load-balancers --query "LoadBalancers[*].[LoadBalancerArn,VpcId]"
   ```

4. **Check for CloudFormation stacks:**
   ```bash
   aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --query "StackSummaries[*].[StackName,StackStatus]"
   ```

5. **Check for S3 buckets:**
   ```bash
   aws s3 ls | grep -E 'devops|lab'
   ```

6. **Check for ECS clusters:**
   ```bash
   aws ecs list-clusters
   ```

7. **Check for CloudWatch log groups:**
   ```bash
   aws logs describe-log-groups --query "logGroups[*].[logGroupName]"
   ```

## Potential Lingering Costs

Even after cleanup, be aware of these potential sources of lingering costs:

1. **S3 Buckets**: Ensure all buckets are empty before deletion
2. **EBS Volumes**: Check for detached volumes that might not be automatically deleted
3. **Snapshots**: EC2 and RDS snapshots persist after instance deletion
4. **CloudWatch Logs**: Log data continues to incur storage costs
5. **Elastic IPs**: Unassociated Elastic IPs incur charges
6. **NAT Gateways**: These are expensive and should be explicitly deleted
7. **Load Balancers**: These continue to incur hourly charges until deleted

## Final Cleanup Checklist

- [ ] All EC2 instances terminated
- [ ] All NAT Gateways deleted
- [ ] All Load Balancers deleted
- [ ] All ECS services and tasks stopped
- [ ] All CloudFormation stacks deleted
- [ ] All S3 buckets emptied and deleted
- [ ] All CloudWatch log groups deleted
- [ ] All EBS volumes deleted
- [ ] All Elastic IPs released
- [ ] All IAM roles and policies deleted (optional)

> ⚠️ **IMPORTANT**: After completing all cleanup steps, monitor your AWS Billing Dashboard for a few days to ensure no unexpected charges appear. If you notice any unusual charges, check for lingering resources that might have been missed during cleanup.

## Troubleshooting Cleanup Issues

### Resource Deletion Failures

If resources fail to delete, it's often due to dependencies. Try the following:

1. **Identify dependencies**: Use the AWS Console to check what's preventing deletion
2. **Force deletion**: Some resources have a force delete option
3. **Manual deletion**: Delete resources manually in the correct order
4. **Wait and retry**: Sometimes resources are still being used by background processes

### CloudFormation Stack Deletion Failures

If CloudFormation stacks fail to delete:

1. **Check the events**: Look at stack events to identify the failing resource
2. **Retain resources**: Use the `--retain-resources` flag to skip problematic resources
3. **Manual cleanup**: Delete the resources manually, then delete the stack
4. **Delete nested stacks first**: For nested stacks, delete child stacks before parent stacks

### S3 Bucket Deletion Failures

If S3 buckets fail to delete:

1. **Empty the bucket**: Buckets must be empty before deletion
2. **Check versioning**: Delete all versions and delete markers
3. **Check bucket policies**: Remove any policies that prevent deletion
4. **Check object locks**: Remove any object locks

### NAT Gateway and Load Balancer Deletion

These resources can be expensive if left running:

1. **Check dependencies**: Ensure no resources are using them
2. **Delete explicitly**: These often need to be deleted explicitly
3. **Verify deletion**: Confirm they're fully deleted, not just being deleted