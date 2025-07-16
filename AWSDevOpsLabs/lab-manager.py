#!/usr/bin/env python3
"""
AWS DevOps Labs Manager
A CLI tool for managing AWS DevOps certification lab exercises.
"""

import argparse
import json
import os
import sys
import yaml
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional

class LabManager:
    def __init__(self):
        self.base_dir = Path(__file__).parent
        self.config_dir = self.base_dir / "config"
        self.sessions_file = self.config_dir / "sessions.json"
        self.labs_config = self.config_dir / "labs.yaml"
        
        # Ensure config directory exists
        self.config_dir.mkdir(exist_ok=True)
        
        # Initialize sessions file if it doesn't exist
        if not self.sessions_file.exists():
            self._save_sessions({})
    
    def _load_sessions(self) -> Dict:
        """Load lab sessions from file."""
        try:
            with open(self.sessions_file, 'r') as f:
                return json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            return {}
    
    def _save_sessions(self, sessions: Dict):
        """Save lab sessions to file."""
        with open(self.sessions_file, 'w') as f:
            json.dump(sessions, f, indent=2, default=str)
    
    def _load_labs_config(self) -> Dict:
        """Load labs configuration."""
        if not self.labs_config.exists():
            return self._generate_default_labs_config()
        
        try:
            with open(self.labs_config, 'r') as f:
                return yaml.safe_load(f)
        except (FileNotFoundError, yaml.YAMLError):
            return self._generate_default_labs_config()
    
    def _generate_default_labs_config(self) -> Dict:
        """Generate default labs configuration."""
        return {
            "labs": {
                "cicd-codepipeline": {
                    "name": "CodePipeline Multi-Stage Pipeline",
                    "description": "Create and manage multi-stage CI/CD pipelines",
                    "category": "cicd",
                    "difficulty": "intermediate",
                    "duration": 60,
                    "path": "01-cicd/codepipeline",
                    "prerequisites": ["AWS CLI", "CodeCommit access"],
                    "estimated_cost": 5.00
                },
                "cicd-codebuild": {
                    "name": "Advanced CodeBuild Projects",
                    "description": "Custom build environments and caching strategies",
                    "category": "cicd", 
                    "difficulty": "intermediate",
                    "duration": 45,
                    "path": "01-cicd/codebuild",
                    "prerequisites": ["AWS CLI", "Docker basics"],
                    "estimated_cost": 3.00
                },
                "cicd-codedeploy": {
                    "name": "CodeDeploy Strategies",
                    "description": "Deployment strategies for EC2, ECS, and Lambda",
                    "category": "cicd",
                    "difficulty": "advanced",
                    "duration": 75,
                    "path": "01-cicd/codedeploy",
                    "prerequisites": ["AWS CLI", "Target environments"],
                    "estimated_cost": 8.00
                },
                "iac-cloudformation": {
                    "name": "Advanced CloudFormation",
                    "description": "Nested stacks and custom resources",
                    "category": "iac",
                    "difficulty": "advanced",
                    "duration": 90,
                    "path": "02-iac/cloudformation",
                    "prerequisites": ["AWS CLI", "CloudFormation basics"],
                    "estimated_cost": 10.00
                },
                "iac-cdk": {
                    "name": "AWS CDK Projects",
                    "description": "Infrastructure as code with CDK",
                    "category": "iac",
                    "difficulty": "intermediate",
                    "duration": 60,
                    "path": "02-iac/cdk",
                    "prerequisites": ["Node.js", "TypeScript/Python"],
                    "estimated_cost": 7.00
                }
            }
        }
    
    def list_labs(self, category: Optional[str] = None):
        """List available labs."""
        config = self._load_labs_config()
        labs = config.get("labs", {})
        
        if category:
            labs = {k: v for k, v in labs.items() if v.get("category") == category}
        
        print("Available Labs:")
        print("=" * 50)
        
        for lab_id, lab_info in labs.items():
            print(f"ID: {lab_id}")
            print(f"Name: {lab_info['name']}")
            print(f"Category: {lab_info['category']}")
            print(f"Difficulty: {lab_info['difficulty']}")
            print(f"Duration: {lab_info['duration']} minutes")
            print(f"Estimated Cost: ${lab_info['estimated_cost']:.2f}")
            print(f"Description: {lab_info['description']}")
            print("-" * 30)
    
    def start_lab(self, lab_id: str):
        """Start a lab session."""
        config = self._load_labs_config()
        labs = config.get("labs", {})
        
        if lab_id not in labs:
            print(f"Error: Lab '{lab_id}' not found.")
            return False
        
        lab_info = labs[lab_id]
        sessions = self._load_sessions()
        
        # Check if lab is already running
        for session_id, session in sessions.items():
            if session["lab_id"] == lab_id and session["status"] == "running":
                print(f"Lab '{lab_id}' is already running (session: {session_id})")
                return False
        
        # Create new session
        session_id = f"{lab_id}-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
        session = {
            "lab_id": lab_id,
            "start_time": datetime.now().isoformat(),
            "status": "running",
            "resources": [],
            "estimated_cost": lab_info["estimated_cost"]
        }
        
        sessions[session_id] = session
        self._save_sessions(sessions)
        
        print(f"Started lab '{lab_info['name']}' (session: {session_id})")
        print(f"Lab guide: {lab_info['path']}/lab-guide.md")
        print(f"Estimated cost: ${lab_info['estimated_cost']:.2f}")
        print("\nRemember to run cleanup when finished!")
        
        return True
    
    def stop_lab(self, session_id: str):
        """Stop a lab session."""
        sessions = self._load_sessions()
        
        if session_id not in sessions:
            print(f"Error: Session '{session_id}' not found.")
            return False
        
        session = sessions[session_id]
        if session["status"] != "running":
            print(f"Session '{session_id}' is not running.")
            return False
        
        session["status"] = "stopped"
        session["end_time"] = datetime.now().isoformat()
        
        sessions[session_id] = session
        self._save_sessions(sessions)
        
        print(f"Stopped session '{session_id}'")
        print("Note: This does not clean up AWS resources. Run cleanup command separately.")
        
        return True
    
    def list_sessions(self):
        """List all lab sessions."""
        sessions = self._load_sessions()
        
        if not sessions:
            print("No lab sessions found.")
            return
        
        print("Lab Sessions:")
        print("=" * 50)
        
        for session_id, session in sessions.items():
            print(f"Session ID: {session_id}")
            print(f"Lab ID: {session['lab_id']}")
            print(f"Status: {session['status']}")
            print(f"Start Time: {session['start_time']}")
            if 'end_time' in session:
                print(f"End Time: {session['end_time']}")
            print(f"Estimated Cost: ${session['estimated_cost']:.2f}")
            print("-" * 30)
    
    def cleanup_session(self, session_id: str):
        """Cleanup resources for a lab session."""
        sessions = self._load_sessions()
        
        if session_id not in sessions:
            print(f"Error: Session '{session_id}' not found.")
            return False
        
        session = sessions[session_id]
        lab_id = session["lab_id"]
        
        print(f"Cleaning up session '{session_id}' for lab '{lab_id}'")
        print("This will run the cleanup script for the lab...")
        
        # Here we would run the actual cleanup script
        # For now, just mark as cleaned up
        session["status"] = "cleaned_up"
        session["cleanup_time"] = datetime.now().isoformat()
        
        sessions[session_id] = session
        self._save_sessions(sessions)
        
        print(f"Session '{session_id}' marked as cleaned up.")
        print("Verify in AWS console that all resources have been removed.")
        
        return True

