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
- AWS Account with administrative access
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

### Time to Complete
Approximately 45 minutes

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
   # View the Node.js buildspec file
   cat buildspecs/buildspec-nodejs.yml
   ```

4. **Run the provisioning script:**
   ```bash
   # On Linux/Mac:
   ./scripts/provision-codebuild.sh
   
   # On Windows:
   bash scripts/provision-codebuild.sh
   ```
   
   > **Note**: This script will create AWS resources in your account. Make sure you have the necessary permissions.

5. **Monitor the deployment:**
   - The script creates a single Node.js build project
   - CloudFormation stack creation takes 3-5 minutes
   - Sample source code is uploaded to S3 automatically

### Step 2: Execute Your First Build

1. **Start a Node.js build:**
   ```bash
   # Get the project name from the session info
   PROJECT_NAME=$(grep "Build Project:" lab-session-info.txt | cut -d' ' -f4)
   
   # Start the build
   aws codebuild start-build --project-name "$PROJECT_NAME"
   ```

2. **Monitor the build progress:**
   - Go to AWS Console → CodeBuild
   - Find your build project and click on the running build
   - Observe the build phases: SUBMITTED → QUEUED → IN_PROGRESS → SUCCEEDED
   - Examine the build logs to understand each phase
   
   > **Note**: The build typically takes 2-3 minutes to complete. You can also monitor the build status using the AWS CLI:
   ```bash
   # Get the latest build ID
   BUILD_ID=$(aws codebuild list-builds-for-project --project-name "$PROJECT_NAME" --query 'ids[0]' --output text)
   
   # Check build status
   aws codebuild batch-get-builds --ids "$BUILD_ID" --query 'builds[0].buildStatus'
   ```
   
   Expected output when complete:
   ```
   "SUCCEEDED"
   ```

3. **View build artifacts:**
   ```bash
   # Get the artifact bucket name
   ARTIFACT_BUCKET=$(grep "Artifact Bucket:" lab-session-info.txt | cut -d' ' -f4)
   
   # List the build artifacts
   aws s3 ls "s3://$ARTIFACT_BUCKET/" --recursive
   ```
   
   Expected output:
   ```
   YYYY-MM-DD HH:MM:SS       XXXX codebuild-artifacts/...
   ```

4. **Download and examine artifacts:**
   ```bash
   # Download the build output
   aws s3 cp "s3://$ARTIFACT_BUCKET/" ./build-artifacts/ --recursive
   
   # Examine the built application
   ls -la build-artifacts/
   ```
   
   Expected output:
   ```
   total XX
   drwxr-xr-x X user group YYYY-MM-DD HH:MM .
   drwxr-xr-x X user group YYYY-MM-DD HH:MM ..
   -rw-r--r-- X user group YYYY-MM-DD HH:MM index.html
   -rw-r--r-- X user group YYYY-MM-DD HH:MM package.json
   ...
   ```

### Step 3: Test Build Caching

1. **Start a second build to test caching:**
   ```bash
   # Get the project name from the session info
   PROJECT_NAME=$(grep "Build Project:" lab-session-info.txt | cut -d' ' -f4)

   # Start another build of the same project
   aws codebuild start-build --project-name "$PROJECT_NAME"
   ```

2. **Compare build times:**
   - First build: Dependencies downloaded and cached
   - Second build: Dependencies restored from cache
   - Note the significant time difference in build logs

3. **Examine cache behavior:**
   ```bash
   # Check the artifact bucket for cache files after the second build
   ARTIFACT_BUCKET=$(grep "Artifact Bucket:" lab-session-info.txt | cut -d' ' -f4)
   
   # List cache contents
   aws s3 ls "s3://$ARTIFACT_BUCKET/build-cache/" --recursive
   ```
   
   Expected output:
   ```
   YYYY-MM-DD HH:MM:SS       XXXX build-cache/...
   ```
   
   - Compare the build logs between first and second builds
   - Look for cache-related messages in the build logs (e.g., "Cache hit" or "Extracting cache")
   - Note the difference in dependency installation time (second build should be faster)

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
   # Create deployment package (replace the existing source)
   cd custom-build && zip -r ../nodejs-app-source.zip . && cd ..
   
   # Upload to S3 (replacing the existing file)
   aws s3 cp nodejs-app-source.zip "s3://$SOURCE_BUCKET/"
   
   # Start build (uses the updated source automatically)
   aws codebuild start-build --project-name "$PROJECT_NAME"
   ```

