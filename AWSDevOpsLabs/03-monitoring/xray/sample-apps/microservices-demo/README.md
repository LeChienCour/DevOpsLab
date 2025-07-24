# X-Ray Microservices Demo

This demo application showcases AWS X-Ray distributed tracing with a microservices architecture. It consists of two services:

1. **User Service**: Manages user profiles
2. **Order Service**: Manages orders and communicates with the User Service
3. **Load Generator**: Generates traffic to demonstrate tracing

## Architecture

```
┌─────────────────┐    ┌─────────────────┐
│  Load Generator │───▶│  User Service   │
│                 │    │                 │
└─────────────────┘    └─────────────────┘
         │                     ▲
         │                     │
         ▼                     │
┌─────────────────┐            │
│  Order Service  │────────────┘
│                 │
└─────────────────┘
```

## Prerequisites

- Docker and Docker Compose
- AWS account with appropriate permissions
- AWS CLI configured with credentials

## Running the Demo

1. Set your AWS credentials as environment variables:

```bash
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
export AWS_SESSION_TOKEN=your_session_token  # if using temporary credentials
export AWS_REGION=us-east-1
```

2. Create the required DynamoDB tables:

```bash
# Create UserProfiles table
aws dynamodb create-table \
  --table-name UserProfiles \
  --attribute-definitions AttributeName=userId,AttributeType=S \
  --key-schema AttributeName=userId,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

# Create Orders table
aws dynamodb create-table \
  --table-name Orders \
  --attribute-definitions AttributeName=orderId,AttributeType=S \
  --key-schema AttributeName=orderId,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

3. Add sample data:

```bash
# Add sample users
aws dynamodb put-item \
  --table-name UserProfiles \
  --item '{
    "userId": {"S": "user123"},
    "name": {"S": "John Doe"},
    "email": {"S": "john@example.com"},
    "preferences": {"S": "theme:dark,notifications:enabled"}
  }'

aws dynamodb put-item \
  --table-name UserProfiles \
  --item '{
    "userId": {"S": "user456"},
    "name": {"S": "Jane Smith"},
    "email": {"S": "jane@example.com"},
    "preferences": {"S": "theme:light,notifications:disabled"}
  }'

# Add sample orders
aws dynamodb put-item \
  --table-name Orders \
  --item '{
    "orderId": {"S": "order123"},
    "userId": {"S": "user123"},
    "items": {"L": [
      {"M": {"id": {"S": "prod1"}, "name": {"S": "Product 1"}, "price": {"N": "29.99"}, "quantity": {"N": "2"}}},
      {"M": {"id": {"S": "prod2"}, "name": {"S": "Product 2"}, "price": {"N": "49.99"}, "quantity": {"N": "1"}}}
    ]},
    "total": {"N": "109.97"},
    "status": {"S": "shipped"},
    "createdAt": {"S": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}
  }'

aws dynamodb put-item \
  --table-name Orders \
  --item '{
    "orderId": {"S": "order456"},
    "userId": {"S": "user456"},
    "items": {"L": [
      {"M": {"id": {"S": "prod3"}, "name": {"S": "Product 3"}, "price": {"N": "19.99"}, "quantity": {"N": "3"}}}
    ]},
    "total": {"N": "59.97"},
    "status": {"S": "processing"},
    "createdAt": {"S": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}
  }'
```

4. Start the application:

```bash
docker-compose up --build
```

5. The services will be available at:
   - User Service: http://localhost:5000
   - Order Service: http://localhost:5001

6. The load generator will automatically create traffic to generate X-Ray traces.

## Viewing Traces

1. Open the AWS X-Ray console: https://console.aws.amazon.com/xray/home
2. Navigate to the Service Map to see the visualization of your microservices
3. Click on nodes or edges to view detailed trace information
4. Use the Traces view to search for specific traces

## Key X-Ray Features Demonstrated

1. **Service Map Visualization**: See how services connect and communicate
2. **Custom Segments and Subsegments**: Detailed timing for specific operations
3. **Annotations and Metadata**: Searchable data attached to traces
4. **Error Tracking**: Visualization of errors and exceptions
5. **Latency Analysis**: Identify performance bottlenecks

## Cleanup

1. Stop the Docker Compose application with Ctrl+C or:

```bash
docker-compose down
```

2. Delete the DynamoDB tables:

```bash
aws dynamodb delete-table --table-name UserProfiles
aws dynamodb delete-table --table-name Orders
```

## Additional Resources

- [AWS X-Ray Documentation](https://docs.aws.amazon.com/xray/latest/devguide/aws-xray.html)
- [X-Ray SDK for Python](https://docs.aws.amazon.com/xray/latest/devguide/xray-sdk-python.html)
- [X-Ray Concepts](https://docs.aws.amazon.com/xray/latest/devguide/xray-concepts.html)