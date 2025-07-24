# Serverless Integration Patterns Lab Guide

## Objective
Learn how to implement serverless integration patterns using AWS Lambda, demonstrating how to build, deploy, and integrate serverless functions with other AWS services to create scalable, event-driven architectures.

## Learning Outcomes
By completing this lab, you will:
- Design and implement event-driven architectures using AWS Lambda
- Configure various Lambda triggers and destinations
- Implement asynchronous processing patterns with Lambda
- Create service integrations between Lambda and other AWS services
- Monitor and troubleshoot serverless applications

## Prerequisites
- AWS Account with administrative access
- Basic understanding of serverless concepts
- Familiarity with JavaScript or Python programming
- AWS CLI installed and configured

### Required AWS Permissions
Your AWS user/role needs the following permissions:
- Lambda: Full access for creating and managing functions
- IAM: CreateRole, AttachRolePolicy for Lambda execution roles
- CloudWatch: Full access for logs and monitoring
- S3: Full access for bucket operations
- DynamoDB: Full access for table operations
- SNS: Full access for topic and subscription management
- SQS: Full access for queue management
- EventBridge: Full access for rule creation and management

### Time to Complete
Approximately 60-75 minutes

## Architecture Overview

```
┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│               │     │               │     │               │
│  S3 Bucket    │────►│  Lambda       │────►│  DynamoDB     │
│  (Trigger)    │     │  Function 1   │     │  Table        │
│               │     │               │     │               │
└───────────────┘     └───────┬───────┘     └───────────────┘
                              │
                              │
                              ▼
┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│               │     │               │     │               │
│  SNS Topic    │◄────┤  Lambda       │◄────┤  EventBridge  │
│  (Fanout)     │     │  Function 2   │     │  Rule         │
│               │     │               │     │               │
└───────┬───────┘     └───────────────┘     └───────────────┘
        │
        │
┌───────▼───────┐     ┌───────────────┐
│               │     │               │
│  SQS Queue    │────►│  Lambda       │
│  (Buffer)     │     │  Function 3   │
│               │     │               │
└───────────────┘     └───────────────┘
```

### Resources Created:
- **Lambda Functions**: Three functions demonstrating different integration patterns
- **S3 Bucket**: Trigger source for event-based processing
- **DynamoDB Table**: Data storage for processed information
- **SNS Topic**: Message fanout for notifications
- **SQS Queue**: Message buffering for asynchronous processing
- **EventBridge Rule**: Scheduled event trigger
- **IAM Roles**: Execution roles for Lambda functions
- **CloudWatch Log Groups**: Logging for all Lambda functions

## Lab Steps

### Step 1: Create Lambda Execution Role

1. **Create IAM role for Lambda execution:**
   ```bash
   # Create trust policy document
   cat > lambda-trust-policy.json << EOF
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
   
   # Create Lambda execution role
   aws iam create-role \
     --role-name lambda-integration-role \
     --assume-role-policy-document file://lambda-trust-policy.json
   
   # Attach policies for Lambda execution, S3, DynamoDB, SNS, and SQS
   aws iam attach-role-policy \
     --role-name lambda-integration-role \
     --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
   
   aws iam attach-role-policy \
     --role-name lambda-integration-role \
     --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
   
   aws iam attach-role-policy \
     --role-name lambda-integration-role \
     --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess
   
   aws iam attach-role-policy \
     --role-name lambda-integration-role \
     --policy-arn arn:aws:iam::aws:policy/AmazonSNSFullAccess
   
   aws iam attach-role-policy \
     --role-name lambda-integration-role \
     --policy-arn arn:aws:iam::aws:policy/AmazonSQSFullAccess
   ```

2. **Verify role creation:**
   ```bash
   # Verify role was created
   aws iam get-role --role-name lambda-integration-role
   ```

### Step 2: Create DynamoDB Table

1. **Create DynamoDB table for storing processed data:**
   ```bash
   # Create DynamoDB table
   aws dynamodb create-table \
     --table-name lambda-integration-data \
     --attribute-definitions AttributeName=id,AttributeType=S \
     --key-schema AttributeName=id,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST
   ```

