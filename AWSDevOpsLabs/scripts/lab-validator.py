#!/usr/bin/env python3
"""
Lab Validation and Health Check System
Provides automated health checks for provisioned AWS resources and validation
scripts to verify lab completion criteria.
"""

import argparse
import json
import os
import subprocess
import sys
import time
import yaml
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any
import boto3
from botocore.exceptions import ClientError, NoCredentialsError


class LabValidator:
    """Lab validation and health check system."""
    
    def __init__(self, config_file: Optional[str] = None):
        """Initialize lab validator."""
        self.base_dir = Path(__file__).parent.parent
        self.config_file = config_file or self.base_dir / "config" / "validation-config.yaml"
        self.config = self._load_config()
        
        # Initialize AWS clients
        self._init_aws_clients()
        
        # Validation results
        self.validation_results = {
            "timestamp": datetime.now().isoformat(),
            "overall_status": "unknown",
            "checks": {},
            "errors": [],
            "warnings": [],
            "recommendations": []
        }
    
    def _init_aws_clients(self):
        """Initialize AWS clients for validation."""
        try:
            self.session = boto3.Session()
            self.cloudformation = self.session.client('cloudformation')
            self.ec2 = self.session.client('ec2')
            self.iam = self.session.client('iam')
            self.lambda_client = self.session.client('lambda')
            self.s3 = self.session.client('s3')
            self.rds = self.session.client('rds')
            self.ecs = self.session.client('ecs')
            self.logs = self.session.client('logs')
            self.cloudwatch = self.session.client('cloudwatch')
            self.sts = self.session.client('sts')
            self.aws_available = True
            
            # Get account information
            self.account_id = self.sts.get_caller_identity()['Account']
            self.region = self.session.region_name or 'us-east-1'
            
        except (NoCredentialsError, ClientError) as e:
            print(f"Warning: AWS credentials not configured properly: {e}")
            self.aws_available = False
    
    def _load_config(self) -> Dict:
        """Load validation configuration."""
        if not self.config_file.exists():
            return self._get_default_config()
        
        try:
            with open(self.config_file, 'r') as f:
                return yaml.safe_load(f)
        except Exception as e:
            print(f"Warning: Could not load config file {self.config_file}: {e}")
            return self._get_default_config()
    
    def _get_default_config(self) -> Dict:
        """Get default validation configuration."""
        return {
            "health_checks": {
                "cloudformation": {
                    "enabled": True,
                    "check_stack_status": True,
                    "check_drift": True,
                    "required_tags": ["Project", "SessionId", "LabName"]
                },
                "ec2": {
                    "enabled": True,
                    "check_instance_status": True,
                    "check_security_groups": True,
                    "allowed_instance_types": ["t3.micro", "t3.small", "t3.medium"]
                },
                "lambda": {
                    "enabled": True,
                    "check_function_status": True,
                    "check_error_rates": True,
                    "max_error_rate": 5.0
                },
                "s3": {
                    "enabled": True,
                    "check_bucket_encryption": True,
                    "check_public_access": True
                },
                "iam": {
                    "enabled": True,
                    "check_policy_compliance": True,
                    "check_unused_roles": True
                }
            },
            "cost_validation": {
                "enabled": True,
                "max_hourly_cost": 10.0,
                "max_daily_cost": 50.0,
                "alert_threshold": 0.8
            },
            "completion_criteria": {
                "required_resources": [],
                "required_outputs": [],
                "required_tags": ["Project", "SessionId", "LabName"],
                "custom_validations": []
            }
        }
    
    def validate_lab_session(self, session_id: str, lab_id: Optional[str] = None) -> Dict:
        """Validate a complete lab session."""
        print(f"🔍 Validating lab session: {session_id}")
        
        if not self.aws_available:
            return self._create_error_result("AWS credentials not available")
        
        # Reset validation results
        self.validation_results = {
            "timestamp": datetime.now().isoformat(),
            "session_id": session_id,
            "lab_id": lab_id,
            "overall_status": "unknown",
            "checks": {},
            "errors": [],
            "warnings": [],
            "recommendations": []
        }
        
        # Run health checks
        if self.config.get("health_checks", {}).get("cloudformation", {}).get("enabled", True):
            self._validate_cloudformation_resources(session_id)
        
        if self.config.get("health_checks", {}).get("ec2", {}).get("enabled", True):
            self._validate_ec2_resources(session_id)
        
        if self.config.get("health_checks", {}).get("lambda", {}).get("enabled", True):
            self._validate_lambda_resources(session_id)
        
        if self.config.get("health_checks", {}).get("s3", {}).get("enabled", True):
            self._validate_s3_resources(session_id)
        
        if self.config.get("health_checks", {}).get("iam", {}).get("enabled", True):
            self._validate_iam_resources(session_id)
        
        # Run cost validation
        if self.config.get("cost_validation", {}).get("enabled", True):
            self._validate_costs(session_id)
        
        # Run completion criteria validation
        self._validate_completion_criteria(session_id, lab_id)
        
        # Determine overall status
        self._determine_overall_status()
        
        return self.validation_results
    
    def _validate_cloudformation_resources(self, session_id: str):
        """Validate CloudFormation resources."""
        print("  📋 Validating CloudFormation resources...")
        
        check_result = {
            "status": "passed",
            "details": {},
            "issues": []
        }
        
        try:
            # Get stacks for this session
            stacks = self._get_session_stacks(session_id)
            check_result["details"]["stack_count"] = len(stacks)
            
            for stack in stacks:
                stack_name = stack["StackName"]
                stack_status = stack["StackStatus"]
                
                # Check stack status
                if not stack_status.endswith("_COMPLETE"):
                    check_result["issues"].append(f"Stack {stack_name} status: {stack_status}")
                    check_result["status"] = "failed"
                
                # Check required tags
                stack_tags = {tag["Key"]: tag["Value"] for tag in stack.get("Tags", [])}
                required_tags = self.config.get("health_checks", {}).get("cloudformation", {}).get("required_tags", [])
                
                for tag in required_tags:
                    if tag not in stack_tags:
                        check_result["issues"].append(f"Stack {stack_name} missing required tag: {tag}")
                        check_result["status"] = "warning"
                
                # Check for drift (if enabled)
                if self.config.get("health_checks", {}).get("cloudformation", {}).get("check_drift", False):
                    try:
                        drift_result = self.cloudformation.describe_stack_drift_detection_status(
                            StackDriftDetectionId=self.cloudformation.detect_stack_drift(
                                StackName=stack_name
                            )["StackDriftDetectionId"]
                        )
                        
                        if drift_result.get("StackDriftStatus") == "DRIFTED":
                            check_result["issues"].append(f"Stack {stack_name} has configuration drift")
                            check_result["status"] = "warning"
                    except ClientError:
                        # Drift detection might not be available for all stacks
                        pass
            
        except ClientError as e:
            check_result["status"] = "error"
            check_result["issues"].append(f"CloudFormation validation error: {str(e)}")
        
        self.validation_results["checks"]["cloudformation"] = check_result
    
    def _validate_ec2_resources(self, session_id: str):
        """Validate EC2 resources."""
        print("  🖥️  Validating EC2 resources...")
        
        check_result = {
            "status": "passed",
            "details": {},
            "issues": []
        }
        
        try:
            # Get EC2 instances for this session
            instances = self._get_session_instances(session_id)
            check_result["details"]["instance_count"] = len(instances)
            
            allowed_types = self.config.get("health_checks", {}).get("ec2", {}).get("allowed_instance_types", [])
            
            for instance in instances:
                instance_id = instance["InstanceId"]
                instance_type = instance["InstanceType"]
                instance_state = instance["State"]["Name"]
                
                # Check instance status
                if instance_state not in ["running", "stopped"]:
                    check_result["issues"].append(f"Instance {instance_id} in unexpected state: {instance_state}")
                    check_result["status"] = "warning"
                
                # Check instance type
                if allowed_types and instance_type not in allowed_types:
                    check_result["issues"].append(f"Instance {instance_id} using non-approved type: {instance_type}")
                    check_result["status"] = "warning"
                
                # Check security groups
                if self.config.get("health_checks", {}).get("ec2", {}).get("check_security_groups", True):
                    for sg in instance.get("SecurityGroups", []):
                        sg_id = sg["GroupId"]
                        if self._check_security_group_rules(sg_id):
                            check_result["issues"].append(f"Instance {instance_id} has overly permissive security group: {sg_id}")
                            check_result["status"] = "warning"
            
        except ClientError as e:
            check_result["status"] = "error"
            check_result["issues"].append(f"EC2 validation error: {str(e)}")
        
        self.validation_results["checks"]["ec2"] = check_result
    
    def _validate_lambda_resources(self, session_id: str):
        """Validate Lambda resources."""
        print("  ⚡ Validating Lambda resources...")
        
        check_result = {
            "status": "passed",
            "details": {},
            "issues": []
        }
        
        try:
            # Get Lambda functions for this session
            functions = self._get_session_lambda_functions(session_id)
            check_result["details"]["function_count"] = len(functions)
            
            max_error_rate = self.config.get("health_checks", {}).get("lambda", {}).get("max_error_rate", 5.0)
            
            for function in functions:
                function_name = function["FunctionName"]
                
                # Check function configuration
                try:
                    config_response = self.lambda_client.get_function_configuration(FunctionName=function_name)
                    if config_response["State"] != "Active":
                        check_result["issues"].append(f"Function {function_name} not in Active state")
                        check_result["status"] = "warning"
                except ClientError:
                    check_result["issues"].append(f"Could not get configuration for function {function_name}")
                    check_result["status"] = "warning"
                
                # Check error rates (if enabled)
                if self.config.get("health_checks", {}).get("lambda", {}).get("check_error_rates", True):
                    error_rate = self._get_lambda_error_rate(function_name)
                    if error_rate > max_error_rate:
                        check_result["issues"].append(f"Function {function_name} error rate too high: {error_rate:.2f}%")
                        check_result["status"] = "warning"
            
        except ClientError as e:
            check_result["status"] = "error"
            check_result["issues"].append(f"Lambda validation error: {str(e)}")
        
        self.validation_results["checks"]["lambda"] = check_result
    
    def _validate_s3_resources(self, session_id: str):
        """Validate S3 resources."""
        print("  🪣 Validating S3 resources...")
        
        check_result = {
            "status": "passed",
            "details": {},
            "issues": []
        }
        
        try:
            # Get S3 buckets for this session
            buckets = self._get_session_s3_buckets(session_id)
            check_result["details"]["bucket_count"] = len(buckets)
            
            for bucket_name in buckets:
                # Check bucket encryption
                if self.config.get("health_checks", {}).get("s3", {}).get("check_bucket_encryption", True):
                    if not self._check_bucket_encryption(bucket_name):
                        check_result["issues"].append(f"Bucket {bucket_name} does not have encryption enabled")
                        check_result["status"] = "warning"
                
                # Check public access
                if self.config.get("health_checks", {}).get("s3", {}).get("check_public_access", True):
                    if self._check_bucket_public_access(bucket_name):
                        check_result["issues"].append(f"Bucket {bucket_name} may have public access enabled")
                        check_result["status"] = "warning"
            
        except ClientError as e:
            check_result["status"] = "error"
            check_result["issues"].append(f"S3 validation error: {str(e)}")
        
        self.validation_results["checks"]["s3"] = check_result
    
    def _validate_iam_resources(self, session_id: str):
        """Validate IAM resources."""
        print("  🔐 Validating IAM resources...")
        
        check_result = {
            "status": "passed",
            "details": {},
            "issues": []
        }
        
        try:
            # Get IAM roles for this session
            roles = self._get_session_iam_roles(session_id)
            check_result["details"]["role_count"] = len(roles)
            
            for role_name in roles:
                # Check policy compliance
                if self.config.get("health_checks", {}).get("iam", {}).get("check_policy_compliance", True):
                    if self._check_iam_policy_compliance(role_name):
                        check_result["issues"].append(f"Role {role_name} may have overly permissive policies")
                        check_result["status"] = "warning"
            
        except ClientError as e:
            check_result["status"] = "error"
            check_result["issues"].append(f"IAM validation error: {str(e)}")
        
        self.validation_results["checks"]["iam"] = check_result
    
    def _validate_costs(self, session_id: str):
        """Validate costs against budget limits."""
        print("  💰 Validating costs...")
        
        check_result = {
            "status": "passed",
            "details": {},
            "issues": []
        }
        
        try:
            # Estimate current costs for session resources
            estimated_cost = self._estimate_session_costs(session_id)
            check_result["details"]["estimated_hourly_cost"] = estimated_cost
            
            max_hourly_cost = self.config.get("cost_validation", {}).get("max_hourly_cost", 10.0)
            alert_threshold = self.config.get("cost_validation", {}).get("alert_threshold", 0.8)
            
            if estimated_cost > max_hourly_cost:
                check_result["issues"].append(f"Estimated cost ${estimated_cost:.2f}/hour exceeds limit ${max_hourly_cost:.2f}/hour")
                check_result["status"] = "failed"
            elif estimated_cost > (max_hourly_cost * alert_threshold):
                check_result["issues"].append(f"Estimated cost ${estimated_cost:.2f}/hour approaching limit ${max_hourly_cost:.2f}/hour")
                check_result["status"] = "warning"
            
        except Exception as e:
            check_result["status"] = "error"
            check_result["issues"].append(f"Cost validation error: {str(e)}")
        
        self.validation_results["checks"]["cost"] = check_result
    
    def _validate_completion_criteria(self, session_id: str, lab_id: Optional[str]):
        """Validate lab completion criteria."""
        print("  ✅ Validating completion criteria...")
        
        check_result = {
            "status": "passed",
            "details": {},
            "issues": []
        }
        
        try:
            # Load lab-specific completion criteria if available
            if lab_id:
                lab_criteria = self._load_lab_completion_criteria(lab_id)
                if lab_criteria:
                    # Validate required resources
                    for resource_type in lab_criteria.get("required_resources", []):
                        if not self._check_resource_exists(session_id, resource_type):
                            check_result["issues"].append(f"Required resource type not found: {resource_type}")
                            check_result["status"] = "failed"
                    
                    # Validate required outputs
                    for output_name in lab_criteria.get("required_outputs", []):
                        if not self._check_stack_output_exists(session_id, output_name):
                            check_result["issues"].append(f"Required stack output not found: {output_name}")
                            check_result["status"] = "failed"
            
            # General completion checks
            total_resources = self._count_session_resources(session_id)
            check_result["details"]["total_resources"] = total_resources
            
            if total_resources == 0:
                check_result["issues"].append("No resources found for this session")
                check_result["status"] = "failed"
            
        except Exception as e:
            check_result["status"] = "error"
            check_result["issues"].append(f"Completion criteria validation error: {str(e)}")
        
        self.validation_results["checks"]["completion"] = check_result
    
    def _determine_overall_status(self):
        """Determine overall validation status."""
        has_errors = any(check.get("status") == "error" for check in self.validation_results["checks"].values())
        has_failures = any(check.get("status") == "failed" for check in self.validation_results["checks"].values())
        has_warnings = any(check.get("status") == "warning" for check in self.validation_results["checks"].values())
        
        if has_errors:
            self.validation_results["overall_status"] = "error"
        elif has_failures:
            self.validation_results["overall_status"] = "failed"
        elif has_warnings:
            self.validation_results["overall_status"] = "warning"
        else:
            self.validation_results["overall_status"] = "passed"
        
        # Collect all issues
        for check_name, check_result in self.validation_results["checks"].items():
            for issue in check_result.get("issues", []):
                if check_result["status"] == "error":
                    self.validation_results["errors"].append(f"{check_name}: {issue}")
                elif check_result["status"] == "failed":
                    self.validation_results["errors"].append(f"{check_name}: {issue}")
                elif check_result["status"] == "warning":
                    self.validation_results["warnings"].append(f"{check_name}: {issue}")
    
    # Helper methods for resource discovery
    def _get_session_stacks(self, session_id: str) -> List[Dict]:
        """Get CloudFormation stacks for a session."""
        try:
            response = self.cloudformation.list_stacks(
                StackStatusFilter=['CREATE_COMPLETE', 'UPDATE_COMPLETE', 'ROLLBACK_COMPLETE']
            )
            
            session_stacks = []
            for stack in response['StackSummaries']:
                try:
                    stack_detail = self.cloudformation.describe_stacks(StackName=stack['StackName'])
                    stack_info = stack_detail['Stacks'][0]
                    
                    # Check if stack belongs to this session
                    stack_tags = {tag['Key']: tag['Value'] for tag in stack_info.get('Tags', [])}
                    if stack_tags.get('SessionId') == session_id:
                        session_stacks.append(stack_info)
                except ClientError:
                    continue
            
            return session_stacks
        except ClientError:
            return []
    
    def _get_session_instances(self, session_id: str) -> List[Dict]:
        """Get EC2 instances for a session."""
        try:
            response = self.ec2.describe_instances(
                Filters=[
                    {'Name': 'tag:SessionId', 'Values': [session_id]},
                    {'Name': 'instance-state-name', 'Values': ['running', 'stopped', 'stopping']}
                ]
            )
            
            instances = []
            for reservation in response['Reservations']:
                instances.extend(reservation['Instances'])
            
            return instances
        except ClientError:
            return []
    
    def _get_session_lambda_functions(self, session_id: str) -> List[Dict]:
        """Get Lambda functions for a session."""
        try:
            response = self.lambda_client.list_functions()
            session_functions = []
            
            for function in response['Functions']:
                try:
                    tags_response = self.lambda_client.list_tags(Resource=function['FunctionArn'])
                    if tags_response.get('Tags', {}).get('SessionId') == session_id:
                        session_functions.append(function)
                except ClientError:
                    continue
            
            return session_functions
        except ClientError:
            return []
    
    def _get_session_s3_buckets(self, session_id: str) -> List[str]:
        """Get S3 buckets for a session."""
        try:
            response = self.s3.list_buckets()
            session_buckets = []
            
            for bucket in response['Buckets']:
                bucket_name = bucket['Name']
                try:
                    tags_response = self.s3.get_bucket_tagging(Bucket=bucket_name)
                    bucket_tags = {tag['Key']: tag['Value'] for tag in tags_response.get('TagSet', [])}
                    if bucket_tags.get('SessionId') == session_id:
                        session_buckets.append(bucket_name)
                except ClientError:
                    # Bucket might not have tags
                    continue
            
            return session_buckets
        except ClientError:
            return []
    
    def _get_session_iam_roles(self, session_id: str) -> List[str]:
        """Get IAM roles for a session."""
        try:
            response = self.iam.list_roles()
            session_roles = []
            
            for role in response['Roles']:
                role_name = role['RoleName']
                try:
                    tags_response = self.iam.list_role_tags(RoleName=role_name)
                    role_tags = {tag['Key']: tag['Value'] for tag in tags_response.get('Tags', [])}
                    if role_tags.get('SessionId') == session_id:
                        session_roles.append(role_name)
                except ClientError:
                    continue
            
            return session_roles
        except ClientError:
            return []
    
    # Helper methods for specific checks
    def _check_security_group_rules(self, sg_id: str) -> bool:
        """Check if security group has overly permissive rules."""
        try:
            response = self.ec2.describe_security_groups(GroupIds=[sg_id])
            sg = response['SecurityGroups'][0]
            
            for rule in sg.get('IpPermissions', []):
                for ip_range in rule.get('IpRanges', []):
                    if ip_range.get('CidrIp') == '0.0.0.0/0':
                        return True  # Overly permissive
            
            return False
        except ClientError:
            return False
    
    def _get_lambda_error_rate(self, function_name: str) -> float:
        """Get Lambda function error rate."""
        try:
            end_time = datetime.utcnow()
            start_time = end_time - timedelta(hours=1)
            
            # Get invocation count
            invocations = self.cloudwatch.get_metric_statistics(
                Namespace='AWS/Lambda',
                MetricName='Invocations',
                Dimensions=[{'Name': 'FunctionName', 'Value': function_name}],
                StartTime=start_time,
                EndTime=end_time,
                Period=3600,
                Statistics=['Sum']
            )
            
            # Get error count
            errors = self.cloudwatch.get_metric_statistics(
                Namespace='AWS/Lambda',
                MetricName='Errors',
                Dimensions=[{'Name': 'FunctionName', 'Value': function_name}],
                StartTime=start_time,
                EndTime=end_time,
                Period=3600,
                Statistics=['Sum']
            )
            
            total_invocations = sum(point['Sum'] for point in invocations['Datapoints'])
            total_errors = sum(point['Sum'] for point in errors['Datapoints'])
            
            if total_invocations > 0:
                return (total_errors / total_invocations) * 100
            return 0.0
            
        except ClientError:
            return 0.0
    
    def _check_bucket_encryption(self, bucket_name: str) -> bool:
        """Check if S3 bucket has encryption enabled."""
        try:
            self.s3.get_bucket_encryption(Bucket=bucket_name)
            return True
        except ClientError as e:
            if e.response['Error']['Code'] == 'ServerSideEncryptionConfigurationNotFoundError':
                return False
            return True  # Assume encrypted if we can't check
    
    def _check_bucket_public_access(self, bucket_name: str) -> bool:
        """Check if S3 bucket has public access."""
        try:
            response = self.s3.get_public_access_block(Bucket=bucket_name)
            config = response['PublicAccessBlockConfiguration']
            
            # If all public access is blocked, return False (not public)
            return not (
                config.get('BlockPublicAcls', False) and
                config.get('BlockPublicPolicy', False) and
                config.get('IgnorePublicAcls', False) and
                config.get('RestrictPublicBuckets', False)
            )
        except ClientError:
            return True  # Assume public if we can't check
    
    def _check_iam_policy_compliance(self, role_name: str) -> bool:
        """Check if IAM role has overly permissive policies."""
        try:
            # Get attached policies
            response = self.iam.list_attached_role_policies(RoleName=role_name)
            
            for policy in response['AttachedPolicies']:
                policy_arn = policy['PolicyArn']
                
                # Skip AWS managed policies (they're generally safe)
                if policy_arn.startswith('arn:aws:iam::aws:policy/'):
                    continue
                
                # Check custom policies for wildcard permissions
                try:
                    policy_response = self.iam.get_policy(PolicyArn=policy_arn)
                    version_response = self.iam.get_policy_version(
                        PolicyArn=policy_arn,
                        VersionId=policy_response['Policy']['DefaultVersionId']
                    )
                    
                    policy_doc = version_response['PolicyVersion']['Document']
                    for statement in policy_doc.get('Statement', []):
                        if (statement.get('Effect') == 'Allow' and 
                            statement.get('Resource') == '*' and
                            '*' in statement.get('Action', [])):
                            return True  # Overly permissive
                            
                except ClientError:
                    continue
            
            return False
        except ClientError:
            return False
    
    def _estimate_session_costs(self, session_id: str) -> float:
        """Estimate costs for session resources."""
        total_cost = 0.0
        
        # EC2 instance costs
        instances = self._get_session_instances(session_id)
        instance_costs = {
            't3.micro': 0.0104, 't3.small': 0.021, 't3.medium': 0.042,
            't2.micro': 0.0116, 't2.small': 0.023, 't2.medium': 0.046,
            'm5.large': 0.096, 'm5.xlarge': 0.192
        }
        
        for instance in instances:
            if instance['State']['Name'] == 'running':
                instance_type = instance['InstanceType']
                total_cost += instance_costs.get(instance_type, 0.05)
        
        # Lambda function costs (minimal for labs)
        functions = self._get_session_lambda_functions(session_id)
        total_cost += len(functions) * 0.01
        
        # S3 bucket costs (minimal for labs)
        buckets = self._get_session_s3_buckets(session_id)
        total_cost += len(buckets) * 0.023
        
        # Base infrastructure cost
        total_cost += 0.50
        
        return round(total_cost, 2)
    
    def _load_lab_completion_criteria(self, lab_id: str) -> Optional[Dict]:
        """Load lab-specific completion criteria."""
        criteria_file = self.base_dir / "config" / "completion-criteria" / f"{lab_id}.yaml"
        
        if not criteria_file.exists():
            return None
        
        try:
            with open(criteria_file, 'r') as f:
                return yaml.safe_load(f)
        except Exception:
            return None
    
    def _check_resource_exists(self, session_id: str, resource_type: str) -> bool:
        """Check if a specific resource type exists for the session."""
        if resource_type == "ec2":
            return len(self._get_session_instances(session_id)) > 0
        elif resource_type == "lambda":
            return len(self._get_session_lambda_functions(session_id)) > 0
        elif resource_type == "s3":
            return len(self._get_session_s3_buckets(session_id)) > 0
        elif resource_type == "cloudformation":
            return len(self._get_session_stacks(session_id)) > 0
        return False
    
    def _check_stack_output_exists(self, session_id: str, output_name: str) -> bool:
        """Check if a CloudFormation stack output exists."""
        stacks = self._get_session_stacks(session_id)
        
        for stack in stacks:
            for output in stack.get('Outputs', []):
                if output['OutputKey'] == output_name:
                    return True
        
        return False
    
    def _count_session_resources(self, session_id: str) -> int:
        """Count total resources for a session."""
        return (
            len(self._get_session_stacks(session_id)) +
            len(self._get_session_instances(session_id)) +
            len(self._get_session_lambda_functions(session_id)) +
            len(self._get_session_s3_buckets(session_id)) +
            len(self._get_session_iam_roles(session_id))
        )
    
    def _create_error_result(self, error_message: str) -> Dict:
        """Create error result."""
        return {
            "timestamp": datetime.now().isoformat(),
            "overall_status": "error",
            "checks": {},
            "errors": [error_message],
            "warnings": [],
            "recommendations": []
        }
    
    def generate_health_report(self, session_id: str, output_file: Optional[str] = None) -> str:
        """Generate comprehensive health report."""
        results = self.validate_lab_session(session_id)
        
        if not output_file:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_file = f"health_report_{session_id}_{timestamp}.json"
        
        output_path = Path(output_file)
        with open(output_path, 'w') as f:
            json.dump(results, f, indent=2, default=str)
        
        print(f"📄 Health report saved to: {output_path}")
        return str(output_path)
    
    def print_validation_summary(self):
        """Print validation summary to console."""
        results = self.validation_results
        
        print(f"\n🎯 Lab Validation Summary")
        print("=" * 50)
        print(f"Overall Status: {results['overall_status'].upper()}")
        print(f"Timestamp: {results['timestamp']}")
        
        if results.get('session_id'):
            print(f"Session ID: {results['session_id']}")
        
        print(f"\n📋 Check Results:")
        for check_name, check_result in results['checks'].items():
            status_icon = {
                'passed': '✅',
                'warning': '⚠️',
                'failed': '❌',
                'error': '💥'
            }.get(check_result['status'], '❓')
            
            print(f"  {status_icon} {check_name.title()}: {check_result['status'].upper()}")
            
            if check_result.get('details'):
                for key, value in check_result['details'].items():
                    print(f"    {key}: {value}")
        
        if results['errors']:
            print(f"\n❌ Errors ({len(results['errors'])}):")
            for error in results['errors']:
                print(f"  • {error}")
        
        if results['warnings']:
            print(f"\n⚠️  Warnings ({len(results['warnings'])}):")
            for warning in results['warnings']:
                print(f"  • {warning}")
        
        if results['recommendations']:
            print(f"\n💡 Recommendations:")
            for rec in results['recommendations']:
                print(f"  • {rec}")