3. **Monitor the custom build:**
   - Watch how environment variables are used
   - Examine the generated artifacts
   - Note the different build phases and their outputs
   
   ```bash
   # Get the latest build ID
   BUILD_ID=$(aws codebuild list-builds-for-project --project-name "$PROJECT_NAME" --query 'ids[0]' --output text)
   
   # Check build logs
   PROJECT_FROM_BUILD=$(echo "$BUILD_ID" | cut -d':' -f1)
   LOG_STREAM=$(echo "$BUILD_ID" | cut -d':' -f2)
   aws logs get-log-events --log-group-name "/aws/codebuild/$PROJECT_FROM_BUILD" --log-stream-name "$LOG_STREAM" --query 'events[*].message' --output text | grep -E "Environment:|Version:|Build phase"
   ```
   
   Expected output:
   ```
   Environment: production
   Version: 1.2.0
   Build phase started on...
   ```

### Step 5: Monitor and Troubleshoot Builds

1. **Analyze build performance:**
   ```bash
   # Get the project name from the session info
   PROJECT_NAME=$(grep "Build Project:" lab-session-info.txt | cut -d' ' -f4)

   # Get build metrics
   aws codebuild list-builds-for-project \
     --project-name "$PROJECT_NAME" \
     --sort-order DESCENDING
   
   # Get the most recent build ID
   BUILD_ID=$(aws codebuild list-builds-for-project \
     --project-name "$PROJECT_NAME" \
     --query 'ids[0]' \
     --output text)
   
   # Get detailed build information
   aws codebuild batch-get-builds --ids "$BUILD_ID"
   ```

2. **Review build logs:**
   ```bash
   # Extract project name and log stream from build ID to avoid Git Bash path issues
   PROJECT_FROM_BUILD=$(echo "$BUILD_ID" | cut -d':' -f1)
   LOG_STREAM=$(echo "$BUILD_ID" | cut -d':' -f2)
   
   # For Windows use MSYS_NO_PATHCONV=1 before the command
   # View build logs
   aws logs get-log-events --log-group-name "/aws/codebuild/$PROJECT_FROM_BUILD" --log-stream-name "$LOG_STREAM" --query 'events[*].message' --output text
   ```

3. **Set up basic monitoring:**
   ```bash
   # Create alarm for build failures
   aws cloudwatch put-metric-alarm --alarm-name "CodeBuild-Lab-Failures" --alarm-description "Alert on CodeBuild failures" --metric-name "FailedBuilds" --namespace "AWS/CodeBuild" --statistic "Sum" --period 300 --threshold 1 --comparison-operator "GreaterThanOrEqualToThreshold" --evaluation-periods 1
   ```

## Troubleshooting Guide

### Common Issues and Solutions

1. **Build timeouts:**
   - **Issue**: Builds are taking longer than the configured timeout period.
   - **Solutions**:
     - Increase timeout values in the CloudFormation template or project settings (up to 8 hours maximum)
     - Optimize build scripts to reduce execution time by removing unnecessary steps
     - Use larger compute instances for resource-intensive builds (e.g., upgrade from BUILD_GENERAL1_SMALL to BUILD_GENERAL1_MEDIUM)
     - Implement caching for dependencies to speed up subsequent builds
     - Split large builds into multiple smaller, parallel build projects
     - Check for network-related delays when downloading dependencies

2. **Cache not working:**
   - **Issue**: Build cache isn't being used or isn't improving build times.
   - **Solutions**:
     - Verify S3 bucket permissions allow CodeBuild to read/write cache files
     - Check cache path configurations in buildspec.yml match your project structure
     - Ensure cache keys are consistent between builds for the same branch/project
     - Verify the cache is being populated by examining S3 bucket contents
     - Check build logs for cache-related messages (hit, miss, population)
     - Try different cache modes (LOCAL, S3) to see which works better for your project
     - Ensure you're caching the right directories (e.g., node_modules, .m2)

3. **Custom image failures:**
   - **Issue**: Builds using custom Docker images are failing.
   - **Solutions**:
     - Verify ECR repository permissions allow CodeBuild to pull the image
     - Check that the image exists and is tagged correctly in the repository
     - Ensure proper authentication to ECR is configured in the build project
     - Verify the image is compatible with CodeBuild (e.g., has required tools)
     - Check if the image is in the same region as the build project
     - Try pulling the image manually to verify it works
     - Check for image size issues (very large images may time out during pull)

