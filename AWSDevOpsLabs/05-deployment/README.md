# Deployment Strategy Labs

This module provides comprehensive hands-on experience with advanced deployment strategies including blue-green, canary, and rolling deployments. These labs demonstrate different approaches to updating applications with minimal downtime and risk, essential skills for the AWS DevOps Professional certification.

## 🎯 Learning Objectives

By completing these labs, you will:
- Master different deployment strategies and understand their appropriate use cases
- Implement zero-downtime deployment patterns for production environments
- Configure automated monitoring, health checks, and rollback procedures
- Practice risk mitigation techniques for safe production deployments
- Balance deployment speed with system availability and reliability
- Understand the trade-offs between different deployment approaches

## 📚 Labs Available

### [Blue-Green Deployment Lab](blue-green/lab-guide.md)
**Duration**: 60 minutes | **Difficulty**: Intermediate

Implement zero-downtime deployments using two identical environments (blue and green) with instant traffic switching capabilities.

**Key Topics**:
- ECS service blue-green deployment with CodeDeploy
- Lambda alias-based deployment strategies
- Application Load Balancer target group switching
- Automated rollback triggers based on CloudWatch metrics
- Database migration strategies during deployments
- Environment parity and configuration management

**Resources Created**:
- Two identical ECS services (blue and green environments)
- Application Load Balancer with target group switching
- CodeDeploy application and deployment group
- CloudWatch alarms for automated rollback
- Lambda functions with alias-based deployments
- RDS database with read replicas

**Best For**: Applications requiring instant rollback capability and zero downtime

### [Canary Deployment Lab](canary/lab-guide.md)
**Duration**: 75 minutes | **Difficulty**: Advanced

Practice gradual traffic shifting to new versions with automated monitoring, A/B testing, and intelligent rollback decisions.

**Key Topics**:
- Gradual traffic shifting with Application Load Balancer weighted routing
- CloudWatch alarm-based promotion and rollback automation
- A/B testing scenarios with feature flag integration
- Performance comparison between application versions
- Custom metrics for business KPI monitoring
- Automated canary analysis and decision making

**Resources Created**:
- Application Load Balancer with weighted target groups
- CloudWatch custom metrics and composite alarms
- Lambda functions for canary analysis
- Feature flag system for A/B testing
- CloudWatch dashboards for version comparison
- SNS topics for deployment notifications

**Best For**: Applications where gradual rollout and performance validation are critical

### [Rolling Deployment Lab](rolling/lab-guide.md)
**Duration**: 50 minutes | **Difficulty**: Beginner-Intermediate

Learn instance-by-instance updates using Auto Scaling Groups with configurable deployment parameters and health maintenance.

**Key Topics**:
- Rolling update configurations for Auto Scaling Groups
- ECS service rolling deployments with capacity management
- Health check strategies and availability maintenance
- Zero-downtime deployment with minimum healthy capacity
- Deployment speed vs. availability trade-offs
- Rollback procedures for failed rolling deployments

**Resources Created**:
- Auto Scaling Group with rolling update configuration
- ECS service with rolling deployment strategy
- Application Load Balancer with health checks
- CloudWatch monitoring for deployment progress
- Launch templates with versioning
- Deployment automation scripts

**Best For**: Applications that can tolerate gradual updates and mixed version states

## 🔧 Prerequisites

### Technical Requirements
- **AWS Account**: With administrative access or appropriate IAM permissions
- **AWS CLI**: Version 2.x configured with your credentials
- **Docker**: For containerizing applications (blue-green and canary labs)
- **Application Code**: Sample applications provided or bring your own
- **Load Testing Tools**: For validating deployment performance (optional)

### Knowledge Prerequisites
- **Load Balancers**: Understanding of Application Load Balancer and target groups
- **Auto Scaling**: Familiarity with Auto Scaling Groups and launch configurations
- **ECS/Fargate**: Container orchestration concepts (for container-based labs)
- **CloudWatch**: Metrics, alarms, and monitoring concepts
- **CI/CD Concepts**: Understanding of deployment pipelines and automation

