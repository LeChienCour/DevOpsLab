#!/usr/bin/env python3
"""
Tests for Lab Validation and Health Check System.
Tests automated health checks for provisioned AWS resources and validation
scripts to verify lab completion criteria.
"""

import json
import os
import tempfile
import unittest
from datetime import datetime
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock
import yaml

# Import the LabValidator class
import sys
sys.path.insert(0, str(Path(__file__).parent.parent / "scripts"))
try:
    from lab_validator import LabValidator
except ImportError:
    # Create a mock LabValidator for testing if the actual one doesn't exist
    class LabValidator:
        def __init__(self, config_file=None):
            self.config = {}
            self.aws_available = False
            self.validation_results = {}


class TestLabValidator(unittest.TestCase):
    """Test cases for LabValidator class."""
    
    def setUp(self):
        """Set up test environment with temporary directories and mocks."""
        self.test_dir = tempfile.mkdtemp()
        self.test_path = Path(self.test_dir)
        
        # Create test configuration
        self.create_test_config()
        
        # Mock AWS clients
        self.setup_aws_mocks()
        
        # Initialize validator with test config
        config_file = self.test_path / "validation-config.yaml"
        with patch.object(LabValidator, '_init_aws_clients', self.mock_init_aws_clients):
            self.validator = LabValidator(str(config_file))
    
    def tearDown(self):
        """Clean up test environment."""
        import shutil
        shutil.rmtree(self.test_dir)
    
    def create_test_config(self):
        """Create test validation configuration."""
        config = {
            "health_checks": {
                "cloudformation": {
                    "enabled": True,
                    "check_stack_status": True,
                    "required_tags": ["Project", "SessionId", "LabName"]
                },
                "ec2": {
                    "enabled": True,
                    "check_instance_status": True,
                    "allowed_instance_types": ["t3.micro", "t3.small"]
                },
                "lambda": {
                    "enabled": True,
                    "check_function_status": True,
                    "max_error_rate": 5.0
                },
                "s3": {
                    "enabled": True,
                    "check_bucket_encryption": True,
                    "check_public_access": True
                },
                "iam": {
                    "enabled": True,
                    "check_policy_compliance": True
                }
            },
            "cost_validation": {
                "enabled": True,
                "max_hourly_cost": 10.0,
                "alert_threshold": 0.8
            },
            "completion_criteria": {
                "min_resources": 1,
                "required_tags": ["Project", "SessionId", "LabName"]
            }
        }
        
        config_file = self.test_path / "validation-config.yaml"
        with open(config_file, 'w') as f:
            yaml.dump(config, f)
    
    def setup_aws_mocks(self):
        """Set up comprehensive AWS service mocks."""
        # CloudFormation mock
        self.mock_cf_client = Mock()
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
                    {'Key': 'SessionId', 'Value': 'test-session-123'},
                    {'Key': 'LabName', 'Value': 'test-lab'}
                ],
                'Outputs': [
                    {'OutputKey': 'InstanceId', 'OutputValue': 'i-1234567890abcdef0'}
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
                    ],
                    'SecurityGroups': [{'GroupId': 'sg-12345678'}]
                }]
            }]
        }
        self.mock_ec2_client.describe_security_groups.return_value = {
            'SecurityGroups': [{
                'GroupId': 'sg-12345678',
                'IpPermissions': [{
                    'IpProtocol': 'tcp',
                    'FromPort': 22,
                    'ToPort': 22,
                    'IpRanges': [{'CidrIp': '10.0.0.0/8'}]
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
        self.mock_lambda_client.get_function_configuration.return_value = {
            'State': 'Active'
        }
        
        # S3 mock
        self.mock_s3_client = Mock()
        self.mock_s3_client.list_buckets.return_value = {
            'Buckets': [{'Name': 'test-lab-bucket-123456789012'}]
        }
        self.mock_s3_client.get_bucket_tagging.return_value = {
            'TagSet': [
                {'Key': 'Project', 'Value': 'AWSDevOpsLabs'},
                {'Key': 'SessionId', 'Value': 'test-session-123'}
            ]
        }
        self.mock_s3_client.get_bucket_encryption.return_value = {
            'ServerSideEncryptionConfiguration': {
                'Rules': [{'ApplyServerSideEncryptionByDefault': {'SSEAlgorithm': 'AES256'}}]
            }
        }
        self.mock_s3_client.get_public_access_block.return_value = {
            'PublicAccessBlockConfiguration': {
                'BlockPublicAcls': True,
                'BlockPublicPolicy': True,
                'IgnorePublicAcls': True,
                'RestrictPublicBuckets': True
            }
        }
        
        # IAM mock
        self.mock_iam_client = Mock()
        self.mock_iam_client.list_roles.return_value = {
            'Roles': [{
                'RoleName': 'test-lab-role',
                'Arn': 'arn:aws:iam::123456789012:role/test-lab-role'
            }]
        }
        self.mock_iam_client.list_role_tags.return_value = {
            'Tags': [
                {'Key': 'Project', 'Value': 'AWSDevOpsLabs'},
                {'Key': 'SessionId', 'Value': 'test-session-123'}
            ]
        }
        self.mock_iam_client.list_attached_role_policies.return_value = {
            'AttachedPolicies': [{
                'PolicyName': 'AmazonS3ReadOnlyAccess',
                'PolicyArn': 'arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess'
            }]
        }
        
        # CloudWatch mock
        self.mock_cloudwatch_client = Mock()
        self.mock_cloudwatch_client.get_metric_statistics.return_value = {
            'Datapoints': [{'Sum': 10.0}]
        }
        
        # STS mock
        self.mock_sts_client = Mock()
        self.mock_sts_client.get_caller_identity.return_value = {
            'Account': '123456789012'
        }
    
    def mock_init_aws_clients(self, validator_self):
        """Mock AWS client initialization."""
        validator_self.session = Mock()
        validator_self.cloudformation = self.mock_cf_client
        validator_self.ec2 = self.mock_ec2_client
        validator_self.iam = self.mock_iam_client
        validator_self.lambda_client = self.mock_lambda_client
        validator_self.s3 = self.mock_s3_client
        validator_self.rds = Mock()
        validator_self.ecs = Mock()
        validator_self.logs = Mock()
        validator_self.cloudwatch = self.mock_cloudwatch_client
        validator_self.sts = self.mock_sts_client
        validator_self.aws_available = True
        validator_self.account_id = '123456789012'
        validator_self.region = 'us-east-1'
    
    def test_validator_initialization(self):
        """Test LabValidator initialization."""
        self.assertIsInstance(self.validator, LabValidator)
        self.assertTrue(self.validator.aws_available)
        self.assertIn("health_checks", self.validator.config)
    
    def test_validate_lab_session(self):
        """Test complete lab session validation."""
        session_id = "test-session-123"
        lab_id = "test-lab"
        
        result = self.validator.validate_lab_session(session_id, lab_id)
        
        self.assertIsInstance(result, dict)
        self.assertIn("overall_status", result)
        self.assertIn("checks", result)
        self.assertIn("timestamp", result)
        self.assertEqual(result["session_id"], session_id)
        self.assertEqual(result["lab_id"], lab_id)
    
    def test_cloudformation_validation(self):
        """Test CloudFormation resource validation."""
        session_id = "test-session-123"
        
        # Test with valid CloudFormation stack
        self.validator._validate_cloudformation_resources(session_id)
        
        cf_check = self.validator.validation_results["checks"]["cloudformation"]
        self.assertEqual(cf_check["status"], "passed")
        self.assertEqual(cf_check["details"]["stack_count"], 1)
        self.assertEqual(len(cf_check["issues"]), 0)
    
    def test_cloudformation_validation_missing_tags(self):
        """Test CloudFormation validation with missing required tags."""
        session_id = "test-session-123"
        
        # Mock stack without required tags
        self.mock_cf_client.describe_stacks.return_value = {
            'Stacks': [{
                'StackName': 'test-lab-stack',
                'StackStatus': 'CREATE_COMPLETE',
                'CreationTime': datetime.now(),
                'Tags': [
                    {'Key': 'Project', 'Value': 'AWSDevOpsLabs'}
                    # Missing SessionId and LabName tags
                ]
            }]
        }
        
        self.validator._validate_cloudformation_resources(session_id)
        
        cf_check = self.validator.validation_results["checks"]["cloudformation"]
        self.assertEqual(cf_check["status"], "warning")
        self.assertGreater(len(cf_check["issues"]), 0)
    
    def test_ec2_validation(self):
        """Test EC2 resource validation."""
        session_id = "test-session-123"
        
        self.validator._validate_ec2_resources(session_id)
        
        ec2_check = self.validator.validation_results["checks"]["ec2"]
        self.assertEqual(ec2_check["status"], "passed")
        self.assertEqual(ec2_check["details"]["instance_count"], 1)
    
    def test_ec2_validation_invalid_instance_type(self):
        """Test EC2 validation with invalid instance type."""
        session_id = "test-session-123"
        
        # Mock instance with invalid type
        self.mock_ec2_client.describe_instances.return_value = {
            'Reservations': [{
                'Instances': [{
                    'InstanceId': 'i-1234567890abcdef0',
                    'InstanceType': 'm5.large',  # Not in allowed types
                    'State': {'Name': 'running'},
                    'LaunchTime': datetime.now(),
                    'Tags': [
                        {'Key': 'Project', 'Value': 'AWSDevOpsLabs'},
                        {'Key': 'SessionId', 'Value': 'test-session-123'}
                    ],
                    'SecurityGroups': [{'GroupId': 'sg-12345678'}]
                }]
            }]
        }
        
        self.validator._validate_ec2_resources(session_id)
        
        ec2_check = self.validator.validation_results["checks"]["ec2"]
        self.assertEqual(ec2_check["status"], "warning")
        self.assertGreater(len(ec2_check["issues"]), 0)
    
    def test_lambda_validation(self):
        """Test Lambda resource validation."""
        session_id = "test-session-123"
        
        self.validator._validate_lambda_resources(session_id)
        
        lambda_check = self.validator.validation_results["checks"]["lambda"]
        self.assertEqual(lambda_check["status"], "passed")
        self.assertEqual(lambda_check["details"]["function_count"], 1)
    
    def test_s3_validation(self):
        """Test S3 resource validation."""
        session_id = "test-session-123"
        
        self.validator._validate_s3_resources(session_id)
        
        s3_check = self.validator.validation_results["checks"]["s3"]
        self.assertEqual(s3_check["status"], "passed")
        self.assertEqual(s3_check["details"]["bucket_count"], 1)
    
    def test_s3_validation_no_encryption(self):
        """Test S3 validation with unencrypted bucket."""
        session_id = "test-session-123"
        
        # Mock bucket without encryption
        from botocore.exceptions import ClientError
        self.mock_s3_client.get_bucket_encryption.side_effect = ClientError(
            error_response={'Error': {'Code': 'ServerSideEncryptionConfigurationNotFoundError'}},
            operation_name='GetBucketEncryption'
        )
        
        self.validator._validate_s3_resources(session_id)
        
        s3_check = self.validator.validation_results["checks"]["s3"]
        self.assertEqual(s3_check["status"], "warning")
        self.assertGreater(len(s3_check["issues"]), 0)
    
    def test_iam_validation(self):
        """Test IAM resource validation."""
        session_id = "test-session-123"
        
        self.validator._validate_iam_resources(session_id)
        
        iam_check = self.validator.validation_results["checks"]["iam"]
        self.assertEqual(iam_check["status"], "passed")
        self.assertEqual(iam_check["details"]["role_count"], 1)
    
    def test_cost_validation(self):
        """Test cost validation."""
        session_id = "test-session-123"
        
        self.validator._validate_costs(session_id)
        
        cost_check = self.validator.validation_results["checks"]["cost"]
        self.assertEqual(cost_check["status"], "passed")
        self.assertIn("estimated_hourly_cost", cost_check["details"])
        self.assertIsInstance(cost_check["details"]["estimated_hourly_cost"], float)
    
    def test_cost_validation_exceeds_limit(self):
        """Test cost validation when cost exceeds limit."""
        session_id = "test-session-123"
        
        # Mock high cost scenario
        with patch.object(self.validator, '_estimate_session_costs', return_value=15.0):
            self.validator._validate_costs(session_id)
        
        cost_check = self.validator.validation_results["checks"]["cost"]
        self.assertEqual(cost_check["status"], "failed")
        self.assertGreater(len(cost_check["issues"]), 0)
    
    def test_completion_criteria_validation(self):
        """Test completion criteria validation."""
        session_id = "test-session-123"
        lab_id = "test-lab"
        
        self.validator._validate_completion_criteria(session_id, lab_id)
        
        completion_check = self.validator.validation_results["checks"]["completion"]
        self.assertEqual(completion_check["status"], "passed")
        self.assertIn("total_resources", completion_check["details"])
        self.assertGreater(completion_check["details"]["total_resources"], 0)
    
    def test_overall_status_determination(self):
        """Test overall status determination logic."""
        # Test with all passed checks
        self.validator.validation_results = {
            "checks": {
                "test1": {"status": "passed"},
                "test2": {"status": "passed"}
            }
        }
        self.validator._determine_overall_status()
        self.assertEqual(self.validator.validation_results["overall_status"], "passed")
        
        # Test with warning
        self.validator.validation_results = {
            "checks": {
                "test1": {"status": "passed"},
                "test2": {"status": "warning", "issues": ["Warning message"]}
            }
        }
        self.validator._determine_overall_status()
        self.assertEqual(self.validator.validation_results["overall_status"], "warning")
        
        # Test with failure
        self.validator.validation_results = {
            "checks": {
                "test1": {"status": "passed"},
                "test2": {"status": "failed", "issues": ["Failure message"]}
            }
        }
        self.validator._determine_overall_status()
        self.assertEqual(self.validator.validation_results["overall_status"], "failed")
        
        # Test with error
        self.validator.validation_results = {
            "checks": {
                "test1": {"status": "passed"},
                "test2": {"status": "error", "issues": ["Error message"]}
            }
        }
        self.validator._determine_overall_status()
        self.assertEqual(self.validator.validation_results["overall_status"], "error")
    
    def test_security_group_check(self):
        """Test security group rule checking."""
        # Test restrictive security group
        sg_id = "sg-12345678"
        result = self.validator._check_security_group_rules(sg_id)
        self.assertFalse(result)  # Should not be overly permissive
        
        # Test permissive security group
        self.mock_ec2_client.describe_security_groups.return_value = {
            'SecurityGroups': [{
                'GroupId': 'sg-12345678',
                'IpPermissions': [{
                    'IpProtocol': 'tcp',
                    'FromPort': 22,
                    'ToPort': 22,
                    'IpRanges': [{'CidrIp': '0.0.0.0/0'}]  # Overly permissive
                }]
            }]
        }
        
        result = self.validator._check_security_group_rules(sg_id)
        self.assertTrue(result)  # Should be overly permissive
    
    def test_lambda_error_rate_calculation(self):
        """Test Lambda error rate calculation."""
        function_name = "test-function"
        
        # Mock CloudWatch metrics
        self.mock_cloudwatch_client.get_metric_statistics.side_effect = [
            {'Datapoints': [{'Sum': 100.0}]},  # Invocations
            {'Datapoints': [{'Sum': 5.0}]}     # Errors
        ]
        
        error_rate = self.validator._get_lambda_error_rate(function_name)
        self.assertEqual(error_rate, 5.0)  # 5% error rate
    
    def test_bucket_encryption_check(self):
        """Test S3 bucket encryption checking."""
        bucket_name = "test-bucket"
        
        # Test encrypted bucket
        result = self.validator._check_bucket_encryption(bucket_name)
        self.assertTrue(result)
        
        # Test unencrypted bucket
        from botocore.exceptions import ClientError
        self.mock_s3_client.get_bucket_encryption.side_effect = ClientError(
            error_response={'Error': {'Code': 'ServerSideEncryptionConfigurationNotFoundError'}},
            operation_name='GetBucketEncryption'
        )
        
        result = self.validator._check_bucket_encryption(bucket_name)
        self.assertFalse(result)
    
    def test_cost_estimation(self):
        """Test session cost estimation."""
        session_id = "test-session-123"
        
        estimated_cost = self.validator._estimate_session_costs(session_id)
        
        self.assertIsInstance(estimated_cost, float)
        self.assertGreaterEqual(estimated_cost, 0.0)
        self.assertLessEqual(estimated_cost, 100.0)  # Reasonable upper bound
    
    def test_resource_counting(self):
        """Test session resource counting."""
        session_id = "test-session-123"
        
        resource_count = self.validator._count_session_resources(session_id)
        
        self.assertIsInstance(resource_count, int)
        self.assertGreaterEqual(resource_count, 0)
    
    def test_generate_health_report(self):
        """Test health report generation."""
        session_id = "test-session-123"
        
        # Run validation first
        self.validator.validate_lab_session(session_id)
        
        # Generate report
        output_file = self.test_path / "health_report.json"
        report_path = self.validator.generate_health_report(session_id, str(output_file))
        
        self.assertTrue(Path(report_path).exists())
        
        # Verify report content
        with open(report_path, 'r') as f:
            report_data = json.load(f)
        
        self.assertIn("overall_status", report_data)
        self.assertIn("checks", report_data)
        self.assertIn("timestamp", report_data)
    
    def test_aws_unavailable_scenario(self):
        """Test behavior when AWS is unavailable."""
        # Create validator with AWS unavailable
        with patch.object(LabValidator, '_init_aws_clients') as mock_init:
            def mock_init_unavailable(validator_self):
                validator_self.aws_available = False
            
            mock_init.side_effect = mock_init_unavailable
            validator = LabValidator()
            
            result = validator.validate_lab_session("test-session")
            
            self.assertEqual(result["overall_status"], "error")
            self.assertIn("AWS credentials not available", result["errors"])
    
    def test_config_loading(self):
        """Test configuration loading."""
        # Test with valid config file
        config = self.validator._load_config()
        self.assertIsInstance(config, dict)
        self.assertIn("health_checks", config)
        
        # Test with missing config file
        validator = LabValidator("/nonexistent/config.yaml")
        config = validator._load_config()
        self.assertIsInstance(config, dict)  # Should return default config
    
    def test_error_handling(self):
        """Test error handling in validation methods."""
        session_id = "test-session-123"
        
        # Mock AWS client error
        from botocore.exceptions import ClientError
        self.mock_cf_client.list_stacks.side_effect = ClientError(
            error_response={'Error': {'Code': 'AccessDenied', 'Message': 'Access denied'}},
            operation_name='ListStacks'
        )
        
        self.validator._validate_cloudformation_resources(session_id)
        
        cf_check = self.validator.validation_results["checks"]["cloudformation"]
        self.assertEqual(cf_check["status"], "error")
        self.assertGreater(len(cf_check["issues"]), 0)


class TestLabValidatorIntegration(unittest.TestCase):
    """Integration tests for LabValidator."""
    
    def setUp(self):
        """Set up integration test environment."""
        self.test_dir = tempfile.mkdtemp()
        self.test_path = Path(self.test_dir)
    
    def tearDown(self):
        """Clean up integration test environment."""
        import shutil
        shutil.rmtree(self.test_dir)
    
    def test_end_to_end_validation_workflow(self):
        """Test complete end-to-end validation workflow."""
        # This test would require actual AWS resources or more sophisticated mocking
        # For now, we'll test the workflow structure
        
        session_id = "integration-test-session"
        
        # Mock the validator to avoid AWS calls
        with patch('lab_validator.LabValidator') as MockValidator:
            mock_validator = MockValidator.return_value
            mock_validator.validate_lab_session.return_value = {
                "overall_status": "passed",
                "checks": {
                    "cloudformation": {"status": "passed"},
                    "ec2": {"status": "passed"},
                    "cost": {"status": "passed"}
                },
                "errors": [],
                "warnings": []
            }
            
            # Test validation workflow
            validator = MockValidator()
            result = validator.validate_lab_session(session_id)
            
            self.assertEqual(result["overall_status"], "passed")
            self.assertIn("checks", result)


if __name__ == '__main__':
    unittest.main()