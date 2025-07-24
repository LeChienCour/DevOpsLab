#!/usr/bin/env python3
"""
Script to generate AWS Config compliance reports
"""

import boto3
import argparse
import json
import datetime
import os
import sys
from tabulate import tabulate

def get_config_rules():
    """
    Get all AWS Config rules
    """
    config = boto3.client('config')
    rules = []
    
    paginator = config.get_paginator('describe_config_rules')
    for page in paginator.paginate():
        rules.extend(page['ConfigRules'])
    
    return rules

def get_rule_compliance(rule_name):
    """
    Get compliance status for a specific rule
    """
    config = boto3.client('config')
    
    try:
        response = config.describe_compliance_by_config_rule(
            ConfigRuleNames=[rule_name]
        )
        
        for result in response['ComplianceByConfigRules']:
            if result['ConfigRuleName'] == rule_name:
                return result.get('Compliance', {}).get('ComplianceType', 'UNKNOWN')
    except Exception as e:
        print(f"Error getting compliance for rule {rule_name}: {str(e)}")
    
    return 'UNKNOWN'

def get_non_compliant_resources(rule_name):
    """
    Get non-compliant resources for a specific rule
    """
    config = boto3.client('config')
    resources = []
    
    try:
        paginator = config.get_paginator('get_compliance_details_by_config_rule')
        for page in paginator.paginate(
            ConfigRuleName=rule_name,
            ComplianceTypes=['NON_COMPLIANT']
        ):
            for result in page['EvaluationResults']:
                resource_id = result['EvaluationResultIdentifier']['EvaluationResultQualifier']['ResourceId']
                resource_type = result['EvaluationResultIdentifier']['EvaluationResultQualifier']['ResourceType']
                annotation = result.get('Annotation', '')
                
                resources.append({
                    'ResourceId': resource_id,
                    'ResourceType': resource_type,
                    'Annotation': annotation
                })
    except Exception as e:
        print(f"Error getting non-compliant resources for rule {rule_name}: {str(e)}")
    
    return resources

