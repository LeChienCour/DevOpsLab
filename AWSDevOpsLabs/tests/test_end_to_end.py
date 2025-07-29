#!/usr/bin/env python3
"""
End-to-end tests for complete lab execution workflows.
Tests the full lifecycle of lab provisioning, execution, and cleanup.
"""

import json
import os
import subprocess
import tempfile
import time
import unittest
from datetime import datetime
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock
import yaml
import boto3
from botocore.exceptions import ClientError

# Import test utilities
import sys
sys.path.insert(0, str(Path(__file__).parent.parent))
from lab_manager import LabManager


class TestEndToEndLabExecution(unittest.TestCase):
    """End-to-end test cases for complete lab workflows."""
    
    def setUp(self):
        """Set up test environment with mock AWS services."""
        self.test_dir = tempfile.mkdtemp()
        self.test_path = Path(self.test_dir)
        
        # Create comprehensive test lab structure
        self.create_comprehensive_lab_structure()
        
        # Mock AWS services for end-to-end testing
        self.setup_aws_mocks()
        
        # Initialize lab manager with test environment
        with patch.object(LabManager, '__init__', self.mock_lab_manager_init):
            self.manager = LabManager()
    
    def tearDown(self):
        """Clean up test environment."""
        import shutil
        shutil.rmtree(self.test_dir)
    
    def mock_lab_manager_init(self, manager_self):
        """Mock LabManager initialization for testing."""
        manager_self.base_dir = self.test_path
        manager_self.config_dir = self.test_path / "config"
        manager_self.sessions_file = manager_self.config_dir / "sessions.json"
        manager_self.labs_config = manager_self.config_dir / "labs.yaml"
        manager_self.resource_tags = {"Project": "AWSDevOpsLabs", "ManagedBy": "LabManager"}
        
        # Ensure config directory exists
        manager_self.config_dir.mkdir(exist_ok=True)
        
        # Initialize sessions file
        if not manager_self.sessions_file.exists():
            manager_self._save_sessions({})
        
        # Set up mocked AWS clients
        manager_self.aws_available = True
        manager_self.session = self.mock_session
        manager_self.cloudformation = self.mock_cf_client
        manager_self.ec2 = self.mock_ec2_client
        manager_self.iam = self.mock_iam_client
        manager_self.lambda_client = self.mock_lambda_client
        manager_self.s3 = self.mock_s3_client
        manager_self.pricing = self.mock_pricing_client
        manager_self.sts = self.mock_sts_client
    
    def setup_aws_mocks(self):
        """Set up comprehensive AWS service mocks."""
        # CloudFormation mock
        self.mock_cf_client = Mock()
        self.mock_cf_client.validate_template.return_value = {
            'Parameters': [],
            'Description': 'Test template',
            'Capabilities': []
        }
        self.mock_cf_client.list_stacks.return_value = {
            'StackSummaries': [
                {
                    'StackName': 'test-lab-stack',
                    'StackStatus': 'CREATE_COMPLETE',
                    'CreationTime': datetime.now()
                }
            ]
        }
        self.mock_cf_client.describe_stacks.return_value = {
            'Stacks': [{
                'StackName': 'test-lab-stack',
                'StackStatus': 'CREATE_COMPLETE',
                'CreationTime': datetime.now(),
                'Tags': [
                    {'Key': 'Project', 'Value': 'AWSDevOpsLabs'},
                    {'Key': 'SessionId', 'Value': 'test-session-123'}
                ]
            }]
        }
        
        # EC2 mock
        self.mock_ec2_client = Mock()
        self.mock_ec2_client.describe_instances.return_value = {
            'Reservations': [{
                'Instances': [{
                    'InstanceId': 'i-1234567890abcdef0',
                    'InstanceType': 't3.micro',
                    'State': {'Name': 'running'},
                    'LaunchTime': datetime.now(),
                    'Tags': [
                        {'Key': 'Project', 'Value': 'AWSDevOpsLabs'},
                        {'Key': 'SessionId', 'Value': 'test-session-123'}
                    ]
                }]
            }]
        }
        
        # Lambda mock
        self.mock_lambda_client = Mock()
        self.mock_lambda_client.list_functions.return_value = {
            'Functions': [{
                'FunctionName': 'test-lab-function',
                'Runtime': 'python3.9',
                'LastModified': datetime.now().isoformat(),
                'FunctionArn': 'arn:aws:lambda:us-east-1:123456789012:function:test-lab-function'
            }]
        }
        self.mock_lambda_client.list_tags.return_value = {
            'Tags': {
                'Project': 'AWSDevOpsLabs',
                'SessionId': 'test-session-123'
            }
        }
        
        # Other AWS service mocks
        self.mock_iam_client = Mock()
        self.mock_s3_client = Mock()
        self.mock_pricing_client = Mock()
        self.mock_sts_client = Mock()
        self.mock_session = Mock()
    
    def create_comprehensive_lab_structure(self):
        """Create a comprehensive test lab structure."""
        # Create all lab categories
        categories = {
            "01-cicd": ["codepipeline", "codebuild", "codedeploy"],
            "02-iac": ["cloudformation", "cdk", "terraform"],
            "03-monitoring": ["cloudwatch", "xray", "config"],
            "04-security": ["iam", "secrets", "scanning"],
            "05-deployment": ["blue-green", "canary", "rolling"],
            "06-integration": ["ecs", "lambda", "rds", "api-gateway"]
        }
        
        for category, labs in categories.items():
            category_dir = self.test_path / category
            category_dir.mkdir(parents=True)
            
            for lab in labs:
                lab_dir = category_dir / lab
                lab_dir.mkdir()
                
                # Create comprehensive lab guide
                lab_guide = lab_dir / "lab-guide.md"
                lab_guide.write_text(self.create_comprehensive_lab_guide(lab, category))
                
                # Create scripts directory with provision and cleanup scripts
                scripts_dir = lab_dir / "scripts"
                scripts_dir.mkdir()
                
                provision_script = scripts_dir / "provision.sh"
                provision_script.write_text(self.create_provision_script(lab))
                provision_script.chmod(0o755)
                
                cleanup_script = scripts_dir / "cleanup.sh"
                cleanup_script.write_text(self.create_cleanup_script(lab))
                cleanup_script.chmod(0o755)
                
                # Create templates directory with CloudFormation templates
                templates_dir = lab_dir / "templates"
                templates_dir.mkdir()
                
                template_file = templates_dir / f"{lab}-infrastructure.yaml"
                template_file.write_text(self.create_cloudformation_template(lab))
    
    def create_comprehensive_lab_guide(self, lab_name, category):
        """Create a comprehensive lab guide for testing."""
        return f"""# {lab_name.title()} Lab - {category.split('-')[1].upper()}

## Objective

This lab demonstrates {lab_name} implementation for AWS DevOps Professional certification preparation.
You will learn to configure, deploy, and manage {lab_name} in a production-like environment.

## Prerequisites

- AWS CLI configured with appropriate permissions
- Basic understanding of AWS {lab_name.upper()} service
- Familiarity with CloudFormation templates
- Python 3.8+ for automation scripts

## Time to Complete

90 minutes

## Learning Objectives

By the end of this lab, you will be able to:
1. Deploy {lab_name} infrastructure using CloudFormation
2. Configure {lab_name} for production workloads
3. Implement monitoring and logging for {lab_name}
4. Troubleshoot common {lab_name} issues
5. Clean up resources to avoid unnecessary charges

## Architecture Overview

This lab creates a complete {lab_name} environment including:
- Core {lab_name} infrastructure
- Supporting AWS services (VPC, Security Groups, IAM roles)
- Monitoring and logging configuration
- Automated backup and recovery procedures

## Steps

### Step 1: Environment Setup
1. Verify AWS CLI configuration
2. Check required IAM permissions
3. Set up lab environment variables

### Step 2: Infrastructure Deployment
1. Review CloudFormation template
2. Deploy infrastructure stack
3. Verify resource creation

### Step 3: {lab_name.title()} Configuration
1. Configure {lab_name} service
2. Set up integration with other AWS services
3. Test basic functionality

### Step 4: Monitoring and Logging
1. Configure CloudWatch monitoring
2. Set up log aggregation
3. Create custom dashboards and alarms

### Step 5: Testing and Validation
1. Run functional tests
2. Perform load testing
3. Validate monitoring and alerting

### Step 6: Cleanup
1. Remove test data
2. Delete CloudFormation stack
3. Verify resource cleanup

## AWS Services Used

- {lab_name.upper()}
- CloudFormation
- EC2
- VPC
- IAM
- CloudWatch
- S3
- Lambda

## Estimated Cost

**Free Tier Account:** $0.50 - $2.00
**Standard Account:** $3.00 - $8.00

Cost varies based on:
- Instance types used
- Data transfer
- Storage requirements
- Lab duration

## Troubleshooting

### Common Issues

1. **Permission Errors**
   - Verify IAM permissions
   - Check resource policies

2. **Resource Limits**
   - Check service quotas
   - Verify region availability

3. **Network Connectivity**
   - Verify VPC configuration
   - Check security group rules

### Getting Help

- Check AWS documentation
- Review CloudWatch logs
- Use AWS Support if needed

## Additional Resources

- [AWS {lab_name.upper()} Documentation](https://docs.aws.amazon.com/)
- [CloudFormation User Guide](https://docs.aws.amazon.com/cloudformation/)
- [AWS DevOps Professional Exam Guide](https://aws.amazon.com/certification/)
"""
    
    def create_provision_script(self, lab_name):
        """Create a provision script for testing."""
        return f"""#!/bin/bash
set -e

# {lab_name.title()} Lab Provisioning Script
echo "Starting {lab_name} lab provisioning..."

# Get session ID from command line argument
SESSION_ID=${{1:-"default-session"}}
STACK_NAME="{lab_name}-lab-$SESSION_ID"

# Set AWS region
export AWS_DEFAULT_REGION=${{AWS_DEFAULT_REGION:-us-east-1}}

# Validate AWS credentials
echo "Validating AWS credentials..."
aws sts get-caller-identity > /dev/null || {{
    echo "Error: AWS credentials not configured"
    exit 1
}}

# Deploy CloudFormation stack
echo "Deploying CloudFormation stack: $STACK_NAME"
aws cloudformation deploy \\
    --template-file templates/{lab_name}-infrastructure.yaml \\
    --stack-name "$STACK_NAME" \\
    --parameter-overrides \\
        SessionId="$SESSION_ID" \\
        LabName="{lab_name}" \\
    --capabilities CAPABILITY_IAM \\
    --tags \\
        Project=AWSDevOpsLabs \\
        ManagedBy=LabManager \\
        SessionId="$SESSION_ID" \\
        LabName="{lab_name}"

# Wait for stack creation to complete
echo "Waiting for stack creation to complete..."
aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME"

# Get stack outputs
echo "Retrieving stack outputs..."
aws cloudformation describe-stacks \\
    --stack-name "$STACK_NAME" \\
    --query 'Stacks[0].Outputs' \\
    --output table

echo "✓ {lab_name.title()} lab provisioning completed successfully!"
echo "Stack Name: $STACK_NAME"
echo "Session ID: $SESSION_ID"
echo ""
echo "Next steps:"
echo "1. Follow the lab guide to complete exercises"
echo "2. Run cleanup script when finished: ./scripts/cleanup.sh $SESSION_ID"
"""
    
    def create_cleanup_script(self, lab_name):
        """Create a cleanup script for testing."""
        return f"""#!/bin/bash
set -e

# {lab_name.title()} Lab Cleanup Script
echo "Starting {lab_name} lab cleanup..."

# Get session ID from command line argument
SESSION_ID=${{1:-"default-session"}}
STACK_NAME="{lab_name}-lab-$SESSION_ID"

# Set AWS region
export AWS_DEFAULT_REGION=${{AWS_DEFAULT_REGION:-us-east-1}}

# Validate AWS credentials
echo "Validating AWS credentials..."
aws sts get-caller-identity > /dev/null || {{
    echo "Error: AWS credentials not configured"
    exit 1
}}

# Check if stack exists
if aws cloudformation describe-stacks --stack-name "$STACK_NAME" > /dev/null 2>&1; then
    echo "Found stack: $STACK_NAME"
    
    # Delete CloudFormation stack
    echo "Deleting CloudFormation stack: $STACK_NAME"
    aws cloudformation delete-stack --stack-name "$STACK_NAME"
    
    # Wait for stack deletion to complete
    echo "Waiting for stack deletion to complete..."
    aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME"
    
    echo "✓ Stack deleted successfully"
else
    echo "Stack $STACK_NAME not found, skipping deletion"
fi

# Clean up any orphaned resources
echo "Checking for orphaned resources..."

# Clean up EC2 instances with lab tags
INSTANCES=$(aws ec2 describe-instances \\
    --filters \\
        "Name=tag:Project,Values=AWSDevOpsLabs" \\
        "Name=tag:SessionId,Values=$SESSION_ID" \\
        "Name=instance-state-name,Values=running,stopped" \\
    --query 'Reservations[].Instances[].InstanceId' \\
    --output text)

if [ ! -z "$INSTANCES" ]; then
    echo "Terminating orphaned EC2 instances: $INSTANCES"
    aws ec2 terminate-instances --instance-ids $INSTANCES
fi

# Clean up Lambda functions with lab tags
FUNCTIONS=$(aws lambda list-functions \\
    --query 'Functions[?contains(FunctionName, `{lab_name}-lab-$SESSION_ID`)].FunctionName' \\
    --output text)

for FUNCTION in $FUNCTIONS; do
    if [ ! -z "$FUNCTION" ]; then
        echo "Deleting Lambda function: $FUNCTION"
        aws lambda delete-function --function-name "$FUNCTION"
    fi
done

echo "✓ {lab_name.title()} lab cleanup completed successfully!"
echo "Session ID: $SESSION_ID"
"""
    
    def create_cloudformation_template(self, lab_name):
        """Create a CloudFormation template for testing."""
        return f"""AWSTemplateFormatVersion: '2010-09-09'
Description: '{lab_name.title()} Lab Infrastructure for AWS DevOps Professional Certification'

Parameters:
  SessionId:
    Type: String
    Description: 'Unique session identifier for resource tracking'
    Default: 'default-session'
  
  LabName:
    Type: String
    Description: 'Name of the lab being deployed'
    Default: '{lab_name}'
  
  InstanceType:
    Type: String
    Description: 'EC2 instance type for lab resources'
    Default: 't3.micro'
    AllowedValues:
      - t3.micro
      - t3.small
      - t3.medium
  
  KeyName:
    Type: 'AWS::EC2::KeyPair::KeyName'
    Description: 'EC2 Key Pair for SSH access'
    Default: ''

Conditions:
  HasKeyName: !Not [!Equals [!Ref KeyName, '']]

Resources:
  # VPC and Networking
  LabVPC:
    Type: 'AWS::EC2::VPC'
    Properties:
      CidrBlock: '10.0.0.0/16'
      EnableDnsHostnames: true
      EnableDnsSupport: true
      Tags:
        - Key: Name
          Value: !Sub '${{LabName}}-lab-vpc-${{SessionId}}'
        - Key: Project
          Value: 'AWSDevOpsLabs'
        - Key: SessionId
          Value: !Ref SessionId
        - Key: LabName
          Value: !Ref LabName

  PublicSubnet:
    Type: 'AWS::EC2::Subnet'
    Properties:
      VpcId: !Ref LabVPC
      CidrBlock: '10.0.1.0/24'
      AvailabilityZone: !Select [0, !GetAZs '']
      MapPublicIpOnLaunch: true
      Tags:
        - Key: Name
          Value: !Sub '${{LabName}}-public-subnet-${{SessionId}}'
        - Key: Project
          Value: 'AWSDevOpsLabs'
        - Key: SessionId
          Value: !Ref SessionId

  InternetGateway:
    Type: 'AWS::EC2::InternetGateway'
    Properties:
      Tags:
        - Key: Name
          Value: !Sub '${{LabName}}-igw-${{SessionId}}'
        - Key: Project
          Value: 'AWSDevOpsLabs'
        - Key: SessionId
          Value: !Ref SessionId

  AttachGateway:
    Type: 'AWS::EC2::VPCGatewayAttachment'
    Properties:
      VpcId: !Ref LabVPC
      InternetGatewayId: !Ref InternetGateway

  PublicRouteTable:
    Type: 'AWS::EC2::RouteTable'
    Properties:
      VpcId: !Ref LabVPC
      Tags:
        - Key: Name
          Value: !Sub '${{LabName}}-public-rt-${{SessionId}}'
        - Key: Project
          Value: 'AWSDevOpsLabs'
        - Key: SessionId
          Value: !Ref SessionId

  PublicRoute:
    Type: 'AWS::EC2::Route'
    DependsOn: AttachGateway
    Properties:
      RouteTableId: !Ref PublicRouteTable
      DestinationCidrBlock: '0.0.0.0/0'
      GatewayId: !Ref InternetGateway

  PublicSubnetRouteTableAssociation:
    Type: 'AWS::EC2::SubnetRouteTableAssociation'
    Properties:
      SubnetId: !Ref PublicSubnet
      RouteTableId: !Ref PublicRouteTable

  # Security Groups
  LabSecurityGroup:
    Type: 'AWS::EC2::SecurityGroup'
    Properties:
      GroupDescription: !Sub 'Security group for ${{LabName}} lab'
      VpcId: !Ref LabVPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          CidrIp: '0.0.0.0/0'
          Description: 'SSH access'
        - IpProtocol: tcp
          FromPort: 80
          ToPort: 80
          CidrIp: '0.0.0.0/0'
          Description: 'HTTP access'
        - IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          CidrIp: '0.0.0.0/0'
          Description: 'HTTPS access'
      Tags:
        - Key: Name
          Value: !Sub '${{LabName}}-sg-${{SessionId}}'
        - Key: Project
          Value: 'AWSDevOpsLabs'
        - Key: SessionId
          Value: !Ref SessionId

  # IAM Role for Lab Resources
  LabInstanceRole:
    Type: 'AWS::IAM::Role'
    Properties:
      RoleName: !Sub '${{LabName}}-instance-role-${{SessionId}}'
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: ec2.amazonaws.com
            Action: 'sts:AssumeRole'
      ManagedPolicyArns:
        - 'arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy'
      Policies:
        - PolicyName: LabResourcesPolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - 's3:GetObject'
                  - 's3:PutObject'
                  - 'logs:CreateLogGroup'
                  - 'logs:CreateLogStream'
                  - 'logs:PutLogEvents'
                Resource: '*'
      Tags:
        - Key: Project
          Value: 'AWSDevOpsLabs'
        - Key: SessionId
          Value: !Ref SessionId

  LabInstanceProfile:
    Type: 'AWS::IAM::InstanceProfile'
    Properties:
      InstanceProfileName: !Sub '${{LabName}}-instance-profile-${{SessionId}}'
      Roles:
        - !Ref LabInstanceRole

  # EC2 Instance for Lab
  LabInstance:
    Type: 'AWS::EC2::Instance'
    Properties:
      ImageId: 'ami-0abcdef1234567890'  # Amazon Linux 2 AMI (update as needed)
      InstanceType: !Ref InstanceType
      KeyName: !If [HasKeyName, !Ref KeyName, !Ref 'AWS::NoValue']
      SubnetId: !Ref PublicSubnet
      SecurityGroupIds:
        - !Ref LabSecurityGroup
      IamInstanceProfile: !Ref LabInstanceProfile
      UserData:
        Fn::Base64: !Sub |
          #!/bin/bash
          yum update -y
          yum install -y aws-cli docker
          service docker start
          usermod -a -G docker ec2-user
          
          # Install CloudWatch agent
          wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
          rpm -U ./amazon-cloudwatch-agent.rpm
          
          # Create lab marker file
          echo "${{LabName}}-${{SessionId}}" > /home/ec2-user/lab-info.txt
          chown ec2-user:ec2-user /home/ec2-user/lab-info.txt
      Tags:
        - Key: Name
          Value: !Sub '${{LabName}}-instance-${{SessionId}}'
        - Key: Project
          Value: 'AWSDevOpsLabs'
        - Key: SessionId
          Value: !Ref SessionId
        - Key: LabName
          Value: !Ref LabName

  # S3 Bucket for Lab Resources
  LabS3Bucket:
    Type: 'AWS::S3::Bucket'
    Properties:
      BucketName: !Sub '${{LabName}}-lab-bucket-${{SessionId}}-${{AWS::AccountId}}'
      BucketEncryption:
        ServerSideEncryptionConfiguration:
          - ServerSideEncryptionByDefault:
              SSEAlgorithm: AES256
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true
      Tags:
        - Key: Project
          Value: 'AWSDevOpsLabs'
        - Key: SessionId
          Value: !Ref SessionId
        - Key: LabName
          Value: !Ref LabName

  # CloudWatch Log Group
  LabLogGroup:
    Type: 'AWS::Logs::LogGroup'
    Properties:
      LogGroupName: !Sub '/aws/labs/${{LabName}}/${{SessionId}}'
      RetentionInDays: 7
      Tags:
        - Key: Project
          Value: 'AWSDevOpsLabs'
        - Key: SessionId
          Value: !Ref SessionId

Outputs:
  VPCId:
    Description: 'VPC ID for the lab environment'
    Value: !Ref LabVPC
    Export:
      Name: !Sub '${{AWS::StackName}}-VPC-ID'

  PublicSubnetId:
    Description: 'Public subnet ID'
    Value: !Ref PublicSubnet
    Export:
      Name: !Sub '${{AWS::StackName}}-PublicSubnet-ID'

  InstanceId:
    Description: 'EC2 instance ID'
    Value: !Ref LabInstance
    Export:
      Name: !Sub '${{AWS::StackName}}-Instance-ID'

  InstancePublicIP:
    Description: 'Public IP address of the lab instance'
    Value: !GetAtt LabInstance.PublicIp
    Export:
      Name: !Sub '${{AWS::StackName}}-Instance-PublicIP'

  S3BucketName:
    Description: 'S3 bucket name for lab resources'
    Value: !Ref LabS3Bucket
    Export:
      Name: !Sub '${{AWS::StackName}}-S3Bucket-Name'

  LogGroupName:
    Description: 'CloudWatch log group name'
    Value: !Ref LabLogGroup
    Export:
      Name: !Sub '${{AWS::StackName}}-LogGroup-Name'

  SessionId:
    Description: 'Lab session identifier'
    Value: !Ref SessionId
    Export:
      Name: !Sub '${{AWS::StackName}}-SessionId'
"""
    
    def test_complete_lab_lifecycle(self):
        """Test complete lab lifecycle from discovery to cleanup."""
        # Step 1: Discover labs
        print("Testing lab discovery...")
        config = self.manager._discover_labs()
        self.assertIn("labs", config)
        self.assertGreater(len(config["labs"]), 0)
        
        # Step 2: Start a lab
        print("Testing lab start...")
        lab_ids = list(config["labs"].keys())
        test_lab_id = lab_ids[0]  # Use first discovered lab
        
        result = self.manager.start_lab(test_lab_id)
        self.assertTrue(result)
        
        # Verify session was created
        sessions = self.manager._load_sessions()
        session_ids = [sid for sid in sessions.keys() if sessions[sid]["lab_id"] == test_lab_id]
        self.assertEqual(len(session_ids), 1)
        session_id = session_ids[0]
        
        # Step 3: Update progress
        print("Testing progress tracking...")
        progress_result = self.manager.update_session_progress(
            session_id, "setup_environment", True, "Environment configured successfully"
        )
        self.assertTrue(progress_result)
        
        progress_result = self.manager.update_session_progress(
            session_id, "deploy_infrastructure", True, "Infrastructure deployed"
        )
        self.assertTrue(progress_result)
        
        # Verify progress tracking
        progress = self.manager.get_session_progress(session_id)
        self.assertIsNotNone(progress)
        self.assertEqual(len(progress["steps"]), 2)
        self.assertEqual(progress["completion_percentage"], 100.0)
        
        # Step 4: Test resource inventory
        print("Testing resource inventory...")
        inventory = self.manager.get_resource_inventory(session_id)
        self.assertIn("cloudformation_stacks", inventory)
        self.assertIn("ec2_instances", inventory)
        self.assertIn("lambda_functions", inventory)
        
        # Step 5: Stop lab
        print("Testing lab stop...")
        stop_result = self.manager.stop_lab(session_id)
        self.assertTrue(stop_result)
        
        # Verify session status
        updated_sessions = self.manager._load_sessions()
        self.assertEqual(updated_sessions[session_id]["status"], "stopped")
        
        # Step 6: Cleanup
        print("Testing lab cleanup...")
        with patch('subprocess.run') as mock_subprocess:
            mock_subprocess.return_value.returncode = 0
            mock_subprocess.return_value.stderr = ""
            
            # Mock successful cleanup - no resources remain
            self.manager.get_resource_inventory = Mock(return_value={
                'cloudformation_stacks': [],
                'ec2_instances': [],
                'lambda_functions': []
            })
            
            cleanup_result = self.manager.cleanup_session(session_id, verify=True)
            self.assertTrue(cleanup_result)
            
            # Verify cleanup status
            final_sessions = self.manager._load_sessions()
            self.assertEqual(final_sessions[session_id]["status"], "cleaned_up")
    
    @patch('subprocess.run')
    def test_provision_script_execution(self, mock_subprocess):
        """Test provision script execution for labs."""
        mock_subprocess.return_value.returncode = 0
        mock_subprocess.return_value.stdout = "Stack creation successful"
        mock_subprocess.return_value.stderr = ""
        
        # Test provision script for each lab type
        test_labs = ["codepipeline", "cloudformation", "cloudwatch"]
        
        for lab in test_labs:
            with self.subTest(lab=lab):
                script_path = self.test_path / "01-cicd" / lab / "scripts" / "provision.sh"
                if not script_path.exists():
                    script_path = self.test_path / "02-iac" / lab / "scripts" / "provision.sh"
                if not script_path.exists():
                    script_path = self.test_path / "03-monitoring" / lab / "scripts" / "provision.sh"
                
                if script_path.exists():
                    # Test script execution
                    result = subprocess.run(
                        [str(script_path), "test-session-123"],
                        capture_output=True,
                        text=True,
                        timeout=5
                    )
                    
                    # Script should be executable and not fail immediately
                    self.assertNotEqual(result.returncode, 127)  # Command not found
    
    @patch('subprocess.run')
    def test_cleanup_script_execution(self, mock_subprocess):
        """Test cleanup script execution for labs."""
        mock_subprocess.return_value.returncode = 0
        mock_subprocess.return_value.stdout = "Cleanup successful"
        mock_subprocess.return_value.stderr = ""
        
        # Test cleanup script for each lab type
        test_labs = ["codepipeline", "cloudformation", "cloudwatch"]
        
        for lab in test_labs:
            with self.subTest(lab=lab):
                script_path = self.test_path / "01-cicd" / lab / "scripts" / "cleanup.sh"
                if not script_path.exists():
                    script_path = self.test_path / "02-iac" / lab / "scripts" / "cleanup.sh"
                if not script_path.exists():
                    script_path = self.test_path / "03-monitoring" / lab / "scripts" / "cleanup.sh"
                
                if script_path.exists():
                    # Test script execution
                    result = subprocess.run(
                        [str(script_path), "test-session-123"],
                        capture_output=True,
                        text=True,
                        timeout=5
                    )
                    
                    # Script should be executable and not fail immediately
                    self.assertNotEqual(result.returncode, 127)  # Command not found
    
    def test_cloudformation_template_validation(self):
        """Test CloudFormation template validation for all labs."""
        from test_cloudformation_validation import CloudFormationValidator
        
        validator = CloudFormationValidator(self.mock_cf_client)
        
        # Find all CloudFormation templates
        template_files = list(self.test_path.rglob("*-infrastructure.yaml"))
        self.assertGreater(len(template_files), 0)
        
        for template_file in template_files:
            with self.subTest(template=template_file.name):
                # Test template syntax validation
                result = validator.validate_template_syntax(template_file)
                self.assertTrue(result['valid'], f"Template {template_file.name} failed validation")
                
                # Test parameter validation
                parameters = {
                    'SessionId': 'test-session-123',
                    'LabName': 'test-lab',
                    'InstanceType': 't3.micro'
                }
                param_result = validator.validate_parameters(template_file, parameters)
                self.assertTrue(param_result['valid'], f"Parameters for {template_file.name} failed validation")
    
    def test_concurrent_lab_sessions(self):
        """Test running multiple lab sessions concurrently."""
        config = self.manager._discover_labs()
        lab_ids = list(config["labs"].keys())[:3]  # Test with first 3 labs
        
        session_ids = []
        
        # Start multiple labs
        for lab_id in lab_ids:
            result = self.manager.start_lab(lab_id)
            self.assertTrue(result, f"Failed to start lab {lab_id}")
            
            # Get the session ID
            sessions = self.manager._load_sessions()
            for sid, session in sessions.items():
                if session["lab_id"] == lab_id and session["status"] == "running":
                    session_ids.append(sid)
                    break
        
        self.assertEqual(len(session_ids), len(lab_ids))
        
        # Test resource inventory for each session
        for session_id in session_ids:
            inventory = self.manager.get_resource_inventory(session_id)
            self.assertIsInstance(inventory, dict)
            self.assertIn("cloudformation_stacks", inventory)
        
        # Stop all sessions
        for session_id in session_ids:
            result = self.manager.stop_lab(session_id)
            self.assertTrue(result, f"Failed to stop session {session_id}")
    
    def test_orphaned_resource_detection(self):
        """Test detection of orphaned resources."""
        # Create a session and then simulate orphaned resources
        config = self.manager._discover_labs()
        lab_id = list(config["labs"].keys())[0]
        
        self.manager.start_lab(lab_id)
        sessions = self.manager._load_sessions()
        session_id = list(sessions.keys())[0]
        
        # Stop the session but don't clean up
        self.manager.stop_lab(session_id)
        
        # Simulate orphaned resources by modifying the session status
        sessions[session_id]["status"] = "cleanup_failed"
        self.manager._save_sessions(sessions)
        
        # Test orphaned resource detection
        orphaned = self.manager.detect_orphaned_resources()
        
        self.assertIn("cloudformation_stacks", orphaned)
        self.assertIn("ec2_instances", orphaned)
        self.assertIn("lambda_functions", orphaned)
        self.assertIn("estimated_cost", orphaned)
    
    def test_cost_estimation_accuracy(self):
        """Test accuracy of cost estimation for labs."""
        config = self.manager._load_labs_config()
        labs = config.get("labs", {})
        
        for lab_id, lab_info in labs.items():
            with self.subTest(lab_id=lab_id):
                estimated_cost = lab_info.get("estimated_cost", 0.0)
                
                # Cost should be reasonable for lab exercises
                self.assertGreaterEqual(estimated_cost, 0.0)
                self.assertLessEqual(estimated_cost, 50.0)  # No lab should cost more than $50
                
                # Verify cost calculation logic
                aws_services = lab_info.get("aws_services", [])
                duration = lab_info.get("duration", 60)
                
                recalculated_cost = self.manager._estimate_lab_cost(aws_services, duration)
                self.assertEqual(estimated_cost, recalculated_cost)
    
    def test_error_handling_and_recovery(self):
        """Test error handling and recovery scenarios."""
        # Test invalid lab ID
        result = self.manager.start_lab("invalid-lab-id")
        self.assertFalse(result)
        
        # Test invalid session ID
        result = self.manager.stop_lab("invalid-session-id")
        self.assertFalse(result)
        
        # Test cleanup with failed script
        config = self.manager._discover_labs()
        lab_id = list(config["labs"].keys())[0]
        
        self.manager.start_lab(lab_id)
        sessions = self.manager._load_sessions()
        session_id = list(sessions.keys())[0]
        
        with patch('subprocess.run') as mock_subprocess:
            # Simulate script failure
            mock_subprocess.return_value.returncode = 1
            mock_subprocess.return_value.stderr = "Cleanup script failed"
            
            # Mock resources still exist after cleanup
            self.manager.get_resource_inventory = Mock(return_value={
                'cloudformation_stacks': [{'name': 'test-stack', 'status': 'CREATE_COMPLETE'}],
                'ec2_instances': [],
                'lambda_functions': []
            })
            
            cleanup_result = self.manager.cleanup_session(session_id, verify=True)
            self.assertFalse(cleanup_result)
            
            # Verify session status reflects failure
            final_sessions = self.manager._load_sessions()
            self.assertEqual(final_sessions[session_id]["status"], "cleanup_failed")


