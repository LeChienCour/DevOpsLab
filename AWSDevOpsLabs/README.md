# AWS DevOps Professional Certification Labs

Comprehensive laboratory exercises for AWS DevOps Professional certification preparation, focusing on key AWS services and DevOps practices including CI/CD pipelines, Infrastructure as Code, monitoring, security, and deployment strategies.

## Quick Start

1. Install prerequisites (AWS CLI, Python 3.8+)
2. Configure AWS credentials
3. Run `python lab-manager.py list` to see available labs
4. Start a lab with `python lab-manager.py start <lab-id>`

## Lab Categories

- **01-cicd**: CI/CD Pipeline labs using CodePipeline, CodeBuild, and CodeDeploy
- **02-iac**: Infrastructure as Code labs with CloudFormation, CDK, and Terraform
- **03-monitoring**: Monitoring and observability with CloudWatch, X-Ray, and Config
- **04-security**: Security and compliance labs covering IAM, Secrets Manager, and scanning
- **05-deployment**: Deployment strategy labs for blue-green, canary, and rolling deployments
- **06-integration**: AWS service integration labs for ECS, Lambda, API Gateway, and RDS

## Prerequisites

- AWS CLI configured with appropriate permissions
- Python 3.8 or higher
- Basic understanding of AWS services
- AWS account with billing alerts configured

## Cost Management

All labs include automated cleanup scripts to minimize costs. Monitor your AWS billing dashboard and set up budget alerts before starting labs.