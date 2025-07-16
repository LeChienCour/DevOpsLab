# CodePipeline Lab Guide

## Objective
Create a comprehensive multi-stage CI/CD pipeline using AWS CodePipeline with source, build, test, and deploy stages. This lab demonstrates automated deployment workflows and pipeline orchestration as required for AWS DevOps Professional certification.

## Learning Outcomes
By completing this lab, you will:
- Understand how to create multi-stage CI/CD pipelines with CodePipeline
- Learn to integrate CodeCommit, CodeBuild, and S3 deployment
- Practice automated testing and deployment strategies
- Implement pipeline monitoring and troubleshooting
- Master rollback procedures and failure handling

## Prerequisites
- AWS CLI installed and configured with appropriate permissions
- Basic understanding of Git version control
- Familiarity with AWS IAM, S3, and CloudFormation
- Text editor for code modifications

### Required AWS Permissions
Your AWS user/role needs the following permissions:
- CloudFormation: Full access for stack management
- CodePipeline: Full access for pipeline creation
- CodeCommit: Full access for repository management
- CodeBuild: Full access for build projects
- S3: Full access for artifact and deployment buckets
- IAM: Permission to create roles and policies
- CloudWatch Events: Permission to create rules

## Architecture Overview

This lab creates the following architecture:

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐    ┌──────────────────┐
│   CodeCommit    │───▶│   CodePipeline   │───▶│   CodeBuild     │───▶│   S3 Website     │
│   Repository    │    │   (Orchestrator) │    │   (Build/Test)  │    │   (Deployment)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘    └──────────────────┘
         │                        │                        │                        │
         │                        ▼                        ▼                        ▼
         │              ┌──────────────────┐    ┌─────────────────┐    ┌──────────────────┐
         │              │  CloudWatch      │    │  CloudWatch     │    │  CloudWatch      │
         └─────────────▶│  Events          │    │  Logs           │    │  Monitoring      │
                        │  (Triggers)      │    │  (Build Logs)   │    │  (Metrics)       │
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
     - CodeCommit repository with initial code
     - CodePipeline with 4 stages (Source, Build, Test, Deploy)
     - CodeBuild projects for build and test phases
     - S3 buckets for artifacts and static website hosting
     - IAM roles with least-privilege permissions
     - CloudWatch Events for automatic pipeline triggering

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

### Step 2: Clone and Explore the Repository

1. **Clone the CodeCommit repository:**
   ```bash
   # Use the clone URL from the provisioning output
   git clone <REPOSITORY_CLONE_URL>
   cd devops-lab-repo
   ```

2. **Explore the initial code structure:**
   ```bash
   ls -la
   cat README.md
   cat buildspec.yml
   ```

3. **Understand the build specification:**
   - The `buildspec.yml` defines the build phases
   - Pre-build: Environment preparation
   - Build: Application compilation/packaging
   - Post-build: Cleanup and artifact preparation

### Step 3: Trigger Your First Pipeline Execution

1. **Make a simple change to trigger the pipeline:**
   ```bash
   echo "Updated on $(date)" >> README.md
   git add README.md
   git commit -m "Trigger initial pipeline execution"
   git push origin main
   ```

2. **Monitor pipeline execution:**
   - Go to AWS Console → CodePipeline
   - Find your pipeline (devops-pipeline-lab-pipeline)
   - Watch the execution progress through all stages:
     - **Source**: Retrieves code from CodeCommit
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

1. **Add a custom build environment variable:**
   ```bash
   # Edit buildspec.yml to include environment info
   cat > buildspec.yml << 'EOF'
   version: 0.2
   env:
     variables:
       APP_ENV: production
       BUILD_VERSION: 1.0.0
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
         - echo "<html><body><h1>DevOps Pipeline Lab - $APP_ENV</h1><p>Version: $BUILD_VERSION</p><p>Build completed on $(date)</p><p>Commit: $CODEBUILD_RESOLVED_SOURCE_VERSION</p></body></html>" > dist/index.html
         - echo "<html><body><h1>Error Page</h1><p>Something went wrong in $APP_ENV!</p></body></html>" > dist/error.html
     post_build:
       commands:
         - echo Build completed on `date`
   artifacts:
     files:
       - '**/*'
     base-directory: dist
   EOF
   ```

2. **Commit and push the changes:**
   ```bash
   git add buildspec.yml
   git commit -m "Add environment variables and version info"
   git push origin main
   ```

3. **Monitor the updated pipeline execution:**
   - Watch how the new environment variables are used
   - Verify the updated application deployment

### Step 6: Simulate and Handle Pipeline Failures

1. **Introduce a build failure:**
   ```bash
   # Create a buildspec that will fail
   cat > buildspec.yml << 'EOF'
   version: 0.2
   phases:
     pre_build:
       commands:
         - echo Build started on `date`
     build:
       commands:
         - echo This build will fail
         - exit 1  # Force failure
     post_build:
       commands:
         - echo This will not execute
   artifacts:
     files:
       - '**/*'
   EOF
   ```

2. **Commit the failing build:**
   ```bash
   git add buildspec.yml
   git commit -m "Introduce build failure for testing"
   git push origin main
   ```

3. **Analyze the failure:**
   - Watch the pipeline fail at the Build stage
   - Examine the error logs in CloudWatch
   - Note that subsequent stages don't execute

4. **Fix the build and implement rollback:**
   ```bash
   # Restore working buildspec
   git revert HEAD
   git push origin main
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
- **CodeCommit Repository**: Git repository with initial application code
- **CodeBuild Projects**: Separate projects for build and test phases
- **S3 Buckets**: Artifact storage and static website hosting

### Supporting Resources
- **IAM Roles**: Service roles for CodePipeline, CodeBuild, and CloudWatch Events
- **CloudWatch Events**: Rule to trigger pipeline on repository changes
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