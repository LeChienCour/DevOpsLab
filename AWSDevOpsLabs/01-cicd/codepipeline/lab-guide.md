# CodePipeline Lab Guide

## Objective
Create a comprehensive multi-stage CI/CD pipeline using AWS CodePipeline with source, build, test, and deploy stages. This lab demonstrates automated deployment workflows and pipeline orchestration as required for AWS DevOps Professional certification.

## Learning Outcomes
By completing this lab, you will:
- Understand how to create multi-stage CI/CD pipelines with CodePipeline
- Learn to integrate S3 source, CodeBuild, and S3 deployment
- Practice automated testing and deployment strategies
- Implement pipeline monitoring and troubleshooting
- Master rollback procedures and failure handling

## Prerequisites
- AWS Account with administrative access
- AWS CLI installed and configured with appropriate permissions
- Familiarity with AWS IAM, S3, and CloudFormation
- Text editor for code modifications

### Required AWS Permissions
Your AWS user/role needs the following permissions:
- CloudFormation: Full access for stack management
- CodePipeline: Full access for pipeline creation
- CodeBuild: Full access for build projects
- S3: Full access for source, artifact and deployment buckets
- IAM: Permission to create roles and policies

### Time to Complete
Approximately 60 minutes

## Architecture Overview

This lab creates the following architecture:

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐    ┌──────────────────┐
│   S3 Source     │───▶│   CodePipeline   │───▶│   CodeBuild     │───▶│   S3 Website     │
│   Bucket        │    │   (Orchestrator) │    │   (Build/Test)  │    │   (Deployment)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘    └──────────────────┘
         │                        │                        │                        │
         │                        ▼                        ▼                        ▼
         │              ┌──────────────────┐    ┌─────────────────┐    ┌──────────────────┐
         │              │  S3 Polling      │    │  CloudWatch     │    │  CloudWatch      │
         └─────────────▶│  (Auto-trigger)  │    │  Logs           │    │  Monitoring      │
                        │                  │    │  (Build Logs)   │    │  (Metrics)       │
                        └──────────────────┘    └─────────────────┘    └──────────────────┘
