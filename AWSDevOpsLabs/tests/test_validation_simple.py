#!/usr/bin/env python3
"""
Simple tests for lab validation functionality.
Tests basic validation concepts without requiring the full LabValidator implementation.
"""

import json
import os
import tempfile
import unittest
from datetime import datetime
from pathlib import Path
import yaml


class TestValidationConcepts(unittest.TestCase):
    """Test basic validation concepts and utilities."""
    
    def setUp(self):
        """Set up test environment."""
        self.test_dir = tempfile.mkdtemp()
        self.test_path = Path(self.test_dir)
    
    def tearDown(self):
        """Clean up test environment."""
        import shutil
        shutil.rmtree(self.test_dir)
    
    def test_validation_config_structure(self):
        """Test validation configuration structure."""
        config = {
            "health_checks": {
                "cloudformation": {
                    "enabled": True,
                    "required_tags": ["Project", "SessionId"]
                },
                "ec2": {
                    "enabled": True,
                    "allowed_instance_types": ["t3.micro", "t3.small"]
                }
            },
            "cost_validation": {
                "enabled": True,
                "max_hourly_cost": 10.0
            }
        }
        
        # Test config structure
        self.assertIn("health_checks", config)
        self.assertIn("cost_validation", config)
        self.assertTrue(config["health_checks"]["cloudformation"]["enabled"])
        self.assertEqual(config["cost_validation"]["max_hourly_cost"], 10.0)
    
    def test_validation_result_structure(self):
        """Test validation result structure."""
        result = {
            "timestamp": datetime.now().isoformat(),
            "overall_status": "passed",
            "session_id": "test-session-123",
            "checks": {
                "cloudformation": {
                    "status": "passed",
                    "details": {"stack_count": 1},
                    "issues": []
                },
                "ec2": {
                    "status": "warning",
                    "details": {"instance_count": 2},
                    "issues": ["Instance type not in approved list"]
                }
            },
            "errors": [],
            "warnings": ["ec2: Instance type not in approved list"],
            "recommendations": []
        }
        
        # Test result structure
        self.assertIn("overall_status", result)
        self.assertIn("checks", result)
        self.assertEqual(result["session_id"], "test-session-123")
        self.assertEqual(len(result["checks"]), 2)
        self.assertEqual(result["checks"]["cloudformation"]["status"], "passed")
        self.assertEqual(result["checks"]["ec2"]["status"], "warning")
    
    def test_cost_estimation_logic(self):
        """Test cost estimation logic."""
        # Mock resource costs
        instance_costs = {
            't3.micro': 0.0104,
            't3.small': 0.021,
            't3.medium': 0.042
        }
        
        # Test cost calculation
        resources = [
            {'type': 'ec2', 'instance_type': 't3.micro', 'state': 'running'},
            {'type': 'ec2', 'instance_type': 't3.small', 'state': 'running'},
            {'type': 'lambda', 'invocations': 1000},
            {'type': 's3', 'storage_gb': 1}
        ]
        
        total_cost = 0.0
        for resource in resources:
            if resource['type'] == 'ec2' and resource['state'] == 'running':
                total_cost += instance_costs.get(resource['instance_type'], 0.05)
            elif resource['type'] == 'lambda':
                total_cost += resource['invocations'] * 0.0000002  # Lambda pricing
            elif resource['type'] == 's3':
                total_cost += resource['storage_gb'] * 0.023  # S3 pricing
        
        # Add base infrastructure cost
        total_cost += 0.50
        
        self.assertGreater(total_cost, 0)
        self.assertLess(total_cost, 10.0)  # Should be reasonable for lab
    
    def test_resource_tagging_validation(self):
        """Test resource tagging validation logic."""
        required_tags = ["Project", "SessionId", "LabName"]
        
        # Test valid resource tags
        valid_resource = {
            "tags": {
                "Project": "AWSDevOpsLabs",
                "SessionId": "test-session-123",
                "LabName": "test-lab",
                "Environment": "lab"
            }
        }
        
        missing_tags = []
        for tag in required_tags:
            if tag not in valid_resource["tags"]:
                missing_tags.append(tag)
        
        self.assertEqual(len(missing_tags), 0)
        
        # Test invalid resource tags
        invalid_resource = {
            "tags": {
                "Project": "AWSDevOpsLabs",
                "Environment": "lab"
                # Missing SessionId and LabName
            }
        }
        
        missing_tags = []
        for tag in required_tags:
            if tag not in invalid_resource["tags"]:
                missing_tags.append(tag)
        
        self.assertEqual(len(missing_tags), 2)
        self.assertIn("SessionId", missing_tags)
        self.assertIn("LabName", missing_tags)
    
    def test_security_validation_logic(self):
        """Test security validation logic."""
        # Test security group rule validation
        security_group_rules = [
            {
                "IpProtocol": "tcp",
                "FromPort": 22,
                "ToPort": 22,
                "IpRanges": [{"CidrIp": "10.0.0.0/8"}]  # Restrictive
            },
            {
                "IpProtocol": "tcp",
                "FromPort": 80,
                "ToPort": 80,
                "IpRanges": [{"CidrIp": "0.0.0.0/0"}]  # Open to world
            }
        ]
        
        security_issues = []
        for rule in security_group_rules:
            for ip_range in rule.get("IpRanges", []):
                if ip_range.get("CidrIp") == "0.0.0.0/0":
                    if rule["FromPort"] == 22:  # SSH
                        security_issues.append("SSH open to world")
                    elif rule["FromPort"] == 3389:  # RDP
                        security_issues.append("RDP open to world")
        
        # Should not flag HTTP as critical (though not ideal)
        self.assertEqual(len(security_issues), 0)
        
        # Test with SSH open to world
        ssh_open_rules = [
            {
                "IpProtocol": "tcp",
                "FromPort": 22,
                "ToPort": 22,
                "IpRanges": [{"CidrIp": "0.0.0.0/0"}]
            }
        ]
        
        security_issues = []
        for rule in ssh_open_rules:
            for ip_range in rule.get("IpRanges", []):
                if ip_range.get("CidrIp") == "0.0.0.0/0" and rule["FromPort"] == 22:
                    security_issues.append("SSH open to world")
        
        self.assertEqual(len(security_issues), 1)
    
    def test_completion_criteria_validation(self):
        """Test completion criteria validation logic."""
        completion_criteria = {
            "required_resources": ["cloudformation", "ec2", "s3"],
            "required_outputs": ["InstanceId", "BucketName"],
            "min_resources": 3
        }
        
        # Test valid lab completion
        lab_resources = {
            "cloudformation": [{"StackName": "test-stack", "Status": "CREATE_COMPLETE"}],
            "ec2": [{"InstanceId": "i-123", "State": "running"}],
            "s3": [{"BucketName": "test-bucket"}],
            "lambda": [{"FunctionName": "test-function"}]
        }
        
        stack_outputs = ["InstanceId", "BucketName", "VPCId"]
        
        # Check required resources
        missing_resources = []
        for resource_type in completion_criteria["required_resources"]:
            if resource_type not in lab_resources or len(lab_resources[resource_type]) == 0:
                missing_resources.append(resource_type)
        
        self.assertEqual(len(missing_resources), 0)
        
        # Check required outputs
        missing_outputs = []
        for output in completion_criteria["required_outputs"]:
            if output not in stack_outputs:
                missing_outputs.append(output)
        
        self.assertEqual(len(missing_outputs), 0)
        
        # Check minimum resource count
        total_resources = sum(len(resources) for resources in lab_resources.values())
        self.assertGreaterEqual(total_resources, completion_criteria["min_resources"])
    
    def test_health_check_status_logic(self):
        """Test health check status determination logic."""
        def determine_overall_status(checks):
            has_errors = any(check.get("status") == "error" for check in checks.values())
            has_failures = any(check.get("status") == "failed" for check in checks.values())
            has_warnings = any(check.get("status") == "warning" for check in checks.values())
            
            if has_errors:
                return "error"
            elif has_failures:
                return "failed"
            elif has_warnings:
                return "warning"
            else:
                return "passed"
        
        # Test all passed
        checks = {
            "cloudformation": {"status": "passed"},
            "ec2": {"status": "passed"},
            "s3": {"status": "passed"}
        }
        self.assertEqual(determine_overall_status(checks), "passed")
        
        # Test with warning
        checks["ec2"]["status"] = "warning"
        self.assertEqual(determine_overall_status(checks), "warning")
        
        # Test with failure
        checks["s3"]["status"] = "failed"
        self.assertEqual(determine_overall_status(checks), "failed")
        
        # Test with error
        checks["cloudformation"]["status"] = "error"
        self.assertEqual(determine_overall_status(checks), "error")
    
    def test_yaml_config_parsing(self):
        """Test YAML configuration parsing."""
        config_content = """
health_checks:
  cloudformation:
    enabled: true
    required_tags:
      - Project
      - SessionId
  ec2:
    enabled: true
    allowed_instance_types:
      - t3.micro
      - t3.small
cost_validation:
  enabled: true
  max_hourly_cost: 10.0
"""
        
        config_file = self.test_path / "test-config.yaml"
        config_file.write_text(config_content)
        
        with open(config_file, 'r') as f:
            config = yaml.safe_load(f)
        
        self.assertIn("health_checks", config)
        self.assertIn("cost_validation", config)
        self.assertTrue(config["health_checks"]["cloudformation"]["enabled"])
        self.assertEqual(len(config["health_checks"]["ec2"]["allowed_instance_types"]), 2)
    
    def test_json_report_generation(self):
        """Test JSON report generation."""
        validation_result = {
            "timestamp": datetime.now().isoformat(),
            "overall_status": "passed",
            "session_id": "test-session-123",
            "checks": {
                "cloudformation": {"status": "passed", "details": {"stack_count": 1}},
                "ec2": {"status": "passed", "details": {"instance_count": 1}}
            },
            "errors": [],
            "warnings": []
        }
        
        report_file = self.test_path / "validation_report.json"
        with open(report_file, 'w') as f:
            json.dump(validation_result, f, indent=2, default=str)
        
        self.assertTrue(report_file.exists())
        
        # Verify report content
        with open(report_file, 'r') as f:
            loaded_result = json.load(f)
        
        self.assertEqual(loaded_result["overall_status"], "passed")
        self.assertEqual(loaded_result["session_id"], "test-session-123")
        self.assertEqual(len(loaded_result["checks"]), 2)
    
    def test_error_rate_calculation(self):
        """Test error rate calculation logic."""
        def calculate_error_rate(total_invocations, total_errors):
            if total_invocations > 0:
                return (total_errors / total_invocations) * 100
            return 0.0
        
        # Test normal error rate
        error_rate = calculate_error_rate(1000, 50)
        self.assertEqual(error_rate, 5.0)
        
        # Test zero invocations
        error_rate = calculate_error_rate(0, 0)
        self.assertEqual(error_rate, 0.0)
        
        # Test zero errors
        error_rate = calculate_error_rate(1000, 0)
        self.assertEqual(error_rate, 0.0)
        
        # Test high error rate
        error_rate = calculate_error_rate(100, 25)
        self.assertEqual(error_rate, 25.0)
    
    def test_resource_filtering_by_session(self):
        """Test resource filtering by session ID."""
        all_resources = [
            {
                "id": "resource-1",
                "tags": {"SessionId": "session-123", "Project": "AWSDevOpsLabs"}
            },
            {
                "id": "resource-2",
                "tags": {"SessionId": "session-456", "Project": "AWSDevOpsLabs"}
            },
            {
                "id": "resource-3",
                "tags": {"SessionId": "session-123", "Project": "OtherProject"}
            },
            {
                "id": "resource-4",
                "tags": {"Project": "AWSDevOpsLabs"}  # No SessionId
            }
        ]
        
        target_session = "session-123"
        
        # Filter resources by session ID and project
        filtered_resources = []
        for resource in all_resources:
            tags = resource.get("tags", {})
            if (tags.get("SessionId") == target_session and 
                tags.get("Project") == "AWSDevOpsLabs"):
                filtered_resources.append(resource)
        
        self.assertEqual(len(filtered_resources), 1)
        self.assertEqual(filtered_resources[0]["id"], "resource-1")