### AWS Permissions Required
Your IAM user/role needs these managed policies or equivalent permissions:
- `AmazonECS_FullAccess`
- `ElasticLoadBalancingFullAccess`
- `AutoScalingFullAccess`
- `AWSCodeDeployFullAccess`
- `CloudWatchFullAccess`
- `AWSLambda_FullAccess`
- `AmazonEC2FullAccess`

## 💰 Cost Breakdown

### Free Tier Eligible Services
- **EC2**: 750 hours/month of t2.micro or t3.micro instances
- **EBS**: 30GB of General Purpose (gp2) storage
- **CloudWatch**: 10 custom metrics, 10 alarms, 1 million API requests
- **Lambda**: 1 million requests and 400,000 GB-seconds per month

### Paid Services
- **Application Load Balancer**: $0.0225/hour + $0.008/LCU-hour
- **ECS Fargate**: $0.04048/vCPU/hour + $0.004445/GB/hour
- **CodeDeploy**: Free for EC2/on-premises, $0.02/update for ECS/Lambda
- **RDS**: $0.017/hour for db.t3.micro + storage costs
- **NAT Gateway**: $0.045/hour + $0.045/GB processed (if using private subnets)

### Estimated Lab Costs
| Lab | Duration | Free Tier Cost | Standard Cost |
|-----|----------|----------------|---------------|
| Rolling Deployment | 50 min | $0.00 | $2.50 |
| Blue-Green Deployment | 60 min | $0.50 | $4.00 |
| Canary Deployment | 75 min | $0.75 | $5.50 |
| **Total** | **3 hours** | **$1.25** | **$12.00** |

> **💡 Cost Optimization Tips**:
> - Use t3.micro instances (Free Tier eligible)
> - Avoid NAT Gateways by using public subnets for labs
> - Clean up resources immediately after completion
> - Run labs sequentially rather than simultaneously
> - Use Application Load Balancer efficiently across labs

## 🚀 Getting Started

### Recommended Learning Path
1. **Rolling Deployment** → Simplest strategy, good foundation
2. **Blue-Green Deployment** → Environment isolation concepts
3. **Canary Deployment** → Advanced monitoring and gradual rollout

### Deployment Strategy Decision Matrix

| Factor | Rolling | Blue-Green | Canary |
|--------|---------|------------|--------|
| **Downtime** | Minimal | Zero | Zero |
| **Resource Usage** | Low | High (2x) | Medium |
| **Rollback Speed** | Slow | Instant | Medium |
| **Risk Level** | Medium | Low | Lowest |
| **Complexity** | Low | Medium | High |
| **Cost** | Low | High | Medium |
| **Monitoring Needs** | Basic | Medium | Advanced |

### When to Use Each Strategy

#### Rolling Deployment
- **Use When**: Cost is a primary concern, application can handle mixed versions
- **Avoid When**: Instant rollback is critical, database schema changes are involved
- **Examples**: Web applications, microservices, stateless applications

#### Blue-Green Deployment
- **Use When**: Zero downtime is mandatory, instant rollback is required
- **Avoid When**: Resources are constrained, database migrations are complex
- **Examples**: Critical business applications, e-commerce platforms, financial systems

#### Canary Deployment
- **Use When**: Risk mitigation is paramount, gradual validation is needed
- **Avoid When**: Simple applications, resource constraints, tight timelines
- **Examples**: High-traffic applications, new feature releases, performance-critical systems

## 🔍 Advanced Deployment Concepts

### Health Check Strategies
- **Application Health**: Custom health endpoints for business logic validation
- **Infrastructure Health**: System-level metrics (CPU, memory, disk)
- **Dependency Health**: External service availability and performance
- **User Experience**: Real user monitoring and synthetic transactions

### Rollback Triggers
- **Error Rate Thresholds**: Automatic rollback on increased error rates
- **Performance Degradation**: Response time or throughput decline
- **Business Metrics**: Revenue, conversion rates, user engagement
- **Manual Triggers**: Human intervention for complex scenarios

### Monitoring and Observability
- **Deployment Metrics**: Success rates, duration, frequency
- **Application Metrics**: Performance, errors, user experience
- **Infrastructure Metrics**: Resource utilization, capacity planning
- **Business Metrics**: KPIs, revenue impact, user satisfaction

