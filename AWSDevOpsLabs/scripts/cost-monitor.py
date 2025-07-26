#!/usr/bin/env python3
"""
Cost monitoring and budget alert system for AWS DevOps Labs
"""

import argparse
import boto3
import json
import sys
from datetime import datetime, timedelta
from typing import Dict, List, Optional

class CostMonitor:
    def __init__(self):
        """Initialize AWS clients for cost monitoring."""
        try:
            self.session = boto3.Session()
            self.ce_client = self.session.client('ce', region_name='us-east-1')
            self.budgets_client = self.session.client('budgets', region_name='us-east-1')
            self.sts_client = self.session.client('sts')
            self.account_id = self.sts_client.get_caller_identity()['Account']
        except Exception as e:
            print(f"Error initializing AWS clients: {e}")
            sys.exit(1)

    def get_session_costs(self, session_id: str, days: int = 7) -> Dict:
        """Get costs for a specific lab session."""
        end_date = datetime.now()
        start_date = end_date - timedelta(days=days)
        
        try:
            response = self.ce_client.get_cost_and_usage(
                TimePeriod={
                    'Start': start_date.strftime('%Y-%m-%d'),
                    'End': end_date.strftime('%Y-%m-%d')
                },
                Granularity='DAILY',
                Metrics=['BlendedCost', 'UsageQuantity'],
                GroupBy=[
                    {'Type': 'TAG', 'Key': 'SessionId'},
                    {'Type': 'SERVICE'}
                ],
                FilterExpression={
                    'Tags': {
                        'Key': 'SessionId',
                        'Values': [session_id]
                    }
                }
            )
            
            total_cost = 0.0
            service_costs = {}
            daily_costs = {}
            
            for result in response['ResultsByTime']:
                date = result['TimePeriod']['Start']
                daily_cost = 0.0
                
                for group in result['Groups']:
                    if session_id in str(group['Keys']):
                        cost = float(group['Metrics']['BlendedCost']['Amount'])
                        total_cost += cost
                        daily_cost += cost
                        
                        # Extract service name
                        service = 'Unknown'
                        for key in group['Keys']:
                            if key != session_id and key != 'NoTagKey':
                                service = key
                                break
                        
                        if service not in service_costs:
                            service_costs[service] = 0.0
                        service_costs[service] += cost
                
                daily_costs[date] = daily_cost
            
            return {
                'session_id': session_id,
                'total_cost': round(total_cost, 2),
                'service_costs': {k: round(v, 2) for k, v in service_costs.items()},
                'daily_costs': {k: round(v, 2) for k, v in daily_costs.items()},
                'period_days': days
            }
            
        except Exception as e:
            print(f"Error getting session costs: {e}")
            return {'session_id': session_id, 'total_cost': 0.0, 'error': str(e)}

    def get_all_lab_costs(self, days: int = 30) -> Dict:
        """Get costs for all lab sessions."""
        end_date = datetime.now()
        start_date = end_date - timedelta(days=days)
        
        try:
            response = self.ce_client.get_cost_and_usage(
                TimePeriod={
                    'Start': start_date.strftime('%Y-%m-%d'),
                    'End': end_date.strftime('%Y-%m-%d')
                },
                Granularity='DAILY',
                Metrics=['BlendedCost'],
                GroupBy=[{'Type': 'TAG', 'Key': 'SessionId'}],
                FilterExpression={
                    'Tags': {
                        'Key': 'Project',
                        'Values': ['AWSDevOpsLabs']
                    }
                }
            )
            
            session_costs = {}
            total_cost = 0.0
            
            for result in response['ResultsByTime']:
                for group in result['Groups']:
                    session_id = None
                    for key in group['Keys']:
                        if key != 'NoTagKey':
                            session_id = key
                            break
                    
                    if session_id:
                        cost = float(group['Metrics']['BlendedCost']['Amount'])
                        if session_id not in session_costs:
                            session_costs[session_id] = 0.0
                        session_costs[session_id] += cost
                        total_cost += cost
            
            return {
                'total_cost': round(total_cost, 2),
                'session_costs': {k: round(v, 2) for k, v in session_costs.items()},
                'period_days': days
            }
            
        except Exception as e:
            print(f"Error getting all lab costs: {e}")
            return {'total_cost': 0.0, 'error': str(e)}

    def create_budget_alert(self, session_id: str, budget_limit: float, 
                          email: Optional[str] = None) -> bool:
        """Create a budget alert for a lab session."""
        budget_name = f'DevOpsLab-{session_id}'
        
        try:
            # Create budget
            budget = {
                'BudgetName': budget_name,
                'BudgetLimit': {
                    'Amount': str(budget_limit),
                    'Unit': 'USD'
                },
                'TimeUnit': 'MONTHLY',
                'TimePeriod': {
                    'Start': datetime.now().replace(day=1),
                    'End': (datetime.now().replace(day=1) + timedelta(days=32)).replace(day=1)
                },
                'BudgetType': 'COST',
                'CostFilters': {
                    'TagKey': ['SessionId'],
                    'TagValue': [session_id]
                }
            }
            
            # Create notifications
            notifications = [
                {
                    'NotificationType': 'ACTUAL',
                    'ComparisonOperator': 'GREATER_THAN',
                    'Threshold': 80.0,
                    'ThresholdType': 'PERCENTAGE'
                },
                {
                    'NotificationType': 'FORECASTED',
                    'ComparisonOperator': 'GREATER_THAN',
                    'Threshold': 100.0,
                    'ThresholdType': 'PERCENTAGE'
                }
            ]
            
            subscribers = []
            if email:
                subscribers.append({
                    'SubscriptionType': 'EMAIL',
                    'Address': email
                })
            
            notifications_with_subscribers = []
            for notification in notifications:
                notifications_with_subscribers.append({
                    'Notification': notification,
                    'Subscribers': subscribers
                })
            
            self.budgets_client.create_budget(
                AccountId=self.account_id,
                Budget=budget,
                NotificationsWithSubscribers=notifications_with_subscribers
            )
            
            print(f"✓ Budget alert created: {budget_name} (${budget_limit})")
            return True
            
        except Exception as e:
            print(f"Error creating budget alert: {e}")
            return False

    def delete_budget_alert(self, session_id: str) -> bool:
        """Delete budget alert for a lab session."""
        budget_name = f'DevOpsLab-{session_id}'
        
        try:
            self.budgets_client.delete_budget(
                AccountId=self.account_id,
                BudgetName=budget_name
            )
            print(f"✓ Budget alert deleted: {budget_name}")
            return True
            
        except Exception as e:
            print(f"Error deleting budget alert: {e}")
            return False

    def list_budget_alerts(self) -> List[Dict]:
        """List all DevOps Lab budget alerts."""
        try:
            response = self.budgets_client.describe_budgets(
                AccountId=self.account_id
            )
            
            lab_budgets = []
            for budget in response['Budgets']:
                if budget['BudgetName'].startswith('DevOpsLab-'):
                    session_id = budget['BudgetName'].replace('DevOpsLab-', '')
                    lab_budgets.append({
                        'session_id': session_id,
                        'budget_name': budget['BudgetName'],
                        'limit': float(budget['BudgetLimit']['Amount']),
                        'time_unit': budget['TimeUnit']
                    })
            
            return lab_budgets
            
        except Exception as e:
            print(f"Error listing budget alerts: {e}")
            return []

    def get_cost_forecast(self, session_id: str, days: int = 30) -> Dict:
        """Get cost forecast for a lab session."""
        end_date = datetime.now() + timedelta(days=days)
        start_date = datetime.now()
        
        try:
            response = self.ce_client.get_cost_forecast(
                TimePeriod={
                    'Start': start_date.strftime('%Y-%m-%d'),
                    'End': end_date.strftime('%Y-%m-%d')
                },
                Metric='BLENDED_COST',
                Granularity='DAILY',
                Filter={
                    'Tags': {
                        'Key': 'SessionId',
                        'Values': [session_id]
                    }
                }
            )
            
            total_forecast = float(response['Total']['Amount'])
            
            return {
                'session_id': session_id,
                'forecast_amount': round(total_forecast, 2),
                'forecast_days': days,
                'confidence_level': response['ForecastResultsByTime'][0]['MeanValue'] if response['ForecastResultsByTime'] else 'Unknown'
            }
            
        except Exception as e:
            print(f"Error getting cost forecast: {e}")
            return {'session_id': session_id, 'forecast_amount': 0.0, 'error': str(e)}

