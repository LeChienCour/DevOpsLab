# Advanced CodeBuild Lab Guide

## Objective
Create and configure advanced CodeBuild projects with multiple build environments, caching strategies, parallel builds, and custom build images. This lab demonstrates sophisticated build automation techniques required for AWS DevOps Professional certification.

## Learning Outcomes
By completing this lab, you will:
- Master multiple build environments (Node.js, Python, Java, Docker)
- Implement effective build caching strategies for faster builds
- Configure parallel build execution for complex applications
- Create and use custom Docker build images
- Integrate security scanning and code quality tools
- Understand batch builds and build optimization techniques

## Prerequisites
- AWS CLI installed and configured with appropriate permissions
- Basic understanding of build systems (npm, pip, Maven, Docker)
- Familiarity with AWS CodeBuild concepts
- Text editor for configuration modifications

### Required AWS Permissions
Your AWS user/role needs the following permissions:
- CloudFormation: Full access for stack management
- CodeBuild: Full access for build project creation
- S3: Full access for artifact and cache storage
- ECR: Full access for custom image management
- IAM: Permission to create roles and policies
- CloudWatch Logs: Permission to create and manage log groups

## Architecture Overview

This lab creates multiple specialized CodeBuild projects:

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Source Code   │───▶│   CodeBuild      │───▶│   Artifacts     │
│   (S3 Buckets)  │    │   Projects       │    │   (S3 Bucket)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │   Build Cache    │
                       │   (S3 Bucket)    │
                       └──────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │   Custom Images  │
                       │   (ECR Registry) │
                       └──────────────────┘
