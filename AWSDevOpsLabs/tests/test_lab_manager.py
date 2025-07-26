#!/usr/bin/env python3
"""
Unit tests for LabManager functionality.
Tests the core lab management features including session management,
resource tracking, and CLI commands.
"""

import json
import os
import tempfile
import unittest
from datetime import datetime
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock
import yaml

# Import the LabManager class
import sys
sys.path.insert(0, str(Path(__file__).parent.parent))
from lab_manager import LabManager


class TestLabManager(unittest.TestCase):
    """Test cases for LabManager class."""
    
    def setUp(self):
        """Set up test environment with temporary directories."""
        self.test_dir = tempfile.mkdtemp()
        self.test_path = Path(self.test_dir)
        
        # Create test lab structure
        self.create_test_lab_structure()
        
        # Mock the base directory to use our test directory
        with patch.object(LabManager, '__init__', self.mock_init):
            self.manager = LabManager()
    
    def mock_init(self, manager_self):
        """Mock initialization to use test directory."""
        manager_self.base_dir = self.test_path
        manager_self.config_dir = self.test_path / "config"
        manager_self.sessions_file = manager_self.config_dir / "sessions.json"
        manager_self.labs_config = manager_self.config_dir / "labs.yaml"
        manager_self.resource_tags = {"Project": "AWSDevOpsLabs", "ManagedBy": "LabManager"}
        
        # Ensure config directory exists
        manager_self.config_dir.mkdir(exist_ok=True)
        
        # Initialize sessions file if it doesn't exist
        if not manager_self.sessions_file.exists():
            manager_self._save_sessions({})
        
        # Mock AWS clients
        manager_self.aws_available = False
        manager_self.session = Mock()
        manager_self.cloudformation = Mock()
        manager_self.ec2 = Mock()
        manager_self.iam = Mock()
        manager_self.lambda_client = Mock()
        manager_self.s3 = Mock()
        manager_self.pricing = Mock()
        manager_self.sts = Mock()
    
    def create_test_lab_structure(self):
        """Create a test lab directory structure."""
        # Create category directories
        categories = ["01-cicd", "02-iac", "03-monitoring"]
        
        for category in categories:
            category_dir = self.test_path / category
            category_dir.mkdir(parents=True)
            
            # Create lab subdirectories
            if category == "01-cicd":
                labs = ["codepipeline", "codebuild", "codedeploy"]
            elif category == "02-iac":
                labs = ["cloudformation", "cdk", "terraform"]
            else:
                labs = ["cloudwatch", "xray", "config"]
            
            for lab in labs:
                lab_dir = category_dir / lab
                lab_dir.mkdir()
                
                # Create lab guide
                lab_guide = lab_dir / "lab-guide.md"
                lab_guide.write_text(self.create_test_lab_guide(lab))
                
                # Create scripts directory
                scripts_dir = lab_dir / "scripts"
                scripts_dir.mkdir()
                
                # Create provision and cleanup scripts
                provision_script = scripts_dir / "provision.sh"
                provision_script.write_text("#!/bin/bash\necho 'Provisioning lab'\n")
                provision_script.chmod(0o755)
                
                cleanup_script = scripts_dir / "cleanup.sh"
                cleanup_script.write_text("#!/bin/bash\necho 'Cleaning up lab'\n")
                cleanup_script.chmod(0o755)
    
    def create_test_lab_guide(self, lab_name):
        """Create a test lab guide markdown content."""
        return f"""# {lab_name.title()} Lab

## Objective

Learn how to use {lab_name} for AWS DevOps practices.

## Prerequisites

- AWS CLI configured
- Basic understanding of AWS services

## Time to Complete

60 minutes

## Steps

1. Set up the environment
2. Configure {lab_name}
3. Test the configuration
4. Clean up resources

## AWS Services Used

- {lab_name.upper()}
- CloudFormation
- EC2
- IAM

## Estimated Cost

$2.50 for this lab exercise.
"""
    
    def tearDown(self):
        """Clean up test environment."""
        import shutil
        shutil.rmtree(self.test_dir)
    
    def test_init(self):
        """Test LabManager initialization."""
        self.assertIsInstance(self.manager, LabManager)
        self.assertTrue(self.manager.config_dir.exists())
        self.assertTrue(self.manager.sessions_file.exists())
    
    def test_load_save_sessions(self):
        """Test session loading and saving."""
        test_sessions = {
            "test-session-1": {
                "lab_id": "cicd-codepipeline",
                "status": "running",
                "start_time": datetime.now().isoformat()
            }
        }
        
        self.manager._save_sessions(test_sessions)
        loaded_sessions = self.manager._load_sessions()
        
        self.assertEqual(loaded_sessions, test_sessions)
    
    def test_discover_labs(self):
        """Test lab discovery functionality."""
        config = self.manager._discover_labs()
        
        self.assertIn("labs", config)
        labs = config["labs"]
        
        # Should discover labs from our test structure
        self.assertGreater(len(labs), 0)
        
        # Check specific lab exists
        cicd_labs = [lab_id for lab_id in labs.keys() if lab_id.startswith("cicd-")]
        self.assertGreater(len(cicd_labs), 0)
        
        # Check lab metadata
        first_lab = list(labs.values())[0]
        required_fields = ["name", "category", "path", "description", "duration", "aws_services"]
        for field in required_fields:
            self.assertIn(field, first_lab)
    
    def test_parse_lab_metadata(self):
        """Test lab metadata parsing from markdown."""
        # Create a test lab guide
        test_guide_path = self.test_path / "test-guide.md"
        test_guide_content = """# Test Lab Guide

## Objective

This is a test lab for parsing metadata.

## Prerequisites

- AWS CLI
- Python 3.8+

## Time to Complete

45 minutes

This lab uses CloudFormation, EC2, and Lambda services.
"""
        test_guide_path.write_text(test_guide_content)
        
        metadata = self.manager._parse_lab_metadata(
            test_guide_path, "test", self.test_path
        )
        
        self.assertIsNotNone(metadata)
        self.assertEqual(metadata["name"], "Test Lab Guide")
        self.assertEqual(metadata["category"], "test")
        self.assertEqual(metadata["duration"], 45)
        self.assertIn("CloudFormation", metadata["aws_services"])
        self.assertIn("EC2", metadata["aws_services"])
        self.assertIn("Lambda", metadata["aws_services"])
    
    def test_estimate_lab_cost(self):
        """Test lab cost estimation."""
        aws_services = ["EC2", "Lambda", "S3"]
        duration_minutes = 60
        
        cost = self.manager._estimate_lab_cost(aws_services, duration_minutes)
        
        self.assertIsInstance(cost, float)
        self.assertGreater(cost, 0)
    
    def test_start_lab(self):
        """Test starting a lab session."""
        # First discover labs
        self.manager._discover_labs()
        
        # Get a lab ID
        config = self.manager._load_labs_config()
        lab_ids = list(config["labs"].keys())
        self.assertGreater(len(lab_ids), 0)
        
        lab_id = lab_ids[0]
        
        # Start the lab
        result = self.manager.start_lab(lab_id)
        self.assertTrue(result)
        
        # Check session was created
        sessions = self.manager._load_sessions()
        session_ids = [sid for sid in sessions.keys() if sessions[sid]["lab_id"] == lab_id]
        self.assertEqual(len(session_ids), 1)
        
        session = sessions[session_ids[0]]
        self.assertEqual(session["status"], "running")
        self.assertEqual(session["lab_id"], lab_id)
    
    def test_stop_lab(self):
        """Test stopping a lab session."""
        # First start a lab
        self.manager._discover_labs()
        config = self.manager._load_labs_config()
        lab_id = list(config["labs"].keys())[0]
        
        self.manager.start_lab(lab_id)
        
        # Get the session ID
        sessions = self.manager._load_sessions()
        session_id = list(sessions.keys())[0]
        
        # Stop the lab
        result = self.manager.stop_lab(session_id)
        self.assertTrue(result)
        
        # Check session status
        updated_sessions = self.manager._load_sessions()
        self.assertEqual(updated_sessions[session_id]["status"], "stopped")
    
    def test_list_labs(self):
        """Test listing labs functionality."""
        # Discover labs first
        self.manager._discover_labs()
        
        # Test basic listing (should not raise exception)
        try:
            self.manager.list_labs()
        except Exception as e:
            self.fail(f"list_labs() raised an exception: {e}")
        
        # Test category filtering
        try:
            self.manager.list_labs(category="cicd")
        except Exception as e:
            self.fail(f"list_labs(category='cicd') raised an exception: {e}")
    
    def test_update_session_progress(self):
        """Test session progress tracking."""
        # Start a lab first
        self.manager._discover_labs()
        config = self.manager._load_labs_config()
        lab_id = list(config["labs"].keys())[0]
        
        self.manager.start_lab(lab_id)
        sessions = self.manager._load_sessions()
        session_id = list(sessions.keys())[0]
        
        # Update progress
        result = self.manager.update_session_progress(
            session_id, "setup_environment", True, "Environment configured"
        )
        self.assertTrue(result)
        
        # Check progress was saved
        progress = self.manager.get_session_progress(session_id)
        self.assertIsNotNone(progress)
        self.assertEqual(len(progress["steps"]), 1)
        self.assertTrue(progress["steps"][0]["completed"])
        self.assertEqual(progress["steps"][0]["name"], "setup_environment")
    
    @patch('subprocess.run')
    def test_cleanup_session(self, mock_subprocess):
        """Test session cleanup functionality."""
        # Mock successful cleanup script execution
        mock_subprocess.return_value.returncode = 0
        mock_subprocess.return_value.stderr = ""
        
        # Start a lab first
        self.manager._discover_labs()
        config = self.manager._load_labs_config()
        lab_id = list(config["labs"].keys())[0]
        
        self.manager.start_lab(lab_id)
        sessions = self.manager._load_sessions()
        session_id = list(sessions.keys())[0]
        
        # Mock AWS availability for cleanup verification
        self.manager.aws_available = True
        self.manager.get_resource_inventory = Mock(return_value={
            'cloudformation_stacks': [],
            'ec2_instances': [],
            'lambda_functions': []
        })
        
        # Cleanup the session
        result = self.manager.cleanup_session(session_id, verify=True)
        self.assertTrue(result)
        
        # Check session status
        updated_sessions = self.manager._load_sessions()
        self.assertEqual(updated_sessions[session_id]["status"], "cleaned_up")
    
    def test_invalid_lab_id(self):
        """Test handling of invalid lab IDs."""
        result = self.manager.start_lab("invalid-lab-id")
        self.assertFalse(result)
    
    def test_invalid_session_id(self):
        """Test handling of invalid session IDs."""
        result = self.manager.stop_lab("invalid-session-id")
        self.assertFalse(result)
        
        result = self.manager.update_session_progress(
            "invalid-session-id", "test-step", True
        )
        self.assertFalse(result)


