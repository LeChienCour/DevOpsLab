#!/usr/bin/env python3
"""
Cost tracking utility for AWS DevOps Labs
Monitors and reports costs associated with lab sessions.
"""

import boto3
import json
from datetime import datetime, timedelta
from typing import Dict, List

class CostTracker:
    def __init__(self, region='us-east-1'):
        self.ce_client = boto3.client('ce', region_name=region)
        self.ec2_client = boto3.client('ec2', region_name=region)
        
    def get_session_costs(self, session_id: str, days_back: int = 7) -> Dict:
        """Get costs for a specific lab session."""
        end_date = datetime.now().date()
        start_date = end_date - timedelta(days=days_back)
        
        try:
            response = self.ce_client.get_cost_and_usage(
                TimePeriod={
                    'Start': start_date.strftime('%Y-%m-%d'),
                    'End': end_date.strftime('%Y-%m-%d')
                },
                Granularity='DAILY',
                Metrics=['BlendedCost'],
                GroupBy=[
                    {
                        'Type': 'TAG',
                        'Key': 'LabSession'
                    }
                ],
                Filter={
                    'Tags': {
                        'Key': 'LabSession',
                        'Values': [session_id]
                    }
                }
            )
            
            total_cost = 0.0
            daily_costs = []
            
            for result in response['ResultsByTime']:
                date = result['TimePeriod']['Start']
                for group in result['Groups']:
                    if group['Keys'][0] == session_id:
                        cost = float(group['Metrics']['BlendedCost']['Amount'])
                        total_cost += cost
                        daily_costs.append({
                            'date': date,
                            'cost': cost
                        })
            
            return {
                'session_id': session_id,
                'total_cost': total_cost,
                'daily_costs': daily_costs,
                'period': f"{start_date} to {end_date}"
            }
            
        except Exception as e:
            print(f"Error retrieving cost data: {e}")
            return {
                'session_id': session_id,
                'total_cost': 0.0,
                'daily_costs': [],
                'error': str(e)
            }
    
    def get_all_lab_costs(self, days_back: int = 30) -> List[Dict]:
        """Get costs for all lab sessions."""
        end_date = datetime.now().date()
        start_date = end_date - timedelta(days=days_back)
        
        try:
            response = self.ce_client.get_cost_and_usage(
                TimePeriod={
                    'Start': start_date.strftime('%Y-%m-%d'),
                    'End': end_date.strftime('%Y-%m-%d')
                },
                Granularity='MONTHLY',
                Metrics=['BlendedCost'],
                GroupBy=[
                    {
                        'Type': 'TAG',
                        'Key': 'LabSession'
                    }
                ],
                Filter={
                    'Tags': {
                        'Key': 'Environment',
                        'Values': ['lab']
                    }
                }
            )
            
            session_costs = {}
            
            for result in response['ResultsByTime']:
                for group in result['Groups']:
                    session_id = group['Keys'][0]
                    if session_id and session_id != 'No LabSession':
                        cost = float(group['Metrics']['BlendedCost']['Amount'])
                        if session_id not in session_costs:
                            session_costs[session_id] = 0.0
                        session_costs[session_id] += cost
            
            return [
                {'session_id': session_id, 'total_cost': cost}
                for session_id, cost in session_costs.items()
            ]
            
        except Exception as e:
            print(f"Error retrieving cost data: {e}")
            return []
    
    def get_running_resources(self, session_id: str) -> Dict:
        """Get currently running resources for a session."""
        resources = {
            'ec2_instances': [],
            's3_buckets': [],
            'lambda_functions': [],
            'cloudformation_stacks': []
        }
        
        try:
            # EC2 instances
            ec2_response = self.ec2_client.describe_instances(
                Filters=[
                    {'Name': 'tag:LabSession', 'Values': [session_id]},
                    {'Name': 'instance-state-name', 'Values': ['running', 'stopped']}
                ]
            )
            
            for reservation in ec2_response['Reservations']:
                for instance in reservation['Instances']:
                    resources['ec2_instances'].append({
                        'instance_id': instance['InstanceId'],
                        'instance_type': instance['InstanceType'],
                        'state': instance['State']['Name'],
                        'launch_time': instance['LaunchTime'].isoformat()
                    })
            
            # CloudFormation stacks
            cf_client = boto3.client('cloudformation')
            stacks_response = cf_client.describe_stacks()
            
            for stack in stacks_response['Stacks']:
                for tag in stack.get('Tags', []):
                    if tag['Key'] == 'LabSession' and tag['Value'] == session_id:
                        resources['cloudformation_stacks'].append({
                            'stack_name': stack['StackName'],
                            'status': stack['StackStatus'],
                            'creation_time': stack['CreationTime'].isoformat()
                        })
                        break
            
        except Exception as e:
            print(f"Error retrieving resource data: {e}")
        
        return resources
    
    def estimate_hourly_cost(self, session_id: str) -> float:
        """Estimate hourly cost for running resources."""
        resources = self.get_running_resources(session_id)
        
        # Simple cost estimation (these are approximate rates)
        cost_per_hour = 0.0
        
        # EC2 instance costs (simplified)
        instance_costs = {
            't3.micro': 0.0104,
            't3.small': 0.0208,
            't3.medium': 0.0416,
            't3.large': 0.0832,
            'm5.large': 0.096,
            'm5.xlarge': 0.192
        }
        
        for instance in resources['ec2_instances']:
            if instance['state'] == 'running':
                instance_type = instance['instance_type']
                cost_per_hour += instance_costs.get(instance_type, 0.05)  # Default estimate
        
        return cost_per_hour

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description="AWS DevOps Labs Cost Tracker")
    parser.add_argument('--session-id', help='Specific session ID to track')
    parser.add_argument('--all-sessions', action='store_true', help='Show costs for all sessions')
    parser.add_argument('--running-resources', help='Show running resources for session ID')
    parser.add_argument('--estimate-hourly', help='Estimate hourly cost for session ID')
    parser.add_argument('--days', type=int, default=7, help='Number of days to look back')
    
    args = parser.parse_args()
    
    tracker = CostTracker()
    
    if args.session_id:
        costs = tracker.get_session_costs(args.session_id, args.days)
        print(f"Costs for session {args.session_id}:")
        print(f"Total cost: ${costs['total_cost']:.2f}")
        print(f"Period: {costs['period']}")
        
        if costs['daily_costs']:
            print("\nDaily breakdown:")
            for daily in costs['daily_costs']:
                print(f"  {daily['date']}: ${daily['cost']:.2f}")
    
    elif args.all_sessions:
        costs = tracker.get_all_lab_costs(args.days)
        print("Costs for all lab sessions:")
        total = 0.0
        for session_cost in costs:
            print(f"  {session_cost['session_id']}: ${session_cost['total_cost']:.2f}")
            total += session_cost['total_cost']
        print(f"\nTotal lab costs: ${total:.2f}")
    
    elif args.running_resources:
        resources = tracker.get_running_resources(args.running_resources)
        print(f"Running resources for session {args.running_resources}:")
        
        if resources['ec2_instances']:
            print("EC2 Instances:")
            for instance in resources['ec2_instances']:
                print(f"  {instance['instance_id']} ({instance['instance_type']}) - {instance['state']}")
        
        if resources['cloudformation_stacks']:
            print("CloudFormation Stacks:")
            for stack in resources['cloudformation_stacks']:
                print(f"  {stack['stack_name']} - {stack['status']}")
    
    elif args.estimate_hourly:
        hourly_cost = tracker.estimate_hourly_cost(args.estimate_hourly)
        print(f"Estimated hourly cost for session {args.estimate_hourly}: ${hourly_cost:.4f}")
        print(f"Estimated daily cost: ${hourly_cost * 24:.2f}")
    
    else:
        parser.print_help()

if __name__ == "__main__":
    main()