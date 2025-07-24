#!/usr/bin/env python3
"""
CloudWatch Dashboard Generator

This script automatically generates CloudWatch dashboards based on AWS infrastructure changes.
It detects resources in your AWS account and creates appropriate dashboard widgets.

Usage:
  python dashboard-generator.py --stack-name <stack-name> [--region <region>] [--profile <profile>]
  
Options:
  --stack-name    CloudFormation stack name to monitor (or 'all' for all resources)
  --region        AWS region (default: from AWS config)
  --profile       AWS profile (default: default)
  --output        Output file for dashboard JSON (default: dashboard.json)
  --apply         Apply the dashboard directly to CloudWatch
  --dashboard-name Name of the dashboard (default: auto-generated)
"""

import argparse
import boto3
import json
import time
import os
import sys
from datetime import datetime
from botocore.exceptions import ClientError

def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description='Generate CloudWatch dashboards based on AWS infrastructure')
    parser.add_argument('--stack-name', required=True, help='CloudFormation stack name to monitor (or "all")')
    parser.add_argument('--region', help='AWS region')
    parser.add_argument('--profile', default='default', help='AWS profile')
    parser.add_argument('--output', default='dashboard.json', help='Output file for dashboard JSON')
    parser.add_argument('--apply', action='store_true', help='Apply the dashboard directly to CloudWatch')
    parser.add_argument('--dashboard-name', help='Name of the dashboard (default: auto-generated)')
    return parser.parse_args()

def get_boto3_session(profile_name, region_name=None):
    """Create a boto3 session with the specified profile and region."""
    session = boto3.Session(profile_name=profile_name, region_name=region_name)
    return session

def get_stack_resources(session, stack_name):
    """Get resources from a CloudFormation stack."""
    cfn = session.client('cloudformation')
    resources = []
    
    try:
        if stack_name.lower() == 'all':
            # Get all stacks
            stacks = []
            paginator = cfn.get_paginator('list_stacks')
            for page in paginator.paginate(StackStatusFilter=['CREATE_COMPLETE', 'UPDATE_COMPLETE']):
                stacks.extend(page['StackSummaries'])
            
            # Get resources for each stack
            for stack in stacks:
                stack_resources = cfn.list_stack_resources(StackName=stack['StackName'])
                for resource in stack_resources.get('StackResourceSummaries', []):
                    resources.append({
                        'StackName': stack['StackName'],
                        'LogicalId': resource['LogicalResourceId'],
                        'PhysicalId': resource['PhysicalResourceId'],
                        'Type': resource['ResourceType']
                    })
        else:
            # Get resources for the specified stack
            stack_resources = cfn.list_stack_resources(StackName=stack_name)
            for resource in stack_resources.get('StackResourceSummaries', []):
                resources.append({
                    'StackName': stack_name,
                    'LogicalId': resource['LogicalResourceId'],
                    'PhysicalId': resource['PhysicalResourceId'],
                    'Type': resource['ResourceType']
                })
    except ClientError as e:
        print(f"Error getting stack resources: {e}")
        sys.exit(1)
    
    return resources

def get_ec2_instances(session):
    """Get EC2 instances with their tags."""
    ec2 = session.client('ec2')
    instances = []
    
    try:
        paginator = ec2.get_paginator('describe_instances')
        for page in paginator.paginate(Filters=[{'Name': 'instance-state-name', 'Values': ['running']}]):
            for reservation in page['Reservations']:
                for instance in reservation['Instances']:
                    name = ''
                    for tag in instance.get('Tags', []):
                        if tag['Key'] == 'Name':
                            name = tag['Value']
                            break
                    
                    instances.append({
                        'InstanceId': instance['InstanceId'],
                        'Name': name,
                        'Type': instance['InstanceType'],
                        'State': instance['State']['Name']
                    })
    except ClientError as e:
        print(f"Error getting EC2 instances: {e}")
    
    return instances

def get_lambda_functions(session):
    """Get Lambda functions."""
    lambda_client = session.client('lambda')
    functions = []
    
    try:
        paginator = lambda_client.get_paginator('list_functions')
        for page in paginator.paginate():
            for function in page['Functions']:
                functions.append({
                    'FunctionName': function['FunctionName'],
                    'Runtime': function['Runtime'],
                    'MemorySize': function['MemorySize']
                })
    except ClientError as e:
        print(f"Error getting Lambda functions: {e}")
    
    return functions

def get_rds_instances(session):
    """Get RDS instances."""
    rds = session.client('rds')
    instances = []
    
    try:
        paginator = rds.get_paginator('describe_db_instances')
        for page in paginator.paginate():
            for instance in page['DBInstances']:
                instances.append({
                    'DBInstanceIdentifier': instance['DBInstanceIdentifier'],
                    'Engine': instance['Engine'],
                    'DBInstanceClass': instance['DBInstanceClass']
                })
    except ClientError as e:
        print(f"Error getting RDS instances: {e}")
    
    return instances