class TestValidationUtilities(unittest.TestCase):
    """Test validation utility functions."""
    
    def test_timestamp_generation(self):
        """Test timestamp generation for validation results."""
        timestamp = datetime.now().isoformat()
        
        self.assertIsInstance(timestamp, str)
        self.assertIn("T", timestamp)  # ISO format includes T separator
        
        # Test timestamp parsing
        parsed_time = datetime.fromisoformat(timestamp.replace('Z', '+00:00') if timestamp.endswith('Z') else timestamp)
        self.assertIsInstance(parsed_time, datetime)
    
    def test_status_priority(self):
        """Test status priority logic."""
        status_priority = {
            "passed": 0,
            "warning": 1,
            "failed": 2,
            "error": 3
        }
        
        statuses = ["passed", "warning", "passed", "failed"]
        highest_priority_status = max(statuses, key=lambda x: status_priority[x])
        
        self.assertEqual(highest_priority_status, "failed")
        
        # Test with error
        statuses.append("error")
        highest_priority_status = max(statuses, key=lambda x: status_priority[x])
        
        self.assertEqual(highest_priority_status, "error")
    
    def test_validation_summary_formatting(self):
        """Test validation summary formatting."""
        validation_result = {
            "overall_status": "warning",
            "checks": {
                "cloudformation": {"status": "passed"},
                "ec2": {"status": "warning"},
                "s3": {"status": "passed"}
            },
            "errors": [],
            "warnings": ["ec2: Instance type not approved"]
        }
        
        # Count check statuses
        status_counts = {}
        for check in validation_result["checks"].values():
            status = check["status"]
            status_counts[status] = status_counts.get(status, 0) + 1
        
        self.assertEqual(status_counts["passed"], 2)
        self.assertEqual(status_counts["warning"], 1)
        self.assertEqual(status_counts.get("failed", 0), 0)
        self.assertEqual(status_counts.get("error", 0), 0)


if __name__ == '__main__':
    unittest.main()