```

### Build Projects Created:
- **Node.js Build**: npm/yarn with caching and testing
- **Python Build**: pip/poetry with security scanning
- **Java Build**: Maven/Gradle with code quality analysis
- **Docker Build**: Container builds with layer caching
- **Parallel Build**: Multi-component parallel execution
- **Batch Build**: Multiple build configurations
- **Custom Image Build**: Using custom Docker images

## Lab Steps

### Step 1: Provision the Advanced CodeBuild Environment

1. **Navigate to the CodeBuild lab directory:**
   ```bash
   cd AWSDevOpsLabs/01-cicd/codebuild
   ```

2. **Review the CloudFormation template:**
   - Open `templates/advanced-codebuild-projects.yaml`
   - Examine the different build projects and their configurations
   - Note the caching strategies and environment variables

3. **Review the buildspec files:**
   ```bash
   ls -la buildspecs/
   cat buildspecs/buildspec-nodejs.yml
   cat buildspecs/buildspec-python.yml
   cat buildspecs/buildspec-java.yml
   cat buildspecs/buildspec-docker.yml
   cat buildspecs/buildspec-parallel.yml
   ```

4. **Run the provisioning script:**
   ```bash
   # On Linux/Mac:
   ./scripts/provision-codebuild.sh
   
   # On Windows:
   bash scripts/provision-codebuild.sh
   ```

5. **Monitor the deployment:**
   - The script creates sample projects for each build type
   - CloudFormation stack creation takes 5-10 minutes
   - Sample source code is uploaded to S3 automatically

### Step 2: Explore Build Environments and Caching

1. **Start a Node.js build:**
   ```bash
   # Get the project name from the session info
   PROJECT_NAME=$(grep "Node.js Project:" lab-session-info.txt | cut -d' ' -f3)
   ARTIFACT_BUCKET=$(grep "Artifact Bucket:" lab-session-info.txt | cut -d' ' -f3)
   
   # Start the build
   aws codebuild start-build \
     --project-name "$PROJECT_NAME" \
     --source-location "s3://$ARTIFACT_BUCKET/nodejs-app-source.zip"
   ```

2. **Monitor the build progress:**
   - Go to AWS Console → CodeBuild
   - Find your Node.js project and click on the running build
   - Observe the build phases and caching behavior
   - Note the npm cache being populated

3. **Start a second build to test caching:**
   ```bash
   # Start another build of the same project
   aws codebuild start-build \
     --project-name "$PROJECT_NAME" \
     --source-location "s3://$ARTIFACT_BUCKET/nodejs-app-source.zip"
   ```

4. **Compare build times:**
   - First build: Dependencies downloaded and cached
   - Second build: Dependencies restored from cache
   - Note the significant time difference

### Step 3: Test Different Build Environments

1. **Start a Python build:**
   ```bash
   PYTHON_PROJECT=$(grep "Python Project:" lab-session-info.txt | cut -d' ' -f3)
   
   aws codebuild start-build \
     --project-name "$PYTHON_PROJECT" \
     --source-location "s3://$ARTIFACT_BUCKET/python-app-source.zip"
   ```

2. **Start a Java build:**
   ```bash
   JAVA_PROJECT=$(grep "Java Project:" lab-session-info.txt | cut -d' ' -f3)
   
   aws codebuild start-build \
     --project-name "$JAVA_PROJECT" \
     --source-location "s3://$ARTIFACT_BUCKET/java-app-source.zip"
   ```

3. **Start a Docker build:**
   ```bash
   DOCKER_PROJECT=$(grep "Docker Project:" lab-session-info.txt | cut -d' ' -f3)
   
   aws codebuild start-build \
     --project-name "$DOCKER_PROJECT" \
     --source-location "s3://$ARTIFACT_BUCKET/docker-app-source.zip"
   ```

4. **Analyze build differences:**
   - Compare build times across different environments
   - Examine the different tools and dependencies used
   - Note the security scanning in Python and Docker builds

### Step 4: Explore Parallel Build Execution

1. **Create a multi-component project structure:**
   ```bash
   mkdir -p multi-app/{frontend,backend}
   
   # Create frontend (Node.js)
   cat > multi-app/frontend/package.json << 'EOF'
   {
     "name": "frontend-app",
     "version": "1.0.0",
     "scripts": {
       "test": "echo 'Frontend tests passed'",
       "build": "echo 'Frontend built successfully'"
     },
     "devDependencies": {
       "eslint": "^8.0.0"
     }
   }
   EOF
   
   # Create backend (Python)
   cat > multi-app/backend/requirements.txt << 'EOF'
   flask==2.3.0
   pytest==7.4.0
   EOF
   
   cat > multi-app/backend/app.py << 'EOF'
   from flask import Flask
   app = Flask(__name__)
   
   @app.route('/')
   def hello():
       return 'Backend API'
   EOF
   
   # Create archive
   cd multi-app && zip -r ../multi-app-source.zip . && cd ..
   ```

2. **Upload and test parallel build:**
   ```bash
   # Upload the multi-component source
   aws s3 cp multi-app-source.zip "s3://$ARTIFACT_BUCKET/"
   
   # Start parallel build
   PARALLEL_PROJECT=$(grep "Parallel Project:" lab-session-info.txt | cut -d' ' -f3)
   
   aws codebuild start-build \
     --project-name "$PARALLEL_PROJECT" \
     --source-location "s3://$ARTIFACT_BUCKET/multi-app-source.zip"
   ```

3. **Monitor parallel execution:**
   - Watch the build logs for parallel task execution
   - Note how multiple tasks run simultaneously
   - Examine the parallel execution log and timing

### Step 5: Advanced Build Features

1. **Test batch builds:**
   ```bash
   BATCH_PROJECT=$(grep "Batch Project:" lab-session-info.txt | cut -d' ' -f3)
   
   # Start a batch build that runs multiple configurations
   aws codebuild start-build-batch \
     --project-name "$BATCH_PROJECT" \
     --source-location "s3://$ARTIFACT_BUCKET/nodejs-app-source.zip"
   ```

2. **Monitor batch execution:**
   - Go to AWS Console → CodeBuild → Batch builds
   - Observe multiple builds running in parallel
   - Note how different build configurations are tested

3. **Explore build reports:**
   - Go to AWS Console → CodeBuild → Reports
   - Examine test results and code coverage reports
   - Note how different report formats are handled

### Step 6: Custom Build Images (Advanced)

1. **Create a custom build image:**
   ```bash
   # Create a Dockerfile for a custom build environment
   cat > Dockerfile << 'EOF'
   FROM amazonlinux:2
   
   # Install development tools
   RUN yum update -y && \
       yum install -y git wget curl unzip && \
       yum groupinstall -y "Development Tools"
   
   # Install Node.js
   RUN curl -sL https://rpm.nodesource.com/setup_18.x | bash - && \
       yum install -y nodejs
   
   # Install Python
   RUN yum install -y python3 python3-pip
   
   # Install Java
   RUN yum install -y java-11-openjdk-devel
   
   # Install custom tools
   RUN npm install -g typescript eslint && \
       pip3 install flake8 pytest
   
   # Set environment variables
   ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk
   ENV PATH=$PATH:$JAVA_HOME/bin
   
   WORKDIR /codebuild
   EOF
   ```

2. **Build and push the custom image:**
   ```bash
   # Get ECR repository URI
   ECR_REPO=$(grep "ECR Repository:" lab-session-info.txt | cut -d' ' -f3)
   
   # Login to ECR
   aws ecr get-login-password --region $AWS_DEFAULT_REGION | \
     docker login --username AWS --password-stdin $ECR_REPO
   
   # Build and push
   docker build -t custom-build-env .
   docker tag custom-build-env:latest $ECR_REPO:latest
   docker push $ECR_REPO:latest
   ```

3. **Test the custom image build:**
   ```bash
   CUSTOM_PROJECT=$(grep "Custom Image Project:" lab-session-info.txt | cut -d' ' -f3)
   
   aws codebuild start-build \
     --project-name "$CUSTOM_PROJECT" \
     --source-location "s3://$ARTIFACT_BUCKET/nodejs-app-source.zip"
   ```

### Step 7: Build Optimization and Monitoring

1. **Analyze build performance:**
   ```bash
   # Get build metrics
   aws codebuild list-builds-for-project \
     --project-name "$PROJECT_NAME" \
     --sort-order DESCENDING
   
   # Get detailed build information
   BUILD_ID=$(aws codebuild list-builds-for-project \
     --project-name "$PROJECT_NAME" \
     --query 'ids[0]' --output text)
   
   aws codebuild batch-get-builds --ids "$BUILD_ID"
   ```

2. **Monitor cache effectiveness:**
   - Go to AWS Console → S3
   - Find your cache bucket
   - Examine cached artifacts and their sizes
   - Note cache hit/miss patterns in build logs

3. **Set up CloudWatch alarms:**
   ```bash
   # Create alarm for build failures
   aws cloudwatch put-metric-alarm \
     --alarm-name "CodeBuild-Failures" \
     --alarm-description "Alert on CodeBuild failures" \
     --metric-name "FailedBuilds" \
     --namespace "AWS/CodeBuild" \
     --statistic "Sum" \
     --period 300 \
     --threshold 1 \
     --comparison-operator "GreaterThanOrEqualToThreshold" \
     --evaluation-periods 1
   ```

### Step 8: Security and Compliance Integration

1. **Review security scan results:**
   - Examine Trivy security scan reports from Docker builds
   - Review Bandit security analysis from Python builds
   - Check dependency vulnerability scans

2. **Implement compliance checks:**
   ```bash
   # Add compliance buildspec
   cat > buildspecs/buildspec-compliance.yml << 'EOF'
   version: 0.2
   phases:
     install:
       runtime-versions:
         python: 3.9
       commands:
         - pip install checkov
     build:
       commands:
         - echo "Running compliance checks..."
         - checkov -f . --framework cloudformation || true
         - echo "Compliance scan completed"
   artifacts:
     files:
       - '**/*'
   EOF
   ```

## Troubleshooting Guide

### Common Issues and Solutions

1. **Build timeouts:**
   - Increase timeout values in CloudFormation template
   - Optimize build scripts to reduce execution time
   - Use larger compute instances for resource-intensive builds

2. **Cache not working:**
   - Verify S3 bucket permissions
   - Check cache path configurations in buildspec
   - Ensure cache keys are consistent between builds

3. **Custom image failures:**
   - Verify ECR repository permissions
   - Check image exists and is accessible
   - Ensure proper authentication to ECR

4. **Parallel build issues:**
   - Check available CPU cores and memory
   - Adjust PARALLEL_JOBS environment variable
   - Monitor resource utilization during builds

### Debugging Commands

```bash
# View build logs
aws logs get-log-events \
  --log-group-name "/aws/codebuild/$PROJECT_NAME" \
  --log-stream-name "$BUILD_ID"

