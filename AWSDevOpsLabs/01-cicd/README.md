# CI/CD Pipeline Labs

This module provides comprehensive hands-on experience with AWS CI/CD services including CodePipeline, CodeBuild, and CodeDeploy. These labs are designed to help you master automated deployment workflows and pipeline orchestration for the AWS DevOps Professional certification.

## 🎯 Learning Objectives

By completing these labs, you will:
- Master multi-stage CI/CD pipeline creation and management
- Understand automated build, test, and deployment processes
- Implement advanced deployment strategies and rollback procedures
- Configure pipeline monitoring and troubleshooting
- Integrate security scanning and quality gates into pipelines

## 📚 Labs Available

### [CodePipeline Lab](codepipeline/lab-guide.md)
**Duration**: 60 minutes | **Difficulty**: Intermediate

Learn to create comprehensive multi-stage CI/CD pipelines with source, build, test, and deploy stages.

**Key Topics**:
- Multi-stage pipeline orchestration
- S3 source integration and artifact management
- Pipeline monitoring and failure handling
- Advanced pipeline features and optimization

**Resources Created**:
- CodePipeline with 4 stages
- S3 buckets for source and artifacts
- CodeBuild projects for build and test
- IAM roles and policies

### [CodeBuild Lab](codebuild/lab-guide.md)
**Duration**: 45 minutes | **Difficulty**: Intermediate

Master advanced build scenarios with custom environments, parallel builds, and build optimization.

**Key Topics**:
- Custom build environments and Docker images
- Build specification (buildspec.yml) advanced features
- Build caching and optimization strategies
- Integration with security scanning tools

**Resources Created**:
- Multiple CodeBuild projects
- Custom build environments
- Build artifact storage
- CloudWatch Logs for build monitoring

### [CodeDeploy Lab](codedeploy/lab-guide.md)
**Duration**: 50 minutes | **Difficulty**: Advanced

Implement sophisticated deployment strategies for EC2, ECS, and Lambda with automated rollback.

**Key Topics**:
- Blue-green and rolling deployment strategies
- Deployment configurations and health checks
- Automated rollback triggers and procedures
- Multi-target deployment scenarios

**Resources Created**:
- CodeDeploy applications and deployment groups
- EC2 instances with CodeDeploy agent
- Application Load Balancer configurations
- CloudWatch alarms for deployment monitoring

## 🔧 Prerequisites

### Technical Requirements
- **AWS Account**: With administrative access or appropriate IAM permissions
- **AWS CLI**: Version 2.x configured with your credentials
- **Git**: For source code management and version control
- **Text Editor**: VS Code, Sublime Text, or similar for editing configurations
- **Python 3.8+**: For running automation scripts (optional)

### Knowledge Prerequisites
- **CI/CD Concepts**: Understanding of continuous integration and deployment
- **AWS Basics**: Familiarity with IAM, S3, EC2, and CloudFormation
- **Version Control**: Basic Git operations and branching strategies
- **YAML/JSON**: Ability to read and modify configuration files

### AWS Permissions Required
Your IAM user/role needs these managed policies or equivalent permissions:
- `AWSCodePipelineFullAccess`
- `AWSCodeBuildAdminAccess`
- `AWSCodeDeployFullAccess`
- `AmazonS3FullAccess`
- `IAMFullAccess` (for creating service roles)
- `CloudWatchFullAccess`

## 💰 Cost Breakdown

### Free Tier Eligible
- **CodeDeploy**: Free for EC2/on-premises deployments
- **S3**: 5GB storage, 20,000 GET requests, 2,000 PUT requests/month
- **CloudWatch**: 10 custom metrics, 10 alarms, 1 million API requests/month

### Paid Services
- **CodePipeline**: $1.00/month per active pipeline
- **CodeBuild**: $0.005/minute for general1.small compute type
- **EC2 Instances**: ~$0.0104/hour for t3.micro (varies by region)
- **Application Load Balancer**: $0.0225/hour + $0.008/LCU-hour

