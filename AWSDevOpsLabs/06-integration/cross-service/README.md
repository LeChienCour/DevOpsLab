# Cross-Service Communication Lab

This lab demonstrates advanced patterns for cross-service communication in AWS, including service mesh architecture with AWS App Mesh, asynchronous messaging with SQS and SNS, and distributed system resilience patterns with circuit breakers.

## Lab Components

### 1. AWS App Mesh Service Mesh
- **Virtual Services**: Logical representation of microservices
- **Virtual Nodes**: Physical deployment targets (ECS tasks)
- **Virtual Routers**: Traffic routing and load balancing
- **Envoy Proxy**: Sidecar proxy for traffic management

### 2. Messaging Infrastructure
- **SNS Topics**: Event publishing for order, user, and inventory events
- **SQS Queues**: Asynchronous message processing with dead letter queues
- **Message Filtering**: Attribute-based message routing

### 3. Circuit Breaker Pattern
- **Lambda Functions**: Circuit breaker state management and health checking
- **DynamoDB**: Circuit breaker state persistence
- **CloudWatch**: Metrics and monitoring

### 4. Microservices
- **User Service**: User management and authentication
- **Order Service**: Order processing and orchestration
- **Inventory Service**: Inventory management
- **Notification Service**: Event-driven notifications

## Prerequisites

- AWS CLI configured with appropriate permissions
- PowerShell or Bash shell
- Basic understanding of microservices architecture
- Familiarity with AWS services (ECS, Lambda, SNS, SQS)

## Quick Start

### 1. Deploy the Lab

**On Linux/macOS:**
```bash
cd AWSDevOpsLabs/06-integration/cross-service/scripts
./provision-cross-service-lab.sh
```

**On Windows (PowerShell):**
```powershell
cd AWSDevOpsLabs\06-integration\cross-service\scripts
bash provision-cross-service-lab.sh
```

### 2. Test the Services

After deployment, test the services using the provided endpoints:

```bash
# Get the load balancer DNS from the output
ALB_DNS="your-alb-dns-here"

# Test user service
curl -X GET http://$ALB_DNS:8080/users/123

# Test order service
curl -X POST http://$ALB_DNS:8080/orders \
  -H 'Content-Type: application/json' \
  -d '{"user_id": 123, "items": [{"product_id": "prod-123", "quantity": 2}]}'
```

### 3. Test Messaging

Publish a test message to SNS:

```bash
# Get topic ARN from deployment output
ORDER_TOPIC_ARN="your-topic-arn-here"

aws sns publish \
  --topic-arn $ORDER_TOPIC_ARN \
  --message '{"orderId": "12345", "userId": "123", "status": "created"}' \
  --message-attributes eventType='{"DataType":"String","StringValue":"order_created"}'
```

### 4. Test Circuit Breaker

Simulate service failure:

```bash
# Simulate failure
./simulate-service-failure.sh user-service fail

# Check circuit breaker state
aws lambda invoke \
  --function-name circuit-breaker-manager \
  --payload '{"service_name": "user-service", "action": "check"}' \
  /tmp/response.json && cat /tmp/response.json

# Simulate recovery
./simulate-service-failure.sh user-service recover
```

## Lab Exercises

### Exercise 1: Service Mesh Communication
1. Deploy the infrastructure using the provisioning script
2. Verify App Mesh resources in the AWS Console
3. Test service-to-service communication through the mesh
4. Review Envoy proxy logs and X-Ray traces

### Exercise 2: Asynchronous Messaging
1. Publish events to SNS topics
2. Monitor SQS queue processing
3. Test message filtering with different event types
4. Simulate message processing failures

### Exercise 3: Circuit Breaker Patterns
1. Monitor service health with the health checker
2. Simulate service failures
3. Observe circuit breaker state changes
4. Test fallback behavior during failures

### Exercise 4: Observability and Monitoring
1. Review CloudWatch metrics and dashboards
2. Analyze X-Ray service maps and traces
3. Monitor circuit breaker state changes
4. Set up custom alarms and notifications

