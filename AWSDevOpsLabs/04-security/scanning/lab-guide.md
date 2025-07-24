# Security Scanning Lab Guide

## Objective
Learn to implement comprehensive security scanning in your DevOps pipeline using AWS CodeGuru, Amazon Inspector, and third-party security tools. This lab covers static code analysis, dependency vulnerability scanning, container image scanning, and infrastructure security assessment.

## Learning Outcomes
By completing this lab, you will:
- Set up automated security scanning in CI/CD pipelines
- Implement static code analysis using Amazon CodeGuru Reviewer
- Configure container image vulnerability scanning with Amazon ECR
- Use Amazon Inspector for runtime security assessment
- Integrate third-party security scanning tools (Snyk, OWASP ZAP)
- Create security gates and automated remediation workflows

## Prerequisites
- AWS Account with administrative access
- AWS CLI configured with appropriate permissions
- Docker installed locally
- Git repository with sample application code
- Basic understanding of CI/CD pipelines and security concepts
- Node.js or Python development environment

### Required AWS Permissions
Your AWS user/role needs the following permissions:
- **CodeGuru**: Full access for code analysis
- **Inspector**: Full access for security assessments
- **ECR**: Full access for container scanning
- **CodeBuild**: Full access for CI/CD integration
- **CodePipeline**: Full access for pipeline automation
- **Lambda**: Full access for custom scanning functions
- **S3**: Full access for storing scan results
- **IAM**: Full access for creating service roles

### Time to Complete
Approximately 75-90 minutes## A
rchitecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                Security Scanning Architecture                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐                    │
│  │   Developer     │    │   Git           │                    │
│  │   Commits       │───▶│   Repository    │                    │
│  └─────────────────┘    └─────────┬───────┘                    │
│                                   │                            │
│                                   ▼                            │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              CI/CD Pipeline                             │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │   │
│  │  │   Source    │  │    Build    │  │   Deploy    │   │   │
│  │  │             │  │             │  │             │   │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                            │                                   │
│                            ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Security Scanning Layer                   │   │
│  │                                                         │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │   │
│  │  │  CodeGuru   │  │    ECR      │  │  Inspector  │   │   │
│  │  │  Reviewer   │  │  Scanning   │  │  Runtime    │   │   │
│  │  │ (SAST)      │  │ (Container) │  │ (DAST)      │   │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘   │   │
│  │                                                         │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │   │
│  │  │    Snyk     │  │  OWASP ZAP  │  │   Custom    │   │   │
│  │  │ (SCA/SAST)  │  │   (DAST)    │  │  Scanners   │   │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                            │                                   │
│                            ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │            Results Aggregation & Reporting              │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │   │
│  │  │ S3 Bucket   │  │ CloudWatch  │  │    SNS      │   │   │
│  │  │ (Reports)   │  │ (Metrics)   │  │ (Alerts)    │   │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                            │                                   │
│                            ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Security Gates & Actions                   │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │   │
│  │  │   Block     │  │   Create    │  │  Notify     │   │   │
│  │  │ Deployment  │  │   Tickets   │  │   Teams     │   │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘   │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Resources Created:
- **CodeGuru Reviewer**: Code quality and security analysis
- **ECR Repository**: Container image with vulnerability scanning
- **Inspector Assessment**: Runtime security evaluation
- **CodeBuild Projects**: Security scanning build jobs
- **Lambda Functions**: Custom security scanning logic
- **S3 Bucket**: Security scan results storage
- **CloudWatch Dashboards**: Security metrics visualization## Lab 
Steps

### Step 1: Set Up Sample Application for Scanning

1. **Create a sample vulnerable Node.js application:**
   ```bash
   mkdir security-scanning-lab
   cd security-scanning-lab
   
   # Initialize Node.js project
   npm init -y
   
   # Install some packages with known vulnerabilities (for demonstration)
   npm install express@4.16.0 lodash@4.17.4 moment@2.24.0
   ```

