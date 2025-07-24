'''
Custom AWS Config rule to check if EC2 instances are using approved instance types
'''

import json
import boto3
import datetime

def evaluate_compliance(configuration_item, rule_parameters):
    """
    Evaluates if EC2 instances are using approved instance types
    """
    if configuration_item['resourceType'] != 'AWS::EC2::Instance':
        return 'NOT_APPLICABLE'
    
    # Get the instance type
    instance_type = configuration_item['configuration'].get('instanceType')
    
    # Get the approved instance types from rule parameters
    approved_types = rule_parameters.get('approvedInstanceTypes', 't2.micro,t3.micro,t3.small').split(',')
    
    # Check if the instance type is in the approved list
    if instance_type not in approved_types:
        return 'NON_COMPLIANT'
    
    return 'COMPLIANT'

def lambda_handler(event, context):
    """
    Lambda function handler for AWS Config custom rule
    """
    invoking_event = json.loads(event['invokingEvent'])
    rule_parameters = json.loads(event['ruleParameters']) if 'ruleParameters' in event else {}
    
    if 'configurationItem' not in invoking_event:
        return {
            'compliance_type': 'NOT_APPLICABLE',
            'annotation': 'The event did not contain a configuration item.'
        }
    
    configuration_item = invoking_event['configurationItem']
    
    # Check if the resource was deleted
    if configuration_item['configurationItemStatus'] == 'ResourceDeleted':
        return {
            'compliance_type': 'NOT_APPLICABLE',
            'annotation': 'The resource was deleted.'
        }
    
    # Evaluate compliance
    compliance_type = evaluate_compliance(configuration_item, rule_parameters)
    
    # Get the approved instance types for the annotation
    approved_types = rule_parameters.get('approvedInstanceTypes', 't2.micro,t3.micro,t3.small').split(',')
    
    # Build the evaluation response
    instance_type = configuration_item['configuration'].get('instanceType')
    annotation = f"EC2 instance type {instance_type} is approved" if compliance_type == 'COMPLIANT' else f"EC2 instance type {instance_type} is not in the approved list: {', '.join(approved_types)}"
    
    evaluation = {
        'compliance_type': compliance_type,
        'annotation': annotation,
        'ordering_timestamp': configuration_item['configurationItemCaptureTime']
    }
    
    put_evaluations_request = {
        'Evaluations': [
            {
                'ComplianceResourceType': configuration_item['resourceType'],
                'ComplianceResourceId': configuration_item['resourceId'],
                'ComplianceType': compliance_type,
                'Annotation': annotation,
                'OrderingTimestamp': datetime.datetime.now().isoformat()
            }
        ],
        'ResultToken': event['resultToken']
    }
    
    # Submit the evaluation results to AWS Config
    config = boto3.client('config')
    config.put_evaluations(**put_evaluations_request)
    
    return evaluation