```

## Lab Steps

### Step 1: Provision the Pipeline Infrastructure

1. **Navigate to the CodePipeline lab directory:**
   ```bash
   cd AWSDevOpsLabs/01-cicd/codepipeline
   ```

2. **Review the CloudFormation template:**
   - Open `templates/pipeline-infrastructure.yaml`
   - Examine the resources that will be created:
     - S3 source bucket for source code
     - CodePipeline with 4 stages (Source, Build, Test, Deploy)
     - CodeBuild projects for build and test phases
     - S3 buckets for artifacts and static website hosting
     - IAM roles with least-privilege permissions

3. **Run the provisioning script:**
   ```bash
   # On Linux/Mac:
   ./scripts/provision-pipeline.sh
   
   # On Windows:
   bash scripts/provision-pipeline.sh
   ```
   
   > **Note**: This script will create AWS resources in your account. Make sure you have the necessary permissions.

4. **Monitor the deployment:**
   - The script will display progress information
   - CloudFormation stack creation takes 3-5 minutes
   - Upon completion, you'll see session information with URLs and resource names

5. **Verify the deployment:**
   - Check the AWS Console for created resources
   - Note the repository clone URL and deployment URL from the output
   
   ```bash
   # Verify the CloudFormation stack was created successfully
   aws cloudformation describe-stacks --stack-name devops-pipeline-lab-stack --query 'Stacks[0].StackStatus'
   ```
   
   Expected output:
   ```
   "CREATE_COMPLETE"
   ```

### Step 2: Understand the Source Code Structure

1. **Review the initial source code:**
   - The provisioning script creates initial source code automatically
   - Source code is uploaded to the S3 source bucket as `source-code.zip`
   - The pipeline will automatically detect and use this source

2. **Understand the build specification:**
   - The `buildspec.yml` defines the build phases
   - Pre-build: Environment preparation
   - Build: Application compilation/packaging
   - Post-build: Cleanup and artifact preparation

3. **Source code components:**
   - `README.md`: Project documentation
   - `buildspec.yml`: CodeBuild build specification
   - Application files for deployment

### Step 3: Trigger Your First Pipeline Execution

1. **The pipeline should automatically start:**
   - The initial source code was uploaded during provisioning
   - The pipeline will automatically detect the source-code.zip file
   - Check AWS Console → CodePipeline to see if it's running

2. **Monitor pipeline execution:**
   - Go to AWS Console → CodePipeline
   - Find your pipeline (devops-pipeline-lab-pipeline)
   - Watch the execution progress through all stages:
     - **Source**: Retrieves code from S3 source bucket
     - **Build**: Compiles application using CodeBuild
     - **Test**: Runs validation tests
     - **Deploy**: Deploys to S3 static website

3. **View build logs:**
   - Click on the Build stage → View details
   - Examine CloudWatch Logs for build output
   - Understand how artifacts flow between stages

### Step 4: Test the Deployed Application

1. **Access the deployed website:**
   - Use the deployment URL from the provisioning output
   - Verify the application loads correctly
   - Note the build timestamp and commit information
   
   ```bash
   # Get the deployment URL from the session info
   DEPLOY_URL=$(grep "Deployment URL:" lab-session-info.txt | cut -d':' -f2- | xargs)
   
   # Open the URL in your browser or use curl to check it
   echo "Deployment URL: $DEPLOY_URL"
   curl -s "$DEPLOY_URL" | grep -o "<h1>.*</h1>"
   ```
   
   Expected output:
   ```
   <h1>DevOps Pipeline Lab</h1>
   ```

2. **Examine the deployment:**
   - Go to AWS Console → S3
   - Find your deployment bucket
   - Explore the deployed files (index.html, error.html)

### Step 5: Implement Advanced Pipeline Features

1. **Create an updated source code package:**
   ```bash
   # Create a new directory for updated source
   mkdir -p updated-source
   
   # Create updated buildspec.yml with environment variables
   cat > updated-source/buildspec.yml << 'EOF'
   version: 0.2
   env:
     variables:
       APP_ENV: production
       BUILD_VERSION: 2.0.0
   phases:
     pre_build:
       commands:
         - echo "Build started on $(date)"
         - echo "Environment - $APP_ENV"
         - echo "Version - $BUILD_VERSION"
     build:
       commands:
         - echo "Build phase started on $(date)"
         - mkdir -p dist
         - echo "<html><body><h1>DevOps Pipeline Lab - $APP_ENV</h1><p>Version - $BUILD_VERSION</p><p>Build completed on $(date)</p><p>Build ID - $CODEBUILD_BUILD_ID</p></body></html>" > dist/index.html
         - echo "<html><body><h1>Error Page</h1><p>Something went wrong in $APP_ENV</p></body></html>" > dist/error.html
     post_build:
       commands:
         - echo "Build completed on $(date)"
   artifacts:
     files:
       - '**/*'
     base-directory: dist
   EOF

   # Create updated README
   cat > updated-source/README.md << 'EOF'
   # DevOps Pipeline Lab - Updated Version
   
   This is an updated version of the pipeline lab application.
   
   ## Changes in v2.0.0
   - Added environment variables
   - Updated build process
   - Enhanced HTML output
   EOF
   ```

2. **Upload the updated source code:**
   ```bash
   # Get the source bucket name from lab-session-info.txt
   SOURCE_BUCKET=$(grep "Source Bucket:" lab-session-info.txt | cut -d':' -f2 | xargs)
   # Create new source package
   cd updated-source && zip -r ../updated-source-code.zip . && cd ..
   
   # Upload to S3 to trigger pipeline
   aws s3 cp updated-source-code.zip "s3://$SOURCE_BUCKET/source-code.zip"
   
   echo "Updated source code uploaded. Check CodePipeline console for automatic execution."
   ```

3. **Monitor the updated pipeline execution:**
   - Watch how the new environment variables are used
   - Verify the updated application deployment
   - Check the new version information in the deployed site
   
   ```bash
   # Check pipeline execution status
   aws codepipeline get-pipeline-state --name devops-pipeline-lab-pipeline --query 'stageStates[*].[stageName,actionStates[0].latestExecution.status]'
   ```
   
   Expected output when complete:
   ```
   [
       [
           "Source",
           "Succeeded"
       ],
       [
           "Build",
           "Succeeded"
       ],
       [
           "Test",
           "Succeeded"
       ],
       [
           "Deploy",
           "Succeeded"
       ]
   ]
   ```

### Step 6: Simulate and Handle Pipeline Failures

1. **Create a deployment that will fail:**
   ```bash
   # Create a broken version
   mkdir -p broken-source
   
   # Create a buildspec that will fail
   cat > broken-source/buildspec.yml << 'EOF'
   version: 0.2
   phases:
     pre_build:
       commands:
         - echo Build started on `date`
     build:
       commands:
         - echo This build will fail
         - command_that_does_not_exist  # Use non-existent command to force failure
         - exit 1  # This line may not execute if the previous command fails
     post_build:
       commands:
         - echo This will not execute
   artifacts:
     files:
       - non_existent_file.html  # Reference a file that doesn't exist
   EOF

   # Create simple README
   echo '# Broken Version - This will fail' > broken-source/README.md
   ```

2. **Upload the broken source code:**
   ```bash
   # Get the source bucket name (if not already set from Step 5)
   SOURCE_BUCKET=$(grep "Source Bucket:" lab-session-info.txt | cut -d':' -f2 | xargs)
   
   echo "Source bucket: $SOURCE_BUCKET"
   
   # Create deployment package
   cd broken-source && zip -r ../broken-source-code.zip . && cd ..
   
   # Upload to S3 to trigger pipeline
   aws s3 cp broken-source-code.zip "s3://$SOURCE_BUCKET/source-code.zip"
   
   echo "Broken source code uploaded. Pipeline should fail at Build stage."
   ```

3. **Analyze the failure:**
   - Watch the pipeline fail at the Build stage
   - Examine the error logs in CloudWatch
   - Note that subsequent stages don't execute
   
   ```bash
   # Check pipeline execution status
   aws codepipeline get-pipeline-state --name devops-pipeline-lab-pipeline --query 'stageStates[*].[stageName,actionStates[0].latestExecution.status]'
   ```
   
   Expected output:
   ```
   [
       [
           "Source",
           "Succeeded"
       ],
       [
           "Build",
           "Failed"
       ],
       [
           "Test",
           null
       ],
       [
           "Deploy",
           null
       ]
   ]
   ```
   
   > **Note**: The "Failed" status indicates the build stage failed, and subsequent stages were not executed.

4. **Fix the build and implement rollback:**
   ```bash
   # Restore the working version by re-uploading the updated source
   aws s3 cp updated-source-code.zip "s3://$SOURCE_BUCKET/source-code.zip"
   
   echo "Working source code restored. Pipeline should execute successfully."
   ```

5. **Monitor the recovery:**
   - Watch the pipeline execute successfully again
   - Verify the application is restored

### Step 7: Advanced Pipeline Monitoring

1. **Set up CloudWatch alarms for pipeline failures:**
   - Go to CloudWatch → Alarms
   - Create alarm for pipeline failure metrics
   - Configure SNS notifications (optional)

2. **Explore pipeline metrics:**
   - Go to CloudWatch → Metrics → CodePipeline
   - View "Pipeline Execution Duration" metrics to track performance
   - Check "SuccessCount" and "FailureCount" metrics for reliability
   - Examine stage-specific metrics like "BuildSuccessCount" and "DeploymentTime"

### Step 8: Pipeline Optimization and Best Practices

1. **Implement build caching (Advanced):**
   - Modify the CodeBuild project to use caching
   - Observe build time improvements

2. **Add manual approval stage (Optional):**
   - Insert a manual approval between Test and Deploy
   - Practice approval workflows

3. **Implement parallel execution:**
   - Add parallel actions in the Test stage
   - Run multiple test suites simultaneously

## Troubleshooting Guide

### Common Issues and Solutions

1. **Pipeline not triggering automatically:**
   - **Issue**: Pipeline doesn't start automatically when source changes are made.
   - **Solutions**:
     - Check IAM permissions for the event role to ensure it has sufficient permissions
     - Verify CloudWatch Events/EventBridge rules are correctly configured
     - For S3 sources, confirm that versioning is enabled on the bucket
     - Check that the source bucket notifications are properly configured
     - Verify the source file key matches exactly what the pipeline is configured to watch
     - For CodeCommit sources, ensure the branch name is correct
     - Check CloudTrail logs for failed event deliveries
     - Try manually releasing a change through the console to verify pipeline functionality

2. **Build failures:**
   - **Issue**: The build stage fails during pipeline execution.
   - **Solutions**:
     - Check CodeBuild logs in CloudWatch for specific error messages
     - Verify buildspec.yml syntax and structure is correct
     - Ensure all required files are included in the source code
     - Check that environment variables are correctly defined
     - Verify the build project has the necessary permissions
     - Test the build project directly outside of the pipeline
     - Check for resource constraints (memory, CPU) during build execution
     - Verify dependencies are available and correctly versioned

3. **Deployment issues:**
   - **Issue**: Deployment stage fails or deploys incorrectly.
   - **Solutions**:
     - Verify S3 bucket permissions allow the pipeline to write objects
     - Check if bucket policy allows public read access for static website hosting
     - Ensure artifacts are properly generated and packaged in the build stage
     - Verify the deployment configuration matches the artifact structure
     - Check for file path issues in the deployment configuration
     - For CloudFormation deployments, validate templates before deployment
     - For CodeDeploy, check instance health and agent status
     - Verify that the deployment target exists and is accessible

4. **Permission errors:**
   - **Issue**: Pipeline fails due to insufficient permissions.
   - **Solutions**:
     - Review IAM roles and policies for the pipeline and each action
     - Check CloudFormation stack events for specific permission errors
     - Verify your AWS CLI credentials have sufficient permissions
     - Use IAM Access Analyzer to identify missing permissions
     - Check for resource-based policies that might be denying access
     - Ensure cross-account roles are properly configured if applicable
     - Verify service roles have necessary permissions for each stage

5. **Artifact issues:**
   - **Issue**: Artifacts aren't properly passed between stages.
   - **Solutions**:
     - Check that output artifacts are correctly defined in the source stage
     - Verify input artifacts are correctly referenced in subsequent stages
     - Ensure artifact names match between output and input configurations
     - Check S3 artifact bucket permissions
     - Verify artifact paths and file patterns are correct
     - Check for artifact size limits (especially for large builds)
     - Ensure the artifact format is compatible with the consuming stage

6. **Pipeline stuck in progress:**
   - **Issue**: Pipeline execution gets stuck in an "In Progress" state.
   - **Solutions**:
     - Check for manual approval actions that might be waiting for input
     - Look for timeouts in long-running stages
     - Check if a dependent service (CodeBuild, CodeDeploy) is experiencing issues
     - Verify that all required resources exist and are accessible
     - Try stopping and restarting the pipeline execution
     - Check service quotas to ensure you haven't hit any limits
     - Look for stuck executions in third-party actions

7. **Stage transition issues:**
   - **Issue**: Pipeline fails to transition between stages.
   - **Solutions**:
     - Check that artifact outputs from previous stages are correctly configured
     - Verify stage dependencies are properly set up
     - Check for disabled stage transitions in the pipeline configuration
     - Ensure all required parameters are provided for each stage
     - Check CloudWatch Events for transition failures
     - Verify service roles have permissions across all required services

8. **Rollback failures:**
   - **Issue**: Pipeline fails to roll back after a failed deployment.
   - **Solutions**:
     - Check that rollback configurations are properly set up
     - Verify previous successful deployments exist to roll back to
     - Check permissions for rollback operations
     - Review CloudWatch logs for specific rollback failure messages
     - Ensure the deployment provider supports automatic rollbacks
     - Check for manual intervention that might be blocking rollback

### Debugging Commands

```bash
# Check pipeline status
aws codepipeline get-pipeline-state --name devops-pipeline-lab-pipeline