4. **Parallel build issues:**
   - **Issue**: Parallel build steps are causing resource contention or failures.
   - **Solutions**:
     - Check available CPU cores and memory in the selected compute type
     - Adjust PARALLEL_JOBS environment variable to match available resources
     - Monitor resource utilization during builds using CloudWatch metrics
     - Consider using a larger compute type for parallel builds
     - Split highly parallel workloads across multiple build projects
     - Ensure parallel processes don't conflict (e.g., writing to the same files)

5. **Environment variable issues:**
   - **Issue**: Environment variables aren't available or have unexpected values.
   - **Solutions**:
     - Check that variables are correctly defined in the project configuration
     - Verify variable names and values in the buildspec.yml file
     - Use the `printenv` command in build phases to debug variable values
     - Check for variable name conflicts between different sources
     - For sensitive values, ensure they're stored in Parameter Store or Secrets Manager
     - Verify that environment variables are being exported correctly between phases

6. **Dependency download failures:**
   - **Issue**: Builds fail when downloading dependencies from external sources.
   - **Solutions**:
     - Check network connectivity to external repositories
     - Verify VPC configuration if using a VPC-connected build
     - Configure a NAT gateway if using private subnets
     - Check if external repositories are rate-limiting requests
     - Consider using a dependency proxy or mirror
     - Implement retry logic for dependency downloads
     - Use a VPC endpoint for AWS services to improve reliability

7. **Permission issues:**
   - **Issue**: Build fails due to insufficient permissions.
   - **Solutions**:
     - Check the service role attached to the CodeBuild project
     - Verify the role has necessary permissions for all AWS services used
     - Check for resource-based policies that might be denying access
     - Use the AWS Policy Simulator to test permissions
     - Add specific permissions needed for your build process
     - Check for permission issues in the build logs (Access Denied errors)

8. **Build artifact issues:**
   - **Issue**: Artifacts aren't being created or uploaded correctly.
   - **Solutions**:
     - Verify the artifacts section in buildspec.yml is correctly configured
     - Check that the specified files exist in the build environment
     - Ensure the CodeBuild role has S3 permissions to upload artifacts
     - Verify the artifact bucket exists and is accessible
     - Check for file path issues (absolute vs. relative paths)
     - Ensure the total artifact size doesn't exceed limits

### Debugging Commands

```bash
# View build logs (extract project name and log stream from build ID)
PROJECT_FROM_BUILD=$(echo "$BUILD_ID" | cut -d':' -f1)
LOG_STREAM=$(echo "$BUILD_ID" | cut -d':' -f2)
aws logs get-log-events \
  --log-group-name "/aws/codebuild/$PROJECT_FROM_BUILD" \
  --log-stream-name "$LOG_STREAM"

# Check build project configuration (use project name from build ID)
aws codebuild batch-get-projects --names "$PROJECT_FROM_BUILD"

# List all builds for a project (use project name from build ID)
aws codebuild list-builds-for-project --project-name "$PROJECT_FROM_BUILD"

# Get build artifacts
aws s3 ls "s3://$ARTIFACT_BUCKET/" --recursive

# Get detailed information about a specific build
aws codebuild batch-get-builds --ids "$BUILD_ID"

# List environment variables for a project
aws codebuild batch-get-projects --names "$PROJECT_NAME" --query "projects[0].environment.environmentVariables"

# Check build metrics in CloudWatch
aws cloudwatch get-metric-statistics \
  --namespace AWS/CodeBuild \
  --metric-name BuildDuration \
  --dimensions Name=ProjectName,Value="$PROJECT_NAME" \
  --start-time "$(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%SZ)" \
  --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --period 300 \
  --statistics Average

# Check cache hit/miss metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/CodeBuild \
  --metric-name CacheHit \
  --dimensions Name=ProjectName,Value="$PROJECT_NAME" \
  --start-time "$(date -d '1 day ago' -u +%Y-%m-%dT%H:%M:%SZ)" \
  --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --period 3600 \
  --statistics Sum
```

### Log Analysis Guide

When troubleshooting CodeBuild issues, analyzing logs is essential. Here's how to interpret key logs:

1. **Build Phase Logs**:
   - Look for phase transition messages (`[Container] YYYY/MM/DD HH:MM:SS Phase: DOWNLOAD_SOURCE`)
   - Check for phase status (`[Container] YYYY/MM/DD HH:MM:SS Phase complete: INSTALL Success`)
   - Identify which phase is failing (DOWNLOAD_SOURCE, INSTALL, PRE_BUILD, BUILD, POST_BUILD)
   - Note the duration of each phase to identify performance bottlenecks

2. **Command Output Analysis**:
   - Look for command exit codes (`[Container] YYYY/MM/DD HH:MM:SS Command exited with code 1`)
   - Check for error messages from build tools (npm, pip, maven, etc.)
   - Identify dependency resolution issues
   - Look for compilation or test failures

3. **Cache-Related Messages**:
   - Check for cache download messages (`[Container] YYYY/MM/DD HH:MM:SS Extracting cache...`)
   - Look for cache upload messages (`[Container] YYYY/MM/DD HH:MM:SS Uploading cache...`)
   - Identify cache hit/miss patterns
   - Check for cache-related errors

4. **Resource Utilization**:
   - Monitor memory usage warnings
   - Check for disk space issues (`No space left on device`)
   - Look for CPU throttling messages
   - Identify network-related delays

5. **Common Error Patterns**:
   - `Unable to locate credentials`: IAM permission issues
   - `AccessDenied`: Insufficient permissions for AWS resources
   - `Connection timed out`: Network connectivity problems
   - `No such file or directory`: Path or file not found
   - `ENOSPC`: Disk space issues
   - `OutOfMemoryError`: Insufficient memory allocation

When analyzing build logs, consider:
- The sequence of events leading up to the failure
- Environment-specific issues (different behavior across environments)
- Intermittent failures that might indicate resource contention
- Changes in dependencies or external services that might affect builds

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

When you're finished with the lab, follow these steps to avoid ongoing charges:

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
   - Check CloudFormation stack is deleted
   - Review CloudWatch Alarms

3. **Clean up local files:**
   ```bash
   # Remove any custom build files created during the lab
   rm -rf custom-build
   rm -f nodejs-app-source.zip
   ```

> **Important**: Failure to delete resources may result in unexpected charges to your AWS account.

## Next Steps

After completing this lab, consider:

1. **Integrate with CodePipeline** for end-to-end CI/CD workflows
2. **Implement advanced security scanning** with additional tools
3. **Create custom build environments** for specific technology stacks
4. **Explore CodeBuild webhooks** for GitHub/Bitbucket integration
5. **Implement build notifications** with SNS and Lambda

## Additional Resources

