# Getting Started with AWS DevOps Labs

This comprehensive guide will walk you through setting up your environment and running your first AWS DevOps lab. Follow these steps carefully to ensure a smooth experience.

## 🎯 Overview

The AWS DevOps Labs provide hands-on experience with real-world AWS DevOps scenarios. Each lab includes:
- Step-by-step instructions
- Automated provisioning scripts
- Cost estimation and tracking
- Automated cleanup procedures
- Troubleshooting guidance

## 📋 Prerequisites Checklist

### AWS Account Requirements
- [ ] **AWS Account**: Active AWS account (not root user for daily operations)
- [ ] **Billing Setup**: Credit card or payment method configured
- [ ] **Billing Alerts**: Budget alerts configured (recommended: $50-100/month)
- [ ] **Region Access**: Ensure you can create resources in supported regions

### Software Requirements
- [ ] **Python 3.8+**: `python --version` should show 3.8 or higher
- [ ] **AWS CLI v2**: `aws --version` should show version 2.x
- [ ] **Git**: `git --version` for repository operations
- [ ] **Text Editor**: VS Code, PyCharm, or similar for configuration editing

### Knowledge Prerequisites
- [ ] Basic understanding of AWS services (EC2, S3, IAM)
- [ ] Familiarity with command-line operations
- [ ] Understanding of DevOps concepts (CI/CD, IaC, monitoring)
- [ ] Basic knowledge of YAML/JSON for configuration files

## 🔧 Detailed Setup Instructions

### Step 1: AWS Account Setup

#### 1.1 Create AWS Account (if needed)
```bash
# Visit https://aws.amazon.com/
# Click "Create an AWS Account"
# Follow the registration process
# Verify your email and phone number
# Add payment method
```

#### 1.2 Set Up Billing Alerts
```bash
# 1. Go to AWS Billing Console
# 2. Navigate to "Budgets"
# 3. Create a new budget:
#    - Budget type: Cost budget
#    - Amount: $50-100 (adjust based on your needs)
#    - Alert threshold: 80% of budgeted amount
#    - Email notification: Your email address
```

#### 1.3 Create IAM User for Labs
```bash
# 1. Go to IAM Console
# 2. Click "Users" → "Add user"
# 3. Username: devops-labs-user
# 4. Access type: Programmatic access
# 5. Attach policies:
#    - PowerUserAccess (recommended)
#    - Or specific policies listed in main README
# 6. Download credentials CSV file
# 7. Store credentials securely (never commit to version control)
```

### Step 2: Software Installation

#### 2.1 Install Python 3.8+
```bash
# Check current version
python --version
python3 --version

# Windows (using Python.org installer)
# Download from https://www.python.org/downloads/
# Ensure "Add Python to PATH" is checked during installation

# macOS (using Homebrew)
brew install python@3.9

# Ubuntu/Debian
sudo apt update
sudo apt install python3.9 python3.9-pip python3.9-venv

# Verify installation
python3 --version
pip3 --version
```

#### 2.2 Install AWS CLI v2
```bash
# Windows
# Download from https://awscli.amazonaws.com/AWSCLIV2.msi
# Run installer and follow prompts

# macOS
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify installation
aws --version
# Should show: aws-cli/2.x.x Python/3.x.x ...
```

#### 2.3 Install Git
```bash
# Windows: Download from https://git-scm.com/download/win
# macOS: brew install git
# Ubuntu/Debian: sudo apt install git

# Verify installation
git --version
```

### Step 3: AWS CLI Configuration

#### 3.1 Configure AWS Credentials
```bash
# Run AWS configure command
aws configure

# Enter the following information:
# AWS Access Key ID: [From your IAM user credentials]
# AWS Secret Access Key: [From your IAM user credentials]
# Default region name: us-east-1 (or your preferred region)
# Default output format: json
```

#### 3.2 Verify AWS Configuration
```bash
# Test AWS connectivity
aws sts get-caller-identity

# Expected output:
# {
#     "UserId": "AIDACKCEVSQ6C2EXAMPLE",
#     "Account": "123456789012",
#     "Arn": "arn:aws:iam::123456789012:user/devops-labs-user"
# }

# Check available regions
aws ec2 describe-regions --query 'Regions[].RegionName' --output table

# Test permissions (should not error)
aws s3 ls
aws ec2 describe-instances
```

#### 3.3 Configure Additional Profiles (Optional)
```bash
# For multiple AWS accounts or environments
aws configure --profile dev
aws configure --profile prod

# Use specific profile
aws s3 ls --profile dev
export AWS_PROFILE=dev
```

### Step 4: Lab Environment Setup

#### 4.1 Clone Repository
```bash
# Clone the repository (replace with actual URL)
git clone <repository-url>
cd AWSDevOpsLabs

# Verify directory structure
ls -la
# Should see: README.md, lab-manager.py, 01-cicd/, 02-iac/, etc.
```

#### 4.2 Set Up Python Virtual Environment
```bash
# Create virtual environment
python3 -m venv venv

# Activate virtual environment
# Linux/macOS:
source venv/bin/activate

# Windows:
venv\Scripts\activate

# Verify activation (prompt should show (venv))
which python  # Should point to venv/bin/python
```

