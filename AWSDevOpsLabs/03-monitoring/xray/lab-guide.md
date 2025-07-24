# AWS X-Ray Distributed Tracing Lab Guide

## Objective
Learn to implement distributed tracing using AWS X-Ray to monitor and debug microservices applications. This lab demonstrates how to instrument applications, analyze trace data, and identify performance bottlenecks in distributed systems.

## Learning Outcomes
By completing this lab, you will:
- Instrument applications with AWS X-Ray SDK for distributed tracing
- Configure X-Ray daemon for trace collection and forwarding
- Analyze service maps and trace timelines to identify bottlenecks
- Implement custom segments and annotations for detailed tracing
- Set up X-Ray sampling rules for cost-effective monitoring

## Prerequisites
- AWS Account with administrative access
- AWS CLI configured with appropriate credentials
- Python 3.7+ or Node.js 14+ installed locally
- Basic understanding of microservices architecture
- Docker installed (optional, for containerized examples)

### Required AWS Permissions
Your AWS user/role needs the following permissions:
- X-Ray: Full access for tracing operations
- Lambda: Create and manage functions (for serverless examples)
- EC2: Launch instances and manage security groups
- IAM: Create roles for X-Ray daemon and Lambda functions
- API Gateway: Create and manage APIs

### Time to Complete
Approximately 60-75 minutes

## Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Frontend      │───▶│   API Gateway    │───▶│   Lambda        │
│   Application   │    │   (X-Ray         │    │   Function      │
│                 │    │    Enabled)      │    │   (Traced)      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
                       ┌──────────────────┐    ┌─────────────────┐
                       │     X-Ray        │◀───│   DynamoDB      │
                       │    Service       │    │   (Traced)      │
                       │                  │    │                 │
                       └──────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │   X-Ray Console  │
                       │   (Service Map   │
                       │   & Trace View)  │
                       └──────────────────┘
```

### Resources Created:
- **Lambda Functions**: Microservices with X-Ray tracing enabled
- **API Gateway**: REST API with X-Ray tracing
- **DynamoDB Table**: Database with X-Ray integration
- **IAM Roles**: Execution roles with X-Ray permissions
- **X-Ray Sampling Rules**: Custom sampling configuration

## Lab Steps

### Step 1: Set Up X-Ray Service and Sampling Rules

1. **Create a custom sampling rule for cost optimization:**
   ```bash
   cat > sampling-rule.json << 'EOF'
{
    "version": 2,
    "default": {
        "fixed_target": 1,
        "rate": 0.1
    },
    "rules": [
        {
            "description": "High priority service sampling",
            "service_name": "user-service",
            "http_method": "*",
            "url_path": "/api/users/*",
            "fixed_target": 2,
            "rate": 0.5
        }
    ]
}
EOF
   ```

2. **Create the sampling rule:**
   ```bash
   aws xray create-sampling-rule --sampling-rule file://sampling-rule.json
   ```

3. **Verify the sampling rule:**
   ```bash
   aws xray get-sampling-rules
   ```

### Step 2: Create a DynamoDB Table for the Application

1. **Create a DynamoDB table:**
   ```bash
   aws dynamodb create-table \
     --table-name UserProfiles \
     --attribute-definitions \
         AttributeName=userId,AttributeType=S \
     --key-schema \
         AttributeName=userId,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST
   ```

2. **Wait for table to be active:**
   ```bash
   aws dynamodb wait table-exists --table-name UserProfiles
   ```

3. **Add sample data:**
   ```bash
   aws dynamodb put-item \
     --table-name UserProfiles \
     --item '{
       "userId": {"S": "user123"},
       "name": {"S": "John Doe"},
       "email": {"S": "john@example.com"},
       "preferences": {"S": "theme:dark,notifications:enabled"}
     }'
   ```

### Step 3: Create Lambda Functions with X-Ray Tracing

1. **Create IAM role for Lambda functions:**
   ```bash
   cat > lambda-trust-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

   aws iam create-role \
     --role-name XRayLambdaRole \
     --assume-role-policy-document file://lambda-trust-policy.json
   ```

2. **Attach necessary policies:**
   ```bash
   aws iam attach-role-policy \
     --role-name XRayLambdaRole \
     --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

   aws iam attach-role-policy \
     --role-name XRayLambdaRole \
     --policy-arn arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess

   aws iam attach-role-policy \
     --role-name XRayLambdaRole \
     --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess
   ```

3. **Create the user service Lambda function:**
   ```bash
   mkdir -p ~/xray-lab/user-service
   cd ~/xray-lab/user-service

   cat > lambda_function.py << 'EOF'