def get_api_gateways(session):
    """Get API Gateway APIs."""
    apigw = session.client('apigateway')
    apis = []
    
    try:
        response = apigw.get_rest_apis()
        for api in response.get('items', []):
            apis.append({
                'ApiId': api['id'],
                'Name': api['name']
            })
    except ClientError as e:
        print(f"Error getting API Gateways: {e}")
    
    return apis

def get_ecs_clusters(session):
    """Get ECS clusters and services."""
    ecs = session.client('ecs')
    clusters = []
    
    try:
        # Get clusters
        cluster_arns = ecs.list_clusters()['clusterArns']
        if not cluster_arns:
            return clusters
        
        cluster_details = ecs.describe_clusters(clusters=cluster_arns)['clusters']
        
        for cluster in cluster_details:
            cluster_name = cluster['clusterName']
            services = []
            
            # Get services for each cluster
            service_arns = ecs.list_services(cluster=cluster_name).get('serviceArns', [])
            if service_arns:
                service_details = ecs.describe_services(cluster=cluster_name, services=service_arns)['services']
                for service in service_details:
                    services.append({
                        'ServiceName': service['serviceName'],
                        'TaskDefinition': service['taskDefinition']
                    })
            
            clusters.append({
                'ClusterName': cluster_name,
                'Services': services
            })
    except ClientError as e:
        print(f"Error getting ECS clusters: {e}")
    
    return clusters

def create_ec2_widgets(instances, start_y):
    """Create dashboard widgets for EC2 instances."""
    widgets = []
    
    # Add header
    widgets.append({
        "type": "text",
        "x": 0,
        "y": start_y,
        "width": 24,
        "height": 1,
        "properties": {
            "markdown": "## EC2 Instances"
        }
    })
    
    # Add widgets for each instance
    x = 0
    y = start_y + 1
    
    for i, instance in enumerate(instances):
        instance_name = instance['Name'] if instance['Name'] else instance['InstanceId']
        
        # CPU Utilization
        widgets.append({
            "type": "metric",
            "x": x,
            "y": y,
            "width": 8,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/EC2", "CPUUtilization", "InstanceId", instance['InstanceId'] ]
                ],
                "period": 300,
                "stat": "Average",
                "region": "us-east-1",
                "title": f"{instance_name} - CPU"
            }
        })
        
        # Update position
        x += 8
        if x >= 24:
            x = 0
            y += 6
    
    return widgets, y + 6

def create_lambda_widgets(functions, start_y):
    """Create dashboard widgets for Lambda functions."""
    widgets = []
    
    # Add header
    widgets.append({
        "type": "text",
        "x": 0,
        "y": start_y,
        "width": 24,
        "height": 1,
        "properties": {
            "markdown": "## Lambda Functions"
        }
    })
    
    # Add widgets for each function
    x = 0
    y = start_y + 1
    
    for i, function in enumerate(functions):
        # Invocations and Errors
        widgets.append({
            "type": "metric",
            "x": x,
            "y": y,
            "width": 8,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/Lambda", "Invocations", "FunctionName", function['FunctionName'] ],
                    [ ".", "Errors", ".", "." ]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "us-east-1",
                "title": f"{function['FunctionName']} - Invocations & Errors"
            }
        })
        
        # Update position
        x += 8
        if x >= 24:
            x = 0
            y += 6
    
    return widgets, y + 6

def create_rds_widgets(instances, start_y):
    """Create dashboard widgets for RDS instances."""
    widgets = []
    
    # Add header
    widgets.append({
        "type": "text",
        "x": 0,
        "y": start_y,
        "width": 24,
        "height": 1,
        "properties": {
            "markdown": "## RDS Instances"
        }
    })
    
    # Add widgets for each instance
    x = 0
    y = start_y + 1
    
    for i, instance in enumerate(instances):
        # CPU Utilization
        widgets.append({
            "type": "metric",
            "x": x,
            "y": y,
            "width": 8,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", instance['DBInstanceIdentifier'] ]
                ],
                "period": 300,
                "stat": "Average",
                "region": "us-east-1",
                "title": f"{instance['DBInstanceIdentifier']} - CPU"
            }
        })
        
        # Update position
        x += 8
        if x >= 24:
            x = 0
            y += 6
    
    return widgets, y + 6

def create_api_gateway_widgets(apis, start_y):
    """Create dashboard widgets for API Gateway."""
    widgets = []
    
    # Add header
    widgets.append({
        "type": "text",
        "x": 0,
        "y": start_y,
        "width": 24,
        "height": 1,
        "properties": {
            "markdown": "## API Gateway"
        }
    })
    
    # Add widgets for each API
    x = 0
    y = start_y + 1
    
    for i, api in enumerate(apis):
        # Requests and Latency
        widgets.append({
            "type": "metric",
            "x": x,
            "y": y,
            "width": 8,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/ApiGateway", "Count", "ApiName", api['Name'] ]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "us-east-1",
                "title": f"{api['Name']} - Requests"
            }
        })
        
        # Update position
        x += 8
        if x >= 24:
            x = 0
            y += 6
    
    return widgets, y + 6