def main():
    parser = argparse.ArgumentParser(description="AWS DevOps Labs Manager")
    subparsers = parser.add_subparsers(dest="command", help="Available commands")
    
    # List command
    list_parser = subparsers.add_parser("list", help="List available labs")
    list_parser.add_argument("--category", help="Filter by category")
    
    # Start command
    start_parser = subparsers.add_parser("start", help="Start a lab")
    start_parser.add_argument("lab_id", help="Lab ID to start")
    
    # Stop command
    stop_parser = subparsers.add_parser("stop", help="Stop a lab session")
    stop_parser.add_argument("session_id", help="Session ID to stop")
    
    # Sessions command
    subparsers.add_parser("sessions", help="List all sessions")
    
    # Cleanup command
    cleanup_parser = subparsers.add_parser("cleanup", help="Cleanup lab resources")
    cleanup_parser.add_argument("session_id", help="Session ID to cleanup")
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    manager = LabManager()
    
    if args.command == "list":
        manager.list_labs(args.category)
    elif args.command == "start":
        manager.start_lab(args.lab_id)
    elif args.command == "stop":
        manager.stop_lab(args.session_id)
    elif args.command == "sessions":
        manager.list_sessions()
    elif args.command == "cleanup":
        manager.cleanup_session(args.session_id)

if __name__ == "__main__":
    main()