## Architecture Diagram

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   User Service  │    │  Order Service  │    │Inventory Service│
│                 │    │                 │    │                 │
│  ┌───────────┐  │    │  ┌───────────┐  │    │  ┌───────────┐  │
│  │   App     │  │    │  │   App     │  │    │  │   App     │  │
│  │Container  │  │    │  │Container  │  │    │  │Container  │  │
│  └───────────┘  │    │  └───────────┘  │    │  └───────────┘  │
│  ┌───────────┐  │    │  ┌───────────┐  │    │  ┌───────────┐  │
│  │   Envoy   │  │    │  │   Envoy   │  │    │  │   Envoy   │  │
│  │   Proxy   │  │    │  │   Proxy   │  │    │  │   Proxy   │  │
│  └───────────┘  │    │  └───────────┘  │    │  └───────────┘  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   App Mesh      │
                    │  Virtual Router │
                    └─────────────────┘
                                 │
                    ┌─────────────────┐
                    │ Application     │
                    │ Load Balancer   │
                    └─────────────────┘
                                 │
                    ┌─────────────────┐
                    │   SNS Topics    │
                    │ ┌─────────────┐ │
                    │ │Order Events │ │
                    │ │User Events  │ │
                    │ │Inventory    │ │
                    │ └─────────────┘ │
                    └─────────────────┘
                                 │
                    ┌─────────────────┐
                    │   SQS Queues    │
                    │ ┌─────────────┐ │
                    │ │Processing   │ │
                    │ │Notification │ │
                    │ │Analytics    │ │
                    │ └─────────────┘ │
                    └─────────────────┘
```

## Cost Estimation

**Estimated costs for a 2-hour lab session:**

- **App Mesh**: $0.043 per proxy per hour × 6 proxies × 2 hours = $0.52
- **ECS Fargate**: $0.04048 per vCPU per hour × 3 vCPUs × 2 hours = $0.24
- **ECS Fargate Memory**: $0.004445 per GB per hour × 6 GB × 2 hours = $0.05
- **Application Load Balancer**: $0.0225 per hour × 2 hours = $0.05
- **Lambda**: $0.20 per 1M requests (minimal usage) = $0.01
- **DynamoDB**: On-demand pricing (minimal usage) = $0.01
- **SQS**: $0.40 per million requests (first 1M free) = $0.00
- **SNS**: $0.50 per million requests (first 1M free) = $0.00
- **CloudWatch**: Logs and metrics (minimal usage) = $0.02

**Total estimated cost: ~$0.90 for a 2-hour session**

## Troubleshooting

### Common Issues

1. **Services not starting**: Check ECS task logs for container startup errors
2. **App Mesh connectivity issues**: Verify Envoy proxy configuration and security groups
3. **Circuit breaker not activating**: Check health check endpoints and Lambda function logs
4. **Message processing failures**: Review SQS dead letter queues and Lambda function errors

### Useful Commands

```bash
# Check ECS service status
aws ecs describe-services --cluster cross-service-cluster --services user-service

# View container logs
aws logs tail /ecs/user-service --follow

# Check circuit breaker state
aws lambda invoke --function-name circuit-breaker-manager \
  --payload '{"service_name": "user-service", "action": "check"}' \
  /tmp/response.json && cat /tmp/response.json

# Monitor SQS queue
aws sqs get-queue-attributes --queue-url YOUR_QUEUE_URL \
  --attribute-names ApproximateNumberOfMessages
```

## Cleanup

To avoid ongoing charges, clean up all resources:

**On Linux/macOS:**
```bash
./cleanup-cross-service-lab.sh
```

**On Windows (PowerShell):**
```powershell
bash cleanup-cross-service-lab.sh
```

## Learning Resources

- [AWS App Mesh Documentation](https://docs.aws.amazon.com/app-mesh/)
- [Amazon SQS Developer Guide](https://docs.aws.amazon.com/sqs/)
- [Amazon SNS Developer Guide](https://docs.aws.amazon.com/sns/)
- [Circuit Breaker Pattern](https://martinfowler.com/bliki/CircuitBreaker.html)
- [Microservices Patterns](https://microservices.io/patterns/)

## Next Steps

After completing this lab, consider exploring:
- Advanced App Mesh features (traffic splitting, outlier detection)
- Integration with AWS X-Ray for distributed tracing
- Multi-region service mesh deployments
- Advanced messaging patterns (saga, event sourcing)
- Service mesh security with mutual TLS