2. **Create a vulnerable application with security issues:**
   ```bash
   cat > app.js << 'EOF'
   const express = require('express');
   const fs = require('fs');
   const path = require('path');
   const _ = require('lodash');
   const moment = require('moment');
   
   const app = express();
   const port = process.env.PORT || 3000;
   
   // Security Issue 1: Missing input validation
   app.get('/user/:id', (req, res) => {
       const userId = req.params.id;
       // SQL Injection vulnerability (simulated)
       const query = `SELECT * FROM users WHERE id = ${userId}`;
       console.log('Executing query:', query);
       res.json({ message: 'User data retrieved', query: query });
   });
   
   // Security Issue 2: Path traversal vulnerability
   app.get('/file/:filename', (req, res) => {
       const filename = req.params.filename;
       const filePath = path.join(__dirname, 'files', filename);
       
       // Vulnerable to path traversal
       fs.readFile(filePath, 'utf8', (err, data) => {
           if (err) {
               res.status(404).json({ error: 'File not found' });
           } else {
               res.json({ content: data });
           }
       });
   });
   
   // Security Issue 3: Hardcoded credentials
   const DATABASE_PASSWORD = 'hardcoded-password-123';
   const API_KEY = 'sk-1234567890abcdef';
   
   // Security Issue 4: Insecure random number generation
   app.get('/token', (req, res) => {
       const token = Math.random().toString(36).substring(2);
       res.json({ token: token });
   });
   
   // Security Issue 5: Missing security headers
   app.get('/admin', (req, res) => {
       res.json({ message: 'Admin panel', sensitive: 'data' });
   });
   
   // Security Issue 6: Prototype pollution (via lodash)
   app.post('/merge', express.json(), (req, res) => {
       const result = _.merge({}, req.body);
       res.json(result);
   });
   
   app.listen(port, () => {
       console.log(`Server running on port ${port}`);
   });
   EOF
   ```

3. **Create Dockerfile with security issues:**
   ```bash
   cat > Dockerfile << 'EOF'
   # Security Issue: Using outdated base image
   FROM node:14.15.0
   
   # Security Issue: Running as root user
   WORKDIR /app
   
   # Security Issue: Copying entire context
   COPY . .
   
   # Security Issue: Not specifying exact versions
   RUN npm install
   
   # Security Issue: Exposing unnecessary ports
   EXPOSE 3000 8080
   
   # Security Issue: Running as root
   CMD ["node", "app.js"]
   EOF
   ```

4. **Initialize Git repository:**
   ```bash
   git init
   git add .
   git commit -m "Initial commit with vulnerable code"
   ```### 
Step 2: Set Up Amazon CodeGuru Reviewer

1. **Create CodeCommit repository:**
   ```bash
   aws codecommit create-repository \
       --repository-name security-scanning-lab \
       --repository-description "Repository for security scanning lab"
   
   # Get the clone URL
   REPO_URL=$(aws codecommit get-repository \
       --repository-name security-scanning-lab \
       --query 'repositoryMetadata.cloneUrlHttp' \
       --output text)
   
   echo "Repository URL: $REPO_URL"
   ```

2. **Push code to CodeCommit:**
   ```bash
   # Configure Git credentials helper for CodeCommit
   git config credential.helper '!aws codecommit credential-helper $@'
   git config credential.UseHttpPath true
   
   # Add remote and push
   git remote add origin $REPO_URL
   git push -u origin main
   ```

3. **Enable CodeGuru Reviewer:**
   ```bash
   # Create association with CodeCommit repository
   aws codeguru-reviewer associate-repository \
       --repository CodeCommitRepository='{Name=security-scanning-lab}' \
       --type CodeCommit
   
   # Check association status
   aws codeguru-reviewer list-repository-associations \
       --query 'RepositoryAssociationSummaries[?Name==`security-scanning-lab`]'
   ```

### Step 3: Set Up Container Image Scanning with ECR

1. **Create ECR repository with scan on push enabled:**
   ```bash
   aws ecr create-repository \
       --repository-name security-scanning-lab \
       --image-scanning-configuration scanOnPush=true
   
   # Get repository URI
   ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
   REGION=$(aws configure get region)
   ECR_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/security-scanning-lab"
   ```

2. **Build and push Docker image:**
   ```bash
   # Get ECR login token
   aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI
   
   # Build image
   docker build -t security-scanning-lab .
   docker tag security-scanning-lab:latest $ECR_URI:latest
   
   # Push image (this will trigger automatic scanning)
   docker push $ECR_URI:latest
   ```

3. **Check scan results:**
   ```bash
   # Wait for scan to complete
   echo "Waiting for image scan to complete..."
   sleep 30
   
   # Get scan results
   aws ecr describe-image-scan-findings \
       --repository-name security-scanning-lab \
       --image-id imageTag=latest \
       --query 'imageScanFindings.findings[*].[name,severity,description]' \
       --output table
   ```### Step
 4: Set Up Amazon Inspector for Runtime Assessment