import json
import boto3
import os
from aws_xray_sdk.core import xray_recorder
from aws_xray_sdk.core import patch_all

# Patch AWS SDK calls for automatic tracing
patch_all()

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('UserProfiles')

@xray_recorder.capture('lambda_handler')
def lambda_handler(event, context):
    # Create a custom segment for business logic
    subsegment = xray_recorder.begin_subsegment('user_processing')
    
    try:
        # Add annotations for filtering traces
        xray_recorder.put_annotation('service', 'user-service')
        xray_recorder.put_annotation('operation', event.get('httpMethod', 'unknown'))
        
        # Add metadata for additional context
        xray_recorder.put_metadata('request_info', {
            'path': event.get('path', ''),
            'user_agent': event.get('headers', {}).get('User-Agent', ''),
            'source_ip': event.get('requestContext', {}).get('identity', {}).get('sourceIp', '')
        })
        
        # Extract user ID from path
        path_parts = event.get('path', '').split('/')
        user_id = path_parts[-1] if len(path_parts) > 2 else 'user123'
        
        # Simulate some processing time
        import time
        time.sleep(0.1)
        
        # Get user from DynamoDB
        response = table.get_item(Key={'userId': user_id})
        
        if 'Item' in response:
            user_data = response['Item']
            # Convert DynamoDB types to regular Python types
            user_profile = {
                'userId': user_data['userId'],
                'name': user_data['name'],
                'email': user_data['email'],
                'preferences': user_data['preferences']
            }
            
            xray_recorder.put_annotation('user_found', True)
            
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps(user_profile)
            }
        else:
            xray_recorder.put_annotation('user_found', False)
            
            return {
                'statusCode': 404,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({'error': 'User not found'})
            }
            
    except Exception as e:
        xray_recorder.put_annotation('error', True)
        xray_recorder.put_metadata('error_details', str(e))
        
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'error': 'Internal server error'})
        }
    finally:
        xray_recorder.end_subsegment()

EOF
   ```

4. **Create requirements.txt:**
   ```bash
   cat > requirements.txt << 'EOF'
aws-xray-sdk==2.12.0
boto3==1.26.137
EOF
   ```

5. **Install dependencies and create deployment package:**
   ```bash
   pip install -r requirements.txt -t .
   zip -r user-service.zip .
   ```

6. **Deploy the Lambda function:**
   ```bash
   aws lambda create-function \
     --function-name user-service \
     --runtime python3.9 \
     --role arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/XRayLambdaRole \
     --handler lambda_function.lambda_handler \
     --zip-file fileb://user-service.zip \
     --timeout 30 \
     --tracing-config Mode=Active
   ```

### Step 4: Create API Gateway with X-Ray Tracing

1. **Create REST API:**
   ```bash
   API_ID=$(aws apigateway create-rest-api \
     --name "user-api" \
     --description "User service API with X-Ray tracing" \
     --query 'id' --output text)
   
   echo "API ID: $API_ID"
   ```

2. **Get the root resource ID:**
   ```bash
   ROOT_RESOURCE_ID=$(aws apigateway get-resources \
     --rest-api-id $API_ID \
     --query 'items[0].id' --output text)
   ```

3. **Create resource for users:**
   ```bash
   USERS_RESOURCE_ID=$(aws apigateway create-resource \
     --rest-api-id $API_ID \
     --parent-id $ROOT_RESOURCE_ID \
     --path-part "users" \
     --query 'id' --output text)
   ```

4. **Create resource for user ID:**
   ```bash
   USER_ID_RESOURCE_ID=$(aws apigateway create-resource \
     --rest-api-id $API_ID \
     --parent-id $USERS_RESOURCE_ID \
     --path-part "{userId}" \
     --query 'id' --output text)
   ```

5. **Create GET method:**
   ```bash
   aws apigateway put-method \
     --rest-api-id $API_ID \
     --resource-id $USER_ID_RESOURCE_ID \
     --http-method GET \
     --authorization-type NONE
   ```

6. **Set up Lambda integration:**
   ```bash
   ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
   REGION=$(aws configure get region)
   
   aws apigateway put-integration \
     --rest-api-id $API_ID \
     --resource-id $USER_ID_RESOURCE_ID \
     --http-method GET \
     --type AWS_PROXY \
     --integration-http-method POST \
     --uri "arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/arn:aws:lambda:$REGION:$ACCOUNT_ID:function:user-service/invocations"
   ```

7. **Grant API Gateway permission to invoke Lambda:**
   ```bash
   aws lambda add-permission \
     --function-name user-service \
     --statement-id apigateway-invoke \
     --action lambda:InvokeFunction \
     --principal apigateway.amazonaws.com \
     --source-arn "arn:aws:execute-api:$REGION:$ACCOUNT_ID:$API_ID/*/*"
   ```

8. **Deploy the API:**
   ```bash
   aws apigateway create-deployment \
     --rest-api-id $API_ID \
     --stage-name prod
   ```

9. **Enable X-Ray tracing for API Gateway:**
   ```bash
   aws apigateway update-stage \
     --rest-api-id $API_ID \
     --stage-name prod \
     --patch-ops op=replace,path=/tracingEnabled,value=true
   ```

### Step 5: Test the Application and Generate Traces

1. **Get the API endpoint:**
   ```bash
   API_ENDPOINT="https://$API_ID.execute-api.$REGION.amazonaws.com/prod"
   echo "API Endpoint: $API_ENDPOINT"
   ```

2. **Test the API to generate traces:**
   ```bash
   # Test successful request
   curl "$API_ENDPOINT/users/user123"
   
   # Test not found request
   curl "$API_ENDPOINT/users/nonexistent"
   
   # Generate multiple requests for better trace data
   for i in {1..10}; do
     curl -s "$API_ENDPOINT/users/user123" > /dev/null
     sleep 1
   done
   ```

3. **Create a load testing script:**
   ```bash
   cd ~/xray-lab
   cat > load_test.py << 'EOF'