# View recent executions
aws codepipeline list-pipeline-executions --pipeline-name devops-pipeline-lab-pipeline

# Get detailed information about a specific execution
aws codepipeline get-pipeline-execution --pipeline-name devops-pipeline-lab-pipeline --pipeline-execution-id <execution-id>

# Get build details
aws codebuild batch-get-builds --ids <build-id>

# Check CloudFormation stack status
aws cloudformation describe-stacks --stack-name devops-pipeline-lab-stack

# View pipeline structure
aws codepipeline get-pipeline --name devops-pipeline-lab-pipeline

# Check action execution details
aws codepipeline list-action-executions --pipeline-name devops-pipeline-lab-pipeline --filter pipelineExecutionId=<execution-id>

# Check CloudWatch Events rules for the pipeline
aws events list-rules --name-prefix codepipeline

# Check S3 artifact bucket contents
aws s3 ls s3://<artifact-bucket-name>/ --recursive

# View pipeline execution history with status
aws codepipeline list-pipeline-executions --pipeline-name devops-pipeline-lab-pipeline --query 'pipelineExecutionSummaries[*].[pipelineExecutionId,status,startTime]'
```

### Log Analysis Guide

When troubleshooting CodePipeline issues, analyzing logs and execution history is crucial:

1. **Pipeline Execution History**:
   - Review the overall pipeline execution status in the AWS Console
   - Check the status of each stage and action
   - Note the timestamps to identify when issues occurred
   - Look for patterns in failed executions (same stage always failing)
   - Check for correlation between failures and code changes

2. **Stage Transition Logs**:
   - Examine CloudWatch Events for stage transition events
   - Look for failed transitions and error messages
   - Check for permission issues in transition events
   - Verify artifact handoff between stages

3. **Action Execution Logs**:
   - Review detailed logs for specific actions (build, deploy)
   - For CodeBuild actions, check the associated CloudWatch Logs
   - For CodeDeploy actions, check deployment logs
   - For CloudFormation actions, check stack events
   - Look for consistent failure patterns across executions

4. **CloudTrail Logs**:
   - Check for API calls related to the pipeline execution
   - Look for permission errors or throttling issues
   - Verify service interactions during pipeline execution
   - Identify unauthorized access attempts or configuration changes

5. **Common Error Patterns**:
   - `AccessDenied`: Insufficient IAM permissions
   - `ResourceNotFoundException`: Missing or deleted resources
   - `ValidationException`: Configuration errors in pipeline definition
   - `ThrottlingException`: API rate limiting issues
   - `InvalidArtifactException`: Problems with artifacts between stages

When analyzing pipeline issues, consider:
- The sequence of events across the entire pipeline
- Dependencies between stages and actions
- External factors that might affect pipeline execution
- Recent changes to source code, configuration, or AWS resources
- Service disruptions or quota limits that might impact execution

## Resources Created

This lab creates the following AWS resources:

### Core Pipeline Resources
- **CodePipeline**: Multi-stage pipeline with source, build, test, deploy stages
- **S3 Source Bucket**: Source code storage with versioning
- **CodeBuild Projects**: Separate projects for build and test phases
- **S3 Buckets**: Artifact storage and static website hosting

### Supporting Resources
- **IAM Roles**: Service roles for CodePipeline and CodeBuild
- **S3 Bucket Policies**: Access control for pipeline resources
- **CloudWatch Logs**: Log groups for build and test execution logs

### Estimated Costs
- CodePipeline: $1/month per active pipeline
- CodeBuild: $0.005/minute for build time
- S3 Storage: $0.023/GB/month
- CloudWatch Logs: $0.50/GB ingested
- **Total estimated cost**: $2-5/month for regular use

## Cleanup

When you're finished with the lab, follow these steps to avoid ongoing charges:

1. **Run the cleanup script:**
   ```bash
   # On Linux/Mac:
   ./scripts/cleanup-pipeline.sh
   
   # On Windows:
   bash scripts/cleanup-pipeline.sh
   ```

2. **Verify cleanup:**
   - Check AWS Console to ensure all resources are removed
   - Confirm S3 buckets are deleted (specially the source bucket with versioning enabled)
   - Verify CloudFormation stack is deleted
   
   ```bash
   # Verify the CloudFormation stack was deleted
   aws cloudformation describe-stacks --stack-name devops-pipeline-lab-stack 2>&1 | grep -q "does not exist"
   if [ $? -eq 0 ]; then echo "Stack successfully deleted"; else echo "Stack may still exist"; fi
   ```

3. **Clean up local files:**
   ```bash
   # Remove local files created during the lab
   rm -rf updated-source broken-source
   rm -f *-source-code.zip
   ```

> **Important**: Failure to delete resources may result in unexpected charges to your AWS account.

## Next Steps

After completing this lab, consider:

1. **Explore CodeDeploy integration** for more sophisticated deployment strategies
2. **Add security scanning** with CodeGuru or third-party tools
3. **Implement cross-region deployments** for disaster recovery
4. **Practice with different source providers** (GitHub, Bitbucket)
5. **Add notification integrations** with Slack or email

## Additional Resources

### AWS Official Documentation
- [AWS CodePipeline User Guide](https://docs.aws.amazon.com/codepipeline/latest/userguide/welcome.html) - Complete guide to CodePipeline features and pipeline orchestration
- [Pipeline Structure Reference](https://docs.aws.amazon.com/codepipeline/latest/userguide/reference-pipeline-structure.html) - Detailed pipeline configuration and action types
- [Getting Started with CodePipeline](https://docs.aws.amazon.com/codepipeline/latest/userguide/getting-started-codepipeline.html) - Initial setup and configuration guide
- [CodePipeline Feature Reference](https://docs.aws.amazon.com/codepipeline/latest/userguide/feature-reference.html) - Comprehensive feature documentation
- [CodePipeline Troubleshooting](https://docs.aws.amazon.com/codepipeline/latest/userguide/troubleshooting.html) - Common issues and solutions
- [Working with Variables](https://docs.aws.amazon.com/codepipeline/latest/userguide/actions-variables.html) - Pipeline variables and parameter passing

### Action Types and Integrations
- [CodeBuild Action Reference](https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-CodeBuild.html) - Build and test action configuration
- [CodeDeploy Action Reference](https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-CodeDeploy.html) - Deployment action configuration
- [Lambda Function Actions](https://docs.aws.amazon.com/codepipeline/latest/userguide/actions-invoke-lambda-function.html) - Custom Lambda integrations
- [CloudFormation Actions](https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-CloudFormation.html) - Infrastructure deployment actions

### Monitoring and Event Management
- [Monitoring CodePipeline Events](https://docs.aws.amazon.com/codepipeline/latest/userguide/detect-state-changes-cloudwatch-events.html) - CloudWatch Events integration
- [Pipeline Execution Monitoring](https://docs.aws.amazon.com/codepipeline/latest/userguide/monitoring-cloudwatch-events.html) - Performance and failure monitoring

### Security and Access Control
- [IAM Permissions for CodePipeline](https://docs.aws.amazon.com/codepipeline/latest/userguide/security-iam.html) - Service roles and user permissions
- [Approval Permissions](https://docs.aws.amazon.com/codepipeline/latest/userguide/approvals-iam-permissions.html) - Manual approval workflow configuration
- [Troubleshooting IAM Issues](https://docs.aws.amazon.com/codepipeline/latest/userguide/security_iam_troubleshoot.html) - Permission troubleshooting guide

### Best Practices and Implementation Guides
- [CI/CD Best Practices](https://docs.aws.amazon.com/prescriptive-guidance/latest/strategy-cicd-litmus/cicd-best-practices.html) - AWS Prescriptive Guidance for pipeline design
- [Multi-Account DevOps Strategies](https://docs.aws.amazon.com/prescriptive-guidance/latest/choosing-git-branch-approach/introduction.html) - Git branching and multi-account patterns

### Tutorials and Examples
- [CodePipeline Tutorials](https://docs.aws.amazon.com/codepipeline/latest/userguide/tutorials.html) - Step-by-step implementation guides
- [Four-Stage Pipeline Tutorial](https://docs.aws.amazon.com/codepipeline/latest/userguide/tutorials-four-stage-pipeline.html) - Complete CI/CD pipeline example

### Community Resources and Advanced Topics
- [AWS DevOps Blog: CodePipeline](https://aws.amazon.com/blogs/devops/category/developer-tools/aws-codepipeline/) - Latest features and advanced pipeline patterns
- [Video Tutorial: Building CI/CD Pipelines with AWS CodePipeline](https://www.youtube.com/watch?v=MNt2HGxClZ0) - Comprehensive pipeline walkthrough

### Supplementary Learning Resources

#### Blog Posts and Articles
- [AWS DevOps Blog: Multi-Branch Pipeline Strategies](https://aws.amazon.com/blogs/devops/aws-building-a-secure-cross-account-continuous-delivery-pipeline/) - Advanced branching patterns
- [AWS Architecture Blog: Microservices CI/CD](https://aws.amazon.com/blogs/architecture/lets-architect-microservices-architectures/) - Microservices deployment patterns
- [AWS Compute Blog: Serverless CI/CD](https://aws.amazon.com/blogs/compute/building-a-ci-cd-pipeline-for-serverless-applications/) - Lambda deployment pipelines
- [AWS Security Blog: Pipeline Security](https://aws.amazon.com/blogs/security/how-to-secure-your-cicd-pipeline/) - Security best practices for pipelines

#### Video Tutorials and Webinars
- [AWS re:Invent: Advanced Pipeline Patterns](https://www.youtube.com/results?search_query=aws+reinvent+codepipeline) - Latest pipeline innovations
- [AWS Online Tech Talks: CI/CD at Scale](https://www.youtube.com/results?search_query=aws+online+tech+talks+pipeline) - Enterprise pipeline strategies
- [A Cloud Guru: AWS CodePipeline Mastery](https://acloudguru.com/course/aws-codepipeline-deep-dive) - Comprehensive pipeline training
- [Cloud Academy: DevOps on AWS](https://cloudacademy.com/course/devops-on-aws/) - Complete DevOps implementation

#### Whitepapers and Technical Guides
- [AWS Whitepaper: Practicing CI/CD on AWS](https://docs.aws.amazon.com/whitepapers/latest/practicing-continuous-integration-continuous-delivery/welcome.html) - Comprehensive CI/CD guide
- [AWS Whitepaper: DevOps on AWS](https://docs.aws.amazon.com/whitepapers/latest/introduction-devops-aws/introduction-devops-aws.html) - DevOps transformation guide
- [AWS Whitepaper: Multi-Account Strategy](https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/organizing-your-aws-environment.html) - Cross-account pipeline patterns
- [AWS Well-Architected Framework: Operational Excellence](https://docs.aws.amazon.com/wellarchitected/latest/operational-excellence-pillar/welcome.html) - Operational best practices

#### Third-Party Resources
- [GitHub Actions vs CodePipeline](https://github.blog/2019-08-08-github-actions-now-supports-ci-cd/) - CI/CD platform comparison
- [Jenkins vs CodePipeline Migration](https://www.jenkins.io/doc/book/installing/cloud/) - Migration strategies
- [GitLab CI vs CodePipeline](https://docs.gitlab.com/ee/ci/migration/jenkins.html) - Alternative CI/CD platforms
- [CircleCI vs CodePipeline Comparison](https://circleci.com/blog/aws-codepipeline-vs-circleci/) - Platform feature comparison

#### Industry Best Practices
- [Google SRE Book: Release Engineering](https://sre.google/sre-book/release-engineering/) - Release management principles
- [Netflix Tech Blog: Deployment Strategies](https://netflixtechblog.com/deploying-the-netflix-api-79b6176cc3f0) - Large-scale deployment patterns
- [Spotify Engineering: CI/CD at Scale](https://engineering.atspotify.com/2020/01/16/how-we-improved-data-discovery-for-data-scientists-at-spotify/) - Engineering culture and practices
- [Atlassian CI/CD Guide](https://www.atlassian.com/continuous-delivery) - CI/CD implementation strategies

## AWS DevOps Professional Certification Relevance

### Certification Domain Mapping

This lab comprehensively addresses multiple domains of the AWS Certified DevOps Engineer - Professional exam:

#### Domain 1: SDLC Automation (22% of exam)
- **1.1 Apply concepts required to automate a CI/CD pipeline**
  - Multi-stage pipeline orchestration with CodePipeline
  - Source, build, test, and deploy stage configuration
  - Artifact management and stage transitions
- **1.2 Determine source control strategies and workflows**
  - S3-based source control integration
  - Automated triggering on source changes
  - Version control and artifact versioning
- **1.3 Apply concepts required to automate and integrate testing**
  - Automated testing integration in pipeline stages
  - Build validation and quality gates
  - Parallel testing strategies

#### Domain 2: Configuration Management and Infrastructure as Code (19% of exam)
- **2.1 Determine deployment services based on deployment needs**
  - Pipeline orchestration vs individual service usage
  - Service integration patterns (CodeBuild, S3, CloudFormation)
- **2.2 Determine application and infrastructure deployment models**
  - Static website deployment patterns
  - Multi-environment deployment strategies

#### Domain 3: Monitoring and Logging (15% of exam)
- **3.1 Determine how to set up the aggregation, storage, and analysis of logs and metrics**
  - CloudWatch Logs integration for pipeline monitoring
  - Build logs aggregation and analysis
  - Pipeline execution metrics and reporting
- **3.2 Apply concepts required to automate monitoring and event management**
  - Pipeline failure detection and alerting
  - Automated notifications and escalation
  - Performance monitoring and optimization

#### Domain 4: Policies and Standards Automation (10% of exam)
- **4.1 Apply concepts required to enforce standards for logging, metrics, monitoring, testing, and security**
  - IAM service roles with least-privilege access
  - Standardized pipeline templates and configurations
  - Security scanning integration points

#### Domain 6: High Availability, Fault Tolerance, and Disaster Recovery (14% of exam)
- **6.1 Determine appropriate use of multi-AZ versus multi-region architectures**
  - Cross-region pipeline deployment strategies
  - Artifact replication and disaster recovery
- **6.2 Determine how to implement high availability, scalability, and fault tolerance**
  - Pipeline resilience and failure handling
  - Automated rollback and recovery procedures

### Key Exam Concepts Covered

**Pipeline Architecture Patterns:**
- **Sequential Stages**: Default execution model with stage dependencies
- **Parallel Actions**: Multiple actions within a single stage
- **Fan-out/Fan-in**: Complex workflow patterns for advanced scenarios
- **Manual Approvals**: Human intervention points in automated workflows

**Critical Integration Points:**
- Source providers (S3, CodeCommit, GitHub, Bitbucket)
- Build providers (CodeBuild, Jenkins, third-party)
- Deploy providers (S3, CodeDeploy, CloudFormation, ECS)
- Test providers (CodeBuild, third-party testing tools)

**Artifact Management:**
- S3-based artifact storage and encryption
- Artifact versioning and lifecycle management
- Cross-stage artifact dependencies
- Artifact size limitations and optimization

**Troubleshooting Scenarios (High-Frequency Exam Topics):**
- Pipeline not triggering → Check source configuration and IAM permissions
- Build failures → Examine CodeBuild logs and buildspec configuration
- Deployment issues → Verify target configuration and permissions
- Stuck executions → Identify manual approvals or service dependencies

### Exam Tips and Best Practices

**Remember for the Exam:**
1. **Stage Execution**: Stages run sequentially, actions within stages can run in parallel
2. **Artifact Flow**: Artifacts must be explicitly defined as outputs/inputs between stages
3. **IAM Roles**: Each service needs appropriate permissions for its operations
4. **Event-Driven**: CloudWatch Events/EventBridge enable automated triggering
5. **Error Handling**: Failed stages stop pipeline execution by default

**Common Exam Scenarios:**
- Designing multi-environment deployment pipelines
- Implementing approval workflows for production deployments
- Troubleshooting pipeline failures and performance issues
- Integrating third-party tools and custom actions
- Cross-account and cross-region pipeline strategies

**Advanced Topics for Professional Level:**
- Custom actions and Lambda integrations
- Pipeline templates and reusable components
- Advanced artifact management and caching strategies
- Pipeline-as-Code with CloudFormation and CDK
- Cost optimization and resource management
- Security best practices and compliance automation

**Performance Optimization:**
- Parallel execution strategies to reduce pipeline duration
- Build caching and artifact optimization
- Resource sizing and compute optimization
- Pipeline monitoring and performance analysis