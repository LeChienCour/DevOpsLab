# Security and Compliance Labs

This module provides comprehensive hands-on experience with AWS security practices, focusing on identity and access management, secrets management, and automated security scanning in DevOps pipelines. These labs are designed to help you master security concepts for the AWS DevOps Professional certification.

## 🎯 Learning Objectives

By completing these labs, you will:
- Implement IAM best practices including least-privilege policies and role-based access
- Master secure secrets management with AWS Secrets Manager and Parameter Store
- Set up automated security scanning in CI/CD pipelines with multiple tools
- Configure runtime security monitoring and incident response
- Understand compliance automation and security governance
- Integrate security controls throughout the DevOps lifecycle

## 📚 Labs Available

### [IAM Best Practices Lab](iam/lab-guide.md)
**Duration**: 60 minutes | **Difficulty**: Intermediate

Learn to implement IAM best practices including least-privilege policies, role-based access control, and security monitoring.

**Key Topics**:
- Least-privilege IAM policy design and implementation
- Cross-account role assumption with trust policies
- IAM Access Analyzer for policy validation and optimization
- CloudTrail integration for security monitoring and alerting
- IAM policy evaluation logic and troubleshooting
- Service-linked roles and resource-based policies

**Resources Created**:
- Multiple IAM users with different permission levels
- Custom IAM policies following least-privilege principles
- Cross-account IAM roles with trust relationships
- CloudTrail logging configuration for security events
- CloudWatch alarms for suspicious IAM activities
- Access Analyzer findings and recommendations

### [Secrets Management Lab](secrets/lab-guide.md)
**Duration**: 75 minutes | **Difficulty**: Intermediate

Master secure secrets management using AWS Secrets Manager and Parameter Store with application integration.

**Key Topics**:
- AWS Secrets Manager integration with applications
- Parameter Store hierarchical organization and access patterns
- Automatic credential rotation for RDS and other services
- Application-level secrets retrieval and caching
- Cross-region secrets replication for disaster recovery
- Secrets encryption with customer-managed KMS keys

**Resources Created**:
- Secrets Manager secrets with automatic rotation
- Parameter Store hierarchies for different environments
- RDS instance with automated credential rotation
- Lambda functions demonstrating secrets retrieval
- Sample applications with secure secrets integration
- KMS keys for secrets encryption

### [Security Scanning Integration Lab](scanning/lab-guide.md)
**Duration**: 90 minutes | **Difficulty**: Advanced

Implement comprehensive automated security scanning using CodeGuru, Inspector, and third-party tools in CI/CD pipelines.

**Key Topics**:
- CodeGuru Reviewer integration for code quality and security
- Amazon Inspector V2 for container and instance vulnerability scanning
- SAST/DAST tool integration in CodeBuild pipelines
- Container image security scanning with ECR
- Infrastructure security scanning with third-party tools
- Security findings aggregation and reporting

**Resources Created**:
- CodeGuru Reviewer association with repositories
- Inspector V2 configuration for EC2 and container scanning
- CodeBuild projects with integrated security scanning
- ECR repositories with image scanning enabled
- Security Hub for centralized findings management
- Lambda functions for custom security checks

## 🔧 Prerequisites

### Technical Requirements
- **AWS Account**: With administrative access or appropriate IAM permissions
- **AWS CLI**: Version 2.x configured with your credentials
- **Docker**: For container security labs and image scanning
- **Git**: For code repository management and scanning
- **Development Environment**: Node.js 18+ or Python 3.8+ for sample applications

### Knowledge Prerequisites
- **AWS Security Fundamentals**: Understanding of IAM, encryption, and network security
- **DevOps Practices**: CI/CD pipelines and automation concepts
- **Application Security**: Basic understanding of common vulnerabilities (OWASP Top 10)
- **Compliance Frameworks**: Familiarity with SOC, PCI DSS, or similar standards
- **Container Security**: Docker security best practices

### AWS Permissions Required
Your IAM user/role needs these managed policies or equivalent permissions:
- `IAMFullAccess`
- `SecretsManagerReadWrite`
- `AmazonSSMFullAccess`
- `AmazonInspector2FullAccess`
- `CodeGuruReviewerFullAccess`
- `SecurityHubFullAccess`
- `AWSCloudTrailFullAccess`
- `CloudWatchFullAccess`