2. **Verify table creation:**
   ```bash
   # Verify table was created
   aws dynamodb describe-table --table-name lambda-integration-data
   ```
   
   Expected output should show the table with status "ACTIVE".

### Step 3: Create S3 Bucket and Configure Event Notifications

1. **Create S3 bucket for file uploads:**
   ```bash
   # Create a unique bucket name
   BUCKET_NAME=lambda-integration-$(aws sts get-caller-identity --query Account --output text)-$(date +%s)
   
   # Create S3 bucket
   aws s3api create-bucket \
     --bucket $BUCKET_NAME \
     --create-bucket-configuration LocationConstraint=$(aws configure get region)
   
   echo "Created bucket: $BUCKET_NAME"
   ```

2. **Enable bucket versioning:**
   ```bash
   # Enable versioning
   aws s3api put-bucket-versioning \
     --bucket $BUCKET_NAME \
     --versioning-configuration Status=Enabled
   ```

### Step 4: Create First Lambda Function (S3 to DynamoDB)

1. **Create Lambda function code:**
   ```bash
   # Create directory for Lambda code
   mkdir -p lambda-functions/s3-processor
   
   # Create Lambda function code
   cat > lambda-functions/s3-processor/index.js << EOF
   const AWS = require('aws-sdk');
   const dynamodb = new AWS.DynamoDB.DocumentClient();
   const s3 = new AWS.S3();
   
   exports.handler = async (event) => {
     console.log('Received event:', JSON.stringify(event, null, 2));
     
     try {
       // Process each S3 event record
       for (const record of event.Records) {
         const bucket = record.s3.bucket.name;
         const key = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));
         
         // Get the object from S3
         const s3Object = await s3.getObject({
           Bucket: bucket,
           Key: key
         }).promise();
         
         // Parse the content (assuming it's JSON)
         let content;
         try {
           content = JSON.parse(s3Object.Body.toString('utf-8'));
         } catch (e) {
           content = {
             rawContent: s3Object.Body.toString('utf-8'),
             contentType: s3Object.ContentType
           };
         }
         
         // Store in DynamoDB
         const item = {
           id: \`\${bucket}-\${key}-\${Date.now()}\`,
           fileName: key,
           bucket: bucket,
           content: content,
           processedAt: new Date().toISOString()
         };
         
         await dynamodb.put({
           TableName: 'lambda-integration-data',
           Item: item
         }).promise();
         
         console.log(\`Successfully processed \${key} and stored in DynamoDB\`);
       }
       
       return {
         statusCode: 200,
         body: \`Successfully processed \${event.Records.length} records\`
       };
     } catch (error) {
       console.error('Error processing S3 event:', error);
       throw error;
     }
   };
   EOF
   
   # Create ZIP file for Lambda deployment
   cd lambda-functions/s3-processor
   zip -r function.zip index.js
   cd ../../
   ```

2. **Create Lambda function:**
   ```bash
   # Get role ARN
   ROLE_ARN=$(aws iam get-role --role-name lambda-integration-role --query 'Role.Arn' --output text)
   
   # Create Lambda function
   aws lambda create-function \
     --function-name s3-to-dynamodb-processor \
     --runtime nodejs18.x \
     --handler index.handler \
     --role $ROLE_ARN \
     --zip-file fileb://lambda-functions/s3-processor/function.zip \
     --timeout 30 \
     --memory-size 256
   ```

3. **Configure S3 event trigger:**
   ```bash
   # Get Lambda function ARN
   LAMBDA_ARN=$(aws lambda get-function --function-name s3-to-dynamodb-processor --query 'Configuration.FunctionArn' --output text)
   
   # Add permission for S3 to invoke Lambda
   aws lambda add-permission \
     --function-name s3-to-dynamodb-processor \
     --statement-id s3-trigger \
     --action lambda:InvokeFunction \
     --principal s3.amazonaws.com \
     --source-arn arn:aws:s3:::$BUCKET_NAME
   
   # Configure S3 event notification
   cat > notification-config.json << EOF
   {
     "LambdaFunctionConfigurations": [
       {
         "LambdaFunctionArn": "$LAMBDA_ARN",
         "Events": ["s3:ObjectCreated:*"],
         "Filter": {
           "Key": {
             "FilterRules": [
               {
                 "Name": "suffix",
                 "Value": ".json"
               }
             ]
           }
         }
       }
     ]
   }
   EOF
   
   aws s3api put-bucket-notification-configuration \
     --bucket $BUCKET_NAME \
     --notification-configuration file://notification-config.json
   ```

