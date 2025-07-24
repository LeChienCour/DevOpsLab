# Cross-Service Communication Lab

## Overview

This lab demonstrates advanced patterns for cross-service communication in AWS, including service mesh architecture with AWS App Mesh, asynchronous messaging with SQS and SNS, and distributed system resilience patterns with circuit breakers.

## Learning Objectives

By completing this lab, you will:
- Understand AWS App Mesh service mesh concepts and implementation
- Implement inter-service communication using SQS and SNS messaging patterns
- Build resilient distributed systems with circuit breaker patterns
- Configure service discovery and load balancing in a microservices architecture
- Monitor and troubleshoot cross-service communication issues

## Prerequisites

- AWS CLI configured with appropriate permissions
- Basic understanding of microservices architecture
- Familiarity with ECS, Lambda, and API Gateway
- Understanding of networking concepts (VPC, subnets, security groups)

## Lab Architecture

This lab creates a microservices architecture with the following components:

1. **Service Mesh Layer**: AWS App Mesh for service-to-service communication
2. **Messaging Layer**: SQS queues and SNS topics for asynchronous communication
3. **Application Services**: Multiple ECS services representing different microservices
4. **Circuit Breaker**: Lambda functions implementing circuit breaker patterns
5. **Monitoring**: CloudWatch metrics and X-Ray tracing for observability

## Lab Exercises

### Exercise 1: Deploy App Mesh Infrastructure

1. **Provision the base infrastructure**:
   ```bash
   cd AWSDevOpsLabs/06-integration/cross-service/scripts
   ./provision-cross-service-lab.sh
   ```

2. **Verify App Mesh resources**:
   - Check the mesh creation in AWS Console
   - Verify virtual services and virtual nodes
   - Confirm Envoy proxy deployment

### Exercise 2: Configure Service-to-Service Communication

1. **Deploy microservices with App Mesh integration**:
   - User Service (handles user management)
   - Order Service (processes orders)
   - Inventory Service (manages inventory)
   - Notification Service (sends notifications)

2. **Test service mesh communication**:
   ```bash
   # Test direct service communication through App Mesh
   curl -X GET http://user-service.local/users/123
   curl -X POST http://order-service.local/orders -d '{"userId": 123, "productId": 456}'
   ```

### Exercise 3: Implement Asynchronous Messaging

1. **Configure SQS and SNS for event-driven architecture**:
   - Order events published to SNS topic
   - Multiple SQS queues subscribed for different services
   - Dead letter queues for failed message handling

2. **Test messaging patterns**:
   ```bash
   # Trigger order creation to test messaging flow
   aws sns publish --topic-arn arn:aws:sns:region:account:order-events \
     --message '{"orderId": "12345", "userId": "123", "status": "created"}'
   ```

### Exercise 4: Implement Circuit Breaker Patterns

1. **Deploy circuit breaker Lambda functions**:
   - Monitor service health and response times
   - Implement fail-fast behavior for unhealthy services
   - Provide fallback responses during service failures

2. **Test resilience patterns**:
   ```bash
   # Simulate service failure to test circuit breaker
   ./scripts/simulate-service-failure.sh inventory-service
   
   # Verify circuit breaker activation
   curl -X GET http://order-service.local/orders/123
   ```

### Exercise 5: Monitor and Troubleshoot

1. **Review CloudWatch metrics**:
   - Service mesh traffic metrics
   - Message queue depths and processing rates
   - Circuit breaker state changes

2. **Analyze X-Ray traces**:
   - End-to-end request tracing through service mesh
   - Identify performance bottlenecks
   - Troubleshoot failed requests

## Key Concepts Demonstrated

### AWS App Mesh
- **Service Mesh Architecture**: Centralized traffic management and observability
- **Virtual Services**: Logical representation of services in the mesh
- **Virtual Nodes**: Physical deployment targets (ECS tasks, EC2 instances)
- **Virtual Routers**: Traffic routing rules and load balancing
- **Envoy Proxy**: Sidecar proxy for traffic interception and management

### Messaging Patterns
- **Publish-Subscribe**: SNS topics with multiple SQS subscribers
- **Point-to-Point**: Direct SQS queue communication
- **Fan-out**: Single event triggering multiple downstream processes
- **Dead Letter Queues**: Handling failed message processing

### Resilience Patterns
- **Circuit Breaker**: Preventing cascade failures in distributed systems
- **Retry with Backoff**: Handling transient failures gracefully
- **Bulkhead**: Isolating critical resources from failures
- **Timeout**: Preventing resource exhaustion from slow services

## Troubleshooting Guide

### Common Issues

1. **App Mesh Envoy Proxy Not Starting**:
   - Check ECS task definition for proper Envoy configuration
   - Verify IAM permissions for App Mesh integration
   - Review CloudWatch logs for Envoy startup errors

2. **Service Discovery Issues**:
   - Confirm Cloud Map service registration
   - Check security group rules for inter-service communication
   - Verify DNS resolution within VPC

3. **Message Processing Failures**:
   - Check SQS queue visibility timeout settings
   - Review dead letter queue messages for error patterns
   - Verify Lambda function permissions for SQS access

4. **Circuit Breaker Not Activating**:
   - Review health check endpoint responses
   - Check CloudWatch metrics for service health indicators
   - Verify circuit breaker threshold configurations

## Cleanup

To avoid ongoing charges, clean up all resources:

```bash
cd AWSDevOpsLabs/06-integration/cross-service/scripts
./cleanup-cross-service-lab.sh
```

## Cost Considerations

**Estimated costs for this lab**:
- App Mesh: $0.043 per proxy per hour
- ECS Tasks: $0.04048 per vCPU per hour, $0.004445 per GB per hour
- SQS: $0.40 per million requests (first 1M free)
- SNS: $0.50 per million requests (first 1M free)
- Lambda: $0.20 per 1M requests + compute time

**Total estimated cost**: $2-5 for a 2-hour lab session

## Next Steps

After completing this lab, consider exploring:
- Advanced App Mesh features (traffic splitting, outlier detection)
- Integration with service mesh observability tools
- Multi-region service mesh deployments
- Advanced messaging patterns (saga, event sourcing)