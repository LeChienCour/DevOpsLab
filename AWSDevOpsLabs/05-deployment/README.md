# Deployment Strategy Labs

This module covers advanced deployment strategies including blue-green, canary, and rolling deployments. Each lab demonstrates different approaches to updating applications with minimal downtime and risk.

## Labs Available

- **[blue-green](blue-green/lab-guide.md)**: Implement zero-downtime deployments using two identical environments with instant traffic switching
- **[canary](canary/lab-guide.md)**: Practice gradual traffic shifting to new versions with automated monitoring and rollback
- **[rolling](rolling/lab-guide.md)**: Learn instance-by-instance updates using Auto Scaling Groups with configurable deployment parameters

## Prerequisites

- AWS Account with administrative access
- AWS CLI configured with appropriate credentials
- Basic understanding of load balancers and target groups
- Familiarity with Auto Scaling Groups and EC2 instances
- Knowledge of CloudWatch metrics and monitoring

## Learning Objectives

By completing these labs, you will:
- Understand different deployment strategies and their use cases
- Implement zero-downtime deployment patterns
- Configure automated monitoring and rollback procedures
- Practice risk mitigation techniques for production deployments
- Learn to balance deployment speed with system availability

## Estimated Costs

### Per Lab
- **Application Load Balancer**: ~$0.54/day ($0.0225/hour)
- **EC2 Instances**: $0.00/day (Free Tier) or ~$1.16/day (4 x t2.micro)
- **EBS Volumes**: ~$0.32/day (4 x 8GB)
- **CloudWatch**: Minimal cost for basic metrics
- **Total per lab**: $0.86-$2.02/day (partially Free Tier eligible)

### All Labs Combined
If running all labs simultaneously: ~$2.58-$6.06/day

> **Note**: Costs may vary based on region, usage patterns, and Free Tier eligibility. Always clean up resources after completing labs to avoid ongoing charges.

## Lab Sequence Recommendation

1. **Start with Rolling Deployment**: Easiest to understand and implement
2. **Progress to Blue-Green**: Learn about environment isolation and instant switching
3. **Finish with Canary**: Most complex with gradual traffic shifting and monitoring

## Certification Relevance

These labs cover key areas for AWS DevOps Professional certification:
- **Domain 2**: Configuration Management and Infrastructure as Code
- **Domain 3**: Monitoring and Logging
- **Domain 4**: Policies and Standards Automation
- **Domain 5**: Incident and Event Response