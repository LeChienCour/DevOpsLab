# API Gateway Integration Lab Guide

## Objective
Learn how to implement API Gateway integration patterns with Lambda, demonstrating how to build, deploy, and secure RESTful APIs that connect to serverless backends and other AWS services.

## Learning Outcomes
By completing this lab, you will:
- Design and implement RESTful APIs using Amazon API Gateway
- Configure Lambda integrations for API endpoints
- Implement request/response transformations using mapping templates
- Set up API authentication and authorization
- Deploy and version APIs for different environments
- Monitor and troubleshoot API performance and errors

## Prerequisites
- AWS Account with administrative access
- Basic understanding of REST API concepts
- Familiarity with JavaScript or Python programming
- AWS CLI installed and configured

### Required AWS Permissions
Your AWS user/role needs the following permissions:
- API Gateway: Full access for creating and managing APIs
- Lambda: Full access for creating and managing functions
- IAM: CreateRole, AttachRolePolicy for execution roles
- CloudWatch: Full access for logs and monitoring
- DynamoDB: Full access for table operations (for data storage)
- Cognito: Full access for user pool management (for authentication)

### Time to Complete
Approximately 60-90 minutes

## Architecture Overview

```
┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│               │     │               │     │               │
│  API Gateway  │────►│  Lambda       │────►│  DynamoDB     │
│  REST API     │     │  Functions    │     │  Table        │
│               │     │               │     │               │
└───────┬───────┘     └───────────────┘     └───────────────┘
        │
        │
┌───────▼───────┐     ┌───────────────┐
│               │     │               │
│  Cognito      │     │  CloudWatch   │
│  User Pool    │     │  Logs/Metrics │
│               │     │               │
└───────────────┘     └───────────────┘
```

### Resources Created:
- **API Gateway REST API**: API with multiple endpoints and methods
- **Lambda Functions**: Backend handlers for API operations
- **DynamoDB Table**: Data storage for API resources
- **Cognito User Pool**: Authentication for API access
- **IAM Roles**: Execution roles for Lambda and API Gateway
- **CloudWatch Log Groups**: Logging for API Gateway and Lambda functions

## Lab Steps

### Step 1: Create DynamoDB Table for API Data

1. **Create DynamoDB table for storing API data:**
   ```bash
   # Create DynamoDB table
   aws dynamodb create-table \
     --table-name api-products \
     --attribute-definitions \
       AttributeName=id,AttributeType=S \
     --key-schema \
       AttributeName=id,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST
   ```

2. **Verify table creation:**
   ```bash
   # Verify table was created
   aws dynamodb describe-table --table-name api-products
   ```
   
   Expected output should show the table with status "ACTIVE".

3. **Add sample data to the table:**
   ```bash
   # Add sample product 1
   aws dynamodb put-item \
     --table-name api-products \
     --item '{
       "id": {"S": "prod-001"},
       "name": {"S": "Product One"},
       "price": {"N": "29.99"},
       "description": {"S": "This is the first product"},
       "inStock": {"BOOL": true}
     }'
   
   # Add sample product 2
   aws dynamodb put-item \
     --table-name api-products \
     --item '{
       "id": {"S": "prod-002"},
       "name": {"S": "Product Two"},
       "price": {"N": "59.99"},
       "description": {"S": "This is the second product"},
       "inStock": {"BOOL": true}
     }'
   ```