#!/usr/bin/env python3
import requests
import time
import random
import threading
import sys

def make_request(api_endpoint, user_id):
    try:
        response = requests.get(f"{api_endpoint}/users/{user_id}")
        print(f"Request to {user_id}: {response.status_code}")
    except Exception as e:
        print(f"Error: {e}")

def load_test(api_endpoint, duration=60):
    end_time = time.time() + duration
    user_ids = ['user123', 'user456', 'nonexistent', 'user789']
    
    while time.time() < end_time:
        user_id = random.choice(user_ids)
        thread = threading.Thread(target=make_request, args=(api_endpoint, user_id))
        thread.start()
        time.sleep(random.uniform(0.5, 2.0))

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 load_test.py <API_ENDPOINT>")
        sys.exit(1)
    
    api_endpoint = sys.argv[1]
    print(f"Starting load test against {api_endpoint}")
    load_test(api_endpoint)
EOF

   chmod +x load_test.py
   ```

4. **Run the load test:**
   ```bash
   python3 load_test.py "$API_ENDPOINT"
   ```

### Step 6: Analyze Traces in X-Ray Console

1. **Get trace summaries via CLI:**
   ```bash
   # Get traces from the last 10 minutes
   START_TIME=$(date -d '10 minutes ago' -u +%s)
   END_TIME=$(date -u +%s)
   
   aws xray get-trace-summaries \
     --time-range-type TimeRangeByStartTime \
     --start-time $START_TIME \
     --end-time $END_TIME \
     --query 'TraceSummaries[0:5].[Id,Duration,ResponseTime,HasError]' \
     --output table
   ```

2. **Get detailed trace information:**
   ```bash
   # Get the first trace ID
   TRACE_ID=$(aws xray get-trace-summaries \
     --time-range-type TimeRangeByStartTime \
     --start-time $START_TIME \
     --end-time $END_TIME \
     --query 'TraceSummaries[0].Id' \
     --output text)
   
   # Get trace details
   aws xray batch-get-traces --trace-ids $TRACE_ID
   ```

3. **Query traces with filter expressions:**
   ```bash
   # Find traces with errors
   aws xray get-trace-summaries \
     --time-range-type TimeRangeByStartTime \
     --start-time $START_TIME \
     --end-time $END_TIME \
     --filter-expression "error = true"
   
   # Find traces for specific service
   aws xray get-trace-summaries \
     --time-range-type TimeRangeByStartTime \
     --start-time $START_TIME \
     --end-time $END_TIME \
     --filter-expression "service(\"user-service\")"
   ```

## Troubleshooting Guide

### Common Issues and Solutions

1. **Traces not appearing in X-Ray:**
   - Verify X-Ray tracing is enabled on Lambda functions and API Gateway
   - Check IAM permissions for X-Ray daemon write access
   - Ensure X-Ray SDK is properly imported and configured
   - Wait 2-3 minutes for traces to appear in the console

2. **Lambda function timing out:**
   - Increase Lambda timeout setting
   - Check for infinite loops or blocking operations
   - Review CloudWatch logs for error details
   - Verify DynamoDB table exists and is accessible

3. **API Gateway returning 500 errors:**
   - Check Lambda function logs in CloudWatch
   - Verify Lambda integration configuration
   - Ensure proper IAM permissions for API Gateway to invoke Lambda
   - Test Lambda function directly first

4. **Missing trace segments:**
   - Verify all AWS SDK calls are patched with `patch_all()`
   - Check that custom segments are properly closed
   - Ensure subsegments are created within active segments

### Debugging Commands

```bash
# Check Lambda function configuration
aws lambda get-function-configuration --function-name user-service