def create_ecs_widgets(clusters, start_y):
    """Create dashboard widgets for ECS clusters."""
    widgets = []
    
    # Add header
    widgets.append({
        "type": "text",
        "x": 0,
        "y": start_y,
        "width": 24,
        "height": 1,
        "properties": {
            "markdown": "## ECS Clusters"
        }
    })
    
    # Add widgets for each cluster
    x = 0
    y = start_y + 1
    
    for cluster in clusters:
        # CPU Utilization
        widgets.append({
            "type": "metric",
            "x": x,
            "y": y,
            "width": 8,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/ECS", "CPUUtilization", "ClusterName", cluster['ClusterName'] ]
                ],
                "period": 300,
                "stat": "Average",
                "region": "us-east-1",
                "title": f"{cluster['ClusterName']} - CPU"
            }
        })
        
        # Update position
        x += 8
        if x >= 24:
            x = 0
            y += 6
    
    return widgets, y + 6

def generate_dashboard(stack_name, resources, ec2_instances, lambda_functions, rds_instances, api_gateways, ecs_clusters):
    """Generate a CloudWatch dashboard based on discovered resources."""
    widgets = []
    
    # Add header
    widgets.append({
        "type": "text",
        "x": 0,
        "y": 0,
        "width": 24,
        "height": 2,
        "properties": {
            "markdown": f"# Auto-Generated Dashboard - {stack_name}\nLast updated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
        }
    })
    
    current_y = 2
    
    # Add EC2 widgets if instances exist
    if ec2_instances:
        ec2_widgets, current_y = create_ec2_widgets(ec2_instances, current_y)
        widgets.extend(ec2_widgets)
    
    # Add Lambda widgets if functions exist
    if lambda_functions:
        lambda_widgets, current_y = create_lambda_widgets(lambda_functions, current_y)
        widgets.extend(lambda_widgets)
    
    # Add RDS widgets if instances exist
    if rds_instances:
        rds_widgets, current_y = create_rds_widgets(rds_instances, current_y)
        widgets.extend(rds_widgets)
    
    # Add API Gateway widgets if APIs exist
    if api_gateways:
        api_widgets, current_y = create_api_gateway_widgets(api_gateways, current_y)
        widgets.extend(api_widgets)
    
    # Add ECS widgets if clusters exist
    if ecs_clusters:
        ecs_widgets, current_y = create_ecs_widgets(ecs_clusters, current_y)
        widgets.extend(ecs_widgets)
    
    # Create dashboard JSON
    dashboard = {
        "widgets": widgets
    }
    
    return dashboard

def save_dashboard(dashboard, output_file):
    """Save dashboard JSON to a file."""
    with open(output_file, 'w') as f:
        json.dump(dashboard, f, indent=2)
    print(f"Dashboard JSON saved to {output_file}")

def apply_dashboard(session, dashboard_name, dashboard):
    """Apply the dashboard directly to CloudWatch."""
    cloudwatch = session.client('cloudwatch')
    
    try:
        response = cloudwatch.put_dashboard(
            DashboardName=dashboard_name,
            DashboardBody=json.dumps(dashboard)
        )
        print(f"Dashboard '{dashboard_name}' successfully applied to CloudWatch")
        return True
    except ClientError as e:
        print(f"Error applying dashboard: {e}")
        return False

def main():
    """Main function."""
    args = parse_args()
    
    # Create boto3 session
    session = get_boto3_session(args.profile, args.region)
    
    # Get stack resources
    resources = get_stack_resources(session, args.stack_name)
    print(f"Found {len(resources)} resources in stack(s)")
    
    # Get EC2 instances
    ec2_instances = get_ec2_instances(session)
    print(f"Found {len(ec2_instances)} EC2 instances")
    
    # Get Lambda functions
    lambda_functions = get_lambda_functions(session)
    print(f"Found {len(lambda_functions)} Lambda functions")
    
    # Get RDS instances
    rds_instances = get_rds_instances(session)
    print(f"Found {len(rds_instances)} RDS instances")
    
    # Get API Gateway APIs
    api_gateways = get_api_gateways(session)
    print(f"Found {len(api_gateways)} API Gateway APIs")
    
    # Get ECS clusters
    ecs_clusters = get_ecs_clusters(session)
    print(f"Found {len(ecs_clusters)} ECS clusters")
    
    # Generate dashboard
    dashboard = generate_dashboard(
        args.stack_name,
        resources,
        ec2_instances,
        lambda_functions,
        rds_instances,
        api_gateways,
        ecs_clusters
    )
    
    # Save dashboard to file
    save_dashboard(dashboard, args.output)
    
    # Apply dashboard if requested
    if args.apply:
        dashboard_name = args.dashboard_name or f"Auto-{args.stack_name}-{int(time.time())}"
        apply_dashboard(session, dashboard_name, dashboard)

if __name__ == "__main__":
    main()