### Step 2: Create Lambda Functions for API Backend

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
     --role-name api-lambda-role \
     --assume-role-policy-document file://lambda-trust-policy.json
   
   # Attach policies for Lambda execution and DynamoDB access
   aws iam attach-role-policy \
     --role-name api-lambda-role \
     --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
   
   aws iam attach-role-policy \
     --role-name api-lambda-role \
     --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess
   ```

2. **Create Lambda function for GET operations:**
   ```bash
   # Create directory for Lambda code
   mkdir -p lambda-functions/api-get
   
   # Create Lambda function code
   cat > lambda-functions/api-get/index.js << EOF
   const AWS = require('aws-sdk');
   const dynamodb = new AWS.DynamoDB.DocumentClient();
   
   exports.handler = async (event) => {
     console.log('Received event:', JSON.stringify(event, null, 2));
     
     try {
       // Get product ID from path parameter or return all products
       const productId = event.pathParameters ? event.pathParameters.id : null;
       
       let response;
       
       if (productId) {
         // Get specific product
         const result = await dynamodb.get({
           TableName: 'api-products',
           Key: { id: productId }
         }).promise();
         
         if (!result.Item) {
           return {
             statusCode: 404,
             headers: {
               'Content-Type': 'application/json',
               'Access-Control-Allow-Origin': '*'
             },
             body: JSON.stringify({ message: 'Product not found' })
           };
         }
         
         response = result.Item;
       } else {
         // Get all products
         const result = await dynamodb.scan({
           TableName: 'api-products'
         }).promise();
         
         response = result.Items;
       }
       
       return {
         statusCode: 200,
         headers: {
           'Content-Type': 'application/json',
           'Access-Control-Allow-Origin': '*'
         },
         body: JSON.stringify(response)
       };
     } catch (error) {
       console.error('Error processing request:', error);
       
       return {
         statusCode: 500,
         headers: {
           'Content-Type': 'application/json',
           'Access-Control-Allow-Origin': '*'
         },
         body: JSON.stringify({ message: 'Internal server error' })
       };
     }
   };
   EOF
   
   # Create ZIP file for Lambda deployment
   cd lambda-functions/api-get
   zip -r function.zip index.js
   cd ../../
   ```

3. **Create Lambda function for POST operations:**
   ```bash
   # Create directory for Lambda code
   mkdir -p lambda-functions/api-post
   
   # Create Lambda function code
   cat > lambda-functions/api-post/index.js << EOF
   const AWS = require('aws-sdk');
   const dynamodb = new AWS.DynamoDB.DocumentClient();
   const { v4: uuidv4 } = require('uuid');
   
   exports.handler = async (event) => {
     console.log('Received event:', JSON.stringify(event, null, 2));
     
     try {
       // Parse request body
       const requestBody = JSON.parse(event.body);
       
       // Validate required fields
       if (!requestBody.name || !requestBody.price) {
         return {
           statusCode: 400,
           headers: {
             'Content-Type': 'application/json',
             'Access-Control-Allow-Origin': '*'
           },
           body: JSON.stringify({ message: 'Name and price are required fields' })
         };
       }
       
       // Create new product item
       const productId = requestBody.id || \`prod-\${uuidv4().substring(0, 8)}\`;
       const product = {
         id: productId,
         name: requestBody.name,
         price: requestBody.price,
         description: requestBody.description || '',
         inStock: requestBody.inStock !== undefined ? requestBody.inStock : true,
         createdAt: new Date().toISOString()
       };
       
       // Save to DynamoDB
       await dynamodb.put({
         TableName: 'api-products',
         Item: product
       }).promise();
       
       return {
         statusCode: 201,
         headers: {
           'Content-Type': 'application/json',
           'Access-Control-Allow-Origin': '*'
         },
         body: JSON.stringify(product)
       };
     } catch (error) {
       console.error('Error processing request:', error);
       
       return {
         statusCode: 500,
         headers: {
           'Content-Type': 'application/json',
           'Access-Control-Allow-Origin': '*'
         },
         body: JSON.stringify({ message: 'Internal server error' })
       };
     }
   };
   EOF
   
   # Create package.json for dependencies
   cat > lambda-functions/api-post/package.json << EOF
   {
     "name": "api-post-function",
     "version": "1.0.0",
     "description": "Lambda function for API POST operations",
     "main": "index.js",
     "dependencies": {
       "uuid": "^8.3.2"
     }
   }
   EOF
   
   # Install dependencies and create ZIP file
   cd lambda-functions/api-post
   npm install
   zip -r function.zip index.js node_modules
   cd ../../
   ```

4. **Create Lambda function for DELETE operations:**
   ```bash
   # Create directory for Lambda code
   mkdir -p lambda-functions/api-delete
   
   # Create Lambda function code
   cat > lambda-functions/api-delete/index.js << EOF
   const AWS = require('aws-sdk');
   const dynamodb = new AWS.DynamoDB.DocumentClient();
   
   exports.handler = async (event) => {
     console.log('Received event:', JSON.stringify(event, null, 2));
     
     try {
       // Get product ID from path parameter
       const productId = event.pathParameters ? event.pathParameters.id : null;
       
       if (!productId) {
         return {
           statusCode: 400,
           headers: {
             'Content-Type': 'application/json',
             'Access-Control-Allow-Origin': '*'
           },
           body: JSON.stringify({ message: 'Product ID is required' })
         };
       }
       
       // Check if product exists
       const getResult = await dynamodb.get({
         TableName: 'api-products',
         Key: { id: productId }
       }).promise();
       
       if (!getResult.Item) {
         return {
           statusCode: 404,
           headers: {
             'Content-Type': 'application/json',
             'Access-Control-Allow-Origin': '*'
           },
           body: JSON.stringify({ message: 'Product not found' })
         };
       }
       
       // Delete from DynamoDB
       await dynamodb.delete({
         TableName: 'api-products',
         Key: { id: productId }
       }).promise();
       
       return {
         statusCode: 200,
         headers: {
           'Content-Type': 'application/json',
           'Access-Control-Allow-Origin': '*'
         },
         body: JSON.stringify({ message: \`Product \${productId} deleted successfully\` })
       };
     } catch (error) {
       console.error('Error processing request:', error);
       
       return {
         statusCode: 500,
         headers: {
           'Content-Type': 'application/json',
           'Access-Control-Allow-Origin': '*'
         },
         body: JSON.stringify({ message: 'Internal server error' })
       };
     }
   };
   EOF
   
   # Create ZIP file for Lambda deployment
   cd lambda-functions/api-delete
   zip -r function.zip index.js
   cd ../../
   ```

5. **Deploy Lambda functions:**
   ```bash
   # Get role ARN
   ROLE_ARN=$(aws iam get-role --role-name api-lambda-role --query 'Role.Arn' --output text)
   
   # Create GET Lambda function
   aws lambda create-function \
     --function-name api-get-products \
     --runtime nodejs18.x \
     --handler index.handler \
     --role $ROLE_ARN \
     --zip-file fileb://lambda-functions/api-get/function.zip \
     --timeout 10 \
     --memory-size 128
   
   # Create POST Lambda function
   aws lambda create-function \
     --function-name api-create-product \
     --runtime nodejs18.x \
     --handler index.handler \
     --role $ROLE_ARN \
     --zip-file fileb://lambda-functions/api-post/function.zip \
     --timeout 10 \
     --memory-size 128
   
   # Create DELETE Lambda function
   aws lambda create-function \
     --function-name api-delete-product \
     --runtime nodejs18.x \
     --handler index.handler \
     --role $ROLE_ARN \
     --zip-file fileb://lambda-functions/api-delete/function.zip \
     --timeout 10 \
     --memory-size 128
   ```

### Step 3: Create Cognito User Pool for API Authentication

1. **Create Cognito User Pool:**
   ```bash
   # Create User Pool
   aws cognito-idp create-user-pool \
     --pool-name api-user-pool \
     --policies '{"PasswordPolicy":{"MinimumLength":8,"RequireUppercase":true,"RequireLowercase":true,"RequireNumbers":true,"RequireSymbols":false}}' \
     --auto-verified-attributes email
   
   # Get User Pool ID
   USER_POOL_ID=$(aws cognito-idp list-user-pools --max-results 10 --query 'UserPools[?Name==`api-user-pool`].Id' --output text)
   ```

2. **Create User Pool Client:**
   ```bash
   # Create User Pool Client
   aws cognito-idp create-user-pool-client \
     --user-pool-id $USER_POOL_ID \
     --client-name api-client \
     --no-generate-secret \
     --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH
   
   # Get Client ID
   CLIENT_ID=$(aws cognito-idp list-user-pool-clients --user-pool-id $USER_POOL_ID --query 'UserPoolClients[0].ClientId' --output text)
   ```

3. **Create test user:**
   ```bash
   # Create test user
   aws cognito-idp admin-create-user \
     --user-pool-id $USER_POOL_ID \
     --username testuser \
     --temporary-password Test@123 \
     --user-attributes Name=email,Value=test@example.com Name=email_verified,Value=true
   
   # Set permanent password
   aws cognito-idp admin-set-user-password \
     --user-pool-id $USER_POOL_ID \
     --username testuser \
     --password Test@123 \
     --permanent
   ```

### Step 4: Create API Gateway REST API

1. **Create REST API:**
   ```bash
   # Create API
   aws apigateway create-rest-api \
     --name products-api \
     --description "API for product management" \
     --endpoint-configuration '{"types":["REGIONAL"]}'
   
   # Get API ID
   API_ID=$(aws apigateway get-rest-apis --query 'items[?name==`products-api`].id' --output text)
   
   # Get root resource ID
   ROOT_RESOURCE_ID=$(aws apigateway get-resources --rest-api-id $API_ID --query 'items[?path==`/`].id' --output text)
   ```

2. **Create API resources:**
   ```bash
   # Create /products resource
   aws apigateway create-resource \
     --rest-api-id $API_ID \
     --parent-id $ROOT_RESOURCE_ID \
     --path-part products
   
   # Get products resource ID
   PRODUCTS_RESOURCE_ID=$(aws apigateway get-resources --rest-api-id $API_ID --query 'items[?path==`/products`].id' --output text)
   
   # Create /products/{id} resource
   aws apigateway create-resource \
     --rest-api-id $API_ID \
     --parent-id $PRODUCTS_RESOURCE_ID \
     --path-part "{id}"
   
   # Get product ID resource ID
   PRODUCT_ID_RESOURCE_ID=$(aws apigateway get-resources --rest-api-id $API_ID --query 'items[?path==`/products/{id}`].id' --output text)
   ```

3. **Create API methods and integrations:**
   ```bash
   # Get Lambda ARNs
   GET_LAMBDA_ARN=$(aws lambda get-function --function-name api-get-products --query 'Configuration.FunctionArn' --output text)
   POST_LAMBDA_ARN=$(aws lambda get-function --function-name api-create-product --query 'Configuration.FunctionArn' --output text)
   DELETE_LAMBDA_ARN=$(aws lambda get-function --function-name api-delete-product --query 'Configuration.FunctionArn' --output text)
   
   # Create GET method for /products
   aws apigateway put-method \
     --rest-api-id $API_ID \
     --resource-id $PRODUCTS_RESOURCE_ID \
     --http-method GET \
     --authorization-type NONE
   
   # Create Lambda integration for GET /products
   aws apigateway put-integration \
     --rest-api-id $API_ID \
     --resource-id $PRODUCTS_RESOURCE_ID \
     --http-method GET \
     --type AWS_PROXY \
     --integration-http-method POST \
     --uri arn:aws:apigateway:$(aws configure get region):lambda:path/2015-03-31/functions/$GET_LAMBDA_ARN/invocations
   
   # Create POST method for /products
   aws apigateway put-method \
     --rest-api-id $API_ID \
     --resource-id $PRODUCTS_RESOURCE_ID \
     --http-method POST \
     --authorization-type NONE
   
   # Create Lambda integration for POST /products
   aws apigateway put-integration \
     --rest-api-id $API_ID \
     --resource-id $PRODUCTS_RESOURCE_ID \
     --http-method POST \
     --type AWS_PROXY \
     --integration-http-method POST \
     --uri arn:aws:apigateway:$(aws configure get region):lambda:path/2015-03-31/functions/$POST_LAMBDA_ARN/invocations
   
   # Create GET method for /products/{id}
   aws apigateway put-method \
     --rest-api-id $API_ID \
     --resource-id $PRODUCT_ID_RESOURCE_ID \
     --http-method GET \
     --authorization-type NONE \
     --request-parameters "method.request.path.id=true"
   
   # Create Lambda integration for GET /products/{id}
   aws apigateway put-integration \
     --rest-api-id $API_ID \
     --resource-id $PRODUCT_ID_RESOURCE_ID \
     --http-method GET \
     --type AWS_PROXY \
     --integration-http-method POST \
     --uri arn:aws:apigateway:$(aws configure get region):lambda:path/2015-03-31/functions/$GET_LAMBDA_ARN/invocations
   
   # Create DELETE method for /products/{id}
   aws apigateway put-method \
     --rest-api-id $API_ID \
     --resource-id $PRODUCT_ID_RESOURCE_ID \
     --http-method DELETE \
     --authorization-type NONE \
     --request-parameters "method.request.path.id=true"
   
   # Create Lambda integration for DELETE /products/{id}
   aws apigateway put-integration \
     --rest-api-id $API_ID \
     --resource-id $PRODUCT_ID_RESOURCE_ID \
     --http-method DELETE \
     --type AWS_PROXY \
     --integration-http-method POST \
     --uri arn:aws:apigateway:$(aws configure get region):lambda:path/2015-03-31/functions/$DELETE_LAMBDA_ARN/invocations
   ```

4. **Add Lambda permissions for API Gateway:**
   ```bash
   # Add permissions for Lambda functions
   aws lambda add-permission \
     --function-name api-get-products \
     --statement-id apigateway-get \
     --action lambda:InvokeFunction \
     --principal apigateway.amazonaws.com \
     --source-arn "arn:aws:execute-api:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):$API_ID/*/GET/products"
   
   aws lambda add-permission \
     --function-name api-get-products \
     --statement-id apigateway-get-id \
     --action lambda:InvokeFunction \
     --principal apigateway.amazonaws.com \
     --source-arn "arn:aws:execute-api:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):$API_ID/*/GET/products/*"
   
   aws lambda add-permission \
     --function-name api-create-product \
     --statement-id apigateway-post \
     --action lambda:InvokeFunction \
     --principal apigateway.amazonaws.com \
     --source-arn "arn:aws:execute-api:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):$API_ID/*/POST/products"
   
   aws lambda add-permission \
     --function-name api-delete-product \
     --statement-id apigateway-delete \
     --action lambda:InvokeFunction \
     --principal apigateway.amazonaws.com \
     --source-arn "arn:aws:execute-api:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):$API_ID/*/DELETE/products/*"
   ```

### Step 5: Deploy API and Create Usage Plan

1. **Create API deployment:**
   ```bash
   # Create deployment
   aws apigateway create-deployment \
     --rest-api-id $API_ID \
     --stage-name dev \
     --stage-description "Development Stage" \
     --description "Initial deployment"
   ```

2. **Create API key and usage plan:**
   ```bash
   # Create API key
   aws apigateway create-api-key \
     --name "products-api-key" \
     --description "API key for products API" \
     --enabled
   
   # Get API key ID
   API_KEY_ID=$(aws apigateway get-api-keys --query 'items[?name==`products-api-key`].id' --output text)
   
   # Create usage plan
   aws apigateway create-usage-plan \
     --name "products-api-plan" \
     --description "Usage plan for products API" \
     --throttle burstLimit=10,rateLimit=5 \
     --quota limit=100,offset=0,period=DAY \
     --api-stages apiId=$API_ID,stage=dev
   
   # Get usage plan ID
   USAGE_PLAN_ID=$(aws apigateway get-usage-plans --query 'items[?name==`products-api-plan`].id' --output text)
   
   # Add API key to usage plan
   aws apigateway create-usage-plan-key \
     --usage-plan-id $USAGE_PLAN_ID \
     --key-id $API_KEY_ID \
     --key-type API_KEY
   ```

### Step 6: Test the API

1. **Get API invoke URL:**
   ```bash
   # Get API invoke URL
   API_URL="https://$API_ID.execute-api.$(aws configure get region).amazonaws.com/dev"
   echo "API URL: $API_URL"
   ```

2. **Test GET all products:**
   ```bash
   # Test GET /products
   curl -X GET "$API_URL/products"
   ```

3. **Test GET specific product:**
   ```bash
   # Test GET /products/{id}
   curl -X GET "$API_URL/products/prod-001"
   ```

4. **Test POST to create product:**
   ```bash
   # Test POST /products
   curl -X POST "$API_URL/products" \
     -H "Content-Type: application/json" \
     -d '{
       "name": "New Product",
       "price": 19.99,
       "description": "A newly created product",
       "inStock": true
     }'
   ```

5. **Test DELETE product:**
   ```bash
   # Test DELETE /products/{id}
   curl -X DELETE "$API_URL/products/prod-001"
   ```

### Step 7: Add Cognito Authorizer to API (Optional)

1. **Create Cognito authorizer:**
   ```bash
   # Create authorizer
   aws apigateway create-authorizer \
     --rest-api-id $API_ID \
     --name CognitoAuthorizer \
     --type COGNITO_USER_POOLS \
     --provider-arns arn:aws:cognito-idp:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):userpool/$USER_POOL_ID \
     --identity-source method.request.header.Authorization
   
   # Get authorizer ID
   AUTHORIZER_ID=$(aws apigateway get-authorizers --rest-api-id $API_ID --query 'items[?name==`CognitoAuthorizer`].id' --output text)
   ```

2. **Update API methods to use Cognito authorizer:**
   ```bash
   # Update POST method to use Cognito authorizer
   aws apigateway update-method \
     --rest-api-id $API_ID \
     --resource-id $PRODUCTS_RESOURCE_ID \
     --http-method POST \
     --patch-operations op=replace,path=/authorizationType,value=COGNITO_USER_POOLS \
     op=replace,path=/authorizerId,value=$AUTHORIZER_ID
   
   # Update DELETE method to use Cognito authorizer
   aws apigateway update-method \
     --rest-api-id $API_ID \
     --resource-id $PRODUCT_ID_RESOURCE_ID \
     --http-method DELETE \
     --patch-operations op=replace,path=/authorizationType,value=COGNITO_USER_POOLS \
     op=replace,path=/authorizerId,value=$AUTHORIZER_ID
   ```

3. **Redeploy API:**
   ```bash
   # Create new deployment
   aws apigateway create-deployment \
     --rest-api-id $API_ID \
     --stage-name dev \
     --description "Added Cognito authorizer"
   ```

4. **Test with authentication:**
   ```bash
   # Get authentication token
   AUTH_RESULT=$(aws cognito-idp initiate-auth \
     --auth-flow USER_PASSWORD_AUTH \
     --client-id $CLIENT_ID \
     --auth-parameters USERNAME=testuser,PASSWORD=Test@123)
   
   ID_TOKEN=$(echo $AUTH_RESULT | jq -r '.AuthenticationResult.IdToken')
   
   # Test authenticated POST request
   curl -X POST "$API_URL/products" \
     -H "Content-Type: application/json" \
     -H "Authorization: $ID_TOKEN" \
     -d '{
       "name": "Authenticated Product",
       "price": 39.99,
       "description": "Created with authentication",
       "inStock": true
     }'
   ```

## Troubleshooting Guide

### Common Issues and Solutions

1. **API Gateway 5xx errors:**
   - Check Lambda function logs for errors
   - Verify Lambda execution role has necessary permissions
   - Ensure Lambda function is returning the correct response format

2. **API Gateway 4xx errors:**
   - 400: Check request format and required parameters
   - 401/403: Verify authentication token is valid and not expired
   - 404: Ensure resource paths are correct

3. **Cognito authentication issues:**
   - Verify user exists and password is correct
   - Check that user is confirmed in the user pool
   - Ensure ID token is being passed correctly in the Authorization header

4. **CORS issues when calling from browser:**
   - Verify 'Access-Control-Allow-Origin' header is included in responses
   - For preflight requests, ensure OPTIONS method is configured correctly

### Debugging Commands

```bash
# Check Lambda function logs
aws logs get-log-events \
  --log-group-name /aws/lambda/api-get-products \
  --log-stream-name $(aws logs describe-log-streams \
    --log-group-name /aws/lambda/api-get-products \
    --order-by LastEventTime \
    --descending \
    --limit 1 \
    --query 'logStreams[0].logStreamName' \
    --output text)

# Test Lambda function directly
aws lambda invoke \
  --function-name api-get-products \
  --payload '{"pathParameters": null}' \
  response.json

# Check API Gateway execution logs
aws apigateway get-stage \
  --rest-api-id $API_ID \
  --stage-name dev

# Verify DynamoDB table contents
aws dynamodb scan --table-name api-products
```

## Resources Created

This lab creates the following AWS resources:

### Compute
- **Lambda Functions**: Three Node.js functions for API operations
- **IAM Role**: Execution role with permissions for Lambda functions

### Storage
- **DynamoDB Table**: NoSQL database for storing product data

### API Management
- **API Gateway REST API**: API with multiple endpoints and methods
- **API Gateway Deployment**: Deployment to dev stage
- **API Key**: For API access control
- **Usage Plan**: For rate limiting and quota management

### Authentication
- **Cognito User Pool**: For user authentication
- **Cognito User Pool Client**: For application integration
- **API Gateway Authorizer**: For securing API endpoints

### Monitoring
- **CloudWatch Log Groups**: One for each Lambda function and API Gateway

### Estimated Costs
- Lambda: Free tier includes 1M requests/month and 400,000 GB-seconds/month
- API Gateway: Free tier includes 1M API calls/month
- DynamoDB: Free tier includes 25 WCU and 25 RCU
- Cognito: Free tier includes 50,000 MAUs
- CloudWatch: Free tier includes 5GB of logs
- **Total estimated cost**: $0-5/month (mostly free tier eligible)

## Cleanup

When you're finished with the lab, follow these steps to avoid ongoing charges:

1. **Delete API Gateway resources:**
   ```bash
   # Delete usage plan key
   aws apigateway delete-usage-plan-key \
     --usage-plan-id $USAGE_PLAN_ID \
     --key-id $API_KEY_ID
   
   # Delete usage plan
   aws apigateway delete-usage-plan \
     --usage-plan-id $USAGE_PLAN_ID
   
   # Delete API key
   aws apigateway delete-api-key \
     --api-key $API_KEY_ID
   
   # Delete REST API
   aws apigateway delete-rest-api \
     --rest-api-id $API_ID
   ```

2. **Delete Lambda functions:**
   ```bash
   # Delete Lambda functions
   aws lambda delete-function --function-name api-get-products
   aws lambda delete-function --function-name api-create-product
   aws lambda delete-function --function-name api-delete-product
   ```

3. **Delete Cognito resources:**
   ```bash
   # Delete user pool client
   aws cognito-idp delete-user-pool-client \
     --user-pool-id $USER_POOL_ID \
     --client-id $CLIENT_ID
   
   # Delete user pool
   aws cognito-idp delete-user-pool \
     --user-pool-id $USER_POOL_ID
   ```

4. **Delete DynamoDB table:**
   ```bash
   # Delete DynamoDB table
   aws dynamodb delete-table --table-name api-products
   ```

5. **Delete IAM role:**
   ```bash
   # Detach policies
   aws iam detach-role-policy \
     --role-name api-lambda-role \
     --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
   
   aws iam detach-role-policy \
     --role-name api-lambda-role \
     --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess
   
   # Delete role
   aws iam delete-role --role-name api-lambda-role
   ```

6. **Delete CloudWatch log groups:**
   ```bash
   # Delete Lambda log groups
   aws logs delete-log-group --log-group-name /aws/lambda/api-get-products
   aws logs delete-log-group --log-group-name /aws/lambda/api-create-product
   aws logs delete-log-group --log-group-name /aws/lambda/api-delete-product
   
   # Delete API Gateway log group
   aws logs delete-log-group --log-group-name API-Gateway-Execution-Logs_$API_ID/dev
   ```

7. **Verify cleanup:**
   ```bash
   # Verify Lambda functions are deleted
   aws lambda list-functions --query 'Functions[?starts_with(FunctionName, `api-`)]'
   
   # Verify DynamoDB table is deleted
   aws dynamodb describe-table --table-name api-products || echo "Table deleted successfully"
   
   # Verify API is deleted
   aws apigateway get-rest-apis --query 'items[?name==`products-api`]'
   ```

> **Important**: Failure to delete resources may result in unexpected charges to your AWS account.

## Next Steps

After completing this lab, consider:

1. **Add custom domain name** for your API using Route 53 and ACM
2. **Implement request validation** using API Gateway request validators
3. **Create API documentation** using API Gateway documentation feature
4. **Implement caching** to improve API performance
5. **Set up canary deployments** for safer API updates
6. **Add WAF integration** to protect your API from common web exploits

## Certification Exam Tips

This lab covers several key areas for the AWS DevOps Professional exam:

- **Domain 1**: SDLC Automation (API deployment, versioning)
- **Domain 2**: Configuration Management and IaC (API Gateway configuration)
- **Domain 3**: Monitoring and Logging (CloudWatch integration, API Gateway logging)
- **Domain 4**: Policies and Standards Automation (IAM roles, API authentication)
- **Domain 5**: Incident and Event Response (Error handling, troubleshooting)

Key concepts to remember:
- API Gateway supports various integration types (Lambda proxy, HTTP, AWS service)
- Lambda proxy integration passes the entire request to Lambda and expects a specific response format
- Cognito User Pools provide authentication for API Gateway
- API keys and usage plans control access and rate limiting
- CloudWatch logs capture API Gateway and Lambda execution details
- CORS must be properly configured for browser-based applications

## Additional Resources

- [API Gateway Developer Guide](https://docs.aws.amazon.com/apigateway/latest/developerguide/welcome.html)
- [Lambda Developer Guide](https://docs.aws.amazon.com/lambda/latest/dg/welcome.html)
- [Cognito Developer Guide](https://docs.aws.amazon.com/cognito/latest/developerguide/what-is-amazon-cognito.html)
- [API Gateway Best Practices](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-api-development-best-practices.html)
- [Serverless API Workshop](https://github.com/aws-samples/aws-serverless-workshops/tree/master/WebApplication)
- [Building Secure APIs with API Gateway](https://aws.amazon.com/blogs/compute/building-secure-apis-with-amazon-api-gateway/)