1. **Create EC2 instance for Inspector assessment:**
   ```bash
   # Create key pair
   aws ec2 create-key-pair \
       --key-name security-lab-key \
       --query 'KeyMaterial' \
       --output text > security-lab-key.pem
   chmod 400 security-lab-key.pem
   
   # Get default VPC and subnet
   DEFAULT_VPC=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text)
   SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$DEFAULT_VPC" --query 'Subnets[0].SubnetId' --output text)
   
   # Create security group
   SG_ID=$(aws ec2 create-security-group \
       --group-name security-lab-sg \
       --description "Security group for Inspector lab" \
       --vpc-id $DEFAULT_VPC \
       --query 'GroupId' --output text)
   
   # Allow SSH access
   aws ec2 authorize-security-group-ingress \
       --group-id $SG_ID \
       --protocol tcp \
       --port 22 \
       --cidr 0.0.0.0/0
   
   # Launch EC2 instance
   INSTANCE_ID=$(aws ec2 run-instances \
       --image-id ami-0c02fb55956c7d316 \
       --instance-type t3.micro \
       --key-name security-lab-key \
       --security-group-ids $SG_ID \
       --subnet-id $SUBNET_ID \
       --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=security-lab-instance}]' \
       --query 'Instances[0].InstanceId' \
       --output text)
   
   echo "Instance ID: $INSTANCE_ID"
   ```

2. **Set up Inspector V2:**
   ```bash
   # Enable Inspector V2
   aws inspector2 enable \
       --resource-types ECR EC2
   
   # Check enablement status
   aws inspector2 batch-get-account-status \
       --account-ids $ACCOUNT_ID
   ```

### Step 5: Integrate Third-Party Security Tools

1. **Create S3 bucket for scan results:**
   ```bash
   RESULTS_BUCKET="security-scan-results-${ACCOUNT_ID}-${REGION}"
   aws s3 mb s3://$RESULTS_BUCKET
   
   # Enable versioning
   aws s3api put-bucket-versioning \
       --bucket $RESULTS_BUCKET \
       --versioning-configuration Status=Enabled
   ```

2. **Create CodeBuild project for security scanning:**
   ```bash
   cat > snyk-buildspec.yml << 'EOF'
   version: 0.2
   
   phases:
     install:
       runtime-versions:
         nodejs: 14
       commands:
         - echo Installing security scanning tools
         - npm install -g snyk
         - npm install -g retire
     
     pre_build:
       commands:
         - echo Starting security scans
         - npm install
     
     build:
       commands:
         - echo Running dependency vulnerability scan
         - npm audit --json > npm-audit-results.json || true
         - echo Running retire.js scan
         - retire --outputformat json --outputpath retire-results.json || true
         - echo Running basic SAST checks
         - grep -r "password\|secret\|key" . --include="*.js" > secrets-scan.txt || true
     
     post_build:
       commands:
         - echo Security scan completed
         - echo Uploading results to S3
         - aws s3 cp npm-audit-results.json s3://$RESULTS_BUCKET/scans/
         - aws s3 cp retire-results.json s3://$RESULTS_BUCKET/scans/
         - aws s3 cp secrets-scan.txt s3://$RESULTS_BUCKET/scans/
   
   artifacts:
     files:
       - '*-results.json'
       - 'secrets-scan.txt'
   EOF
   ```3
. **Create IAM role for CodeBuild:**
   ```bash
   cat > codebuild-trust-policy.json << 'EOF'
   {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Effect": "Allow",
               "Principal": {
                   "Service": "codebuild.amazonaws.com"
               },
               "Action": "sts:AssumeRole"
           }
       ]
   }
   EOF
   
   aws iam create-role \
       --role-name SecurityScanCodeBuildRole \
       --assume-role-policy-document file://codebuild-trust-policy.json
   
   # Create custom policy for security scanning
   cat > security-scan-policy.json << EOF
   {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Effect": "Allow",
               "Action": [
                   "logs:CreateLogGroup",
                   "logs:CreateLogStream",
                   "logs:PutLogEvents"
               ],
               "Resource": "arn:aws:logs:*:*:*"
           },
           {
               "Effect": "Allow",
               "Action": [
                   "s3:GetObject",
                   "s3:PutObject"
               ],
               "Resource": [
                   "arn:aws:s3:::${RESULTS_BUCKET}/*"
               ]
           },
           {
               "Effect": "Allow",
               "Action": [
                   "ecr:GetAuthorizationToken",
                   "ecr:BatchCheckLayerAvailability",
                   "ecr:GetDownloadUrlForLayer",
                   "ecr:BatchGetImage"
               ],
               "Resource": "*"
           }
       ]
   }
   EOF
   
   aws iam create-policy \
       --policy-name SecurityScanPolicy \
       --policy-document file://security-scan-policy.json
   
   # Attach policies to role
   POLICY_ARN=$(aws iam list-policies --query 'Policies[?PolicyName==`SecurityScanPolicy`].Arn' --output text)
   aws iam attach-role-policy \
       --role-name SecurityScanCodeBuildRole \
       --policy-arn $POLICY_ARN
   ```