#### 4.3 Install Lab Dependencies
```bash
# Install required Python packages
pip install -r config/requirements.txt

# Verify installation
pip list
# Should show: boto3, pyyaml, click, etc.
```

#### 4.4 Initialize Lab Manager
```bash
# Initialize lab manager configuration
python lab-manager.py init

# Verify installation
python lab-manager.py --version
python lab-manager.py --help

# Check system health
python lab-manager.py health-check
```

## 🚀 Running Your First Lab

### Step 1: Explore Available Labs
```bash
# List all available labs
python lab-manager.py list

# Get detailed information about a specific lab
python lab-manager.py info codepipeline-basic

# Check prerequisites for a lab
python lab-manager.py check-prereqs codepipeline-basic
```

### Step 2: Estimate Costs
```bash
# Get cost estimate for a lab
python lab-manager.py estimate codepipeline-basic

# Example output:
# Lab: codepipeline-basic
# Estimated Cost (Free Tier): $0.00
# Estimated Cost (Standard): $2.50
# Duration: 2 hours
# Resources: CodePipeline, S3, CodeBuild
```

### Step 3: Start Your First Lab
```bash
# Start the CodePipeline basic lab
python lab-manager.py start codepipeline-basic

# Follow the prompts:
# - Confirm cost estimate
# - Choose configuration options
# - Wait for resource provisioning
```

### Step 4: Follow Lab Instructions
```bash
# Open the lab guide
# File: 01-cicd/codepipeline/lab-guide.md

# The lab guide includes:
# - Learning objectives
# - Step-by-step instructions
# - Expected outcomes
# - Troubleshooting tips
```

### Step 5: Monitor Your Lab Session
```bash
# Check active sessions
python lab-manager.py sessions

# Monitor costs in real-time
python lab-manager.py costs

# View provisioned resources
python lab-manager.py resources <session-id>
```

### Step 6: Complete and Clean Up
```bash
# When finished with the lab
python lab-manager.py cleanup <session-id>

# Verify cleanup completed
python lab-manager.py verify-cleanup <session-id>

# Check for any orphaned resources
python lab-manager.py orphaned-resources
```

## 💡 Best Practices

### Cost Management
- Always run cost estimates before starting labs
- Set up AWS Budget alerts for your account
- Clean up resources immediately after completing labs
- Use the smallest instance types that meet requirements
- Monitor costs regularly with `python lab-manager.py costs`

### Security
- Never commit AWS credentials to version control
- Use IAM users instead of root account
- Regularly rotate access keys
- Enable MFA on your AWS account
- Review IAM permissions periodically

### Lab Execution
- Read the entire lab guide before starting
- Follow instructions step-by-step
- Take notes of any issues encountered
- Use version control for any custom configurations
- Test cleanup procedures in a safe environment first

## 🔍 Verification Steps

### Environment Verification Checklist
```bash
# Run these commands to verify your setup:

# 1. Python version
python --version  # Should be 3.8+

# 2. AWS CLI version
aws --version     # Should be 2.x

# 3. AWS credentials
aws sts get-caller-identity  # Should return your user info

# 4. Lab manager
python lab-manager.py --version  # Should return version info

# 5. Dependencies
pip list | grep boto3  # Should show boto3 package

# 6. Permissions test
aws s3 ls  # Should not error (even if no buckets)

# 7. Region connectivity
aws ec2 describe-regions --region us-east-1  # Should return regions
```

### Troubleshooting Verification Issues

#### Python Issues
```bash
# If python command not found
which python3
alias python=python3

# If pip not found
python -m pip --version
```

#### AWS CLI Issues
```bash
# If aws command not found
which aws
echo $PATH

# If credentials not working
aws configure list
cat ~/.aws/credentials
```

#### Permission Issues
```bash
# Check IAM user permissions
aws iam get-user
aws iam list-attached-user-policies --user-name <your-username>

# Test specific permissions
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT:user/USERNAME \
  --action-names s3:ListBucket \
  --resource-arns arn:aws:s3:::*
```

## 📚 Next Steps

### Recommended Learning Path
1. **Start with IAM basics** (04-security/iam/lab-guide.md)
2. **Learn CloudFormation** (02-iac/cloudformation/lab-guide.md)
3. **Build CI/CD pipeline** (01-cicd/codepipeline/lab-guide.md)
4. **Set up monitoring** (03-monitoring/cloudwatch/lab-guide.md)

### Additional Resources
- [AWS DevOps Professional Exam Guide](https://aws.amazon.com/certification/certified-devops-engineer-professional/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [AWS DevOps Blog](https://aws.amazon.com/blogs/devops/)
- [Troubleshooting Guide](troubleshooting.md)

## 🆘 Getting Help

### Common Issues
- **Permission Errors**: Check IAM policies and AWS credentials
- **Region Issues**: Ensure you're using supported regions
- **Cost Concerns**: Monitor billing dashboard and use cleanup scripts
- **Resource Limits**: Check AWS service quotas for your account

### Support Channels
- **Documentation**: Check individual lab guides and troubleshooting.md
- **AWS Support**: Use AWS Support Center for account-specific issues
- **Community**: Create issues in the repository for lab-specific problems
- **AWS Forums**: AWS Developer Forums for general AWS questions

---

**You're now ready to start your AWS DevOps learning journey!** 🎉

Choose your first lab from the main README and begin building your AWS DevOps expertise.