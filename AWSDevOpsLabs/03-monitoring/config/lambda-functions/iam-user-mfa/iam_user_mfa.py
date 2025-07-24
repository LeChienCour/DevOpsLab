'''
Custom AWS Config rule to check if IAM users have MFA enabled
'''

import json
import boto3
import datetime

def evaluate_compliance(configuration_item, rule_parameters):
    """
    Evaluates if IAM users have MFA enabled
    """
    if configuration_item['resourceType'] != 'AWS::IAM::User':
        return 'NOT_APPLICABLE'
    
    # Get the IAM user name
    user_name = configuration_item['resourceName']
    
    # Check if the user is the root user (not applicable)
    if user_name == 'root':
        return 'NOT_APPLICABLE'
    
    # Get the MFA devices for the user
    iam = boto3.client('iam')
    try:
        response = iam.list_mfa_devices(UserName=user_name)
        mfa_devices = response['MFADevices']
        
        # If no MFA devices, user is non-compliant
        if not mfa_devices:
            return 'NON_COMPLIANT'
        
        return 'COMPLIANT'
    except Exception as e:
        # If there's an error, mark as non-compliant
        return 'NON_COMPLIANT'

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
    
    # Build the evaluation response
    annotation = "IAM user has MFA enabled" if compliance_type == 'COMPLIANT' else "IAM user does not have MFA enabled"
    
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