### Database Deployment Patterns
- **Schema Migrations**: Forward-compatible changes, rollback strategies
- **Data Migrations**: Blue-green data synchronization, eventual consistency
- **Read Replicas**: Traffic splitting for database load distribution
- **Feature Flags**: Database-driven feature toggles and gradual rollout

## 🎓 Certification Relevance

These labs directly address AWS DevOps Professional exam domains:

### Domain 2: Configuration Management and Infrastructure as Code (19%)
- **2.1**: Determine deployment services based on deployment needs
- **2.2**: Determine application and infrastructure deployment models
- **2.3**: Determine how to implement lifecycle hooks on a deployment

### Domain 5: Incident and Event Response (18%)
- **5.1**: Troubleshoot issues and determine how to restore operations
- **5.2**: Determine how to automate event management and alerting
- **5.3**: Apply concepts required to implement automated healing

### Domain 6: High Availability, Fault Tolerance, and Disaster Recovery (14%)
- **6.1**: Determine appropriate use of multi-AZ versus multi-region architectures
- **6.2**: Determine how to implement high availability, scalability, and fault tolerance

### Key Exam Topics Covered
- Deployment strategy selection based on requirements
- Zero-downtime deployment implementation
- Automated rollback and recovery procedures
- Load balancer configuration for different deployment patterns
- CloudWatch integration for deployment monitoring
- Auto Scaling Group deployment configurations
- ECS deployment strategies and service management

### Exam Tips
- **Understand trade-offs**: Know when to use each deployment strategy
- **Master rollback procedures**: Critical for incident response scenarios
- **Know AWS services**: CodeDeploy, ECS, Auto Scaling, Load Balancers
- **Practice troubleshooting**: Common deployment failure scenarios
- **Understand monitoring**: CloudWatch metrics and alarms for deployments

## 🔧 Troubleshooting

### Common Deployment Issues

#### Rolling Deployment Problems
- **Stuck Deployments**: Check Auto Scaling Group health checks and capacity settings
- **Mixed Version Issues**: Verify application compatibility across versions
- **Performance Degradation**: Monitor resource utilization during deployments

#### Blue-Green Deployment Problems
- **Environment Drift**: Ensure blue and green environments are identical
- **Database Synchronization**: Handle data consistency between environments
- **DNS Propagation**: Account for DNS caching and propagation delays

#### Canary Deployment Problems
- **Traffic Splitting Issues**: Verify load balancer weighted routing configuration
- **Metric Collection**: Ensure sufficient data for automated decision making
- **False Positives**: Tune alarm thresholds to reduce unnecessary rollbacks

### Debugging Commands

```bash
# Check Auto Scaling Group deployment status
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names MyASG

# Monitor ECS service deployment
aws ecs describe-services --cluster MyCluster --services MyService

# Check load balancer target health
aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:...

# View CodeDeploy deployment status
aws deploy get-deployment --deployment-id d-1234567890

# Check CloudWatch metrics for deployment monitoring
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T01:00:00Z \
  --period 300 \
  --statistics Average
```

## 📖 Additional Resources

### AWS Documentation
- [AWS CodeDeploy User Guide](https://docs.aws.amazon.com/codedeploy/latest/userguide/)
- [Amazon ECS Deployment Types](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-types.html)
- [Auto Scaling Group Rolling Updates](https://docs.aws.amazon.com/autoscaling/ec2/userguide/asg-rolling-updates.html)
- [Application Load Balancer Guide](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)

### Deployment Best Practices
- [AWS Well-Architected Reliability Pillar](https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/)
- [Blue/Green Deployments on AWS](https://docs.aws.amazon.com/whitepapers/latest/blue-green-deployments/welcome.html)
- [Deployment Strategies with AWS](https://aws.amazon.com/builders-library/automating-safe-hands-off-deployments/)

### Industry Resources
- [Martin Fowler - Deployment Patterns](https://martinfowler.com/articles/deployment-pipeline.html)
- [Google SRE Book - Release Engineering](https://sre.google/sre-book/release-engineering/)
- [Netflix Tech Blog - Deployment Strategies](https://netflixtechblog.com/)

---

**Ready to master deployment strategies?** Start with the [Rolling Deployment Lab](rolling/lab-guide.md) to build your foundation!