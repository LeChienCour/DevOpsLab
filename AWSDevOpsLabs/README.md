# AWS DevOps Professional Certification Labs

Comprehensive laboratory exercises for AWS DevOps Professional certification preparation, focusing on key AWS services and DevOps practices including CI/CD pipelines, Infrastructure as Code, monitoring, security, and deployment strategies.

These hands-on labs provide practical experience with real-world AWS DevOps scenarios, helping certification candidates master the skills required for the AWS DevOps Professional certification exam.

## 🚀 Quick Start

```bash
# 1. Clone and navigate to the repository
cd AWSDevOpsLabs

# 2. Install dependencies
pip install -r config/requirements.txt

# 3. Configure AWS credentials (if not already done)
aws configure

# 4. List available labs
python lab-manager.py list

# 5. Start your first lab
python lab-manager.py start codepipeline-basic
```

## 📚 Lab Categories

### 01-cicd: CI/CD Pipeline Labs
- **CodePipeline**: Multi-stage pipeline creation and management
- **CodeBuild**: Advanced build scenarios with custom environments
- **CodeDeploy**: Deployment strategies for EC2, ECS, and Lambda

### 02-iac: Infrastructure as Code Labs
- **CloudFormation**: Nested stacks, custom resources, and stack sets
- **CDK**: TypeScript and Python implementations with custom constructs
- **Terraform**: Module development and multi-environment deployments

### 03-monitoring: Monitoring and Observability Labs
- **CloudWatch**: Custom metrics, composite alarms, and dashboard automation
- **X-Ray**: Distributed tracing for microservices architectures
- **Config**: Compliance monitoring and automated remediation

### 04-security: Security and Compliance Labs
- **IAM**: Least-privilege policies and cross-account role assumption
- **Secrets Manager**: Application integration and credential rotation
- **Security Scanning**: CodeGuru, container scanning, and SAST/DAST integration

### 05-deployment: Deployment Strategy Labs
- **Blue-Green**: Zero-downtime deployments with automated rollback
- **Canary**: Gradual traffic shifting with monitoring and automation
- **Rolling**: Availability maintenance during updates

### 06-integration: AWS Service Integration Labs
- **ECS**: Container orchestration with service discovery and auto-scaling
- **Lambda**: Serverless architectures with Step Functions and EventBridge
- **API Gateway**: Integration patterns with Lambda authorizers
- **RDS**: Database integration with applications and backup automation

## 🔧 Prerequisites

### AWS Account Requirements
- **AWS Account**: Active AWS account with billing configured
- **Billing Alerts**: Set up billing alerts and budget limits (recommended: $2-20/month)
- **IAM User**: Dedicated IAM user with programmatic access (avoid using root account)
- **Regions**: Labs tested in us-east-1, us-west-2, eu-west-1 (use supported regions)

### Required Software
- **Python**: Version 3.8 or higher
- **AWS CLI**: Version 2.x (latest recommended)
- **Git**: For cloning repositories and version control
- **Text Editor/IDE**: VS Code, PyCharm, or similar for editing configurations

### AWS CLI Configuration
```bash
# Install AWS CLI v2 (if not already installed)
# Windows: Download from AWS website
# macOS: brew install awscli
# Linux: curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

# Configure AWS credentials
aws configure
# AWS Access Key ID: [Your Access Key]
# AWS Secret Access Key: [Your Secret Key]
# Default region name: us-east-1
# Default output format: json

# Verify configuration
aws sts get-caller-identity
```

### Required IAM Permissions
Your IAM user needs the following managed policies (or equivalent custom policies):
- `PowerUserAccess` (recommended for full lab functionality)
- Or specific policies for individual services:
  - `AWSCodePipelineFullAccess`
  - `AWSCodeBuildAdminAccess`
  - `AWSCodeDeployFullAccess`
  - `AWSCloudFormationFullAccess`
  - `AmazonEC2FullAccess`
  - `AmazonECSFullAccess`
  - `AWSLambda_FullAccess`
  - `IAMFullAccess`
  - `AmazonS3FullAccess`
  - `CloudWatchFullAccess`

## 💰 Cost Management and Pricing

### Free Tier Benefits
- **New Accounts (created before July 15, 2025)**: 12-month Free Tier period
- **New Accounts (created on/after July 15, 2025)**: 6-month Free Tier or $200 credits
- **Always Free Services**: IAM, CloudFormation, VPC (basic usage)

### Estimated Lab Costs
| Lab Category | Free Tier Cost | Standard Cost | Duration |
|--------------|----------------|---------------|----------|
| CI/CD Labs | $0-2 | $5-15 | 2-4 hours |
| IaC Labs | $0-1 | $3-10 | 1-3 hours |
| Monitoring Labs | $0-3 | $8-20 | 2-5 hours |
| Security Labs | $0-1 | $2-8 | 1-2 hours |
| Deployment Labs | $0-2 | $5-15 | 2-4 hours |
| Integration Labs | $0-4 | $10-25 | 3-6 hours |

### Cost Optimization Tips
- Use `t3.micro` instances (Free Tier eligible)
- Enable automated cleanup after lab completion
- Monitor costs with built-in cost tracker: `python lab-manager.py costs`
- Set up AWS Budget alerts for your account
- Run labs during off-peak hours when possible

## 🛠️ Installation and Setup