### Step 5: Create SNS Topic and SQS Queue

1. **Create SNS topic for notifications:**
   ```bash
   # Create SNS topic
   aws sns create-topic --name lambda-integration-notifications
   
   # Get SNS topic ARN
   SNS_TOPIC_ARN=$(aws sns create-topic --name lambda-integration-notifications --query 'TopicArn' --output text)
   ```

2. **Create SQS queue for message buffering:**
   ```bash
   # Create SQS queue
   aws sqs create-queue --queue-name lambda-integration-queue
   
   # Get SQS queue URL and ARN
   SQS_QUEUE_URL=$(aws sqs get-queue-url --queue-name lambda-integration-queue --query 'QueueUrl' --output text)
   SQS_QUEUE_ARN=$(aws sqs get-queue-attributes --queue-url $SQS_QUEUE_URL --attribute-names QueueArn --query 'Attributes.QueueArn' --output text)
   ```

3. **Subscribe SQS queue to SNS topic:**
   ```bash
   # Subscribe SQS to SNS
   aws sns subscribe \
     --topic-arn $SNS_TOPIC_ARN \
     --protocol sqs \
     --notification-endpoint $SQS_QUEUE_ARN
   
   # Set SQS policy to allow SNS to send messages
   cat > sqs-policy.json << EOF
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": {
           "Service": "sns.amazonaws.com"
         },
         "Action": "sqs:SendMessage",
         "Resource": "$SQS_QUEUE_ARN",
         "Condition": {
           "ArnEquals": {
             "aws:SourceArn": "$SNS_TOPIC_ARN"
           }
         }
       }
     ]
   }
   EOF
   
   aws sqs set-queue-attributes \
     --queue-url $SQS_QUEUE_URL \
     --attributes '{"Policy": '$(cat sqs-policy.json | jq -c .)'}'
   ```

### Step 6: Create Second Lambda Function (EventBridge to SNS)

1. **Create Lambda function code:**
   ```bash
   # Create directory for Lambda code
   mkdir -p lambda-functions/event-processor
   
   # Create Lambda function code
   cat > lambda-functions/event-processor/index.js << EOF
   const AWS = require('aws-sdk');
   const sns = new AWS.SNS();
   const dynamodb = new AWS.DynamoDB.DocumentClient();
   
   exports.handler = async (event) => {
     console.log('Received event:', JSON.stringify(event, null, 2));
     
     try {
       // Get latest items from DynamoDB
       const dynamoResult = await dynamodb.scan({
         TableName: 'lambda-integration-data',
         Limit: 10
       }).promise();
       
       const items = dynamoResult.Items || [];
       
       // Create summary message
       const summary = {
         timestamp: new Date().toISOString(),
         itemCount: items.length,
         latestItems: items.map(item => ({
           id: item.id,
           fileName: item.fileName,
           processedAt: item.processedAt
         }))
       };
       
       // Publish to SNS topic
       await sns.publish({
         TopicArn: process.env.SNS_TOPIC_ARN,
         Message: JSON.stringify(summary, null, 2),
         Subject: 'Lambda Integration - Periodic Summary'
       }).promise();
       
       console.log('Successfully published summary to SNS');
       
       return {
         statusCode: 200,
         body: 'Successfully published summary to SNS'
       };
     } catch (error) {
       console.error('Error processing event:', error);
       throw error;
     }
   };
   EOF
   
   # Create ZIP file for Lambda deployment
   cd lambda-functions/event-processor
   zip -r function.zip index.js
   cd ../../
   ```