## 💰 Cost Breakdown

### Free Tier Eligible Services
- **IAM**: Always free for users, roles, and policies
- **CloudTrail**: First trail free, 90-day event history
- **Parameter Store**: Standard parameters are free (up to 10,000)
- **CloudWatch**: 10 custom metrics, 10 alarms, 1 million API requests
- **Security Hub**: 30-day free trial, then $0.0010 per finding

### Paid Services
- **Secrets Manager**: $0.40/secret/month + $0.05/10,000 API calls
- **Inspector V2**: $0.09/instance/month + $0.01/container image scan
- **CodeGuru Reviewer**: $0.75/100 lines of code analyzed
- **RDS**: $0.017/hour for db.t3.micro + storage costs
- **EC2**: $0.0104/hour for t3.micro instances
- **ECR**: $0.10/GB/month for image storage
- **KMS**: $1.00/month per customer-managed key + usage costs

### Estimated Lab Costs
| Lab | Duration | Free Tier Cost | Standard Cost |
|-----|----------|----------------|---------------|
| IAM Best Practices | 60 min | $0.00 | $1.50 |
| Secrets Management | 75 min | $2.00 | $8.00 |
| Security Scanning | 90 min | $3.00 | $12.00 |
| **Total** | **3.75 hours** | **$5.00** | **$21.50** |

> **💡 Cost Optimization Tips**:
> - Use t3.micro instances (Free Tier eligible)
> - Delete secrets after lab completion to avoid monthly charges
> - Use standard Parameter Store parameters (free)
> - Clean up ECR repositories to avoid storage costs
> - Disable Inspector V2 after completing labs

## 🚀 Getting Started

### Recommended Learning Path
1. **IAM Best Practices** → Foundation of AWS security
2. **Secrets Management** → Secure application configuration
3. **Security Scanning** → Automated security in CI/CD

### Security-First Approach
- **Start with IAM**: Establish secure access patterns first
- **Implement Defense in Depth**: Multiple layers of security controls
- **Automate Security**: Integrate security into every stage of development
- **Monitor Continuously**: Set up alerting for security events
- **Practice Incident Response**: Understand how to respond to security findings

## 🔒 Security Concepts Covered

### Identity and Access Management
- **Principle of Least Privilege**: Minimal required permissions
- **Role-Based Access Control**: Permissions based on job functions
- **Temporary Credentials**: STS and role assumption patterns
- **Policy Evaluation**: Understanding AWS policy logic
- **Cross-Account Access**: Secure resource sharing between accounts

### Secrets and Configuration Management
- **Secrets Lifecycle**: Creation, rotation, and deletion
- **Encryption at Rest**: KMS integration for secrets protection
- **Encryption in Transit**: TLS for secrets retrieval
- **Application Integration**: Secure secrets consumption patterns
- **Audit and Compliance**: Tracking secrets access and usage

### Security Scanning and Monitoring
- **Static Analysis**: Code scanning for vulnerabilities
- **Dynamic Analysis**: Runtime security testing
- **Container Security**: Image scanning and runtime protection
- **Infrastructure Security**: Configuration compliance scanning
- **Continuous Monitoring**: Real-time security event detection

### Compliance and Governance
- **Security Standards**: Implementation of security frameworks
- **Audit Trails**: Comprehensive logging and monitoring
- **Policy Enforcement**: Automated compliance checking
- **Risk Assessment**: Vulnerability prioritization and remediation
- **Incident Response**: Security event handling procedures

## 🔍 Security Tools Integration

### AWS Native Security Services
- **AWS Security Hub**: Centralized security findings management
- **Amazon GuardDuty**: Threat detection and monitoring
- **AWS Config**: Configuration compliance monitoring
- **AWS CloudTrail**: API activity logging and analysis
- **Amazon Inspector**: Vulnerability assessment service

### Third-Party Security Tools
- **SAST Tools**: Static application security testing
- **DAST Tools**: Dynamic application security testing
- **Container Scanners**: Specialized container vulnerability scanners
- **Infrastructure Scanners**: Cloud configuration security tools
- **Compliance Tools**: Automated compliance checking solutions