### Step 1: Environment Setup
```bash
# Clone the repository
git clone <repository-url>
cd AWSDevOpsLabs

# Create virtual environment (recommended)
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r config/requirements.txt
```

### Step 2: AWS Account Configuration
```bash
# Configure AWS CLI (if not done already)
aws configure

# Test AWS connectivity
aws sts get-caller-identity

# Check available regions
aws ec2 describe-regions --output table
```

### Step 3: Lab Manager Setup
```bash
# Initialize lab manager
python lab-manager.py init

# Verify installation
python lab-manager.py --version

# List available labs
python lab-manager.py list
```

## 🎯 Getting Started Guide

### Your First Lab: CodePipeline Basics
```bash
# 1. Check prerequisites
python lab-manager.py check-prereqs

# 2. Estimate costs
python lab-manager.py estimate codepipeline-basic

# 3. Start the lab
python lab-manager.py start codepipeline-basic

# 4. Follow the lab guide
# Open: 01-cicd/codepipeline/lab-guide.md

# 5. Monitor your session
python lab-manager.py sessions

# 6. Clean up when done
python lab-manager.py cleanup <session-id>
```

### Lab Manager Commands
```bash
# List all available labs
python lab-manager.py list

# Show lab details
python lab-manager.py info <lab-id>

# Start a lab session
python lab-manager.py start <lab-id>

# List active sessions
python lab-manager.py sessions

# Monitor costs
python lab-manager.py costs

# Clean up resources
python lab-manager.py cleanup <session-id>

# Clean up all resources
python lab-manager.py cleanup --all

# Check system health
python lab-manager.py health-check
```

## 🔍 Troubleshooting

### Common Issues

#### Permission Errors
```bash
# Check your AWS identity
aws sts get-caller-identity

# Verify IAM permissions
aws iam get-user
aws iam list-attached-user-policies --user-name <your-username>
```

#### Region Issues
```bash
# Check current region
aws configure get region

# List available regions
aws ec2 describe-regions --query 'Regions[].RegionName' --output table
```

#### Resource Limits
```bash
# Check EC2 limits
aws service-quotas get-service-quota --service-code ec2 --quota-code L-1216C47A

# Check VPC limits
aws service-quotas get-service-quota --service-code vpc --quota-code L-F678F1CE
```

#### Cost Concerns
```bash
# Check current costs
python lab-manager.py costs

# List all resources by session
python lab-manager.py resources <session-id>

# Force cleanup all resources
python lab-manager.py cleanup --force --all
```

### Getting Help
- **Detailed Troubleshooting**: See [docs/troubleshooting.md](docs/troubleshooting.md)
- **Lab-Specific Issues**: Check individual lab guides in each module
- **AWS Documentation**: [AWS DevOps Professional Exam Guide](https://aws.amazon.com/certification/certified-devops-engineer-professional/)
- **Community Support**: Create issues in the repository for lab-specific problems

## 📖 Documentation Structure

```
AWSDevOpsLabs/
├── README.md                    # This file - main project overview
├── docs/
│   ├── getting-started.md       # Detailed setup instructions
│   ├── troubleshooting.md       # Common issues and solutions
│   ├── cleanup-instructions.md  # Resource cleanup procedures
│   └── templates/               # Documentation templates
├── 01-cicd/                     # CI/CD pipeline labs
│   ├── README.md               # Category overview
│   ├── codepipeline/
│   │   └── lab-guide.md        # Step-by-step instructions
│   ├── codebuild/
│   └── codedeploy/
├── 02-iac/                      # Infrastructure as Code labs
├── 03-monitoring/               # Monitoring and observability labs
├── 04-security/                 # Security and compliance labs
├── 05-deployment/               # Deployment strategy labs
└── 06-integration/              # Service integration labs
```

## 🎓 Learning Path Recommendations

### Beginner Path (New to AWS DevOps)
1. Start with **IAM basics** (04-security/iam)
2. Learn **CloudFormation fundamentals** (02-iac/cloudformation)
3. Build your first **CodePipeline** (01-cicd/codepipeline)
4. Set up **CloudWatch monitoring** (03-monitoring/cloudwatch)

### Intermediate Path (Some AWS Experience)
1. **Advanced CI/CD** with CodeBuild and CodeDeploy
2. **CDK development** for Infrastructure as Code
3. **Blue-green deployments** with automated rollback
4. **ECS orchestration** with service discovery

### Advanced Path (Preparing for Certification)
1. **Multi-service integration** scenarios
2. **Advanced deployment strategies** (canary, rolling)
3. **Security scanning integration** in CI/CD
4. **Cross-account role assumption** and compliance

## 🤝 Contributing

We welcome contributions! Please see our contributing guidelines for:
- Adding new labs
- Improving existing documentation
- Reporting issues and bugs
- Suggesting enhancements

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## ⚠️ Important Notes

- **Cost Monitoring**: Always monitor your AWS costs and set up billing alerts
- **Resource Cleanup**: Use cleanup scripts after each lab to avoid unnecessary charges
- **Security**: Never commit AWS credentials to version control
- **Regions**: Some labs may not work in all AWS regions - check lab-specific requirements
- **Limits**: Be aware of AWS service limits and quotas in your account

---

**Ready to start your AWS DevOps journey?** Begin with the [Getting Started Guide](docs/getting-started.md) and run your first lab!