2. **Create Lambda function:**
   ```bash
   # Create Lambda function
   aws lambda create-function \
     --function-name event-to-sns-processor \
     --runtime nodejs18.x \
     --handler index.handler \
     --role $ROLE_ARN \
     --zip-file fileb://lambda-functions/event-processor/function.zip \
     --timeout 30 \
     --memory-size 256 \
     --environment "Variables={SNS_TOPIC_ARN=$SNS_TOPIC_ARN}"
   ```

3. **Create EventBridge rule for scheduled invocation:**
   ```bash
   # Create EventBridge rule
   aws events put-rule \
     --name lambda-integration-schedule \
     --schedule-expression "rate(5 minutes)"
   
   # Get rule ARN
   RULE_ARN=$(aws events describe-rule --name lambda-integration-schedule --query 'Arn' --output text)
   
   # Add permission for EventBridge to invoke Lambda
   aws lambda add-permission \
     --function-name event-to-sns-processor \
     --statement-id eventbridge-trigger \
     --action lambda:InvokeFunction \
     --principal events.amazonaws.com \
     --source-arn $RULE_ARN
   
   # Set Lambda as target for EventBridge rule
   aws events put-targets \
     --rule lambda-integration-schedule \
     --targets "Id"="1","Arn"="$(aws lambda get-function --function-name event-to-sns-processor --query 'Configuration.FunctionArn' --output text)"
   ```

### Step 7: Create Third Lambda Function (SQS to Processing)

1. **Create Lambda function code:**
   ```bash
   # Create directory for Lambda code
   mkdir -p lambda-functions/queue-processor
   
   # Create Lambda function code
   cat > lambda-functions/queue-processor/index.js << EOF
   const AWS = require('aws-sdk');
   const dynamodb = new AWS.DynamoDB.DocumentClient();
   
   exports.handler = async (event) => {
     console.log('Received event:', JSON.stringify(event, null, 2));
     
     try {
       // Process each SQS message
       for (const record of event.Records) {
         const body = JSON.parse(record.body);
         const message = JSON.parse(body.Message);
         
         console.log('Processing message:', JSON.stringify(message, null, 2));
         
         // Store summary in DynamoDB
         const item = {
           id: \`summary-\${Date.now()}\`,
           type: 'summary',
           timestamp: message.timestamp,
           itemCount: message.itemCount,
           processedAt: new Date().toISOString()
         };
         
         await dynamodb.put({
           TableName: 'lambda-integration-data',
           Item: item
         }).promise();
         
         console.log('Successfully stored summary in DynamoDB');
       }
       
       return {
         statusCode: 200,
         body: \`Successfully processed \${event.Records.length} messages\`
       };
     } catch (error) {
       console.error('Error processing SQS message:', error);
       throw error;
     }
   };
   EOF
   
   # Create ZIP file for Lambda deployment
   cd lambda-functions/queue-processor
   zip -r function.zip index.js
   cd ../../
   ```

2. **Create Lambda function:**
   ```bash
   # Create Lambda function
   aws lambda create-function \
     --function-name sqs-processor \
     --runtime nodejs18.x \
     --handler index.handler \
     --role $ROLE_ARN \
     --zip-file fileb://lambda-functions/queue-processor/function.zip \
     --timeout 30 \
     --memory-size 256
   ```

3. **Configure SQS event source mapping:**
   ```bash
   # Create event source mapping
   aws lambda create-event-source-mapping \
     --function-name sqs-processor \
     --event-source-arn $SQS_QUEUE_ARN \
     --batch-size 10
   ```

### Step 8: Test the Integration Pattern

1. **Create a test JSON file and upload to S3:**
   ```bash
   # Create test JSON file
   cat > test-data.json << EOF
   {
     "id": "test-item-1",
     "name": "Test Item",
     "description": "This is a test item for Lambda integration",
     "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
   }
   EOF
   
   # Upload to S3
   aws s3 cp test-data.json s3://$BUCKET_NAME/
   ```

2. **Verify data in DynamoDB:**
   ```bash
   # Wait a few seconds for processing
   echo "Waiting for Lambda to process the file..."
   sleep 10
   
   # Query DynamoDB
   aws dynamodb scan --table-name lambda-integration-data
   ```
   
   Expected output should show the processed item with data from your test file.

