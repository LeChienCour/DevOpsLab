# CodeBuild Lab Guide

## Objective
Create and configure AWS CodeBuild projects for automated building and testing of applications. This lab demonstrates essential build automation techniques and integration with CI/CD pipelines as required for AWS DevOps Professional certification.

## Learning Outcomes
By completing this lab, you will:
- Understand CodeBuild project configuration and execution
- Master buildspec.yml file structure and commands
- Implement basic build caching for improved performance
- Integrate CodeBuild with S3 for artifact storage
- Monitor build execution and troubleshoot build failures
- Connect CodeBuild with CodePipeline for complete CI/CD workflows

## Prerequisites
- AWS CLI installed and configured with appropriate permissions
- Basic understanding of build systems (npm, pip, Maven, Docker)
- Familiarity with AWS CodeBuild concepts
- Text editor for configuration modifications

### Required AWS Permissions
Your AWS user/role needs the following permissions:
- CloudFormation: Full access for stack management
- CodeBuild: Full access for build project creation
- S3: Full access for artifact storage
- IAM: Permission to create roles and policies
- CloudWatch Logs: Permission to create and manage log groups

## Architecture Overview

This lab creates a simple CodeBuild environment focused on learning fundamentals:

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Source Code   │───▶│   CodeBuild      │───▶│   Build         │
│   (S3 Bucket)   │    │   Project        │    │   Artifacts     │
│                 │    │   (Node.js)      │    │   (S3 Bucket)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │   CloudWatch     │
                       │   Logs           │
                       │   (Build Logs)   │
                       └──────────────────┘
