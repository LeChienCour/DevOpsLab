'''
Custom AWS Config rule to check if resources have required tags
'''

import json
import boto3
import datetime

# Define the required tags
REQUIRED_TAGS = ['Environment', 'Project', 'Owner']

def evaluate_compliance(configuration_item, rule_parameters):
    """
    Evaluates if the resource has all required tags
    """
    if configuration_item['resourceType'] not in [
        'AWS::EC2::Instance',
        'AWS::EC2::Volume',
        'AWS::S3::Bucket',
        'AWS::RDS::DBInstance',
        'AWS::DynamoDB::Table'
    ]:
        return 'NOT_APPLICABLE'
    
    # Check if the resource has tags
    if 'tags' not in configuration_item['configuration']:
        return 'NON_COMPLIANT'
    
    tags = configuration_item['configuration']['tags']
    
    # If no tags, resource is non-compliant
    if not tags:
        return 'NON_COMPLIANT'
    
    # Convert tags list to dictionary for easier lookup
    tags_dict = {tag['key']: tag['value'] for tag in tags}
    
    # Check if all required tags are present
    for required_tag in REQUIRED_TAGS:
        if required_tag not in tags_dict:
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
    
    # Build the evaluation response
    evaluation = {
        'compliance_type': compliance_type,
        'annotation': f"Resource {'has' if compliance_type == 'COMPLIANT' else 'is missing'} required tags: {', '.join(REQUIRED_TAGS)}",
        'ordering_timestamp': configuration_item['configurationItemCaptureTime']
    }
    
    put_evaluations_request = {
        'Evaluations': [
            {
                'ComplianceResourceType': configuration_item['resourceType'],
                'ComplianceResourceId': configuration_item['resourceId'],
                'ComplianceType': compliance_type,
                'Annotation': evaluation['annotation'],
                'OrderingTimestamp': datetime.datetime.now().isoformat()
            }
        ],
        'ResultToken': event['resultToken']
    }
    
    # Submit the evaluation results to AWS Config
    config = boto3.client('config')
    config.put_evaluations(**put_evaluations_request)
    
    return evaluation