4. **Create CodeBuild project:**
   ```bash
   cat > codebuild-project.json << EOF
   {
       "name": "security-scanning-project",
       "description": "Security scanning with multiple tools",
       "source": {
           "type": "CODECOMMIT",
           "location": "$REPO_URL",
           "buildspec": "snyk-buildspec.yml"
       },
       "artifacts": {
           "type": "S3",
           "location": "$RESULTS_BUCKET/artifacts"
       },
       "environment": {
           "type": "LINUX_CONTAINER",
           "image": "aws/codebuild/amazonlinux2-x86_64-standard:3.0",
           "computeType": "BUILD_GENERAL1_SMALL",
           "environmentVariables": [
               {
                   "name": "RESULTS_BUCKET",
                   "value": "$RESULTS_BUCKET"
               },
               {
                   "name": "ECR_URI",
                   "value": "$ECR_URI"
               }
           ]
       },
       "serviceRole": "arn:aws:iam::${ACCOUNT_ID}:role/SecurityScanCodeBuildRole"
   }
   EOF
   
   aws codebuild create-project --cli-input-json file://codebuild-project.json
   ```### Step 6:
 Create Security Monitoring and Alerting

1. **Create CloudWatch dashboard:**
   ```bash
   cat > security-dashboard.json << 'EOF'
   {
       "widgets": [
           {
               "type": "metric",
               "x": 0,
               "y": 0,
               "width": 12,
               "height": 6,
               "properties": {
                   "metrics": [
                       [ "AWS/CodeBuild", "Builds", "ProjectName", "security-scanning-project" ],
                       [ ".", "Duration", ".", "." ],
                       [ ".", "FailedBuilds", ".", "." ]
                   ],
                   "period": 300,
                   "stat": "Sum",
                   "region": "us-east-1",
                   "title": "Security Scan Builds"
               }
           },
           {
               "type": "log",
               "x": 0,
               "y": 6,
               "width": 24,
               "height": 6,
               "properties": {
                   "query": "SOURCE '/aws/codebuild/security-scanning-project'\n| fields @timestamp, @message\n| filter @message like /ERROR/\n| sort @timestamp desc\n| limit 20",
                   "region": "us-east-1",
                   "title": "Security Scanner Errors"
               }
           }
       ]
   }
   EOF
   
   aws cloudwatch put-dashboard \
       --dashboard-name "SecurityScanning" \
       --dashboard-body file://security-dashboard.json
   ```

2. **Create SNS topic for security alerts:**
   ```bash
   aws sns create-topic --name security-scan-alerts
   TOPIC_ARN=$(aws sns list-topics --query 'Topics[?contains(TopicArn, `security-scan-alerts`)].TopicArn' --output text)
   
   # Create CloudWatch alarm for high severity findings
   aws cloudwatch put-metric-alarm \
       --alarm-name "High-Severity-Security-Findings" \
       --alarm-description "Alert on high severity security findings" \
       --metric-name "HighSeverityFindings" \
       --namespace "SecurityScanning" \
       --statistic Sum \
       --period 300 \
       --threshold 1 \
       --comparison-operator GreaterThanOrEqualToThreshold \
       --evaluation-periods 1 \
       --alarm-actions $TOPIC_ARN
   ```

### Step 7: Test Security Scanning Pipeline

1. **Add buildspec to repository:**
   ```bash
   # Copy buildspec to repository
   cp snyk-buildspec.yml security-scanning-lab/
   cd security-scanning-lab
   git add snyk-buildspec.yml
   git commit -m "Add security scanning buildspec"
   git push origin main
   cd ..
   ```