def generate_html_report(rules_data, output_file):
    """
    Generate an HTML report from the compliance data
    """
    # Count compliance status
    compliance_counts = {
        'COMPLIANT': 0,
        'NON_COMPLIANT': 0,
        'NOT_APPLICABLE': 0,
        'UNKNOWN': 0
    }
    
    for rule in rules_data:
        compliance_status = rule['ComplianceStatus']
        if compliance_status in compliance_counts:
            compliance_counts[compliance_status] += 1
    
    # Calculate compliance rate
    total_rules = sum(compliance_counts.values())
    compliance_rate = (compliance_counts['COMPLIANT'] / total_rules * 100) if total_rules > 0 else 0
    
    # Count non-compliant resources by type
    resource_type_counts = {}
    for rule in rules_data:
        for resource in rule.get('NonCompliantResources', []):
            resource_type = resource['ResourceType']
            if resource_type not in resource_type_counts:
                resource_type_counts[resource_type] = 0
            resource_type_counts[resource_type] += 1
    
    # Generate HTML
    html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>AWS Config Compliance Report</title>
        <style>
            body {{ font-family: Arial, sans-serif; margin: 20px; }}
            h1, h2 {{ color: #0073bb; }}
            .summary {{ display: flex; margin-bottom: 20px; }}
            .summary-box {{ flex: 1; margin: 10px; padding: 15px; border-radius: 5px; color: white; text-align: center; }}
            .compliant {{ background-color: #28a745; }}
            .non-compliant {{ background-color: #dc3545; }}
            .not-applicable {{ background-color: #6c757d; }}
            .unknown {{ background-color: #ffc107; color: black; }}
            .compliance-rate {{ background-color: #17a2b8; }}
            table {{ border-collapse: collapse; width: 100%; margin-bottom: 30px; }}
            th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
            th {{ background-color: #f2f2f2; }}
            tr:nth-child(even) {{ background-color: #f9f9f9; }}
            .status-compliant {{ color: #28a745; }}
            .status-non-compliant {{ color: #dc3545; }}
            .status-not-applicable {{ color: #6c757d; }}
            .status-unknown {{ color: #ffc107; }}
            .resource-table {{ margin-left: 20px; }}
        </style>
    </head>
    <body>
        <h1>AWS Config Compliance Report</h1>
        <p>Generated on: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
        
        <h2>Compliance Summary</h2>
        <div class="summary">
            <div class="summary-box compliant">
                <h3>Compliant Rules</h3>
                <p>{compliance_counts['COMPLIANT']}</p>
            </div>
            <div class="summary-box non-compliant">
                <h3>Non-Compliant Rules</h3>
                <p>{compliance_counts['NON_COMPLIANT']}</p>
            </div>
            <div class="summary-box not-applicable">
                <h3>Not Applicable Rules</h3>
                <p>{compliance_counts['NOT_APPLICABLE']}</p>
            </div>
            <div class="summary-box unknown">
                <h3>Unknown Rules</h3>
                <p>{compliance_counts['UNKNOWN']}</p>
            </div>
            <div class="summary-box compliance-rate">
                <h3>Compliance Rate</h3>
                <p>{compliance_rate:.2f}%</p>
            </div>
        </div>
        
        <h2>Non-Compliant Resources by Type</h2>
        <table>
            <tr>
                <th>Resource Type</th>
                <th>Count</th>
            </tr>
    """
    
    # Add rows for each resource type
    for resource_type, count in resource_type_counts.items():
        html += f"""
            <tr>
                <td>{resource_type}</td>
                <td>{count}</td>
            </tr>
        """
    
    html += """
        </table>
        
        <h2>Config Rules Compliance</h2>
        <table>
            <tr>
                <th>Rule Name</th>
                <th>Description</th>
                <th>Compliance Status</th>
                <th>Non-Compliant Resources</th>
            </tr>
    """
    
    # Add rows for each rule
    for rule in rules_data:
        rule_name = rule['ConfigRuleName']
        description = rule.get('Description', '')
        compliance_status = rule['ComplianceStatus']
        non_compliant_count = len(rule.get('NonCompliantResources', []))
        
        status_class = f"status-{compliance_status.lower()}" if compliance_status.lower() in ['compliant', 'non_compliant', 'not_applicable'] else 'status-unknown'
        
        html += f"""
            <tr>
                <td>{rule_name}</td>
                <td>{description}</td>
                <td class="{status_class}">{compliance_status}</td>
                <td>{non_compliant_count}</td>
            </tr>
        """
        
        # Add non-compliant resources if any
        if non_compliant_count > 0:
            html += f"""
            <tr>
                <td colspan="4">
                    <table class="resource-table">
                        <tr>
                            <th>Resource ID</th>
                            <th>Resource Type</th>
                            <th>Reason</th>
                        </tr>
            """
            
            for resource in rule.get('NonCompliantResources', []):
                html += f"""
                        <tr>
                            <td>{resource['ResourceId']}</td>
                            <td>{resource['ResourceType']}</td>
                            <td>{resource['Annotation']}</td>
                        </tr>
                """
            
            html += """
                    </table>
                </td>
            </tr>
            """
    
    html += """
        </table>
    </body>
    </html>
    """
    
    with open(output_file, 'w') as f:
        f.write(html)
    
    print(f"HTML report generated: {output_file}")

def generate_text_report(rules_data):
    """
    Generate a text report from the compliance data
    """
    # Count compliance status
    compliance_counts = {
        'COMPLIANT': 0,
        'NON_COMPLIANT': 0,
        'NOT_APPLICABLE': 0,
        'UNKNOWN': 0
    }
    
    for rule in rules_data:
        compliance_status = rule['ComplianceStatus']
        if compliance_status in compliance_counts:
            compliance_counts[compliance_status] += 1
    
    # Calculate compliance rate
    total_rules = sum(compliance_counts.values())
    compliance_rate = (compliance_counts['COMPLIANT'] / total_rules * 100) if total_rules > 0 else 0
    
    # Count non-compliant resources by type
    resource_type_counts = {}
    for rule in rules_data:
        for resource in rule.get('NonCompliantResources', []):
            resource_type = resource['ResourceType']
            if resource_type not in resource_type_counts:
                resource_type_counts[resource_type] = 0
            resource_type_counts[resource_type] += 1
    
    # Print summary
    print("\nAWS Config Compliance Report")
    print(f"Generated on: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("\nCompliance Summary:")
    print(f"Compliant Rules: {compliance_counts['COMPLIANT']}")
    print(f"Non-Compliant Rules: {compliance_counts['NON_COMPLIANT']}")
    print(f"Not Applicable Rules: {compliance_counts['NOT_APPLICABLE']}")
    print(f"Unknown Rules: {compliance_counts['UNKNOWN']}")
    print(f"Compliance Rate: {compliance_rate:.2f}%")
    
    # Print non-compliant resources by type
    print("\nNon-Compliant Resources by Type:")
    resource_type_table = []
    for resource_type, count in resource_type_counts.items():
        resource_type_table.append([resource_type, count])
    
    print(tabulate(resource_type_table, headers=["Resource Type", "Count"], tablefmt="grid"))
    
    # Print rule compliance
    print("\nConfig Rules Compliance:")
    rule_table = []
    for rule in rules_data:
        rule_name = rule['ConfigRuleName']
        compliance_status = rule['ComplianceStatus']
        non_compliant_count = len(rule.get('NonCompliantResources', []))
        
        rule_table.append([rule_name, compliance_status, non_compliant_count])
    
    print(tabulate(rule_table, headers=["Rule Name", "Compliance Status", "Non-Compliant Resources"], tablefmt="grid"))
    
    # Print non-compliant resources
    print("\nNon-Compliant Resources Details:")
    for rule in rules_data:
        rule_name = rule['ConfigRuleName']
        non_compliant_resources = rule.get('NonCompliantResources', [])
        
        if non_compliant_resources:
            print(f"\nRule: {rule_name}")
            resource_table = []
            for resource in non_compliant_resources:
                resource_table.append([
                    resource['ResourceId'],
                    resource['ResourceType'],
                    resource['Annotation']
                ])
            
            print(tabulate(resource_table, headers=["Resource ID", "Resource Type", "Reason"], tablefmt="grid"))

def upload_to_s3(file_path, bucket, key):
    """
    Upload a file to S3
    """
    s3 = boto3.client('s3')
    
    try:
        s3.upload_file(file_path, bucket, key)
        print(f"Report uploaded to s3://{bucket}/{key}")
        return True
    except Exception as e:
        print(f"Error uploading to S3: {str(e)}")
        return False

def main():
    parser = argparse.ArgumentParser(description='Generate AWS Config compliance reports')
    parser.add_argument('--output', type=str, default='compliance-report.html', help='Output file name')
    parser.add_argument('--format', type=str, choices=['html', 'text'], default='html', help='Report format')
    parser.add_argument('--bucket', type=str, help='S3 bucket to upload the report to')
    parser.add_argument('--key', type=str, help='S3 key for the report')
    
    args = parser.parse_args()
    
    # Get all Config rules
    print("Getting AWS Config rules...")
    rules = get_config_rules()
    
    # Get compliance data for each rule
    rules_data = []
    for rule in rules:
        rule_name = rule['ConfigRuleName']
        print(f"Processing rule: {rule_name}")
        
        compliance_status = get_rule_compliance(rule_name)
        
        rule_data = {
            'ConfigRuleName': rule_name,
            'Description': rule.get('Description', ''),
            'ComplianceStatus': compliance_status
        }
        
        # Get non-compliant resources if the rule is non-compliant
        if compliance_status == 'NON_COMPLIANT':
            rule_data['NonCompliantResources'] = get_non_compliant_resources(rule_name)
        else:
            rule_data['NonCompliantResources'] = []
        
        rules_data.append(rule_data)
    
    # Generate report
    if args.format == 'html':
        generate_html_report(rules_data, args.output)
    else:
        generate_text_report(rules_data)
    
    # Upload to S3 if bucket is specified
    if args.bucket:
        key = args.key if args.key else f"compliance-reports/{datetime.datetime.now().strftime('%Y-%m-%d')}-compliance-report.html"
        upload_to_s3(args.output, args.bucket, key)

if __name__ == '__main__':
    main()