### Estimated Lab Costs
| Lab | Duration | Free Tier Cost | Standard Cost |
|-----|----------|----------------|---------------|
| CodePipeline | 60 min | $0.00 | $2.50 |
| CodeBuild | 45 min | $0.00 | $1.50 |
| CodeDeploy | 50 min | $0.00 | $3.00 |
| **Total** | **2.5 hours** | **$0.00** | **$7.00** |

> **💡 Cost Optimization Tips**:
> - Use t3.micro instances (Free Tier eligible)
> - Clean up resources immediately after labs
> - Monitor costs with AWS Budgets
> - Use provided cleanup scripts

## 🚀 Getting Started

### Quick Start Guide
1. **Choose your first lab**: Start with CodePipeline for foundational concepts
2. **Review prerequisites**: Ensure you have all required tools and permissions
3. **Estimate costs**: Use the AWS Pricing Calculator for your specific region
4. **Set up billing alerts**: Configure budget alerts before starting
5. **Follow the lab guide**: Each lab includes step-by-step instructions

### Recommended Learning Path
1. **CodePipeline Lab** → Learn pipeline orchestration fundamentals
2. **CodeBuild Lab** → Master build processes and optimization
3. **CodeDeploy Lab** → Implement advanced deployment strategies

### Lab Execution Tips
- **Read the entire lab guide** before starting
- **Take notes** of resource names and configurations
- **Use version control** for any custom configurations
- **Monitor costs** regularly during lab execution
- **Clean up resources** immediately after completion

## 🔍 Troubleshooting

### Common Issues
1. **Permission Errors**: Verify IAM policies and service roles
2. **Pipeline Failures**: Check CloudWatch Logs for detailed error messages
3. **Build Failures**: Validate buildspec.yml syntax and dependencies
4. **Deployment Issues**: Verify target health and security group configurations

### Debugging Resources
- [AWS CodePipeline Troubleshooting Guide](https://docs.aws.amazon.com/codepipeline/latest/userguide/troubleshooting.html)
- [CodeBuild Troubleshooting](https://docs.aws.amazon.com/codebuild/latest/userguide/troubleshooting.html)
- [CodeDeploy Troubleshooting](https://docs.aws.amazon.com/codedeploy/latest/userguide/troubleshooting.html)

## 🎓 Certification Relevance

These labs directly address AWS DevOps Professional exam domains:

### Domain 1: SDLC Automation (22%)
- **1.1**: Automate CI/CD pipeline concepts
- **1.2**: Determine source control strategies
- **1.3**: Apply concepts for build and deployment
- **1.4**: Apply security concepts to CI/CD

### Domain 2: Configuration Management and IaC (19%)
- **2.1**: Determine deployment services based on needs
- **2.2**: Determine application and infrastructure deployment models

### Key Exam Topics Covered
- Pipeline orchestration and stage management
- Build automation and artifact management
- Deployment strategies and rollback procedures
- Security integration in CI/CD workflows
- Monitoring and troubleshooting pipelines

## 📖 Additional Resources

### AWS Documentation
- [AWS CodePipeline User Guide](https://docs.aws.amazon.com/codepipeline/latest/userguide/)
- [AWS CodeBuild User Guide](https://docs.aws.amazon.com/codebuild/latest/userguide/)
- [AWS CodeDeploy User Guide](https://docs.aws.amazon.com/codedeploy/latest/userguide/)

### Best Practices
- [CI/CD Best Practices on AWS](https://docs.aws.amazon.com/prescriptive-guidance/latest/strategy-cicd-litmus/)
- [AWS DevOps Blog](https://aws.amazon.com/blogs/devops/)

### Community Resources
- [AWS Samples - CI/CD](https://github.com/aws-samples?q=cicd)
- [AWS DevOps Professional Study Guide](https://aws.amazon.com/certification/certified-devops-engineer-professional/)

---

**Ready to start building CI/CD pipelines?** Begin with the [CodePipeline Lab](codepipeline/lab-guide.md) to establish your foundation!