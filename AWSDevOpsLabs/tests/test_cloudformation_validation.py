#!/usr/bin/env python3
"""
Integration tests for CloudFormation template validation.
Tests template syntax, parameter validation, and resource dependencies.
"""

import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch
import yaml
import boto3
from botocore.exceptions import ClientError


class TestCloudFormationValidation(unittest.TestCase):
    """Test cases for CloudFormation template validation."""
    
    def setUp(self):
        """Set up test environment."""
        self.test_dir = tempfile.mkdtemp()
        self.test_path = Path(self.test_dir)
        
        # Create test templates
        self.create_test_templates()
        
        # Mock AWS clients
        self.mock_cloudformation_client()
    
    def tearDown(self):
        """Clean up test environment."""
        import shutil
        shutil.rmtree(self.test_dir)
    
    def mock_cloudformation_client(self):
        """Mock CloudFormation client for testing."""
        self.cf_client = Mock()
        
        # Mock successful validation
        self.cf_client.validate_template.return_value = {
            'Parameters': [
                {
                    'ParameterKey': 'InstanceType',
                    'DefaultValue': 't3.micro',
                    'NoEcho': False,
                    'Description': 'EC2 instance type'
                }
            ],
            'Description': 'Test template',
            'Capabilities': [],
            'CapabilitiesReason': 'No IAM resources'
        }
        
        # Mock stack operations
        self.cf_client.describe_stacks.return_value = {
            'Stacks': [{
                'StackName': 'test-stack',
                'StackStatus': 'CREATE_COMPLETE',
                'CreationTime': '2024-01-01T00:00:00Z',
                'Tags': [
                    {'Key': 'Project', 'Value': 'AWSDevOpsLabs'},
                    {'Key': 'ManagedBy', 'Value': 'LabManager'}
                ]
            }]
        }
    
    def create_test_templates(self):
        """Create test CloudFormation templates."""
        # Valid template
        valid_template = {
            "AWSTemplateFormatVersion": "2010-09-09",
            "Description": "Test template for validation",
            "Parameters": {
                "InstanceType": {
                    "Type": "String",
                    "Default": "t3.micro",
                    "AllowedValues": ["t3.micro", "t3.small", "t3.medium"],
                    "Description": "EC2 instance type"
                },
                "KeyName": {
                    "Type": "AWS::EC2::KeyPair::KeyName",
                    "Description": "EC2 Key Pair for SSH access"
                }
            },
            "Resources": {
                "TestInstance": {
                    "Type": "AWS::EC2::Instance",
                    "Properties": {
                        "InstanceType": {"Ref": "InstanceType"},
                        "ImageId": "ami-0abcdef1234567890",
                        "KeyName": {"Ref": "KeyName"},
                        "Tags": [
                            {"Key": "Name", "Value": "Test Instance"},
                            {"Key": "Project", "Value": "AWSDevOpsLabs"}
                        ]
                    }
                },
                "TestSecurityGroup": {
                    "Type": "AWS::EC2::SecurityGroup",
                    "Properties": {
                        "GroupDescription": "Test security group",
                        "SecurityGroupIngress": [
                            {
                                "IpProtocol": "tcp",
                                "FromPort": 22,
                                "ToPort": 22,
                                "CidrIp": "0.0.0.0/0"
                            }
                        ]
                    }
                }
            },
            "Outputs": {
                "InstanceId": {
                    "Description": "Instance ID",
                    "Value": {"Ref": "TestInstance"},
                    "Export": {"Name": {"Fn::Sub": "${AWS::StackName}-InstanceId"}}
                }
            }
        }
        
        valid_template_path = self.test_path / "valid-template.yaml"
        with open(valid_template_path, 'w') as f:
            yaml.dump(valid_template, f)
        
        # Invalid template (missing required properties)
        invalid_template = {
            "AWSTemplateFormatVersion": "2010-09-09",
            "Resources": {
                "InvalidInstance": {
                    "Type": "AWS::EC2::Instance",
                    "Properties": {
                        # Missing required ImageId property
                        "InstanceType": "t3.micro"
                    }
                }
            }
        }
        
        invalid_template_path = self.test_path / "invalid-template.yaml"
        with open(invalid_template_path, 'w') as f:
            yaml.dump(invalid_template, f)
        
        # Nested stack template
        nested_template = {
            "AWSTemplateFormatVersion": "2010-09-09",
            "Description": "Parent stack with nested stacks",
            "Parameters": {
                "NestedStackURL": {
                    "Type": "String",
                    "Description": "URL of nested stack template"
                }
            },
            "Resources": {
                "NestedStack": {
                    "Type": "AWS::CloudFormation::Stack",
                    "Properties": {
                        "TemplateURL": {"Ref": "NestedStackURL"},
                        "Parameters": {
                            "InstanceType": "t3.micro"
                        }
                    }
                }
            }
        }
        
        nested_template_path = self.test_path / "nested-template.yaml"
        with open(nested_template_path, 'w') as f:
            yaml.dump(nested_template, f)
    
    def test_template_syntax_validation(self):
        """Test CloudFormation template syntax validation."""
        validator = CloudFormationValidator(self.cf_client)
        
        # Test valid template
        valid_template_path = self.test_path / "valid-template.yaml"
        result = validator.validate_template_syntax(valid_template_path)
        
        self.assertTrue(result['valid'])
        self.assertIn('parameters', result)
        self.assertIn('description', result)
    
    def test_invalid_template_syntax(self):
        """Test validation of invalid template syntax."""
        # Mock validation failure
        self.cf_client.validate_template.side_effect = ClientError(
            error_response={
                'Error': {
                    'Code': 'ValidationError',
                    'Message': 'Template format error: JSON not well-formed'
                }
            },
            operation_name='ValidateTemplate'
        )
        
        validator = CloudFormationValidator(self.cf_client)
        invalid_template_path = self.test_path / "invalid-template.yaml"
        
        result = validator.validate_template_syntax(invalid_template_path)
        
        self.assertFalse(result['valid'])
        self.assertIn('error', result)
    
    def test_parameter_validation(self):
        """Test CloudFormation parameter validation."""
        validator = CloudFormationValidator(self.cf_client)
        valid_template_path = self.test_path / "valid-template.yaml"
        
        # Test valid parameters
        parameters = {
            'InstanceType': 't3.small',
            'KeyName': 'my-key-pair'
        }
        
        result = validator.validate_parameters(valid_template_path, parameters)
        self.assertTrue(result['valid'])
        
        # Test invalid parameter value
        invalid_parameters = {
            'InstanceType': 't3.invalid',  # Not in AllowedValues
            'KeyName': 'my-key-pair'
        }
        
        result = validator.validate_parameters(valid_template_path, invalid_parameters)
        self.assertFalse(result['valid'])
        self.assertIn('errors', result)
    
    def test_resource_dependency_validation(self):
        """Test CloudFormation resource dependency validation."""
        validator = CloudFormationValidator(self.cf_client)
        
        # Create template with circular dependency
        circular_template = {
            "AWSTemplateFormatVersion": "2010-09-09",
            "Resources": {
                "ResourceA": {
                    "Type": "AWS::S3::Bucket",
                    "DependsOn": "ResourceB"
                },
                "ResourceB": {
                    "Type": "AWS::S3::Bucket",
                    "DependsOn": "ResourceA"
                }
            }
        }
        
        circular_template_path = self.test_path / "circular-template.yaml"
        with open(circular_template_path, 'w') as f:
            yaml.dump(circular_template, f)
        
        result = validator.validate_dependencies(circular_template_path)
        self.assertFalse(result['valid'])
        self.assertIn('circular_dependencies', result)
    
    def test_nested_stack_validation(self):
        """Test nested CloudFormation stack validation."""
        validator = CloudFormationValidator(self.cf_client)
        nested_template_path = self.test_path / "nested-template.yaml"
        
        result = validator.validate_nested_stacks(nested_template_path)
        
        # Should identify nested stacks
        self.assertIn('nested_stacks', result)
        self.assertGreater(len(result['nested_stacks']), 0)
    
    def test_security_best_practices(self):
        """Test CloudFormation security best practices validation."""
        validator = CloudFormationValidator(self.cf_client)
        
        # Create template with security issues
        insecure_template = {
            "AWSTemplateFormatVersion": "2010-09-09",
            "Resources": {
                "InsecureSecurityGroup": {
                    "Type": "AWS::EC2::SecurityGroup",
                    "Properties": {
                        "GroupDescription": "Insecure security group",
                        "SecurityGroupIngress": [
                            {
                                "IpProtocol": "tcp",
                                "FromPort": 22,
                                "ToPort": 22,
                                "CidrIp": "0.0.0.0/0"  # Security issue: open to world
                            }
                        ]
                    }
                },
                "S3BucketWithoutEncryption": {
                    "Type": "AWS::S3::Bucket",
                    "Properties": {
                        "BucketName": "my-insecure-bucket"
                        # Missing encryption configuration
                    }
                }
            }
        }
        
        insecure_template_path = self.test_path / "insecure-template.yaml"
        with open(insecure_template_path, 'w') as f:
            yaml.dump(insecure_template, f)
        
        result = validator.validate_security_practices(insecure_template_path)
        
        self.assertIn('security_issues', result)
        self.assertGreater(len(result['security_issues']), 0)
    
    def test_cost_estimation_validation(self):
        """Test CloudFormation cost estimation validation."""
        validator = CloudFormationValidator(self.cf_client)
        valid_template_path = self.test_path / "valid-template.yaml"
        
        result = validator.estimate_template_cost(valid_template_path)
        
        self.assertIn('estimated_cost', result)
        self.assertIsInstance(result['estimated_cost'], (int, float))
        self.assertGreaterEqual(result['estimated_cost'], 0)


