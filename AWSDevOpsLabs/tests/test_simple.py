#!/usr/bin/env python3
"""
Simple test to verify the testing framework is working.
"""

import unittest
import tempfile
import os
from pathlib import Path


class TestSimple(unittest.TestCase):
    """Simple test cases to verify testing framework."""
    
    def test_basic_functionality(self):
        """Test basic Python functionality."""
        self.assertEqual(2 + 2, 4)
        self.assertTrue(True)
        self.assertFalse(False)
    
    def test_file_operations(self):
        """Test file operations."""
        with tempfile.NamedTemporaryFile(mode='w', delete=False) as f:
            f.write("test content")
            temp_file = f.name
        
        try:
            # Test file exists
            self.assertTrue(os.path.exists(temp_file))
            
            # Test file content
            with open(temp_file, 'r') as f:
                content = f.read()
            self.assertEqual(content, "test content")
            
        finally:
            # Clean up
            os.unlink(temp_file)
    
    def test_path_operations(self):
        """Test path operations."""
        test_path = Path(__file__).parent
        self.assertTrue(test_path.exists())
        self.assertTrue(test_path.is_dir())
        
        # Test parent directory
        parent_path = test_path.parent
        self.assertTrue(parent_path.exists())
    
    def test_string_operations(self):
        """Test string operations."""
        test_string = "AWS DevOps Labs"
        self.assertIn("DevOps", test_string)
        self.assertTrue(test_string.startswith("AWS"))
        self.assertTrue(test_string.endswith("Labs"))
    
    def test_list_operations(self):
        """Test list operations."""
        test_list = ["unit", "integration", "e2e"]
        self.assertEqual(len(test_list), 3)
        self.assertIn("unit", test_list)
        self.assertEqual(test_list[0], "unit")
    
    def test_dict_operations(self):
        """Test dictionary operations."""
        test_dict = {
            "name": "test-lab",
            "category": "cicd",
            "duration": 60
        }
        
        self.assertEqual(test_dict["name"], "test-lab")
        self.assertIn("category", test_dict)
        self.assertEqual(len(test_dict), 3)


if __name__ == '__main__':
    unittest.main()