class TestLabValidationFramework(unittest.TestCase):
    """Test cases for lab validation framework."""
    
    def setUp(self):
        """Set up test environment."""
        self.test_dir = tempfile.mkdtemp()
        self.test_path = Path(self.test_dir)
        
        # Create test validation framework
        self.create_validation_framework()
    
    def tearDown(self):
        """Clean up test environment."""
        import shutil
        shutil.rmtree(self.test_dir)
    
    def create_validation_framework(self):
        """Create validation framework structure."""
        # Create validation scripts directory
        validation_dir = self.test_path / "validation"
        validation_dir.mkdir()
        
        # Create validation configuration
        validation_config = {
            "validation_rules": {
                "cloudformation": {
                    "required_tags": ["Project", "SessionId", "LabName"],
                    "security_checks": True,
                    "cost_estimation": True
                },
                "resources": {
                    "max_instances": 5,
                    "allowed_instance_types": ["t3.micro", "t3.small", "t3.medium"],
                    "required_encryption": True
                },
                "scripts": {
                    "timeout_seconds": 300,
                    "required_permissions": ["cloudformation:*", "ec2:*", "iam:*"]
                }
            }
        }
        
        config_file = validation_dir / "validation-config.yaml"
        with open(config_file, 'w') as f:
            yaml.dump(validation_config, f)
    
    def test_validation_framework_initialization(self):
        """Test validation framework initialization."""
        validator = LabValidationFramework(self.test_path / "validation")
        
        self.assertIsNotNone(validator.config)
        self.assertIn("validation_rules", validator.config)
    
    def test_lab_structure_validation(self):
        """Test lab directory structure validation."""
        # Create test lab structure
        lab_dir = self.test_path / "test-lab"
        lab_dir.mkdir()
        
        # Create required files
        (lab_dir / "lab-guide.md").write_text("# Test Lab")
        (lab_dir / "scripts").mkdir()
        (lab_dir / "scripts" / "provision.sh").write_text("#!/bin/bash\necho 'provision'")
        (lab_dir / "scripts" / "cleanup.sh").write_text("#!/bin/bash\necho 'cleanup'")
        (lab_dir / "templates").mkdir()
        (lab_dir / "templates" / "infrastructure.yaml").write_text("AWSTemplateFormatVersion: '2010-09-09'")
        
        validator = LabValidationFramework(self.test_path / "validation")
        result = validator.validate_lab_structure(lab_dir)
        
        self.assertTrue(result["valid"])
        self.assertEqual(len(result["errors"]), 0)
    
    def test_incomplete_lab_structure_validation(self):
        """Test validation of incomplete lab structure."""
        # Create incomplete lab structure
        lab_dir = self.test_path / "incomplete-lab"
        lab_dir.mkdir()
        
        # Only create lab guide, missing other required files
        (lab_dir / "lab-guide.md").write_text("# Incomplete Lab")
        
        validator = LabValidationFramework(self.test_path / "validation")
        result = validator.validate_lab_structure(lab_dir)
        
        self.assertFalse(result["valid"])
        self.assertGreater(len(result["errors"]), 0)


