# Infrastructure as Code (IaC) Labs

This module covers AWS Infrastructure as Code (IaC) tools and practices, demonstrating how to define, deploy, and manage AWS infrastructure using code.

## Labs Available

- **CloudFormation**: Learn advanced AWS CloudFormation techniques by implementing a multi-tier application architecture using nested stacks, change sets, and drift detection.
- **Terraform**: Master Terraform configuration and state management for AWS resources, creating reusable modules and implementing remote state backends.
- **CDK**: Learn how to provision and manage AWS infrastructure using the AWS Cloud Development Kit (CDK) with TypeScript.

## Prerequisites

- AWS Account with administrative access
- AWS CLI installed and configured with appropriate permissions
- Basic understanding of Infrastructure as Code concepts
- Tool-specific requirements:
  - CloudFormation: Basic understanding of YAML syntax
  - Terraform: Terraform CLI installed (version 1.0+)
  - CDK: Node.js 18+, npm, and AWS CDK CLI installed

## Troubleshooting

Each lab guide includes a troubleshooting section to help you resolve common issues:

- Common issues and solutions specific to each IaC tool
- Debugging commands and techniques
- Log analysis guidance
- General troubleshooting approaches

## Estimated Costs

- VPC and Networking: $0.00/day (free)
- NAT Gateway: ~$0.045/hour (~$32/month) - most expensive component
- EC2/ECS: Varies by lab, typically $0.50-$1.00/day
- S3 Storage: Minimal for templates and state storage
- **Total estimated cost**: $0.50-$2.00/day (can be reduced by destroying resources when not in use)

> **Important**: Always follow the cleanup instructions at the end of each lab to avoid ongoing charges to your AWS account.