class TestLabManagerCLI(unittest.TestCase):
    """Test cases for LabManager CLI functionality."""
    
    def setUp(self):
        """Set up test environment."""
        self.test_dir = tempfile.mkdtemp()
        self.test_path = Path(self.test_dir)
    
    def tearDown(self):
        """Clean up test environment."""
        import shutil
        shutil.rmtree(self.test_dir)
    
    @patch('sys.argv', ['lab-manager.py', 'list'])
    @patch('lab_manager.LabManager')
    def test_cli_list_command(self, mock_lab_manager):
        """Test CLI list command."""
        mock_manager = Mock()
        mock_lab_manager.return_value = mock_manager
        
        # Import and run main
        from lab_manager import main
        
        try:
            main()
            mock_manager.list_labs.assert_called_once_with(None, False)
        except SystemExit:
            # argparse calls sys.exit, which is expected
            pass
    
    @patch('sys.argv', ['lab-manager.py', 'start', 'test-lab'])
    @patch('lab_manager.LabManager')
    def test_cli_start_command(self, mock_lab_manager):
        """Test CLI start command."""
        mock_manager = Mock()
        mock_lab_manager.return_value = mock_manager
        
        from lab_manager import main
        
        try:
            main()
            mock_manager.start_lab.assert_called_once_with('test-lab')
        except SystemExit:
            pass
    
    @patch('sys.argv', ['lab-manager.py', 'sessions', '--status', 'running'])
    @patch('lab_manager.LabManager')
    def test_cli_sessions_command(self, mock_lab_manager):
        """Test CLI sessions command with status filter."""
        mock_manager = Mock()
        mock_lab_manager.return_value = mock_manager
        
        from lab_manager import main
        
        try:
            main()
            mock_manager.list_sessions.assert_called_once_with('running')
        except SystemExit:
            pass


if __name__ == '__main__':
    unittest.main()