# View Lambda function logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/user-service"

# Test Lambda function directly
aws lambda invoke \
  --function-name user-service \
  --payload '{"httpMethod":"GET","path":"/users/user123"}' \
  response.json

# Check API Gateway configuration
aws apigateway get-rest-api --rest-api-id $API_ID

# View X-Ray service statistics
aws xray get-service-graph \
  --start-time $(date -d '1 hour ago' -u +%s) \
  --end-time $(date -u +%s)
```

## Resources Created

This lab creates the following AWS resources:

### Compute and API
- **Lambda Function**: user-service with X-Ray tracing enabled
- **API Gateway**: REST API with X-Ray tracing and Lambda integration
- **IAM Role**: XRayLambdaRole with necessary permissions

### Data and Monitoring
- **DynamoDB Table**: UserProfiles for application data
- **X-Ray Sampling Rules**: Custom sampling configuration
- **X-Ray Traces**: Distributed tracing data

### Estimated Costs
- Lambda: $0.20 per 1M requests + $0.0000166667 per GB-second
- API Gateway: $3.50 per million API calls
- DynamoDB: $0.25 per million read/write requests (on-demand)
- X-Ray: $5.00 per million traces recorded + $0.50 per million traces retrieved
- **Total estimated cost**: $2-5/month for moderate usage (some free tier eligible)

## Cleanup

When you're finished with the lab, follow these steps to avoid ongoing charges:

1. **Delete API Gateway:**
   ```bash
   aws apigateway delete-rest-api --rest-api-id $API_ID
   ```

2. **Delete Lambda function:**
   ```bash
   aws lambda delete-function --function-name user-service
   ```

3. **Delete IAM role:**
   ```bash
   aws iam detach-role-policy --role-name XRayLambdaRole --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
   aws iam detach-role-policy --role-name XRayLambdaRole --policy-arn arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess
   aws iam detach-role-policy --role-name XRayLambdaRole --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess
   aws iam delete-role --role-name XRayLambdaRole
   ```

4. **Delete DynamoDB table:**
   ```bash
   aws dynamodb delete-table --table-name UserProfiles
   ```

5. **Delete X-Ray sampling rules:**
   ```bash
   # List and delete custom sampling rules
   aws xray get-sampling-rules --query 'SamplingRuleRecords[?SamplingRule.RuleName!=`Default`].SamplingRule.RuleName' --output text | xargs -I {} aws xray delete-sampling-rule --rule-name {}
   ```

6. **Clean up local files:**
   ```bash
   rm -rf ~/xray-lab
   ```

> **Important**: X-Ray trace data is automatically deleted after 30 days. No manual cleanup is required for trace data.

## Next Steps

After completing this lab, consider:

1. **Implement X-Ray in containerized applications** using ECS or EKS
2. **Explore X-Ray Analytics** for advanced trace analysis and insights
3. **Set up X-Ray with AWS AppMesh** for service mesh observability
4. **Integrate X-Ray with CloudWatch** for comprehensive monitoring
5. **Implement custom X-Ray plugins** for third-party service tracing

## Certification Exam Tips

This lab covers several key areas for the AWS DevOps Professional exam:

- **Domain 1**: SDLC Automation (Monitoring in CI/CD pipelines)
- **Domain 3**: Monitoring and Logging (Distributed tracing and observability)
- **Domain 4**: Policies and Standards Automation (Automated monitoring setup)

Key concepts to remember:
- X-Ray traces requests across multiple services and provides end-to-end visibility
- Sampling rules control the amount of data recorded to manage costs
- Annotations are indexed and can be used for filtering traces
- Metadata provides additional context but is not indexed
- X-Ray integrates natively with Lambda, API Gateway, ECS, and other AWS services
- The X-Ray daemon must be running to collect and forward trace data
- Service maps provide visual representation of application architecture and dependencies

## Additional Resources

- [AWS X-Ray Developer Guide](https://docs.aws.amazon.com/xray/latest/devguide/)
- [X-Ray SDK for Python](https://docs.aws.amazon.com/xray/latest/devguide/xray-sdk-python.html)
- [X-Ray Sampling Rules](https://docs.aws.amazon.com/xray/latest/devguide/xray-console-sampling.html)
- [Debugging with X-Ray](https://docs.aws.amazon.com/xray/latest/devguide/xray-console.html)
- [X-Ray Best Practices](https://docs.aws.amazon.com/xray/latest/devguide/xray-usage.html)