```

### Resources Created:
- **Single CodeBuild Project**: Node.js environment with basic caching
- **S3 Source Bucket**: For uploading source code
- **S3 Artifact Bucket**: For storing build outputs
- **IAM Service Role**: With minimal required permissions
- **CloudWatch Log Group**: For build execution logs

## Lab Steps

### Step 1: Provision the CodeBuild Environment

1. **Navigate to the CodeBuild lab directory:**
   ```bash
   cd AWSDevOpsLabs/01-cicd/codebuild
   ```

2. **Review the CloudFormation template:**
   - Open `templates/codebuild-infrastructure.yaml`
   - Examine the single build project and its configuration
   - Note the basic caching strategy and environment variables

3. **Review the buildspec file:**
   ```bash
   cat buildspecs/buildspec-nodejs.yml
   ```

4. **Run the provisioning script:**
   ```bash
   # On Linux/Mac:
   ./scripts/provision-codebuild.sh
   
   # On Windows:
   bash scripts/provision-codebuild.sh
   ```

5. **Monitor the deployment:**
   - The script creates a single Node.js build project
   - CloudFormation stack creation takes 3-5 minutes
   - Sample source code is uploaded to S3 automatically

### Step 2: Execute Your First Build

1. **Start a Node.js build:**
   ```bash
   # Get the project name from the session info
   PROJECT_NAME=$(grep "Build Project:" lab-session-info.txt | cut -d' ' -f3)
   SOURCE_BUCKET=$(grep "Source Bucket:" lab-session-info.txt | cut -d' ' -f3)
   
   # Start the build
   aws codebuild start-build \
     --project-name "$PROJECT_NAME" \
     --source-location "s3://$SOURCE_BUCKET/nodejs-app-source.zip"
   ```

2. **Monitor the build progress:**
   - Go to AWS Console → CodeBuild
   - Find your build project and click on the running build
   - Observe the build phases: SUBMITTED → QUEUED → IN_PROGRESS → SUCCEEDED
   - Examine the build logs to understand each phase

3. **View build artifacts:**
   ```bash
   # Get the artifact bucket name
   ARTIFACT_BUCKET=$(grep "Artifact Bucket:" lab-session-info.txt | cut -d' ' -f3)
   
   # List the build artifacts
   aws s3 ls "s3://$ARTIFACT_BUCKET/" --recursive
   ```

4. **Download and examine artifacts:**
   ```bash
   # Download the build output
   aws s3 cp "s3://$ARTIFACT_BUCKET/" ./build-artifacts/ --recursive
   
   # Examine the built application
   ls -la build-artifacts/
   ```

### Step 3: Test Build Caching

1. **Start a second build to test caching:**
   ```bash
   # Start another build of the same project
   aws codebuild start-build \
     --project-name "$PROJECT_NAME" \
     --source-location "s3://$SOURCE_BUCKET/nodejs-app-source.zip"
   ```

2. **Compare build times:**
   - First build: Dependencies downloaded and cached
   - Second build: Dependencies restored from cache
   - Note the significant time difference in build logs

3. **Examine cache behavior:**
   - Go to AWS Console → S3
   - Find your cache bucket (if configured)
   - Examine cached artifacts and their sizes
   - Note cache hit/miss patterns in build logs

### Step 4: Modify Build Configuration

1. **Create a custom buildspec:**
   ```bash
   # Create a new directory for custom source
   mkdir -p custom-build
   
   # Create a custom buildspec.yml
   cat > custom-build/buildspec.yml << 'EOF'
   version: 0.2
   env:
     variables:
       NODE_ENV: production
       APP_VERSION: 1.2.0
   phases:
     install:
       runtime-versions:
         nodejs: 18
     pre_build:
       commands:
         - echo "Build started on $(date)"
         - echo "Node.js version:"
         - node --version
         - echo "NPM version:"
         - npm --version
     build:
       commands:
         - echo "Build phase started on $(date)"
         - echo "Environment: $NODE_ENV"
         - echo "Version: $APP_VERSION"
         - mkdir -p dist
         - echo '{"name": "codebuild-lab", "version": "'$APP_VERSION'", "environment": "'$NODE_ENV'"}' > dist/app-info.json
         - echo "<html><body><h1>CodeBuild Lab App</h1><p>Version: $APP_VERSION</p><p>Environment: $NODE_ENV</p></body></html>" > dist/index.html
     post_build:
       commands:
         - echo "Build completed on $(date)"
         - ls -la dist/
   artifacts:
     files:
       - '**/*'
     base-directory: dist
   EOF
   
   # Create package.json
   cat > custom-build/package.json << 'EOF'
   {
     "name": "codebuild-lab-app",
     "version": "1.2.0",
     "description": "Simple Node.js app for CodeBuild lab",
     "scripts": {
       "test": "echo 'No tests specified'"
     }
   }
   EOF
   ```

2. **Upload and test custom build:**
   ```bash
   # Create deployment package
   cd custom-build && zip -r ../custom-build-source.zip . && cd ..
   
   # Upload to S3
   aws s3 cp custom-build-source.zip "s3://$SOURCE_BUCKET/"
   
   # Start build with custom source
   aws codebuild start-build \
     --project-name "$PROJECT_NAME" \
     --source-location "s3://$SOURCE_BUCKET/custom-build-source.zip"
   ```

3. **Monitor the custom build:**
   - Watch how environment variables are used
   - Examine the generated artifacts
   - Note the different build phases and their outputs

### Step 5: Integration with CodePipeline

1. **Understand CodeBuild in CI/CD:**
   - Review how CodeBuild fits into a complete CI/CD pipeline
   - Understand artifact flow between pipeline stages
   - Learn about build triggers and automation

2. **Prepare for pipeline integration:**
   ```bash
   # Create a buildspec optimized for pipeline use
   cat > pipeline-buildspec.yml << 'EOF'
   version: 0.2
   phases:
     install:
       runtime-versions:
         nodejs: 18
     pre_build:
       commands:
         - echo "Pipeline build started on $(date)"
         - npm install
     build:
       commands:
         - echo "Running build..."
         - npm run build || echo "No build script defined"
         - echo "Running tests..."
         - npm test
     post_build:
       commands:
         - echo "Build completed on $(date)"
   artifacts:
     files:
       - '**/*'
     name: BuildArtifact
   EOF
   
   echo "Buildspec ready for CodePipeline integration"
   ```

### Step 6: Monitor and Troubleshoot Builds

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

2. **Review build logs:**
   ```bash
   # View build logs
   aws logs get-log-events \
     --log-group-name "/aws/codebuild/$PROJECT_NAME" \
     --log-stream-name "$BUILD_ID" \
     --query 'events[*].message' \
     --output text
   ```

3. **Set up basic monitoring:**
   ```bash
   # Create alarm for build failures
   aws cloudwatch put-metric-alarm \
     --alarm-name "CodeBuild-Lab-Failures" \
     --alarm-description "Alert on CodeBuild failures" \
     --metric-name "FailedBuilds" \
     --namespace "AWS/CodeBuild" \
     --statistic "Sum" \
     --period 300 \
     --threshold 1 \
     --comparison-operator "GreaterThanOrEqualToThreshold" \
     --evaluation-periods 1
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

### Core Build Resources
- **CodeBuild Project**: Single Node.js build project with basic caching
- **S3 Source Bucket**: Source code storage
- **S3 Artifact Bucket**: Build output storage
- **IAM Service Role**: Permissions for CodeBuild operations
- **CloudWatch Log Group**: Build execution logs

### Estimated Costs (Free Tier Eligible)
- CodeBuild: 100 build minutes/month free, then $0.005/minute
- S3 Storage: 5GB free, then $0.023/GB/month
- CloudWatch Logs: 5GB free, then $0.50/GB ingested
- **Total estimated cost**: $0-5/month for regular use (mostly free tier)

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