### AWS Official Documentation
- [AWS CodeBuild User Guide](https://docs.aws.amazon.com/codebuild/latest/userguide/welcome.html) - Complete guide to CodeBuild features and capabilities
- [Build Specification Reference](https://docs.aws.amazon.com/codebuild/latest/userguide/build-spec-ref.html) - Detailed buildspec.yml syntax and configuration options
- [Build Environment Reference](https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref.html) - Available build environments and runtime versions
- [Environment Variables Reference](https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-env-vars.html) - Built-in and custom environment variables
- [CodeBuild Troubleshooting Guide](https://docs.aws.amazon.com/codebuild/latest/userguide/troubleshooting.html) - Common issues and solutions
- [CodeBuild Concepts](https://docs.aws.amazon.com/codebuild/latest/userguide/concepts.html) - Core concepts and terminology

### Best Practices and Implementation Guides
- [CI/CD Best Practices](https://docs.aws.amazon.com/prescriptive-guidance/latest/strategy-cicd-litmus/cicd-best-practices.html) - AWS Prescriptive Guidance for CI/CD pipelines
- [CodeBuild with CodePipeline Integration](https://docs.aws.amazon.com/codebuild/latest/userguide/how-to-create-pipeline.html) - Integrating CodeBuild with CI/CD pipelines
- [Serverless Applications with CodeBuild](https://docs.aws.amazon.com/codebuild/latest/userguide/serverless-applications.html) - Building serverless applications

### Sample Implementations and Examples
- [Use Case-Based Samples](https://docs.aws.amazon.com/codebuild/latest/userguide/use-case-based-samples.html) - Real-world CodeBuild implementation examples
- [Docker Samples](https://docs.aws.amazon.com/codebuild/latest/userguide/sample-docker-section.html) - Container-based build examples
- [Cross-Service Samples](https://docs.aws.amazon.com/codebuild/latest/userguide/cross-service-samples.html) - Integration examples with other AWS services
- [Runtime Versions Sample](https://docs.aws.amazon.com/codebuild/latest/userguide/sample-runtime-versions.html) - Examples of specifying runtime versions
- [Batch Build Buildspec Reference](https://docs.aws.amazon.com/codebuild/latest/userguide/batch-build-buildspec.html) - Parallel and batch build configurations

### Advanced Topics and Integrations
- [CodeBuild SDK Examples](https://docs.aws.amazon.com/codebuild/latest/userguide/service_code_examples.html) - Programmatic CodeBuild management
- [CodePipeline CodeBuild Action Reference](https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-CodeBuild.html) - Using CodeBuild in pipelines

### Community Resources and Tutorials
- [AWS DevOps Blog: CodeBuild](https://aws.amazon.com/blogs/devops/category/developer-tools/aws-codebuild/) - Latest CodeBuild features and techniques
- [Video Tutorial: AWS CodeBuild Deep Dive](https://www.youtube.com/watch?v=R0b5xiPXAHo) - Comprehensive CodeBuild walkthrough

### Supplementary Learning Resources

#### Blog Posts and Articles
- [AWS DevOps Blog: Building a CI/CD Pipeline](https://aws.amazon.com/blogs/devops/complete-ci-cd-with-aws-codecommit-aws-codebuild-aws-codedeploy-and-aws-codepipeline/) - End-to-end CI/CD implementation
- [AWS Architecture Blog: Container Build Optimization](https://aws.amazon.com/blogs/architecture/optimizing-your-aws-infrastructure-for-sustainability-part-iii-serverless/) - Sustainable build practices
- [AWS Compute Blog: Multi-Architecture Builds](https://aws.amazon.com/blogs/compute/building-multi-architecture-images-with-aws-codebuild/) - ARM and x86 build strategies
- [AWS Security Blog: Secure CI/CD Pipelines](https://aws.amazon.com/blogs/security/how-to-secure-your-cicd-pipeline/) - Security best practices for build systems

#### Video Tutorials and Webinars
- [AWS re:Invent: Advanced CodeBuild Techniques](https://www.youtube.com/results?search_query=aws+reinvent+codebuild) - Latest features and use cases
- [AWS Online Tech Talks: CI/CD Best Practices](https://www.youtube.com/results?search_query=aws+online+tech+talks+cicd) - Expert insights and patterns
- [A Cloud Guru: AWS CodeBuild Course](https://acloudguru.com/course/aws-codebuild-deep-dive) - Comprehensive CodeBuild training
- [Linux Academy: DevOps on AWS](https://linuxacademy.com/course/devops-on-aws/) - Complete DevOps workflow training

#### Whitepapers and Technical Guides
- [AWS Whitepaper: DevOps on AWS](https://docs.aws.amazon.com/whitepapers/latest/introduction-devops-aws/introduction-devops-aws.html) - Comprehensive DevOps guide
- [AWS Whitepaper: Blue/Green Deployments](https://docs.aws.amazon.com/whitepapers/latest/blue-green-deployments/welcome.html) - Deployment strategy patterns
- [AWS Whitepaper: Microservices on AWS](https://docs.aws.amazon.com/whitepapers/latest/microservices-on-aws/introduction.html) - Microservices architecture and CI/CD
- [AWS Well-Architected Framework: Operational Excellence](https://docs.aws.amazon.com/wellarchitected/latest/operational-excellence-pillar/welcome.html) - Operational best practices

#### Third-Party Resources
- [Docker Best Practices for CI/CD](https://docs.docker.com/develop/dev-best-practices/) - Container optimization for builds
- [GitHub Actions vs AWS CodeBuild Comparison](https://github.blog/2019-08-08-github-actions-now-supports-ci-cd/) - CI/CD platform comparison
- [Jenkins vs CodeBuild Migration Guide](https://www.jenkins.io/doc/book/installing/cloud/) - Migration strategies and patterns
- [Terraform with CodeBuild Integration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project) - Infrastructure as Code with CI/CD

## AWS DevOps Professional Certification Relevance

### Certification Domain Mapping

This lab addresses critical domains of the AWS Certified DevOps Engineer - Professional exam:

#### Domain 1: SDLC Automation (22% of exam)
- **1.1 Apply concepts required to automate a CI/CD pipeline**
  - Build automation and integration with CI/CD pipelines
  - Buildspec.yml configuration and build phase management
  - Artifact generation and management for downstream stages
- **1.2 Determine source control strategies and workflows**
  - Source integration patterns (S3, CodeCommit, GitHub)
  - Build triggering mechanisms and webhook configurations
- **1.3 Apply concepts required to automate and integrate testing**
  - Automated testing integration in build processes
  - Test result reporting and quality gates
  - Parallel test execution strategies

#### Domain 2: Configuration Management and Infrastructure as Code (19% of exam)
- **2.1 Determine deployment services based on deployment needs**
  - Build service selection criteria and capabilities
  - Integration with deployment services (CodeDeploy, ECS, Lambda)
- **2.3 Determine how to implement lifecycle hooks on a deployment**
  - Pre-build and post-build hook implementations
  - Custom build phases and lifecycle management

#### Domain 3: Monitoring and Logging (15% of exam)
- **3.1 Determine how to set up the aggregation, storage, and analysis of logs and metrics**
  - CloudWatch Logs integration for build monitoring
  - Build metrics collection and analysis
  - Custom metrics and performance tracking
- **3.2 Apply concepts required to automate monitoring and event management**
  - Build failure detection and alerting
  - Automated notifications and escalation procedures

#### Domain 4: Policies and Standards Automation (10% of exam)
- **4.1 Apply concepts required to enforce standards for logging, metrics, monitoring, testing, and security**
  - Security scanning integration in build processes
  - Compliance checks and policy enforcement
  - Standardized build environments and configurations
- **4.2 Determine how to optimize cost through automation**
  - Build caching strategies for cost and performance optimization
  - Compute type selection and resource optimization

### Key Exam Concepts Covered

**Build Environment Management:**
- **Managed Images**: AWS-provided runtime environments with pre-installed tools
- **Custom Images**: Docker-based environments for specific requirements
- **Compute Types**: Resource allocation based on build requirements
- **Environment Variables**: Configuration management and secret handling

**Build Optimization Strategies:**
- **Caching**: Local and S3-based caching for dependencies and artifacts
- **Parallel Builds**: Concurrent execution for improved performance
- **Batch Builds**: Multiple configurations and environments
- **Resource Sizing**: Appropriate compute type selection

**Integration Patterns:**
- **Pipeline Integration**: Seamless integration with CodePipeline
- **Source Providers**: Multiple source control system support
- **Artifact Management**: Build output handling and distribution
- **Notification Systems**: SNS, CloudWatch Events integration

**Troubleshooting Scenarios (Common Exam Topics):**
- Build timeouts → Resource sizing and optimization strategies
- Cache misses → Cache configuration and key management
- Permission errors → IAM roles and resource access policies
- Environment issues → Runtime version and dependency management

### Exam Tips and Best Practices

**Remember for the Exam:**
1. **Buildspec Structure**: Phases (install, pre_build, build, post_build) and their purposes
2. **Caching Types**: Local (Docker layer, source, custom) vs S3 caching
3. **Compute Types**: BUILD_GENERAL1_SMALL/MEDIUM/LARGE for different workloads
4. **Environment Variables**: Build-time vs runtime variable handling
5. **Artifact Specifications**: File patterns and base directory configuration

**Common Exam Scenarios:**
- Optimizing build performance through caching and parallelization
- Implementing security scanning and compliance checks
- Troubleshooting build failures and environment issues
- Integrating with various source control and deployment systems
- Cost optimization through efficient resource utilization

**Advanced Topics for Professional Level:**
- **Custom Build Environments**: Creating and managing Docker-based build images
- **Cross-Account Builds**: IAM roles and resource sharing strategies
- **VPC Integration**: Private subnet builds and network configuration
- **Secrets Management**: Parameter Store and Secrets Manager integration
- **Multi-Architecture Builds**: ARM and x86 build support
- **Build Fleet Management**: Reserved capacity and fleet optimization

**Performance and Cost Optimization:**
- Cache hit ratio optimization and cache key strategies
- Build parallelization and dependency management
- Resource right-sizing based on build characteristics
- Build time analysis and bottleneck identification
- Artifact size optimization and transfer efficiency

**Security Best Practices:**
- Least-privilege IAM policies for build execution
- Secrets and sensitive data handling in builds
- Image scanning and vulnerability management
- Network isolation and VPC configuration
- Audit logging and compliance monitoring