2. **Trigger CodeBuild scan:**
   ```bash
   # Start build
   BUILD_ID=$(aws codebuild start-build \
       --project-name security-scanning-project \
       --query 'build.id' \
       --output text)
   
   echo "Build started: $BUILD_ID"
   
   # Monitor build status
   aws codebuild batch-get-builds --ids $BUILD_ID \
       --query 'builds[0].buildStatus' \
       --output text
   ```

3. **Check scan results in S3:**
   ```bash
   # Wait for build to complete
   echo "Waiting for build to complete..."
   sleep 120
   
   # List scan results
   aws s3 ls s3://$RESULTS_BUCKET/ --recursive
   
   # Download scan results
   aws s3 sync s3://$RESULTS_BUCKET/scans/ ./scan-results/
   
   # View results
   if [ -f "./scan-results/npm-audit-results.json" ]; then
       echo "NPM Audit Results:"
       cat ./scan-results/npm-audit-results.json | jq '.vulnerabilities | keys | length'
   fi
   ```## 
Troubleshooting Guide

### Common Issues and Solutions

1. **CodeGuru Reviewer not analyzing code:**
   - Verify repository association is active
   - Ensure pull requests are created (CodeGuru analyzes PR diffs)
   - Check that the repository has supported file types

2. **ECR scan not finding vulnerabilities:**
   - Verify scan on push is enabled
   - Check that the image was pushed successfully
   - Wait for scan completion (can take several minutes)

3. **CodeBuild failing with permission errors:**
   - Verify IAM role has necessary permissions
   - Check S3 bucket policies
   - Ensure ECR access permissions are correct

4. **Inspector not finding instances:**
   - Verify Inspector agent is installed (for Classic)
   - Check that EC2 instances have proper tags
   - Ensure Inspector service is enabled in the region

### Debugging Commands

```bash
# Check CodeGuru association status
aws codeguru-reviewer describe-repository-association \
    --association-arn ASSOCIATION_ARN

# Check ECR scan status
aws ecr describe-image-scan-findings \
    --repository-name REPO_NAME \
    --image-id imageTag=TAG

# Check CodeBuild logs
aws logs get-log-events \
    --log-group-name /aws/codebuild/PROJECT_NAME \
    --log-stream-name LOG_STREAM_NAME

# Check Inspector findings
aws inspector2 list-findings \
    --filter-criteria '{"resourceType":[{"comparison":"EQUALS","value":"ECR_CONTAINER_IMAGE"}]}'

# View build status
aws codebuild batch-get-builds --ids BUILD_ID
```

## Resources Created

This lab creates the following AWS resources:

### Code Analysis and Scanning
- **CodeGuru Reviewer**: 1 repository association
- **ECR Repository**: 1 repository with scan on push enabled
- **Inspector V2**: Enabled for ECR and EC2 scanning

### CI/CD and Automation
- **CodeCommit Repository**: 1 repository for source code
- **CodeBuild Project**: 1 project for security scanning

### Storage and Monitoring
- **S3 Bucket**: 1 bucket for scan results storage
- **CloudWatch Dashboard**: 1 dashboard for security metrics
- **CloudWatch Alarms**: 1 alarm for high severity findings
- **SNS Topic**: 1 topic for security alerts

### Compute and Networking
- **EC2 Instance**: 1 t3.micro instance for Inspector testing
- **Security Group**: 1 security group for EC2 access
- **Key Pair**: 1 key pair for EC2 access

### IAM and Security
- **IAM Roles**: 1 role for CodeBuild
- **IAM Policies**: 1 custom policy for security scanning

### Estimated Costs
- **CodeGuru Reviewer**: $0.75/100 lines of code analyzed
- **ECR**: $0.10/GB/month for storage + scanning costs
- **Inspector V2**: $0.09/instance/month + $0.01/container image scan
- **CodeBuild**: $0.005/build minute
- **EC2 (t3.micro)**: ~$8.5/month (free tier eligible)
- **S3**: $0.023/GB/month + request costs
- **CloudWatch**: $0.50/GB ingested + dashboard costs
- **Total estimated cost**: $15-25/month (depending on usage)## 
Cleanup

When you're finished with the lab, follow these steps to avoid ongoing charges:

1. **Delete CodeBuild resources:**
   ```bash
   # Delete CodeBuild project
   aws codebuild delete-project --name security-scanning-project
   ```

2. **Delete EC2 resources:**
   ```bash
   # Terminate EC2 instance
   aws ec2 terminate-instances --instance-ids $INSTANCE_ID
   aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID
   
   # Delete security group and key pair
   aws ec2 delete-security-group --group-id $SG_ID
   aws ec2 delete-key-pair --key-name security-lab-key
   rm -f security-lab-key.pem
   ```