class CloudFormationValidator:
    """CloudFormation template validator for lab testing."""
    
    def __init__(self, cf_client=None):
        """Initialize validator with CloudFormation client."""
        self.cf_client = cf_client or boto3.client('cloudformation')
    
    def validate_template_syntax(self, template_path):
        """Validate CloudFormation template syntax."""
        try:
            with open(template_path, 'r') as f:
                if template_path.suffix.lower() == '.json':
                    template_body = f.read()
                else:
                    template_dict = yaml.safe_load(f)
                    template_body = json.dumps(template_dict)
            
            response = self.cf_client.validate_template(TemplateBody=template_body)
            
            return {
                'valid': True,
                'parameters': response.get('Parameters', []),
                'description': response.get('Description', ''),
                'capabilities': response.get('Capabilities', [])
            }
            
        except ClientError as e:
            return {
                'valid': False,
                'error': str(e),
                'error_code': e.response['Error']['Code']
            }
        except Exception as e:
            return {
                'valid': False,
                'error': f"Template parsing error: {str(e)}"
            }
    
    def validate_parameters(self, template_path, parameters):
        """Validate CloudFormation template parameters."""
        try:
            with open(template_path, 'r') as f:
                template_dict = yaml.safe_load(f)
            
            template_params = template_dict.get('Parameters', {})
            errors = []
            
            # Check required parameters
            for param_name, param_config in template_params.items():
                if param_name not in parameters and 'Default' not in param_config:
                    errors.append(f"Required parameter '{param_name}' is missing")
            
            # Check parameter values
            for param_name, param_value in parameters.items():
                if param_name in template_params:
                    param_config = template_params[param_name]
                    
                    # Check AllowedValues
                    if 'AllowedValues' in param_config:
                        if param_value not in param_config['AllowedValues']:
                            errors.append(
                                f"Parameter '{param_name}' value '{param_value}' "
                                f"not in allowed values: {param_config['AllowedValues']}"
                            )
                    
                    # Check parameter type
                    param_type = param_config.get('Type', 'String')
                    if param_type == 'Number' and not isinstance(param_value, (int, float)):
                        try:
                            float(param_value)
                        except ValueError:
                            errors.append(f"Parameter '{param_name}' must be a number")
            
            return {
                'valid': len(errors) == 0,
                'errors': errors
            }
            
        except Exception as e:
            return {
                'valid': False,
                'errors': [f"Parameter validation error: {str(e)}"]
            }
    
    def validate_dependencies(self, template_path):
        """Validate CloudFormation resource dependencies."""
        try:
            with open(template_path, 'r') as f:
                template_dict = yaml.safe_load(f)
            
            resources = template_dict.get('Resources', {})
            dependencies = {}
            
            # Build dependency graph
            for resource_name, resource_config in resources.items():
                deps = []
                
                # Explicit DependsOn
                if 'DependsOn' in resource_config:
                    depends_on = resource_config['DependsOn']
                    if isinstance(depends_on, str):
                        deps.append(depends_on)
                    elif isinstance(depends_on, list):
                        deps.extend(depends_on)
                
                # Implicit dependencies from Ref and GetAtt
                properties = resource_config.get('Properties', {})
                deps.extend(self._find_implicit_dependencies(properties, resources.keys()))
                
                dependencies[resource_name] = deps
            
            # Check for circular dependencies
            circular_deps = self._detect_circular_dependencies(dependencies)
            
            return {
                'valid': len(circular_deps) == 0,
                'dependencies': dependencies,
                'circular_dependencies': circular_deps
            }
            
        except Exception as e:
            return {
                'valid': False,
                'error': f"Dependency validation error: {str(e)}"
            }
    
    def _find_implicit_dependencies(self, obj, resource_names):
        """Find implicit dependencies in CloudFormation properties."""
        deps = []
        
        if isinstance(obj, dict):
            for key, value in obj.items():
                if key == 'Ref' and value in resource_names:
                    deps.append(value)
                elif key == 'Fn::GetAtt' and isinstance(value, list) and value[0] in resource_names:
                    deps.append(value[0])
                else:
                    deps.extend(self._find_implicit_dependencies(value, resource_names))
        elif isinstance(obj, list):
            for item in obj:
                deps.extend(self._find_implicit_dependencies(item, resource_names))
        
        return deps
    
    def _detect_circular_dependencies(self, dependencies):
        """Detect circular dependencies in resource graph."""
        def has_cycle(node, visited, rec_stack):
            visited[node] = True
            rec_stack[node] = True
            
            for neighbor in dependencies.get(node, []):
                if neighbor in dependencies:
                    if not visited.get(neighbor, False):
                        if has_cycle(neighbor, visited, rec_stack):
                            return True
                    elif rec_stack.get(neighbor, False):
                        return True
            
            rec_stack[node] = False
            return False
        
        visited = {}
        rec_stack = {}
        circular_deps = []
        
        for node in dependencies:
            if not visited.get(node, False):
                if has_cycle(node, visited, rec_stack):
                    circular_deps.append(node)
        
        return circular_deps
    
    def validate_nested_stacks(self, template_path):
        """Validate nested CloudFormation stacks."""
        try:
            with open(template_path, 'r') as f:
                template_dict = yaml.safe_load(f)
            
            resources = template_dict.get('Resources', {})
            nested_stacks = []
            
            for resource_name, resource_config in resources.items():
                if resource_config.get('Type') == 'AWS::CloudFormation::Stack':
                    nested_stacks.append({
                        'name': resource_name,
                        'template_url': resource_config.get('Properties', {}).get('TemplateURL'),
                        'parameters': resource_config.get('Properties', {}).get('Parameters', {})
                    })
            
            return {
                'nested_stacks': nested_stacks,
                'has_nested_stacks': len(nested_stacks) > 0
            }
            
        except Exception as e:
            return {
                'error': f"Nested stack validation error: {str(e)}",
                'nested_stacks': []
            }
    
    def validate_security_practices(self, template_path):
        """Validate CloudFormation security best practices."""
        try:
            with open(template_path, 'r') as f:
                template_dict = yaml.safe_load(f)
            
            resources = template_dict.get('Resources', {})
            security_issues = []
            
            for resource_name, resource_config in resources.items():
                resource_type = resource_config.get('Type')
                properties = resource_config.get('Properties', {})
                
                # Check security group rules
                if resource_type == 'AWS::EC2::SecurityGroup':
                    ingress_rules = properties.get('SecurityGroupIngress', [])
                    for rule in ingress_rules:
                        if rule.get('CidrIp') == '0.0.0.0/0':
                            security_issues.append({
                                'resource': resource_name,
                                'issue': 'Security group allows access from anywhere (0.0.0.0/0)',
                                'severity': 'HIGH'
                            })
                
                # Check S3 bucket encryption
                elif resource_type == 'AWS::S3::Bucket':
                    if 'BucketEncryption' not in properties:
                        security_issues.append({
                            'resource': resource_name,
                            'issue': 'S3 bucket does not have encryption enabled',
                            'severity': 'MEDIUM'
                        })
                
                # Check IAM policies
                elif resource_type in ['AWS::IAM::Role', 'AWS::IAM::Policy']:
                    policy_doc = properties.get('PolicyDocument', {})
                    statements = policy_doc.get('Statement', [])
                    for statement in statements:
                        if statement.get('Effect') == 'Allow' and statement.get('Resource') == '*':
                            security_issues.append({
                                'resource': resource_name,
                                'issue': 'IAM policy allows access to all resources (*)',
                                'severity': 'HIGH'
                            })
            
            return {
                'security_issues': security_issues,
                'secure': len(security_issues) == 0
            }
            
        except Exception as e:
            return {
                'error': f"Security validation error: {str(e)}",
                'security_issues': []
            }
    
    def estimate_template_cost(self, template_path):
        """Estimate CloudFormation template deployment cost."""
        try:
            with open(template_path, 'r') as f:
                template_dict = yaml.safe_load(f)
            
            resources = template_dict.get('Resources', {})
            estimated_cost = 0.0
            
            # Basic cost estimation based on resource types
            cost_estimates = {
                'AWS::EC2::Instance': 0.0104,  # t3.micro per hour
                'AWS::RDS::DBInstance': 0.017,  # db.t3.micro per hour
                'AWS::Lambda::Function': 0.0001,  # per request
                'AWS::S3::Bucket': 0.023,  # per GB per month
                'AWS::ECS::Service': 0.02,  # per hour
                'AWS::ElasticLoadBalancingV2::LoadBalancer': 0.0225  # per hour
            }
            
            for resource_name, resource_config in resources.items():
                resource_type = resource_config.get('Type')
                if resource_type in cost_estimates:
                    estimated_cost += cost_estimates[resource_type]
            
            return {
                'estimated_cost': round(estimated_cost, 4),
                'cost_breakdown': {
                    resource_type: cost_estimates[resource_type]
                    for resource_type in set(r.get('Type') for r in resources.values())
                    if resource_type in cost_estimates
                }
            }
            
        except Exception as e:
            return {
                'error': f"Cost estimation error: {str(e)}",
                'estimated_cost': 0.0
            }


if __name__ == '__main__':
    unittest.main()