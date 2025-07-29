#!/usr/bin/env python3
"""
AWS DevOps Labs Manager
A CLI tool for managing AWS DevOps certification lab exercises.
"""

import argparse
import json
import os
import re
import subprocess
import sys
import yaml
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import boto3
from botocore.exceptions import ClientError, NoCredentialsError

# Import simple pricing helper
try:
    from scripts.simple_pricing import SimplePricingHelper, get_cost_breakdown, format_pricing_info
    PRICING_AVAILABLE = True
except ImportError as e:
    print(f"Warning: Simple pricing helper not available: {e}")
    PRICING_AVAILABLE = False

class LabManager:
    def __init__(self):
        self.base_dir = Path(__file__).parent
        self.config_dir = self.base_dir / "config"
        self.sessions_file = self.config_dir / "sessions.json"
        self.labs_config = self.config_dir / "labs.yaml"
        self.resource_tags = {"Project": "AWSDevOpsLabs", "ManagedBy": "LabManager"}
        
        # Ensure config directory exists
        self.config_dir.mkdir(exist_ok=True)
        
        # Initialize sessions file if it doesn't exist
        if not self.sessions_file.exists():
            self._save_sessions({})
        
        # Initialize AWS clients
        self._init_aws_clients()
        
        # Initialize pricing analysis components
        self._init_pricing_components()
    
    def _init_aws_clients(self):
        """Initialize AWS clients for resource tracking."""
        try:
            self.session = boto3.Session()
            self.cloudformation = self.session.client('cloudformation')
            self.ec2 = self.session.client('ec2')
            self.iam = self.session.client('iam')
            self.lambda_client = self.session.client('lambda')
            self.s3 = self.session.client('s3')
            self.pricing = self.session.client('pricing', region_name='us-east-1')
            self.sts = self.session.client('sts')
            self.aws_available = True
        except (NoCredentialsError, ClientError) as e:
            print(f"Warning: AWS credentials not configured properly: {e}")
            self.aws_available = False
    
    def _init_pricing_components(self):
        """Initialize simple pricing helper."""
        if PRICING_AVAILABLE:
            try:
                self.pricing_helper = SimplePricingHelper()
                self.pricing_available = True
            except Exception as e:
                print(f"Warning: Could not initialize pricing helper: {e}")
                self.pricing_available = False
        else:
            self.pricing_available = False

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
            return self._discover_labs()
        
        try:
            with open(self.labs_config, 'r') as f:
                config = yaml.safe_load(f)
                
                # Always recalculate estimated costs using improved logic
                for lab_id, lab_info in config.get('labs', {}).items():
                    services = lab_info.get('aws_services', [])
                    duration = lab_info.get('duration', 60)
                    lab_info['estimated_cost'] = self._estimate_lab_cost(services, duration)
                
                return config
        except (FileNotFoundError, yaml.YAMLError):
            return self._discover_labs()
    
    def _discover_labs(self) -> Dict:
        """Discover labs by scanning directory structure and parsing metadata."""
        labs = {}
        
        # Define category mappings
        category_mapping = {
            "01-cicd": "cicd",
            "02-iac": "iac", 
            "03-monitoring": "monitoring",
            "04-security": "security",
            "05-deployment": "deployment",
            "06-integration": "integration"
        }
        
        for category_dir in self.base_dir.glob("*-*"):
            if not category_dir.is_dir():
                continue
                
            category = category_mapping.get(category_dir.name, category_dir.name.split('-', 1)[1])
            
            for lab_dir in category_dir.iterdir():
                if not lab_dir.is_dir():
                    continue
                    
                lab_guide = lab_dir / "lab-guide.md"
                if not lab_guide.exists():
                    continue
                
                lab_id = f"{category}-{lab_dir.name}"
                lab_metadata = self._parse_lab_metadata(lab_guide, category, lab_dir)
                
                if lab_metadata:
                    labs[lab_id] = lab_metadata
        
        config = {"labs": labs}
        
        # Save discovered configuration
        with open(self.labs_config, 'w') as f:
            yaml.dump(config, f, default_flow_style=False, indent=2)
        
        return config

    def _parse_lab_metadata(self, lab_guide_path: Path, category: str, lab_dir: Path) -> Optional[Dict]:
        """Parse metadata from lab guide markdown file."""
        try:
            with open(lab_guide_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            metadata = {
                "category": category,
                "path": str(lab_dir.relative_to(self.base_dir)),
                "prerequisites": [],
                "aws_services": [],
                "estimated_cost": 0.0,
                "difficulty": "intermediate",
                "duration": 60
            }
            
            # Extract title
            title_match = re.search(r'^#\s+(.+)', content, re.MULTILINE)
            if title_match:
                metadata["name"] = title_match.group(1).strip()
            else:
                metadata["name"] = lab_dir.name.replace('-', ' ').title()
            
            # Extract objective/description
            objective_match = re.search(r'##\s+Objective\s*\n(.+?)(?=\n##|\n\n|\Z)', content, re.DOTALL)
            if objective_match:
                metadata["description"] = objective_match.group(1).strip()
            
            # Extract duration
            duration_match = re.search(r'(?:Time to Complete|Duration).*?(\d+)\s*minutes?', content, re.IGNORECASE)
            if duration_match:
                metadata["duration"] = int(duration_match.group(1))
            
            # Extract prerequisites
            prereq_match = re.search(r'##\s+Prerequisites\s*\n(.+?)(?=\n##|\n\n|\Z)', content, re.DOTALL)
            if prereq_match:
                prereq_text = prereq_match.group(1)
                # Extract bullet points
                prereqs = re.findall(r'[-*]\s+(.+)', prereq_text)
                metadata["prerequisites"] = [p.strip() for p in prereqs]
            
            # Extract AWS services mentioned
            aws_services = set()
            service_patterns = [
                r'\b(CodePipeline|CodeBuild|CodeDeploy|CodeCommit)\b',
                r'\b(CloudFormation|CDK)\b',
                r'\b(CloudWatch|X-Ray|Config)\b',
                r'\b(IAM|Secrets Manager|Parameter Store)\b',
                r'\b(EC2|ECS|Lambda|API Gateway|RDS|S3|VPC)\b',
                r'\b(SNS|SQS|EventBridge|Step Functions)\b',
                r'\b(Auto Scaling|Load Balancer|ALB|NLB)\b'
            ]
            
            for pattern in service_patterns:
                matches = re.findall(pattern, content, re.IGNORECASE)
                aws_services.update(matches)
            
            metadata["aws_services"] = sorted(list(aws_services))
            
            # Estimate cost based on services and duration
            metadata["estimated_cost"] = self._estimate_lab_cost(metadata["aws_services"], metadata["duration"])
            
            # Determine difficulty based on multiple factors
            metadata["difficulty"] = self._determine_lab_difficulty(content, metadata["aws_services"], metadata["duration"])
            
            return metadata
            
        except Exception as e:
            print(f"Warning: Could not parse metadata for {lab_guide_path}: {e}")
            return None

    def _estimate_lab_cost(self, aws_services: List[str], duration_minutes: int) -> float:
        """Estimate lab cost based on AWS services and duration."""
        duration_hours = duration_minutes / 60
        
        # Use simple pricing helper if available
        if self.pricing_available:
            try:
                cost_data = get_cost_breakdown(aws_services, duration_hours)
                return cost_data['standard_cost']
            except Exception as e:
                print(f"Warning: Could not get pricing data, using fallback: {str(e)}")
        
        # Simple fallback calculation
        service_costs = {
            'EC2': 0.0104, 'ECS': 0.02, 'Lambda': 0.0001, 'RDS': 0.017,
            'S3': 0.023, 'CloudWatch': 0.30, 'CodeBuild': 0.005,
            'CodePipeline': 1.0, 'API Gateway': 0.0035
        }
        
        total_cost = sum(service_costs.get(service, 0.01) * duration_hours for service in aws_services)
        return round(total_cost + 1.0, 2)  # Add base cost
    
    def _determine_lab_difficulty(self, content: str, aws_services: List[str], duration_minutes: int) -> str:
        """Determine lab difficulty based on multiple factors."""
        difficulty_score = 0
        content_lower = content.lower()
        
        # Content-based difficulty indicators
        advanced_keywords = [
            'advanced', 'complex', 'nested', 'custom', 'multi-tier', 'enterprise',
            'production-grade', 'scalable', 'high-availability', 'disaster recovery',
            'cross-region', 'multi-account', 'service mesh', 'microservices',
            'kubernetes', 'helm', 'terraform modules', 'custom resources'
        ]
        
        intermediate_keywords = [
            'intermediate', 'moderate', 'integration', 'automation', 'pipeline',
            'deployment', 'monitoring', 'logging', 'security', 'networking',
            'load balancer', 'auto scaling', 'database', 'caching'
        ]
        
        beginner_keywords = [
            'basic', 'simple', 'introduction', 'getting started', 'fundamentals',
            'hello world', 'tutorial', 'walkthrough', 'first steps', 'beginner'
        ]
        
        # Score based on keywords
        for keyword in advanced_keywords:
            if keyword in content_lower:
                difficulty_score += 3
        
        for keyword in intermediate_keywords:
            if keyword in content_lower:
                difficulty_score += 2
        
        for keyword in beginner_keywords:
            if keyword in content_lower:
                difficulty_score -= 1
        
        # Service complexity scoring
        complex_services = [
            'ECS', 'EKS', 'Fargate', 'Service Mesh', 'App Mesh', 'API Gateway',
            'Step Functions', 'EventBridge', 'Kinesis', 'EMR', 'Redshift',
            'ElastiCache', 'DocumentDB', 'Neptune', 'Timestream'
        ]
        
        intermediate_services = [
            'RDS', 'DynamoDB', 'SQS', 'SNS', 'CodePipeline', 'CodeBuild',
            'CodeDeploy', 'CloudFormation', 'CDK', 'Systems Manager',
            'Secrets Manager', 'Parameter Store', 'CloudWatch', 'X-Ray'
        ]
        
        # Score based on services used
        for service in aws_services:
            if service in complex_services:
                difficulty_score += 2
            elif service in intermediate_services:
                difficulty_score += 1
        
        # Duration-based scoring
        if duration_minutes > 180:  # > 3 hours
            difficulty_score += 2
        elif duration_minutes > 120:  # > 2 hours
            difficulty_score += 1
        elif duration_minutes < 60:  # < 1 hour
            difficulty_score -= 1
        
        # Number of services (complexity indicator)
        service_count = len(aws_services)
        if service_count > 6:
            difficulty_score += 2
        elif service_count > 3:
            difficulty_score += 1
        
        # Prerequisites complexity (if mentioned)
        if 'prerequisite' in content_lower:
            prereq_section = content_lower.split('prerequisite')[1][:500]  # Look at next 500 chars
            if any(word in prereq_section for word in ['experience', 'knowledge', 'familiar']):
                difficulty_score += 1
        
        # Determine final difficulty
        if difficulty_score >= 8:
            return "advanced"
        elif difficulty_score >= 4:
            return "intermediate"
        else:
            return "beginner"
    
    def list_labs(self, category: Optional[str] = None, detailed: bool = False, show_pricing: bool = False):
        """List available labs with optional detailed information and pricing."""
        config = self._load_labs_config()
        labs = config.get("labs", {})
        
        if category:
            labs = {k: v for k, v in labs.items() if v.get("category") == category}
        
        print("Available Labs:")
        print("=" * 70)
        
        for lab_id, lab_info in labs.items():
            print(f"ID: {lab_id}")
            print(f"Name: {lab_info['name']}")
            print(f"Category: {lab_info['category']}")
            print(f"Difficulty: {lab_info['difficulty']}")
            print(f"Duration: {lab_info['duration']} minutes")
            
            # Show cost information
            estimated_cost = lab_info['estimated_cost']
            print(f"Estimated Cost: ${estimated_cost:.2f}")
            
            # Show simple pricing information if requested
            if show_pricing and self.pricing_available:
                try:
                    duration_hours = lab_info.get('duration', 60) / 60.0
                    services = lab_info.get('aws_services', [])
                    pricing_summary = format_pricing_info(services, duration_hours)
                    print(f"  {pricing_summary}")
                except Exception as e:
                    print(f"  ❌ Pricing info unavailable: {str(e)}")
            elif show_pricing:
                print(f"  💡 Install boto3 for enhanced pricing information")
            
            if detailed:
                print(f"AWS Services: {', '.join(lab_info.get('aws_services', []))}")
                print(f"Prerequisites: {', '.join(lab_info.get('prerequisites', []))}")
                print(f"Path: {lab_info['path']}")
            
            print(f"Description: {lab_info.get('description', 'No description available')}")
            print("-" * 50)

    def show_pricing_analysis(self, lab_id: str):
        """Show simple pricing analysis for a specific lab."""
        if not self.pricing_available:
            print("Simple pricing analysis not available.")
            return
        
        config = self._load_labs_config()
        labs = config.get("labs", {})
        
        if lab_id not in labs:
            print(f"Lab '{lab_id}' not found.")
            return
        
        lab_info = labs[lab_id]
        duration_hours = lab_info.get('duration', 60) / 60.0
        services = lab_info.get('aws_services', [])
        
        print(f"\nSimple Pricing Analysis for: {lab_info['name']}")
        print("=" * 60)
        print(format_pricing_info(services, duration_hours))
    
    def show_free_tier_status(self):
        """Show basic Free Tier information."""
        if not self.pricing_available:
            print("Free Tier information not available.")
            return
        
        helper = self.pricing_helper
        status = helper.get_free_tier_status()
        
        print("\nFree Tier Limits (Monthly)")
        print("=" * 30)
        for service, limit in status['limits'].items():
            print(f"{service}: {limit}")
        
        print(f"\n{status['note']}")
        print(f"💡 {status['recommendation']}")
    
    def generate_cost_report(self, output_file: Optional[str] = None):
        """Generate simple cost report for all labs."""
        if not self.pricing_available:
            print("Cost reporting not available.")
            return
        
        config = self._load_labs_config()
        labs = config.get("labs", {})
        
        total_standard_cost = 0.0
        total_free_tier_cost = 0.0
        
        print("\nSimple Cost Report for All Labs")
        print("=" * 50)
        
        for lab_id, lab_info in labs.items():
            duration_hours = lab_info.get('duration', 60) / 60.0
            services = lab_info.get('aws_services', [])
            
            cost_data = get_cost_breakdown(services, duration_hours)
            total_standard_cost += cost_data['standard_cost']
            total_free_tier_cost += cost_data['free_tier_cost']
            
            print(f"{lab_id}: ${cost_data['standard_cost']:.4f} (Free Tier: ${cost_data['free_tier_cost']:.4f})")
        
        print("-" * 50)
        print(f"Total Standard Cost: ${total_standard_cost:.4f}")
        print(f"Total Free Tier Cost: ${total_free_tier_cost:.4f}")
        print(f"Total Potential Savings: ${total_standard_cost - total_free_tier_cost:.4f}")
        
        if output_file:
            report_data = {
                'total_standard_cost': total_standard_cost,
                'total_free_tier_cost': total_free_tier_cost,
                'total_savings': total_standard_cost - total_free_tier_cost,
                'generated_at': datetime.now().isoformat()
            }
            with open(output_file, 'w') as f:
                json.dump(report_data, f, indent=2)
            print(f"Report saved to: {output_file}")
    
    def discover_labs(self):
        """Force rediscovery of labs and update configuration."""
        print("Discovering labs...")
        config = self._discover_labs()
        labs_count = len(config.get("labs", {}))
        print(f"Discovered {labs_count} labs and updated configuration.")
        return config
    
    def update_lab_costs(self):
        """Update cost estimates in the existing labs.yaml file."""
        if not self.labs_config.exists():
            print("No labs.yaml file found. Run 'discover' first.")
            return
        
        try:
            with open(self.labs_config, 'r') as f:
                config = yaml.safe_load(f)
            
            updated_count = 0
            for lab_id, lab_info in config.get('labs', {}).items():
                services = lab_info.get('aws_services', [])
                duration = lab_info.get('duration', 60)
                old_cost = lab_info.get('estimated_cost', 0)
                new_cost = self._estimate_lab_cost(services, duration)
                
                if abs(old_cost - new_cost) > 0.01:  # Only update if significantly different
                    lab_info['estimated_cost'] = new_cost
                    updated_count += 1
                    print(f"Updated {lab_id}: ${old_cost:.2f} → ${new_cost:.2f}")
            
            if updated_count > 0:
                with open(self.labs_config, 'w') as f:
                    yaml.dump(config, f, default_flow_style=False, indent=2)
                print(f"Updated {updated_count} lab cost estimates in labs.yaml")
            else:
                print("No cost updates needed.")
                
        except Exception as e:
            print(f"Error updating lab costs: {str(e)}")

    def get_resource_inventory(self, session_id: Optional[str] = None) -> Dict:
        """Get inventory of AWS resources, optionally filtered by session."""
        if not self.aws_available:
            print("AWS credentials not available for resource inventory.")
            return {}
        
        inventory = {
            "cloudformation_stacks": [],
            "ec2_instances": [],
            "lambda_functions": [],
            "s3_buckets": [],
            "iam_roles": [],
            "total_estimated_cost": 0.0
        }
        
        try:
            # Get CloudFormation stacks
            stacks = self.cloudformation.list_stacks(
                StackStatusFilter=['CREATE_COMPLETE', 'UPDATE_COMPLETE', 'ROLLBACK_COMPLETE']
            )
            
            for stack in stacks['StackSummaries']:
                stack_tags = self._get_stack_tags(stack['StackName'])
                if self._is_lab_resource(stack_tags, session_id):
                    inventory["cloudformation_stacks"].append({
                        "name": stack['StackName'],
                        "status": stack['StackStatus'],
                        "creation_time": stack['CreationTime'].isoformat(),
                        "tags": stack_tags
                    })
            
            # Get EC2 instances
            instances = self.ec2.describe_instances()
            for reservation in instances['Reservations']:
                for instance in reservation['Instances']:
                    if instance['State']['Name'] != 'terminated':
                        instance_tags = {tag['Key']: tag['Value'] for tag in instance.get('Tags', [])}
                        if self._is_lab_resource(instance_tags, session_id):
                            inventory["ec2_instances"].append({
                                "instance_id": instance['InstanceId'],
                                "instance_type": instance['InstanceType'],
                                "state": instance['State']['Name'],
                                "launch_time": instance['LaunchTime'].isoformat(),
                                "tags": instance_tags
                            })
            
            # Get Lambda functions
            functions = self.lambda_client.list_functions()
            for function in functions['Functions']:
                function_tags = self.lambda_client.list_tags(Resource=function['FunctionArn'])
                if self._is_lab_resource(function_tags.get('Tags', {}), session_id):
                    inventory["lambda_functions"].append({
                        "name": function['FunctionName'],
                        "runtime": function['Runtime'],
                        "last_modified": function['LastModified'],
                        "tags": function_tags.get('Tags', {})
                    })
            
            # Estimate costs
            inventory["total_estimated_cost"] = self._calculate_resource_costs(inventory)
            
        except ClientError as e:
            print(f"Error retrieving resource inventory: {e}")
        
        return inventory

    def _get_stack_tags(self, stack_name: str) -> Dict:
        """Get tags for a CloudFormation stack."""
        try:
            response = self.cloudformation.describe_stacks(StackName=stack_name)
            stack = response['Stacks'][0]
            return {tag['Key']: tag['Value'] for tag in stack.get('Tags', [])}
        except ClientError:
            return {}

    def _is_lab_resource(self, tags: Dict, session_id: Optional[str] = None) -> bool:
        """Check if resource belongs to lab management system."""
        if not tags.get('Project') == 'AWSDevOpsLabs':
            return False
        
        if session_id and tags.get('SessionId') != session_id:
            return False
        
        return True

    def _calculate_resource_costs(self, inventory: Dict) -> float:
        """Calculate estimated costs for resources in inventory."""
        total_cost = 0.0
        
        # EC2 instance costs (per hour)
        instance_costs = {
            't2.micro': 0.0116, 't2.small': 0.023, 't2.medium': 0.046,
            't3.micro': 0.0104, 't3.small': 0.021, 't3.medium': 0.042,
            'm5.large': 0.096, 'm5.xlarge': 0.192
        }
        
        for instance in inventory["ec2_instances"]:
            if instance["state"] == "running":
                instance_type = instance["instance_type"]
                hourly_cost = instance_costs.get(instance_type, 0.05)  # Default cost
                total_cost += hourly_cost
        
        # Lambda costs are minimal for labs
        total_cost += len(inventory["lambda_functions"]) * 0.01
        
        # CloudFormation stacks don't have direct costs
        # S3 and other services have minimal costs for lab usage
        total_cost += 0.50  # Base infrastructure cost
        
        return round(total_cost, 2)
    
    def start_lab(self, lab_id: str):
        """Start a lab session with resource tracking."""
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
            "resources": {
                "cloudformation_stacks": [],
                "ec2_instances": [],
                "lambda_functions": [],
                "s3_buckets": [],
                "iam_roles": []
            },
            "estimated_cost": lab_info["estimated_cost"],
            "actual_cost": 0.0,
            "resource_tags": {**self.resource_tags, "SessionId": session_id, "LabId": lab_id}
        }
        
        sessions[session_id] = session
        self._save_sessions(sessions)
        
        print(f"Started lab '{lab_info['name']}' (session: {session_id})")
        print(f"Lab guide: {lab_info['path']}/lab-guide.md")
        print(f"Estimated cost: ${lab_info['estimated_cost']:.2f}")
        print(f"Resource tags: {session['resource_tags']}")
        print("\nIMPORTANT: Tag all AWS resources with the provided tags for proper tracking!")
        print("Remember to run cleanup when finished!")
        
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
    
    def list_sessions(self, status_filter: Optional[str] = None):
        """List all lab sessions with optional status filtering."""
        sessions = self._load_sessions()
        
        if status_filter:
            sessions = {k: v for k, v in sessions.items() if v.get("status") == status_filter}
        
        if not sessions:
            filter_msg = f" with status '{status_filter}'" if status_filter else ""
            print(f"No lab sessions found{filter_msg}.")
            return
        
        print("Lab Sessions:")
        print("=" * 70)
        
        for session_id, session in sessions.items():
            print(f"Session ID: {session_id}")
            print(f"Lab ID: {session['lab_id']}")
            print(f"Status: {session['status']}")
            print(f"Start Time: {session['start_time']}")
            
            if 'end_time' in session:
                print(f"End Time: {session['end_time']}")
            
            if 'cleanup_time' in session:
                print(f"Cleanup Time: {session['cleanup_time']}")
            
            print(f"Estimated Cost: ${session['estimated_cost']:.2f}")
            
            if 'actual_cost' in session:
                print(f"Actual Cost: ${session['actual_cost']:.2f}")
            
            # Show progress information
            if 'progress' in session:
                progress = session['progress']
                completed_steps = len([step for step in progress.get('steps', []) if step.get('completed')])
                total_steps = len(progress.get('steps', []))
                print(f"Progress: {completed_steps}/{total_steps} steps completed")
                
                if progress.get('current_step'):
                    print(f"Current Step: {progress['current_step']}")
            
            # Show resource count
            if 'resources' in session and isinstance(session['resources'], dict):
                total_resources = sum(len(resources) for resources in session['resources'].values())
                print(f"Resources: {total_resources} tracked")
            
            print("-" * 50)
    
    def cleanup_session(self, session_id: str, verify: bool = True):
        """Cleanup resources for a lab session with verification."""
        sessions = self._load_sessions()
        
        if session_id not in sessions:
            print(f"Error: Session '{session_id}' not found.")
            return False
        
        session = sessions[session_id]
        lab_id = session["lab_id"]
        
        print(f"Cleaning up session '{session_id}' for lab '{lab_id}'")
        
        # Get current resource inventory before cleanup
        pre_cleanup_inventory = self.get_resource_inventory(session_id)
        
        if pre_cleanup_inventory:
            print(f"Found {len(pre_cleanup_inventory['cloudformation_stacks'])} stacks, "
                  f"{len(pre_cleanup_inventory['ec2_instances'])} instances, "
                  f"{len(pre_cleanup_inventory['lambda_functions'])} functions to clean up")
        
        # Run cleanup script if it exists
        config = self._load_labs_config()
        lab_info = config.get("labs", {}).get(lab_id, {})
        lab_path = self.base_dir / lab_info.get("path", "")
        cleanup_script = lab_path / "scripts" / "cleanup.sh"
        
        cleanup_success = True
        if cleanup_script.exists():
            print(f"Running cleanup script: {cleanup_script}")
            try:
                result = subprocess.run(
                    [str(cleanup_script), session_id],
                    capture_output=True,
                    text=True,
                    timeout=300  # 5 minute timeout
                )
                if result.returncode != 0:
                    print(f"Cleanup script failed: {result.stderr}")
                    cleanup_success = False
                else:
                    print("Cleanup script completed successfully")
            except subprocess.TimeoutExpired:
                print("Cleanup script timed out")
                cleanup_success = False
            except Exception as e:
                print(f"Error running cleanup script: {e}")
                cleanup_success = False
        
        # Verify cleanup if requested
        if verify and self.aws_available:
            print("Verifying resource cleanup...")
            post_cleanup_inventory = self.get_resource_inventory(session_id)
            
            remaining_resources = (
                len(post_cleanup_inventory['cloudformation_stacks']) +
                len(post_cleanup_inventory['ec2_instances']) +
                len(post_cleanup_inventory['lambda_functions'])
            )
            
            if remaining_resources > 0:
                print(f"WARNING: {remaining_resources} resources still exist after cleanup!")
                self._report_orphaned_resources(post_cleanup_inventory)
                cleanup_success = False
            else:
                print("✓ All tracked resources have been cleaned up successfully")
        
        # Update session status
        session["status"] = "cleaned_up" if cleanup_success else "cleanup_failed"
        session["cleanup_time"] = datetime.now().isoformat()
        session["cleanup_verified"] = verify and cleanup_success
        
        sessions[session_id] = session
        self._save_sessions(sessions)
        
        if cleanup_success:
            print(f"✓ Session '{session_id}' cleaned up successfully")
        else:
            print(f"⚠ Session '{session_id}' cleanup completed with issues")
            print("Please check AWS console and manually remove any remaining resources")
        
        return cleanup_success

    def _report_orphaned_resources(self, inventory: Dict):
        """Report orphaned resources that weren't cleaned up."""
        print("\nOrphaned Resources Found:")
        print("=" * 40)
        
        for stack in inventory['cloudformation_stacks']:
            print(f"CloudFormation Stack: {stack['name']} (Status: {stack['status']})")
        
        for instance in inventory['ec2_instances']:
            print(f"EC2 Instance: {instance['instance_id']} (Type: {instance['instance_type']}, State: {instance['state']})")
        
        for function in inventory['lambda_functions']:
            print(f"Lambda Function: {function['name']} (Runtime: {function['runtime']})")
        
        print("\nTo manually clean up these resources:")
        print("1. Delete CloudFormation stacks from AWS Console")
        print("2. Terminate EC2 instances")
        print("3. Delete Lambda functions")
        print("4. Check for any associated IAM roles, S3 buckets, etc.")

    def detect_orphaned_resources(self) -> Dict:
        """Detect orphaned resources across all sessions."""
        if not self.aws_available:
            print("AWS credentials not available for orphaned resource detection.")
            return {}
        
        print("Scanning for orphaned lab resources...")
        
        # Get all lab resources
        all_resources = self.get_resource_inventory()
        sessions = self._load_sessions()
        
        # Find resources not associated with active sessions
        active_session_ids = {sid for sid, session in sessions.items() 
                            if session.get("status") in ["running", "stopped"]}
        
        orphaned = {
            "cloudformation_stacks": [],
            "ec2_instances": [],
            "lambda_functions": [],
            "estimated_cost": 0.0
        }
        
        for stack in all_resources['cloudformation_stacks']:
            session_id = stack['tags'].get('SessionId')
            if session_id not in active_session_ids:
                orphaned['cloudformation_stacks'].append(stack)
        
        for instance in all_resources['ec2_instances']:
            session_id = instance['tags'].get('SessionId')
            if session_id not in active_session_ids:
                orphaned['ec2_instances'].append(instance)
        
        for function in all_resources['lambda_functions']:
            session_id = function['tags'].get('SessionId')
            if session_id not in active_session_ids:
                orphaned['lambda_functions'].append(function)
        
        orphaned['estimated_cost'] = self._calculate_resource_costs(orphaned)
        
        if any(orphaned[key] for key in ['cloudformation_stacks', 'ec2_instances', 'lambda_functions']):
            print(f"Found orphaned resources with estimated cost: ${orphaned['estimated_cost']:.2f}/hour")
            self._report_orphaned_resources(orphaned)
        else:
            print("✓ No orphaned resources found")
        
        return orphaned

    def update_session_progress(self, session_id: str, step_name: str, completed: bool = True, 
                              notes: Optional[str] = None) -> bool:
        """Update progress for a lab session step."""
        sessions = self._load_sessions()
        
        if session_id not in sessions:
            print(f"Error: Session '{session_id}' not found.")
            return False
        
        session = sessions[session_id]
        
        # Initialize progress structure if it doesn't exist
        if 'progress' not in session:
            session['progress'] = {
                'steps': [],
                'current_step': None,
                'completion_percentage': 0.0,
                'last_updated': datetime.now().isoformat()
            }
        
        progress = session['progress']
        
        # Find or create the step
        step_found = False
        for step in progress['steps']:
            if step['name'] == step_name:
                step['completed'] = completed
                step['completed_at'] = datetime.now().isoformat() if completed else None
                if notes:
                    step['notes'] = notes
                step_found = True
                break
        
        if not step_found:
            new_step = {
                'name': step_name,
                'completed': completed,
                'started_at': datetime.now().isoformat(),
                'completed_at': datetime.now().isoformat() if completed else None
            }
            if notes:
                new_step['notes'] = notes
            progress['steps'].append(new_step)
        
        # Update current step and completion percentage
        if completed:
            # Find next incomplete step
            next_step = None
            for step in progress['steps']:
                if not step['completed']:
                    next_step = step['name']
                    break
            progress['current_step'] = next_step
        else:
            progress['current_step'] = step_name
        
        # Calculate completion percentage
        completed_steps = len([step for step in progress['steps'] if step['completed']])
        total_steps = len(progress['steps'])
        progress['completion_percentage'] = (completed_steps / total_steps * 100) if total_steps > 0 else 0.0
        progress['last_updated'] = datetime.now().isoformat()
        
        sessions[session_id] = session
        self._save_sessions(sessions)
        
        print(f"✓ Updated progress for session '{session_id}': {step_name} ({'completed' if completed else 'in progress'})")
        print(f"Overall progress: {progress['completion_percentage']:.1f}% ({completed_steps}/{total_steps} steps)")
        
        return True

    def get_session_progress(self, session_id: str) -> Optional[Dict]:
        """Get detailed progress information for a session."""
        sessions = self._load_sessions()
        
        if session_id not in sessions:
            print(f"Error: Session '{session_id}' not found.")
            return None
        
        session = sessions[session_id]
        progress = session.get('progress', {})
        
        if not progress:
            return {
                'session_id': session_id,
                'completion_percentage': 0.0,
                'steps': [],
                'current_step': None
            }
        
        return {
            'session_id': session_id,
            'completion_percentage': progress.get('completion_percentage', 0.0),
            'steps': progress.get('steps', []),
            'current_step': progress.get('current_step'),
            'last_updated': progress.get('last_updated')
        }

    def validate_lab_checkpoint(self, session_id: str, checkpoint_name: str) -> Dict:
        """Validate a lab checkpoint by checking expected resources and configurations."""
        sessions = self._load_sessions()
        
        if session_id not in sessions:
            return {'valid': False, 'error': f"Session '{session_id}' not found"}
        
        session = sessions[session_id]
        lab_id = session['lab_id']
        
        print(f"Validating checkpoint '{checkpoint_name}' for session '{session_id}'...")
        
        validation_result = {
            'session_id': session_id,
            'checkpoint_name': checkpoint_name,
            'valid': True,
            'checks': [],
            'warnings': [],
            'errors': []
        }
        
        # Get current resource inventory
        if self.aws_available:
            inventory = self.get_resource_inventory(session_id)
            
            # Define checkpoint validations based on lab type
            checkpoint_validations = self._get_checkpoint_validations(lab_id, checkpoint_name)
            
            for validation in checkpoint_validations:
                check_result = self._perform_validation_check(validation, inventory, session)
                validation_result['checks'].append(check_result)
                
                if check_result['status'] == 'failed':
                    validation_result['valid'] = False
                    validation_result['errors'].append(check_result['message'])
                elif check_result['status'] == 'warning':
                    validation_result['warnings'].append(check_result['message'])
        else:
            validation_result['warnings'].append("AWS credentials not available for resource validation")
        
        # Update session progress if validation passed
        if validation_result['valid']:
            self.update_session_progress(session_id, checkpoint_name, True, 
                                       f"Checkpoint validation passed at {datetime.now().isoformat()}")
        
        return validation_result

    def _get_checkpoint_validations(self, lab_id: str, checkpoint_name: str) -> List[Dict]:
        """Get validation rules for a specific checkpoint."""
        # Define common validation patterns
        validations = []
        
        if 'cloudformation' in lab_id.lower():
            if checkpoint_name == 'stack_deployed':
                validations.append({
                    'type': 'cloudformation_stack',
                    'description': 'CloudFormation stack should be deployed',
                    'expected_count': 1,
                    'status_filter': ['CREATE_COMPLETE', 'UPDATE_COMPLETE']
                })
            elif checkpoint_name == 'nested_stacks':
                validations.append({
                    'type': 'cloudformation_stack',
                    'description': 'Multiple nested stacks should exist',
                    'expected_count': 2,
                    'status_filter': ['CREATE_COMPLETE', 'UPDATE_COMPLETE']
                })
        
        elif 'ec2' in lab_id.lower() or 'deployment' in lab_id.lower():
            if checkpoint_name == 'instances_running':
                validations.append({
                    'type': 'ec2_instance',
                    'description': 'EC2 instances should be running',
                    'expected_count': 1,
                    'state_filter': ['running']
                })
        
        elif 'lambda' in lab_id.lower() or 'serverless' in lab_id.lower():
            if checkpoint_name == 'functions_deployed':
                validations.append({
                    'type': 'lambda_function',
                    'description': 'Lambda functions should be deployed',
                    'expected_count': 1
                })
        
        # Add default validation if no specific rules found
        if not validations:
            validations.append({
                'type': 'resource_count',
                'description': 'At least one resource should be deployed',
                'expected_count': 1
            })
        
        return validations

    def _perform_validation_check(self, validation: Dict, inventory: Dict, session: Dict) -> Dict:
        """Perform a single validation check."""
        check_result = {
            'type': validation['type'],
            'description': validation['description'],
            'status': 'passed',
            'message': '',
            'details': {}
        }
        
        try:
            if validation['type'] == 'cloudformation_stack':
                stacks = inventory.get('cloudformation_stacks', [])
                expected_count = validation.get('expected_count', 1)
                status_filter = validation.get('status_filter', [])
                
                if status_filter:
                    filtered_stacks = [s for s in stacks if s.get('status') in status_filter]
                else:
                    filtered_stacks = stacks
                
                if len(filtered_stacks) >= expected_count:
                    check_result['message'] = f"✓ Found {len(filtered_stacks)} CloudFormation stack(s)"
                    check_result['details']['stacks'] = [s['name'] for s in filtered_stacks]
                else:
                    check_result['status'] = 'failed'
                    check_result['message'] = f"✗ Expected {expected_count} stack(s), found {len(filtered_stacks)}"
            
            elif validation['type'] == 'ec2_instance':
                instances = inventory.get('ec2_instances', [])
                expected_count = validation.get('expected_count', 1)
                state_filter = validation.get('state_filter', [])
                
                if state_filter:
                    filtered_instances = [i for i in instances if i.get('state') in state_filter]
                else:
                    filtered_instances = instances
                
                if len(filtered_instances) >= expected_count:
                    check_result['message'] = f"✓ Found {len(filtered_instances)} EC2 instance(s)"
                    check_result['details']['instances'] = [i['instance_id'] for i in filtered_instances]
                else:
                    check_result['status'] = 'failed'
                    check_result['message'] = f"✗ Expected {expected_count} instance(s), found {len(filtered_instances)}"
            
            elif validation['type'] == 'lambda_function':
                functions = inventory.get('lambda_functions', [])
                expected_count = validation.get('expected_count', 1)
                
                if len(functions) >= expected_count:
                    check_result['message'] = f"✓ Found {len(functions)} Lambda function(s)"
                    check_result['details']['functions'] = [f['name'] for f in functions]
                else:
                    check_result['status'] = 'failed'
                    check_result['message'] = f"✗ Expected {expected_count} function(s), found {len(functions)}"
            
            elif validation['type'] == 'resource_count':
                total_resources = (
                    len(inventory.get('cloudformation_stacks', [])) +
                    len(inventory.get('ec2_instances', [])) +
                    len(inventory.get('lambda_functions', []))
                )
                expected_count = validation.get('expected_count', 1)
                
                if total_resources >= expected_count:
                    check_result['message'] = f"✓ Found {total_resources} total resource(s)"
                else:
                    check_result['status'] = 'failed'
                    check_result['message'] = f"✗ Expected {expected_count} resource(s), found {total_resources}"
        
        except Exception as e:
            check_result['status'] = 'failed'
            check_result['message'] = f"✗ Validation error: {str(e)}"
        
        return check_result

    def verify_lab_completion(self, session_id: str) -> Dict:
        """Verify that a lab has been completed successfully."""
        sessions = self._load_sessions()
        
        if session_id not in sessions:
            return {'completed': False, 'error': f"Session '{session_id}' not found"}
        
        session = sessions[session_id]
        lab_id = session['lab_id']
        
        print(f"Verifying completion for lab '{lab_id}' (session: {session_id})...")
        
        completion_result = {
            'session_id': session_id,
            'lab_id': lab_id,
            'completed': False,
            'completion_percentage': 0.0,
            'requirements_met': [],
            'requirements_missing': [],
            'certification_progress': {}
        }
        
        # Check progress completion
        progress = session.get('progress', {})
        if progress:
            completion_percentage = progress.get('completion_percentage', 0.0)
            completion_result['completion_percentage'] = completion_percentage
            
            if completion_percentage >= 100.0:
                completion_result['completed'] = True
                completion_result['requirements_met'].append("All lab steps completed")
            else:
                completion_result['requirements_missing'].append(f"Lab progress: {completion_percentage:.1f}% (need 100%)")
        
        # Verify final checkpoint
        final_validation = self.validate_lab_checkpoint(session_id, 'lab_complete')
        if final_validation['valid']:
            completion_result['requirements_met'].append("Final checkpoint validation passed")
        else:
            completion_result['requirements_missing'].extend(final_validation['errors'])
        
        # Check resource cleanup status (for completion verification)
        if session.get('status') == 'cleaned_up' and session.get('cleanup_verified'):
            completion_result['requirements_met'].append("Resources properly cleaned up")
        elif session.get('status') == 'running':
            completion_result['requirements_missing'].append("Lab still running - cleanup required for completion")
        
        # Calculate certification progress
        config = self._load_labs_config()
        lab_info = config.get('labs', {}).get(lab_id, {})
        category = lab_info.get('category', 'unknown')
        
        completion_result['certification_progress'] = {
            'category': category,
            'difficulty': lab_info.get('difficulty', 'unknown'),
            'estimated_cost': lab_info.get('estimated_cost', 0.0),
            'actual_cost': session.get('actual_cost', 0.0)
        }
        
        # Update session if completed
        if completion_result['completed'] and session.get('status') != 'completed':
            session['status'] = 'completed'
            session['completion_time'] = datetime.now().isoformat()
            sessions[session_id] = session
            self._save_sessions(sessions)
        
        return completion_result

    def get_certification_progress(self) -> Dict:
        """Get overall certification progress across all completed labs."""
        sessions = self._load_sessions()
        config = self._load_labs_config()
        
        progress = {
            'total_labs': len(config.get('labs', {})),
            'completed_labs': 0,
            'categories': {},
            'total_cost': 0.0,
            'completion_percentage': 0.0
        }
        
        # Initialize categories
        for lab_id, lab_info in config.get('labs', {}).items():
            category = lab_info.get('category', 'unknown')
            if category not in progress['categories']:
                progress['categories'][category] = {
                    'total': 0,
                    'completed': 0,
                    'labs': []
                }
            progress['categories'][category]['total'] += 1
        
        # Count completed labs
        for session_id, session in sessions.items():
            if session.get('status') == 'completed':
                progress['completed_labs'] += 1
                progress['total_cost'] += session.get('actual_cost', session.get('estimated_cost', 0.0))
                
                lab_id = session['lab_id']
                lab_info = config.get('labs', {}).get(lab_id, {})
                category = lab_info.get('category', 'unknown')
                
                if category in progress['categories']:
                    progress['categories'][category]['completed'] += 1
                    progress['categories'][category]['labs'].append({
                        'lab_id': lab_id,
                        'session_id': session_id,
                        'completion_time': session.get('completion_time'),
                        'cost': session.get('actual_cost', session.get('estimated_cost', 0.0))
                    })
        
        # Calculate completion percentage
        if progress['total_labs'] > 0:
            progress['completion_percentage'] = (progress['completed_labs'] / progress['total_labs']) * 100
        
        return progress