class LabValidationFramework:
    """Framework for validating lab structure and content."""
    
    def __init__(self, validation_dir):
        """Initialize validation framework."""
        self.validation_dir = Path(validation_dir)
        self.config = self._load_validation_config()
    
    def _load_validation_config(self):
        """Load validation configuration."""
        config_file = self.validation_dir / "validation-config.yaml"
        if config_file.exists():
            with open(config_file, 'r') as f:
                return yaml.safe_load(f)
        return {}
    
    def validate_lab_structure(self, lab_dir):
        """Validate lab directory structure."""
        lab_path = Path(lab_dir)
        errors = []
        
        # Check required files
        required_files = [
            "lab-guide.md",
            "scripts/provision.sh",
            "scripts/cleanup.sh",
            "templates/infrastructure.yaml"
        ]
        
        for required_file in required_files:
            file_path = lab_path / required_file
            if not file_path.exists():
                errors.append(f"Missing required file: {required_file}")
        
        # Check script permissions
        script_files = ["scripts/provision.sh", "scripts/cleanup.sh"]
        for script_file in script_files:
            script_path = lab_path / script_file
            if script_path.exists() and not os.access(script_path, os.X_OK):
                errors.append(f"Script not executable: {script_file}")
        
        return {
            "valid": len(errors) == 0,
            "errors": errors
        }


if __name__ == '__main__':
    unittest.main()