'''
Custom AWS Config rule to check if S3 buckets have public access blocked
'''

import json
import boto3
import datetime

def evaluate_compliance(configuration_item, rule_parameters):
    """
    Evaluates if S3 buckets have public access blocked
    """
    if configuration_item['resourceType'] != 'AWS::S3::Bucket':
        return 'NOT_APPLICABLE'
    
    # Get the bucket name
    bucket_name = configuration_item['resourceName']
    
    # Check if the bucket has public access blocked
    s3control = boto3.client('s3control')
    s3 = boto3.client('s3')
    account_id = boto3.client('sts').get_caller_identity()['Account']
    
    try:
        # Check bucket-level block public access settings
        try:
            public_access_block = s3.get_public_access_block(Bucket=bucket_name)
            block_config = public_access_block['PublicAccessBlockConfiguration']
            
            # Check if all public access block settings are enabled
            if not (block_config['BlockPublicAcls'] and 
                    block_config['IgnorePublicAcls'] and 
                    block_config['BlockPublicPolicy'] and 
                    block_config['RestrictPublicBuckets']):
                return 'NON_COMPLIANT'
        except s3.exceptions.NoSuchPublicAccessBlockConfiguration:
            # If no public access block configuration exists, it's non-compliant
            return 'NON_COMPLIANT'
        
        # Check bucket policy for public access
        try:
            bucket_policy = s3.get_bucket_policy(Bucket=bucket_name)
            policy_json = json.loads(bucket_policy['Policy'])
            
            # Simple check for public access in policy (this is a basic check)
            for statement in policy_json.get('Statement', []):
                principal = statement.get('Principal', {})
                if principal == '*' or principal.get('AWS') == '*':
                    if statement.get('Effect') == 'Allow':
                        return 'NON_COMPLIANT'
        except s3.exceptions.NoSuchBucketPolicy:
            # No bucket policy is fine
            pass
        
        # Check bucket ACLs
        bucket_acl = s3.get_bucket_acl(Bucket=bucket_name)
        for grant in bucket_acl['Grants']:
            grantee = grant['Grantee']
            if 'URI' in grantee and ('AllUsers' in grantee['URI'] or 'AuthenticatedUsers' in grantee['URI']):
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
    annotation = "S3 bucket has public access blocked" if compliance_type == 'COMPLIANT' else "S3 bucket has public access enabled"
    
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