3. **Manually trigger the EventBridge Lambda:**
   ```bash
   # Invoke Lambda function
   aws lambda invoke \
     --function-name event-to-sns-processor \
     --payload '{}' \
     response.json
   
   # Check response
   cat response.json
   ```

4. **Verify SQS message processing:**
   ```bash
   # Wait for message processing
   echo "Waiting for message to be processed through SNS and SQS..."
   sleep 20
   
   # Check DynamoDB for summary record
   aws dynamodb scan \
     --table-name lambda-integration-data \
     --filter-expression "begins_with(id, :prefix)" \
     --expression-attribute-values '{":prefix": {"S": "summary-"}}'
   ```

## Troubleshooting Guide

### Common Issues and Solutions

1. **Lambda function fails with permission errors:**
   - Check IAM role permissions to ensure it has access to all required services
   - Verify that the Lambda execution role has the correct trust relationship
   - Check CloudWatch Logs for specific permission errors

2. **S3 event notifications not triggering Lambda:**
   - Verify bucket notification configuration is correct
   - Check that Lambda has permission to be invoked by S3
   - Ensure file suffix matches the filter (.json)

3. **SNS to SQS integration not working:**
   - Verify SQS queue policy allows SNS to send messages
   - Check SNS subscription status is "confirmed"
   - Ensure the SQS queue ARN in the SNS subscription is correct

4. **EventBridge scheduled rule not triggering:**
   - Verify the rule is enabled
   - Check that the Lambda function has permission to be invoked by EventBridge
   - Ensure the target configuration is correct

### Debugging Commands

```bash
# Check Lambda function logs
aws logs get-log-events \
  --log-group-name /aws/lambda/s3-to-dynamodb-processor \
  --log-stream-name $(aws logs describe-log-streams \
    --log-group-name /aws/lambda/s3-to-dynamodb-processor \
    --order-by LastEventTime \
    --descending \
    --limit 1 \
    --query 'logStreams[0].logStreamName' \
    --output text)

# Test SQS queue by sending and receiving a message
aws sqs send-message \
  --queue-url $SQS_QUEUE_URL \
  --message-body '{"test": "message"}'

aws sqs receive-message \
  --queue-url $SQS_QUEUE_URL \
  --max-number-of-messages 10

# Check SNS subscription status
aws sns list-subscriptions-by-topic --topic-arn $SNS_TOPIC_ARN
```

## Resources Created

This lab creates the following AWS resources:

### Compute
- **Lambda Functions**: Three Node.js functions for different integration patterns
- **IAM Role**: Execution role with permissions for Lambda functions

### Storage
- **S3 Bucket**: For file uploads that trigger Lambda processing
- **DynamoDB Table**: NoSQL database for storing processed data

### Messaging
- **SNS Topic**: For message fanout and notifications
- **SQS Queue**: For message buffering and asynchronous processing

### Event Management
- **EventBridge Rule**: For scheduled Lambda invocation

### Monitoring
- **CloudWatch Log Groups**: One for each Lambda function

### Estimated Costs
- Lambda: Free tier includes 1M requests/month and 400,000 GB-seconds/month
- S3: Free tier includes 5GB storage, 20,000 GET requests, 2,000 PUT requests
- DynamoDB: Free tier includes 25 WCU and 25 RCU
- SNS: Free tier includes 1M publishes
- SQS: Free tier includes 1M requests
- EventBridge: $1.00 per million events
- **Total estimated cost**: $0-2/month (mostly free tier eligible)

## Cleanup

When you're finished with the lab, follow these steps to avoid ongoing charges:

1. **Delete Lambda functions and event source mappings:**
   ```bash
   # Delete event source mapping
   MAPPING_UUID=$(aws lambda list-event-source-mappings \
     --function-name sqs-processor \
     --event-source-arn $SQS_QUEUE_ARN \
     --query 'EventSourceMappings[0].UUID' \
     --output text)
   
   aws lambda delete-event-source-mapping --uuid $MAPPING_UUID
   
   # Delete Lambda functions
   aws lambda delete-function --function-name s3-to-dynamodb-processor
   aws lambda delete-function --function-name event-to-sns-processor
   aws lambda delete-function --function-name sqs-processor
   ```