def main():
    """Main entry point for lab validator."""
    parser = argparse.ArgumentParser(description="AWS DevOps Labs Validation and Health Check System")
    parser.add_argument(
        "session_id",
        help="Lab session ID to validate"
    )
    parser.add_argument(
        "--lab-id", "-l",
        help="Lab ID for specific completion criteria validation"
    )
    parser.add_argument(
        "--config", "-c",
        help="Path to validation configuration file"
    )
    parser.add_argument(
        "--output", "-o",
        help="Output file for validation report"
    )
    parser.add_argument(
        "--quiet", "-q",
        action="store_true",
        help="Suppress console output"
    )
    parser.add_argument(
        "--format",
        choices=["json", "yaml", "summary"],
        default="summary",
        help="Output format"
    )
    
    args = parser.parse_args()
    
    try:
        validator = LabValidator(args.config)
        
        # Run validation
        results = validator.validate_lab_session(args.session_id, args.lab_id)
        
        # Generate output
        if args.output:
            validator.generate_health_report(args.session_id, args.output)
        
        if not args.quiet:
            if args.format == "summary":
                validator.print_validation_summary()
            elif args.format == "json":
                print(json.dumps(results, indent=2, default=str))
            elif args.format == "yaml":
                print(yaml.dump(results, default_flow_style=False))
        
        # Exit with appropriate code
        if results['overall_status'] in ['error', 'failed']:
            sys.exit(1)
        elif results['overall_status'] == 'warning':
            sys.exit(2)
        else:
            sys.exit(0)
            
    except KeyboardInterrupt:
        print("\n⚠️  Validation interrupted by user")
        sys.exit(130)
    except Exception as e:
        print(f"❌ Validation error: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()