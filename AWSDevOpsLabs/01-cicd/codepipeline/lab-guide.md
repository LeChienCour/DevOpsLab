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

4. **Monitor the deployment:**
   - The script will display progress information
   - CloudFormation stack creation takes 3-5 minutes
   - Upon completion, you'll see session information with URLs and resource names

5. **Verify the deployment:**
   - Check the AWS Console for created resources
   - Note the repository clone URL and deployment URL from the output

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
         - echo Build started on `date`
         - echo Environment: $APP_ENV
         - echo Version: $BUILD_VERSION
     build:
       commands:
         - echo Build phase started on `date`
         - mkdir -p dist
         - echo '<html><body><h1>DevOps Pipeline Lab - $APP_ENV</h1><p>Version: $BUILD_VERSION</p><p>Build completed on $(date)</p><p>Build ID: $CODEBUILD_BUILD_ID</p></body></html>' > dist/index.html
         - echo '<html><body><h1>Error Page</h1><p>Something went wrong in $APP_ENV!</p></body></html>' > dist/error.html
     post_build:
       commands:
         - echo Build completed on `date`
   artifacts:
     files:
       - '**/*'
     base-directory: dist
   EOF

   # Create a separate buildspec for the test stage
   cat > updated-source/buildspec-test.yml << 'EOF'
   version: 0.2
   phases:
   pre_build:
      commands:
         - echo Test phase started on `date`
   build:
      commands:
         - echo Running tests...
         - ls -la
         - test -f index.html && echo 'index.html found' || (echo 'index.html not found' && exit 1)
         - test -f error.html && echo 'error.html found' || (echo 'error.html not found' && exit 1)
         - echo 'Basic file validation passed'
   post_build:
      commands:
         - echo Test phase completed on `date`
   artifacts:
   files:
      - '**/*'
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
   # Get the source bucket name from the CloudFormation stack outputs
   SOURCE_BUCKET=$(aws cloudformation describe-stacks \
     --stack-name devops-pipeline-lab-stack \
     --query 'Stacks[0].Outputs[?OutputKey==`SourceBucket`].OutputValue' \
     --output text)
   
   echo "Source bucket: $SOURCE_BUCKET"
   
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

   # Create a separate buildspec for the test stage
   cat > updated-source/buildspec-test.yml << 'EOF'
   version: 0.2
   phases:
   pre_build:
      commands:
         - echo Test phase started on `date`
   build:
      commands:
         - echo Running tests...
         - ls -la
         - test -f index.html && echo 'index.html found' || (echo 'index.html not found' && exit 1)
         - test -f error.html && echo 'error.html found' || (echo 'error.html not found' && exit 1)
         - echo 'Basic file validation passed'
   post_build:
      commands:
         - echo Test phase completed on `date`
   artifacts:
   files:
      - '**/*'
   EOF

   # Create simple README
   echo '# Broken Version - This will fail' > broken-source/README.md
   ```

2. **Upload the broken source code:**
   ```bash
   # Get the source bucket name (if not already set from Step 5)
   if [ -z "$SOURCE_BUCKET" ]; then
     SOURCE_BUCKET=$(aws cloudformation describe-stacks \
       --stack-name devops-pipeline-lab-stack \
       --query 'Stacks[0].Outputs[?OutputKey==`SourceBucket`].OutputValue' \
       --output text)
   fi
   
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
   - Pipeline execution duration
   - Success/failure rates
   - Stage-specific metrics

3. **Review CloudWatch Events:**
   - Examine the event rule that triggers the pipeline
   - Understand how repository changes trigger executions

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
   - Verify CloudWatch Events rule is enabled
   - Check IAM permissions for the event role
   - Ensure you're pushing to the 'main' branch

2. **Build failures:**
   - Check CodeBuild logs in CloudWatch
   - Verify buildspec.yml syntax
   - Ensure all required files are committed

3. **Deployment issues:**
   - Verify S3 bucket permissions
   - Check if bucket policy allows public read access
   - Ensure artifacts are properly generated

4. **Permission errors:**
   - Review IAM roles and policies
   - Check CloudFormation stack events for permission issues
   - Verify your AWS CLI credentials have sufficient permissions

### Debugging Commands

```bash
# Check pipeline status
aws codepipeline get-pipeline-state --name devops-pipeline-lab-pipeline

# View recent executions
aws codepipeline list-pipeline-executions --pipeline-name devops-pipeline-lab-pipeline

# Get build details
aws codebuild batch-get-builds --ids <build-id>

# Check CloudFormation stack status
aws cloudformation describe-stacks --stack-name devops-pipeline-lab-stack
```

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

When you're finished with the lab:

1. **Run the cleanup script:**
   ```bash
   # On Linux/Mac:
   ./scripts/cleanup-pipeline.sh
   
   # On Windows:
   bash scripts/cleanup-pipeline.sh
   ```

2. **Verify cleanup:**
   - Check AWS Console to ensure all resources are removed
   - Confirm S3 buckets are deleted
   - Verify CloudFormation stack is deleted

3. **Clean up local files:**
   ```bash
   cd ..
   rm -rf devops-lab-repo
   ```

## Next Steps

After completing this lab, consider:

1. **Explore CodeDeploy integration** for more sophisticated deployment strategies
2. **Add security scanning** with CodeGuru or third-party tools
3. **Implement cross-region deployments** for disaster recovery
4. **Practice with different source providers** (GitHub, Bitbucket)
5. **Add notification integrations** with Slack or email

## Certification Exam Tips

This lab covers several key areas for the AWS DevOps Professional exam:

- **Domain 1**: SDLC Automation (CI/CD pipeline design and implementation)
- **Domain 2**: Configuration Management and IaC (CloudFormation templates)
- **Domain 3**: Monitoring and Logging (CloudWatch integration)
- **Domain 4**: Policies and Standards Automation (IAM best practices)

Key concepts to remember:
- Pipeline stages execute sequentially by default
- Artifacts flow between stages through S3
- CloudWatch Events enable automatic triggering
- IAM roles provide least-privilege access
- Build specifications define the build process