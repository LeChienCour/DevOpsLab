#!/usr/bin/env python3
"""
Script to remediate AWS Config compliance violations
"""

import boto3
import argparse
import json
import datetime
import os
import sys
import time

def get_non_compliant_rules():
    """
    Get all non-compliant AWS Config rules
    """
    config = boto3.client('config')
    non_compliant_rules = []
    
    try:
        response = config.describe_compliance_by_config_rule(
            ComplianceTypes=['NON_COMPLIANT']
        )
        
        for rule in response['ComplianceByConfigRules']:
            non_compliant_rules.append(rule['ConfigRuleName'])
    except Exception as e:
        print(f"Error getting non-compliant rules: {str(e)}")
    
    return non_compliant_rules

def get_remediation_configuration(rule_name):
    """
    Get remediation configuration for a specific rule
    """
    config = boto3.client('config')
    
    try:
        response = config.describe_remediation_configurations(
            ConfigRuleNames=[rule_name]
        )
        
        if response['RemediationConfigurations']:
            return response['RemediationConfigurations'][0]
    except Exception as e:
        print(f"Error getting remediation configuration for rule {rule_name}: {str(e)}")
    
    return None

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
                
                resources.append({
                    'ResourceId': resource_id,
                    'ResourceType': resource_type
                })
    except Exception as e:
        print(f"Error getting non-compliant resources for rule {rule_name}: {str(e)}")
    
    return resources

def execute_remediation(rule_name, resource_id, resource_type, remediation_config, dry_run=False):
    """
    Execute remediation for a specific resource
    """
    config = boto3.client('config')
    
    target_id = remediation_config['TargetId']
    target_type = remediation_config['TargetType']
    
    # Build parameters
    parameters = {}
    for param_name, param_value in remediation_config.get('Parameters', {}).items():
        if 'ResourceValue' in param_value and param_value['ResourceValue']['Value'] == 'RESOURCE_ID':
            parameters[param_name] = {'Value': resource_id}
        else:
            parameters[param_name] = {'Value': param_value['StaticValue']['Values'][0]}
    
    print(f"Executing remediation for {resource_id} ({resource_type}) using {target_id}")
    
    if dry_run:
        print("DRY RUN: Would execute remediation with parameters:")
        print(json.dumps(parameters, indent=2))
        return True
    
    try:
        response = config.start_remediation_execution(
            ConfigRuleName=rule_name,
            ResourceKeys=[
                {
                    'resourceType': resource_type,
                    'resourceId': resource_id
                }
            ]
        )
        
        if response['FailedItems']:
            print(f"Failed to execute remediation for {resource_id}: {response['FailedItems']}")
            return False
        
        print(f"Successfully started remediation for {resource_id}")
        return True
    except Exception as e:
        print(f"Error executing remediation for {resource_id}: {str(e)}")
        return False

def remediate_rule(rule_name, dry_run=False, interactive=False):
    """
    Remediate all non-compliant resources for a specific rule
    """
    print(f"\nProcessing rule: {rule_name}")
    
    # Get remediation configuration
    remediation_config = get_remediation_configuration(rule_name)
    if not remediation_config:
        print(f"No remediation configuration found for rule {rule_name}")
        return False
    
    # Get non-compliant resources
    resources = get_non_compliant_resources(rule_name)
    if not resources:
        print(f"No non-compliant resources found for rule {rule_name}")
        return True
    
    print(f"Found {len(resources)} non-compliant resources")
    
    # Execute remediation for each resource
    success_count = 0
    for resource in resources:
        resource_id = resource['ResourceId']
        resource_type = resource['ResourceType']
        
        if interactive:
            response = input(f"Remediate {resource_id} ({resource_type})? [y/N] ")
            if response.lower() != 'y':
                print(f"Skipping {resource_id}")
                continue
        
        success = execute_remediation(rule_name, resource_id, resource_type, remediation_config, dry_run)
        if success:
            success_count += 1
    
    print(f"Remediated {success_count} out of {len(resources)} resources for rule {rule_name}")
    return success_count == len(resources)

def main():
    parser = argparse.ArgumentParser(description='Remediate AWS Config compliance violations')
    parser.add_argument('--rule', type=str, help='Specific rule to remediate')
    parser.add_argument('--dry-run', action='store_true', help='Dry run mode (no actual remediation)')
    parser.add_argument('--interactive', action='store_true', help='Interactive mode (ask before remediating)')
    
    args = parser.parse_args()
    
    if args.rule:
        # Remediate specific rule
        remediate_rule(args.rule, args.dry_run, args.interactive)
    else:
        # Get all non-compliant rules
        print("Getting non-compliant AWS Config rules...")
        non_compliant_rules = get_non_compliant_rules()
        
        if not non_compliant_rules:
            print("No non-compliant rules found")
            return
        
        print(f"Found {len(non_compliant_rules)} non-compliant rules")
        
        # Remediate each rule
        for rule_name in non_compliant_rules:
            remediate_rule(rule_name, args.dry_run, args.interactive)

if __name__ == '__main__':
    main()