def main():
    parser = argparse.ArgumentParser(description="AWS DevOps Labs Manager")
    subparsers = parser.add_subparsers(dest="command", help="Available commands")
    
    # List command
    list_parser = subparsers.add_parser("list", help="List available labs")
    list_parser.add_argument("--category", help="Filter by category")
    list_parser.add_argument("--detailed", action="store_true", help="Show detailed information")
    list_parser.add_argument("--pricing", action="store_true", help="Show pricing information")
    
    # Discover command
    subparsers.add_parser("discover", help="Rediscover labs and update configuration")
    
    # Update costs command
    subparsers.add_parser("update-costs", help="Update cost estimates in labs.yaml")
    
    # Start command
    start_parser = subparsers.add_parser("start", help="Start a lab")
    start_parser.add_argument("lab_id", help="Lab ID to start")
    
    # Stop command
    stop_parser = subparsers.add_parser("stop", help="Stop a lab session")
    stop_parser.add_argument("session_id", help="Session ID to stop")
    
    # Sessions command
    sessions_parser = subparsers.add_parser("sessions", help="List all sessions")
    sessions_parser.add_argument("--status", help="Filter by status (running, stopped, completed, cleaned_up)")
    
    # Resources command
    resources_parser = subparsers.add_parser("resources", help="Show resource inventory")
    resources_parser.add_argument("--session", help="Filter by session ID")
    
    # Cleanup command
    cleanup_parser = subparsers.add_parser("cleanup", help="Cleanup lab resources")
    cleanup_parser.add_argument("session_id", help="Session ID to cleanup")
    cleanup_parser.add_argument("--no-verify", action="store_true", help="Skip cleanup verification")
    
    # Orphaned command
    subparsers.add_parser("orphaned", help="Detect orphaned resources")
    
    # Progress command
    progress_parser = subparsers.add_parser("progress", help="Manage session progress")
    progress_subparsers = progress_parser.add_subparsers(dest="progress_command")
    
    # Progress update
    update_parser = progress_subparsers.add_parser("update", help="Update step progress")
    update_parser.add_argument("session_id", help="Session ID")
    update_parser.add_argument("step_name", help="Step name")
    update_parser.add_argument("--completed", action="store_true", help="Mark step as completed")
    update_parser.add_argument("--notes", help="Optional notes")
    
    # Progress show
    show_parser = progress_subparsers.add_parser("show", help="Show session progress")
    show_parser.add_argument("session_id", help="Session ID")
    
    # Checkpoint validation
    checkpoint_parser = subparsers.add_parser("checkpoint", help="Validate lab checkpoint")
    checkpoint_parser.add_argument("session_id", help="Session ID")
    checkpoint_parser.add_argument("checkpoint_name", help="Checkpoint name")
    
    # Completion verification
    complete_parser = subparsers.add_parser("complete", help="Verify lab completion")
    complete_parser.add_argument("session_id", help="Session ID")
    
    # Certification progress
    subparsers.add_parser("cert-progress", help="Show certification progress")
    
    # Simple pricing commands
    pricing_parser = subparsers.add_parser("pricing", help="Simple pricing analysis for a lab")
    pricing_parser.add_argument("lab_id", help="Lab ID to analyze")
    
    # Free Tier info
    subparsers.add_parser("free-tier", help="Show Free Tier information")
    
    # Simple cost report
    cost_report_parser = subparsers.add_parser("cost-report", help="Generate simple cost report")
    cost_report_parser.add_argument("--output", help="Output file path")
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    manager = LabManager()
    
    if args.command == "list":
        manager.list_labs(args.category, args.detailed, getattr(args, 'pricing', False))
    elif args.command == "discover":
        manager.discover_labs()
    elif args.command == "update-costs":
        manager.update_lab_costs()
    elif args.command == "start":
        manager.start_lab(args.lab_id)
    elif args.command == "stop":
        manager.stop_lab(args.session_id)
    elif args.command == "sessions":
        manager.list_sessions(args.status)
    elif args.command == "resources":
        inventory = manager.get_resource_inventory(args.session)
        if inventory:
            print(f"Resource Inventory:")
            print(f"CloudFormation Stacks: {len(inventory['cloudformation_stacks'])}")
            print(f"EC2 Instances: {len(inventory['ec2_instances'])}")
            print(f"Lambda Functions: {len(inventory['lambda_functions'])}")
            print(f"Estimated Hourly Cost: ${inventory['total_estimated_cost']:.2f}")
        else:
            print("No resources found or AWS credentials not available")
    elif args.command == "cleanup":
        manager.cleanup_session(args.session_id, not args.no_verify)
    elif args.command == "orphaned":
        manager.detect_orphaned_resources()
    elif args.command == "progress":
        if args.progress_command == "update":
            manager.update_session_progress(args.session_id, args.step_name, args.completed, args.notes)
        elif args.progress_command == "show":
            progress = manager.get_session_progress(args.session_id)
            if progress:
                print(f"Session Progress: {args.session_id}")
                print(f"Completion: {progress['completion_percentage']:.1f}%")
                print(f"Current Step: {progress.get('current_step', 'None')}")
                print(f"Last Updated: {progress.get('last_updated', 'Never')}")
                print("\nSteps:")
                for step in progress['steps']:
                    status = "✓" if step['completed'] else "○"
                    print(f"  {status} {step['name']}")
                    if step.get('notes'):
                        print(f"    Notes: {step['notes']}")
        else:
            print("Usage: progress {update|show}")
    elif args.command == "checkpoint":
        result = manager.validate_lab_checkpoint(args.session_id, args.checkpoint_name)
        print(f"Checkpoint Validation: {args.checkpoint_name}")
        print(f"Valid: {'✓' if result['valid'] else '✗'}")
        
        for check in result['checks']:
            status_symbol = "✓" if check['status'] == 'passed' else "⚠" if check['status'] == 'warning' else "✗"
            print(f"  {status_symbol} {check['message']}")
        
        if result['warnings']:
            print("\nWarnings:")
            for warning in result['warnings']:
                print(f"  ⚠ {warning}")
        
        if result['errors']:
            print("\nErrors:")
            for error in result['errors']:
                print(f"  ✗ {error}")
    elif args.command == "complete":
        result = manager.verify_lab_completion(args.session_id)
        print(f"Lab Completion Verification: {args.session_id}")
        print(f"Completed: {'✓' if result['completed'] else '✗'}")
        print(f"Progress: {result['completion_percentage']:.1f}%")
        
        if result['requirements_met']:
            print("\nRequirements Met:")
            for req in result['requirements_met']:
                print(f"  ✓ {req}")
        
        if result['requirements_missing']:
            print("\nRequirements Missing:")
            for req in result['requirements_missing']:
                print(f"  ✗ {req}")
        
        cert_progress = result['certification_progress']
        print(f"\nCertification Progress:")
        print(f"  Category: {cert_progress['category']}")
        print(f"  Difficulty: {cert_progress['difficulty']}")
        print(f"  Estimated Cost: ${cert_progress['estimated_cost']:.2f}")
        print(f"  Actual Cost: ${cert_progress['actual_cost']:.2f}")
    elif args.command == "pricing":
        manager.show_pricing_analysis(args.lab_id)
    elif args.command == "free-tier":
        manager.show_free_tier_status()
    elif args.command == "cost-report":
        manager.generate_cost_report(args.output)
    elif args.command == "cert-progress":
        progress = manager.get_certification_progress()
        print("AWS DevOps Certification Progress")
        print("=" * 40)
        print(f"Overall Progress: {progress['completion_percentage']:.1f}%")
        print(f"Completed Labs: {progress['completed_labs']}/{progress['total_labs']}")
        print(f"Total Cost: ${progress['total_cost']:.2f}")
        
        print("\nProgress by Category:")
        for category, cat_progress in progress['categories'].items():
            percentage = (cat_progress['completed'] / cat_progress['total'] * 100) if cat_progress['total'] > 0 else 0
            print(f"  {category.upper()}: {percentage:.1f}% ({cat_progress['completed']}/{cat_progress['total']})")
            
            for lab in cat_progress['labs']:
                print(f"    ✓ {lab['lab_id']} (${lab['cost']:.2f})")

if __name__ == "__main__":
    main()