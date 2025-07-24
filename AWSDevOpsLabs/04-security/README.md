# Security and Compliance Labs

This module covers comprehensive security practices including identity and access management, secrets management, and automated security scanning in DevOps pipelines.

## Labs Available

- **[iam](iam/lab-guide.md)**: IAM best practices, least-privilege policies, and security monitoring
- **[secrets](secrets/lab-guide.md)**: Secrets Manager and Parameter Store integration with applications
- **[scanning](scanning/lab-guide.md)**: Automated security scanning with CodeGuru, Inspector, and third-party tools

## Prerequisites

- AWS CLI configured with administrative permissions
- Basic understanding of AWS security services
- Docker installed for container security labs
- Git repository access for code scanning labs
- Node.js or Python development environment

## Learning Objectives

By completing these labs, you will:
- Implement IAM best practices and least-privilege access
- Secure application secrets and configuration management
- Set up automated security scanning in CI/CD pipelines
- Configure runtime security monitoring and alerting
- Integrate multiple security tools for comprehensive coverage

## Estimated Costs

- **IAM Lab**: Mostly free (monitoring costs ~$1-3/month)
- **Secrets Lab**: $15-20/month (mostly RDS costs)
- **Scanning Lab**: $15-25/month (depending on usage)
- **Total for all labs**: $30-50/month

### Cost Breakdown by Service
- Secrets Manager: $0.40/secret/month + $0.05/10,000 API calls
- Parameter Store: Free for standard parameters
- CodeGuru: $0.75/100 lines of code analyzed
- Inspector V2: $0.09/instance/month + $0.01/container image scan
- RDS (t3.micro): ~$13/month (free tier eligible)
- EC2 (t3.micro): ~$8.5/month (free tier eligible)
- ECR: $0.10/GB/month for storage
- CodeBuild: $0.005/build minute

## Lab Sequence

For optimal learning, complete the labs in this order:

1. **IAM Lab** - Establish secure access patterns and monitoring
2. **Secrets Lab** - Implement secure secrets management
3. **Scanning Lab** - Add automated security scanning to pipelines

Each lab builds upon security concepts from the previous ones and can be completed independently.