### CI/CD Security Integration
- **Pre-commit Hooks**: Security checks before code commit
- **Build-time Scanning**: Security analysis during build process
- **Deployment Gates**: Security approval before production deployment
- **Runtime Monitoring**: Continuous security monitoring in production
- **Feedback Loops**: Security findings integration with development workflow

## 🎓 Certification Relevance

These labs directly address AWS DevOps Professional exam domains:

### Domain 4: Policies and Standards Automation (10%)
- **4.1**: Apply concepts required to enforce standards for logging, metrics, monitoring, testing, and security
- **4.2**: Determine how to optimize cost through automation
- **4.3**: Apply concepts required to implement governance strategies

### Domain 1: SDLC Automation (22%)
- **1.4**: Apply concepts required to automate security checks in CI/CD pipelines
- **1.1**: Apply concepts required to automate a CI/CD pipeline with security integration

### Domain 5: Incident and Event Response (18%)
- **5.1**: Troubleshoot issues and determine how to restore operations
- **5.2**: Determine how to automate event management and alerting
- **5.3**: Apply concepts required to implement automated healing

### Key Exam Topics Covered
- IAM policy design and least-privilege implementation
- Secrets management best practices and automation
- Security scanning integration in CI/CD pipelines
- Compliance automation and governance
- Security monitoring and incident response
- Cross-account security patterns
- Container and infrastructure security

## 🔧 Troubleshooting

### Common Security Issues

#### IAM Permission Problems
- **Access Denied Errors**: Check policy evaluation logic and explicit denies
- **Cross-Account Issues**: Verify trust relationships and external ID usage
- **Service Role Problems**: Ensure proper service-linked role configuration
- **Policy Size Limits**: Break large policies into smaller, focused policies

#### Secrets Management Issues
- **Rotation Failures**: Check Lambda function permissions and network connectivity
- **Application Integration**: Verify SDK configuration and error handling
- **Cross-Region Access**: Ensure secrets are replicated to required regions
- **KMS Key Access**: Verify key policies allow secrets service access

#### Security Scanning Problems
- **False Positives**: Configure tool-specific suppression rules
- **Performance Impact**: Optimize scanning frequency and scope
- **Integration Failures**: Check service permissions and network connectivity
- **Report Generation**: Ensure proper output formatting and storage

### Security Debugging Tools

```bash
# IAM Policy Simulation
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT:user/USERNAME \
  --action-names s3:GetObject \
  --resource-arns arn:aws:s3:::bucket/key

# CloudTrail Event Analysis
aws logs filter-log-events \
  --log-group-name CloudTrail/APIGatewayExecutionLogs \
  --filter-pattern "ERROR"

# Secrets Manager Troubleshooting
aws secretsmanager describe-secret --secret-id MySecret
aws secretsmanager get-secret-value --secret-id MySecret

# Security Hub Findings
aws securityhub get-findings \
  --filters '{"ProductArn": [{"Value": "arn:aws:securityhub:*:*:product/*/Inspector", "Comparison": "EQUALS"}]}'
```

## 📖 Additional Resources

### AWS Security Documentation
- [AWS Security Best Practices](https://docs.aws.amazon.com/security/)
- [IAM Best Practices Guide](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [AWS Secrets Manager User Guide](https://docs.aws.amazon.com/secretsmanager/latest/userguide/)
- [Amazon Inspector User Guide](https://docs.aws.amazon.com/inspector/latest/user/)

### Security Frameworks and Standards
- [AWS Well-Architected Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CIS AWS Foundations Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services)

### DevSecOps Resources
- [AWS DevSecOps Best Practices](https://aws.amazon.com/blogs/devops/building-end-to-end-aws-devsecops-ci-cd-pipeline-with-open-source-sca-sast-and-dast-tools/)
- [Shift-Left Security](https://docs.aws.amazon.com/whitepapers/latest/devsecops-on-aws/shift-left-security.html)
- [Container Security Best Practices](https://aws.amazon.com/blogs/containers/amazon-ecr-native-container-image-scanning/)

---

**Ready to secure your DevOps pipeline?** Start with the [IAM Best Practices Lab](iam/lab-guide.md) to establish your security foundation!