def main():
    parser = argparse.ArgumentParser(description="AWS DevOps Labs Cost Monitor")
    subparsers = parser.add_subparsers(dest="command", help="Available commands")
    
    # Session costs command
    session_parser = subparsers.add_parser("session", help="Get costs for a specific session")
    session_parser.add_argument("session_id", help="Session ID")
    session_parser.add_argument("--days", type=int, default=7, help="Number of days to analyze")
    
    # All costs command
    all_parser = subparsers.add_parser("all", help="Get costs for all lab sessions")
    all_parser.add_argument("--days", type=int, default=30, help="Number of days to analyze")
    
    # Budget commands
    budget_create_parser = subparsers.add_parser("create-budget", help="Create budget alert")
    budget_create_parser.add_argument("session_id", help="Session ID")
    budget_create_parser.add_argument("limit", type=float, help="Budget limit in USD")
    budget_create_parser.add_argument("--email", help="Email for notifications")
    
    budget_delete_parser = subparsers.add_parser("delete-budget", help="Delete budget alert")
    budget_delete_parser.add_argument("session_id", help="Session ID")
    
    subparsers.add_parser("list-budgets", help="List all budget alerts")
    
    # Forecast command
    forecast_parser = subparsers.add_parser("forecast", help="Get cost forecast")
    forecast_parser.add_argument("session_id", help="Session ID")
    forecast_parser.add_argument("--days", type=int, default=30, help="Forecast period in days")
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    monitor = CostMonitor()
    
    if args.command == "session":
        costs = monitor.get_session_costs(args.session_id, args.days)
        print(json.dumps(costs, indent=2))
        
    elif args.command == "all":
        costs = monitor.get_all_lab_costs(args.days)
        print(json.dumps(costs, indent=2))
        
    elif args.command == "create-budget":
        monitor.create_budget_alert(args.session_id, args.limit, args.email)
        
    elif args.command == "delete-budget":
        monitor.delete_budget_alert(args.session_id)
        
    elif args.command == "list-budgets":
        budgets = monitor.list_budget_alerts()
        print(json.dumps(budgets, indent=2))
        
    elif args.command == "forecast":
        forecast = monitor.get_cost_forecast(args.session_id, args.days)
        print(json.dumps(forecast, indent=2))

if __name__ == "__main__":
    main()