3. **Delete repositories and images:**
   ```bash
   # Delete ECR repository
   aws ecr delete-repository --repository-name security-scanning-lab --force
   
   # Delete CodeCommit repository
   aws codecommit delete-repository --repository-name security-scanning-lab
   ```

4. **Delete IAM roles and policies:**
   ```bash
   # Detach and delete policies
   aws iam detach-role-policy --role-name SecurityScanCodeBuildRole --policy-arn $POLICY_ARN
   
   # Delete roles
   aws iam delete-role --role-name SecurityScanCodeBuildRole
   
   # Delete custom policy
   aws iam delete-policy --policy-arn $POLICY_ARN
   ```

5. **Delete monitoring and storage resources:**
   ```bash
   # Delete CloudWatch dashboard and alarms
   aws cloudwatch delete-dashboards --dashboard-names SecurityScanning
   aws cloudwatch delete-alarms --alarm-names "High-Severity-Security-Findings"
   
   # Delete SNS topic
   aws sns delete-topic --topic-arn $TOPIC_ARN
   
   # Empty and delete S3 bucket
   aws s3 rm s3://$RESULTS_BUCKET --recursive
   aws s3 rb s3://$RESULTS_BUCKET
   ```

6. **Disable Inspector and CodeGuru:**
   ```bash
   # Disable Inspector V2
   aws inspector2 disable --resource-types ECR EC2
   
   # Disassociate CodeGuru Reviewer
   ASSOCIATION_ARN=$(aws codeguru-reviewer list-repository-associations \
       --query 'RepositoryAssociationSummaries[?Name==`security-scanning-lab`].AssociationArn' \
       --output text)
   aws codeguru-reviewer disassociate-repository --association-arn $ASSOCIATION_ARN
   ```

7. **Clean up local files:**
   ```bash
   rm -rf security-scanning-lab/ scan-results/
   rm -f *.json *.yml *.pem
   ```

> **Important**: Verify all resources are deleted to avoid unexpected charges.

## Next Steps

After completing this lab, consider:

1. **Implement Security as Code** with tools like Checkov or Terrascan
2. **Set up Continuous Compliance** with AWS Config and Security Hub
3. **Explore Advanced SAST Tools** like SonarQube or Veracode
4. **Implement Runtime Security** with AWS GuardDuty and Falco
5. **Learn about Supply Chain Security** with SLSA framework
6. **Practice with Kubernetes Security** scanning tools like Twistlock or Aqua

## Certification Exam Tips

This lab covers several key areas for the AWS DevOps Professional exam:

- **Domain 1**: SDLC Automation (security in CI/CD pipelines)
- **Domain 2**: Configuration Management and IaC (security scanning of infrastructure code)
- **Domain 3**: Monitoring and Logging (security event monitoring)
- **Domain 4**: Policies and Standards Automation (automated security policy enforcement)
- **Domain 5**: Incident and Event Response (security incident detection and response)
- **Domain 6**: High Availability, Fault Tolerance, and Disaster Recovery (security in resilient architectures)

Key concepts to remember:
- **Shift-Left Security**: Integrate security early in the development lifecycle
- **SAST vs DAST**: Static analysis during build vs dynamic analysis at runtime
- **Container Security**: Multi-layer scanning (base image, dependencies, configuration)
- **Compliance as Code**: Automated compliance checking and reporting
- **Security Gates**: Automated decision points in CI/CD pipelines
- **Vulnerability Management**: Prioritization, tracking, and remediation workflows
- **DevSecOps Culture**: Shared responsibility for security across teams

## Additional Resources

- [AWS CodeGuru Reviewer User Guide](https://docs.aws.amazon.com/codeguru/latest/reviewer-ug/)
- [Amazon ECR Image Scanning](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-scanning.html)
- [Amazon Inspector User Guide](https://docs.aws.amazon.com/inspector/latest/user/)
- [AWS Security Hub User Guide](https://docs.aws.amazon.com/securityhub/latest/userguide/)
- [OWASP ZAP Documentation](https://www.zaproxy.org/docs/)
- [Snyk Documentation](https://docs.snyk.io/)
- [AWS DevSecOps Best Practices](https://aws.amazon.com/blogs/devops/building-end-to-end-aws-devsecops-ci-cd-pipeline-with-open-source-sca-sast-and-dast-tools/)