# Check build project configuration
aws codebuild batch-get-projects --names "$PROJECT_NAME"

# List all builds for a project
aws codebuild list-builds-for-project --project-name "$PROJECT_NAME"

# Get build artifacts
aws s3 ls "s3://$ARTIFACT_BUCKET/" --recursive
```

## Resources Created

This lab creates the following AWS resources:

### Build Projects
- **Node.js Build Project**: npm/yarn with caching and testing
- **Python Build Project**: pip/poetry with security scanning
- **Java Build Project**: Maven/Gradle with quality analysis
- **Docker Build Project**: Container builds with layer caching
- **Parallel Build Project**: Multi-component parallel execution
- **Batch Build Project**: Multiple build configurations
- **Custom Image Build Project**: Using custom Docker images

### Supporting Resources
- **S3 Artifact Bucket**: Storage for build artifacts
- **S3 Cache Bucket**: Storage for build caching with lifecycle policies
- **ECR Repository**: Custom build images with scanning enabled
- **IAM Service Role**: Permissions for CodeBuild operations
- **CloudWatch Log Groups**: Build execution logs with retention policies

### Estimated Costs
- CodeBuild: $0.005/minute for build time
- S3 Storage: $0.023/GB/month for artifacts and cache
- ECR Storage: $0.10/GB/month for custom images
- CloudWatch Logs: $0.50/GB ingested
- **Total estimated cost**: $5-15/month for regular use

## Cleanup

When you're finished with the lab:

1. **Run the cleanup script:**
   ```bash
   # On Linux/Mac:
   ./scripts/cleanup-codebuild.sh
   
   # On Windows:
   bash scripts/cleanup-codebuild.sh
   ```

2. **Verify cleanup:**
   - Check AWS Console to ensure all resources are removed
   - Confirm S3 buckets are deleted
   - Verify ECR repository is cleaned up
   - Check CloudFormation stack is deleted

3. **Clean up local files:**
   ```bash
   rm -f Dockerfile multi-app-source.zip
   rm -rf multi-app
   ```

## Next Steps

After completing this lab, consider:

1. **Integrate with CodePipeline** for end-to-end CI/CD workflows
2. **Implement advanced security scanning** with additional tools
3. **Create custom build environments** for specific technology stacks
4. **Explore CodeBuild webhooks** for GitHub/Bitbucket integration
5. **Implement build notifications** with SNS and Lambda

## Certification Exam Tips

This lab covers several key areas for the AWS DevOps Professional exam:

- **Domain 1**: SDLC Automation (Build automation and optimization)
- **Domain 2**: Configuration Management (Build environment configuration)
- **Domain 3**: Monitoring and Logging (Build monitoring and reporting)
- **Domain 4**: Policies and Standards (Security scanning and compliance)

Key concepts to remember:
- Build caching significantly improves performance
- Different compute types for different workload requirements
- Security scanning should be integrated into build processes
- Parallel execution reduces overall build time
- Custom images provide consistent build environments
- Batch builds enable testing multiple configurations