2. **Delete EventBridge rule:**
   ```bash
   # Remove target from rule
   aws events remove-targets \
     --rule lambda-integration-schedule \
     --ids "1"
   
   # Delete rule
   aws events delete-rule --name lambda-integration-schedule
   ```

3. **Delete SNS topic and SQS queue:**
   ```bash
   # Delete SNS topic
   aws sns delete-topic --topic-arn $SNS_TOPIC_ARN
   
   # Delete SQS queue
   aws sqs delete-queue --queue-url $SQS_QUEUE_URL
   ```

4. **Delete S3 bucket:**
   ```bash
   # Empty S3 bucket
   aws s3 rm s3://$BUCKET_NAME --recursive
   
   # Delete S3 bucket
   aws s3api delete-bucket --bucket $BUCKET_NAME
   ```

5. **Delete DynamoDB table:**
   ```bash
   # Delete DynamoDB table
   aws dynamodb delete-table --table-name lambda-integration-data
   ```

6. **Delete IAM role:**
   ```bash
   # Detach policies
   aws iam detach-role-policy \
     --role-name lambda-integration-role \
     --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
   
   aws iam detach-role-policy \
     --role-name lambda-integration-role \
     --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
   
   aws iam detach-role-policy \
     --role-name lambda-integration-role \
     --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess
   
   aws iam detach-role-policy \
     --role-name lambda-integration-role \
     --policy-arn arn:aws:iam::aws:policy/AmazonSNSFullAccess
   
   aws iam detach-role-policy \
     --role-name lambda-integration-role \
     --policy-arn arn:aws:iam::aws:policy/AmazonSQSFullAccess
   
   # Delete role
   aws iam delete-role --role-name lambda-integration-role
   ```

7. **Verify cleanup:**
   ```bash
   # Verify Lambda functions are deleted
   aws lambda list-functions --query 'Functions[?starts_with(FunctionName, `s3-to-dynamodb`) || starts_with(FunctionName, `event-to-sns`) || starts_with(FunctionName, `sqs-processor`)]'
   
   # Verify DynamoDB table is deleted
   aws dynamodb describe-table --table-name lambda-integration-data || echo "Table deleted successfully"
   ```

> **Important**: Failure to delete resources may result in unexpected charges to your AWS account.

## Next Steps

After completing this lab, consider:

1. **Implement error handling and dead-letter queues** for Lambda functions
2. **Add API Gateway integration** to create RESTful APIs with Lambda backends
3. **Implement Step Functions** for complex serverless workflows
4. **Add authentication and authorization** using Amazon Cognito
5. **Implement custom metrics and alarms** for serverless applications

## Certification Exam Tips

This lab covers several key areas for the AWS DevOps Professional exam:

- **Domain 1**: SDLC Automation (Serverless deployment, event-driven architecture)
- **Domain 2**: Configuration Management and IaC (Lambda configuration, event source mapping)
- **Domain 3**: Monitoring and Logging (CloudWatch integration, Lambda logging)
- **Domain 4**: Policies and Standards Automation (IAM roles, resource policies)
- **Domain 5**: Incident and Event Response (Error handling, asynchronous processing)

Key concepts to remember:
- Lambda functions can be triggered by various event sources (S3, EventBridge, SQS)
- Event-driven architectures allow for loose coupling between components
- SNS can be used for fanout patterns to multiple subscribers
- SQS provides buffering and retry capabilities for asynchronous processing
- Lambda execution roles control what services your functions can access
- CloudWatch Logs automatically captures Lambda function output

## Additional Resources

- [AWS Lambda Developer Guide](https://docs.aws.amazon.com/lambda/latest/dg/welcome.html)
- [Serverless Applications Lens - AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/serverless-applications-lens/welcome.html)
- [AWS Serverless Multi-Tier Architectures](https://docs.aws.amazon.com/whitepapers/latest/serverless-multi-tier-architectures-api-gateway-lambda/welcome.html)
- [Building Event-Driven Architectures on AWS](https://aws.amazon.com/blogs/compute/building-event-driven-architectures-on-aws/)
- [AWS Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)