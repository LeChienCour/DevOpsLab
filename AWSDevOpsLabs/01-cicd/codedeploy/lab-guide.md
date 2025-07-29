# CodeDeploy Lab Guide

## Objective
Implement basic deployment automation using AWS CodeDeploy for EC2 instances with in-place deployment strategies. This lab demonstrates essential deployment automation techniques and integration with CI/CD pipelines as required for AWS DevOps Professional certification.

## Learning Outcomes
By completing this lab, you will:
- Understand CodeDeploy application and deployment group configuration
- Master in-place deployment strategies for EC2 instances
- Learn appspec.yml file structure and deployment hooks
- Implement basic health checks and monitoring
- Practice deployment troubleshooting and rollback procedures
- Connect CodeDeploy with CodePipeline for complete CI/CD workflows

## Prerequisites
- AWS Account with administrative access
- AWS CLI installed and configured with appropriate permissions
- Basic understanding of EC2 instances
- Familiarity with AWS CodeDeploy concepts
- Text editor for configuration modifications

### Required AWS Permissions
Your AWS user/role needs the following permissions:
- CloudFormation: Full access for stack management
- CodeDeploy: Full access for application and deployment management
- EC2: Full access for instances and security groups
- IAM: Permission to create roles and policies
- S3: Full access for artifact storage

### Time to Complete
Approximately 60 minutes

## Architecture Overview

This lab creates a simple deployment environment using free tier resources:

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Application   │───▶│   CodeDeploy     │───▶│   EC2 Instances │
│   Artifacts     │    │   Application    │    │   (2 x t3.micro)│
│   (S3 Bucket)   │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
                       ┌──────────────────┐    ┌─────────────────┐
                       │  Deployment      │    │  CodeDeploy     │
                       │  Group           │    │  Agent          │
                       │                  │    │                 │
                       └──────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
                       ┌──────────────────┐    ┌─────────────────┐
                       │  Health Checks   │    │  CloudWatch     │
                       │  & Monitoring    │    │  Logs           │
                       └──────────────────┘    └─────────────────┘
```

### Resources Created:
- **CodeDeploy Application**: Single EC2 application
- **Deployment Group**: In-place deployment configuration
- **EC2 Instances**: 2 t3.micro instances (free tier eligible)
- **S3 Bucket**: Deployment artifact storage
- **IAM Roles**: Service roles for CodeDeploy and EC2
- **Security Group**: Basic web access configuration

## Lab Steps

### Step 1: Provision the CodeDeploy Environment

1. **Navigate to the CodeDeploy lab directory:**
   ```bash
   # Change to the lab directory
   cd AWSDevOpsLabs/01-cicd/codedeploy
   ```

2. **Review the infrastructure template:**
   - Open `templates/codedeploy-infrastructure.yaml`
   - Examine the EC2 instances and deployment group configuration
   - Note the basic deployment strategy and IAM roles

3. **Review the deployment configurations:**
   ```bash
   # List deployment configuration files
   ls -la deployment-configs/
   
   # View the AppSpec file
   cat deployment-configs/appspec-ec2.yml
   
   # View the installation script
   cat deployment-configs/scripts/install_dependencies.sh
   ```

4. **Run the provisioning script:**
   ```bash
   # On Linux/Mac:
   ./scripts/provision-codedeploy.sh
   
   # On Windows:
   bash scripts/provision-codedeploy.sh
   ```

5. **Monitor the deployment:**
   - The script creates 2 t3.micro EC2 instances (free tier eligible)
   - CloudFormation stack creation takes 5-8 minutes
   - EC2 instances need additional time to initialize and install CodeDeploy agent

6. **Verify the initial setup:**
   - Check the EC2 instances are running in the AWS Console
   - Confirm the CodeDeploy application and deployment group are created
   - Note the instance IPs for testing

### Step 2: Understand the Deployment Environment

1. **Explore the created resources:**
   - Go to AWS Console → EC2 → Instances
   - Find your 2 EC2 instances and check their status
   - Note the instance IDs and public IP addresses

2. **Review CodeDeploy applications:**
   - Go to AWS Console → CodeDeploy → Applications
   - Examine the EC2 application
   - Review the deployment group configuration

3. **Check the sample application:**
   ```bash
   # Get the instance IPs from the session info
   INSTANCE_IP=$(grep "Instance 1:" lab-session-info.txt | cut -d' ' -f4)
   echo "Application URL: $INSTANCE_IP"
   
   # Test the application
   curl -s "$INSTANCE_IP" | grep -o '<title>.*</title>'
   ```
   
   Expected output:
   ```
   <title>CodeDeploy Lab - Initial Version</title>
   ```

### Step 3: Perform Your First Deployment

1. **Create an updated version of the application:**
   ```bash
   # Create an updated version
   mkdir -p updated-app/{scripts,css,js}
   
   # Copy deployment scripts
   cp -r deployment-configs/scripts updated-app/
   cp deployment-configs/appspec-ec2.yml updated-app/appspec.yml
   
   # Create updated HTML
   cat > updated-app/index.html << 'EOF'
   <!DOCTYPE html>
   <html lang="en">
   <head>
       <meta charset="UTF-8">
       <meta name="viewport" content="width=device-width, initial-scale=1.0">
       <title>CodeDeploy Lab - Updated Version</title>
       <style>
           body { 
               font-family: Arial, sans-serif; 
               margin: 40px; 
               background: linear-gradient(135deg, #28a745 0%, #20c997 100%);
               color: white;
           }
           .container { 
               max-width: 800px; 
               margin: 0 auto; 
               background: rgba(255,255,255,0.1);
               padding: 40px;
               border-radius: 15px;
           }
           .status { 
               background: rgba(255,255,255,0.2); 
               padding: 20px; 
               border-radius: 10px; 
               margin: 20px 0; 
           }
           .version { 
               font-size: 2rem; 
               font-weight: bold; 
               color: #ffd700; 
           }
       </style>
   </head>
   <body>
       <div class="container">
           <h1>🚀 CodeDeploy Lab Application</h1>
           <div class="status">
               <h2>✅ Deployment Successful!</h2>
               <p class="version">Version 2.0.0</p>
               <p>This is the updated version deployed via CodeDeploy.</p>
               <p><strong>Deployment Time:</strong> <span id="deploy-time"></span></p>
               <p><strong>Instance ID:</strong> <span id="instance-id"></span></p>
           </div>
       </div>
       <script>
           fetch('http://169.254.169.254/latest/meta-data/instance-id')
               .then(response => response.text())
               .then(data => document.getElementById('instance-id').textContent = data)
               .catch(() => document.getElementById('instance-id').textContent = 'Unknown');
           
           document.getElementById('deploy-time').textContent = new Date().toLocaleString();
       </script>
   </body>
   </html>
   EOF
   
   # Create deployment package
   cd updated-app && zip -r ../updated-app-deployment.zip . && cd ..
   ```

2. **Upload and deploy the updated version:**
   ```bash
   # Get deployment information
   ARTIFACT_BUCKET=$(grep "Artifact Bucket:" lab-session-info.txt | cut -d' ' -f4)
   EC2_APP=$(grep "EC2 Application:" lab-session-info.txt | cut -d' ' -f4)
   DEPLOYMENT_GROUP=$(grep "Deployment Group:" lab-session-info.txt | cut -d' ' -f4)
   echo $ARTIFACT_BUCKET
   echo $EC2_APP
   echo $DEPLOYMENT_GROUP
   
   # Upload to S3
   aws s3 cp updated-app-deployment.zip "s3://$ARTIFACT_BUCKET/"
   
   # Start deployment
   DEPLOYMENT_ID=$(aws deploy create-deployment --application-name "$EC2_APP" --deployment-group-name "$DEPLOYMENT_GROUP" --s3-location bucket="$ARTIFACT_BUCKET",key=updated-app-deployment.zip,bundleType=zip --query 'deploymentId' --output text)
   
   echo "Deployment started: $DEPLOYMENT_ID"
   ```

3. **Monitor the deployment:**
   ```bash
   # Watch deployment progress
   aws deploy get-deployment --deployment-id "$DEPLOYMENT_ID"
   
   # Monitor in AWS Console
   echo "Monitor at: https://console.aws.amazon.com/codesuite/codedeploy/deployments/$DEPLOYMENT_ID"
   ```
   
   > **Note**: The deployment typically takes 3-5 minutes to complete. You can check the status periodically using the command above.

### Step 4: Test Rollback Scenarios

1. **Create a deployment that will fail:**
   ```bash
   # Create a broken version
   mkdir -p broken-app/{scripts,css,js}
   
   # Copy scripts but modify validation to fail
   cp -r deployment-configs/scripts broken-app/
   cp deployment-configs/appspec-ec2.yml broken-app/appspec.yml
   
   # Create a broken validation script
   cat > broken-app/scripts/validate_service.sh << 'EOF'
   #!/bin/bash
   echo "Starting ValidateService hook..."
   echo "This deployment will intentionally fail for rollback testing"
   
   # Simulate validation failure
   sleep 30
   echo "Validation failed - triggering rollback"
   exit 1
   EOF
   
   chmod +x broken-app/scripts/validate_service.sh
   
   # Create simple HTML
   echo "<html><body><h1>Broken Version</h1></body></html>" > broken-app/index.html
   
   # Create deployment package
   cd broken-app && zip -r ../broken-app-deployment.zip . && cd ..
   ```

2. **Deploy the broken version to test rollback:**
   ```bash
   # Upload broken version
   aws s3 cp broken-app-deployment.zip "s3://$ARTIFACT_BUCKET/"
   
   # Deploy with auto-rollback enabled
   BROKEN_DEPLOYMENT_ID=$(aws deploy create-deployment --application-name "$EC2_APP" --deployment-group-name "$DEPLOYMENT_GROUP" --s3-location bucket="$ARTIFACT_BUCKET",key=broken-app-deployment.zip,bundleType=zip --auto-rollback-configuration enabled=true,events=DEPLOYMENT_FAILURE,DEPLOYMENT_STOP_ON_ALARM --query 'deploymentId' --output text)
   
   echo "Broken Deployment (will rollback): $BROKEN_DEPLOYMENT_ID"
   ```

3. **Monitor the rollback:**
   ```bash
   # Watch the deployment fail and rollback
   while true; do
   STATUS=$(aws deploy get-deployment --deployment-id "$BROKEN_DEPLOYMENT_ID" --query 'deploymentInfo.status' --output text)
   echo "$(date): Deployment Status: $STATUS"
   
   if [ "$STATUS" = "Failed" ] || [ "$STATUS" = "Succeeded" ] || [ "$STATUS" = "Stopped" ]; then
      echo "Deployment completed with status: $STATUS"
      aws deploy get-deployment --deployment-id "$BROKEN_DEPLOYMENT_ID" --query 'deploymentInfo.[status,errorInformation.message]' --output table
      break
   fi
   
   sleep 15
   done
   ```
   
   Expected output after failure:
   ```
   --------------------------------------------------------------
   |                      get-deployment                        |
   +----------------------+-------------------------------------+
   |  FAILED              |  The overall deployment failed...   |
   +----------------------+-------------------------------------+
   ```
   
   > **Note**: The deployment will initially show as "IN_PROGRESS", then "FAILED", and finally trigger an automatic rollback.

### Step 5: Monitor and Troubleshoot Deployments

1. **Analyze deployment performance:**
   ```bash
   ARTIFACT_BUCKET=$(grep "Artifact Bucket:" lab-session-info.txt | cut -d' ' -f4)
   EC2_APP=$(grep "EC2 Application:" lab-session-info.txt | cut -d' ' -f4)
   DEPLOYMENT_GROUP=$(grep "Deployment Group:" lab-session-info.txt | cut -d' ' -f4)

   # Get deployment statistics
   aws deploy list-deployments --application-name "$EC2_APP" --deployment-group-name "$DEPLOYMENT_GROUP" --query 'deployments[0:5]' --output table
   
   # Get detailed deployment info
   aws deploy batch-get-deployments --deployment-ids "$DEPLOYMENT_ID" --query 'deploymentsInfo[*].[deploymentId,status,startTime,completeTime]' --output table
   ```

2. **Review deployment logs:**
   ```bash
   # Get deployment events
   aws deploy list-deployment-instances --deployment-id "$DEPLOYMENT_ID"
   
   # Check instance deployment status
   INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Project,Values=codedeploy-lab" --query 'Reservations[0].Instances[0].InstanceId' --output text)
   
   aws deploy get-deployment-instance --deployment-id "$DEPLOYMENT_ID" --instance-id "$INSTANCE_ID"
   ```

3. **Set up basic monitoring:**
   ```bash
   # Create alarm for deployment failures
   aws cloudwatch put-metric-alarm --alarm-name "CodeDeploy-Lab-Failures" --alarm-description "Alert on CodeDeploy failures" --metric-name "FailedDeployments" --namespace "AWS/CodeDeploy" --statistic "Sum" --period 300 --threshold 1 --comparison-operator "GreaterThanOrEqualToThreshold" --evaluation-periods 1
   ```

## Troubleshooting Guide

### Common Issues and Solutions

1. **Deployment stuck in "InProgress":**
   - **Issue**: Deployments can get stuck when the CodeDeploy agent can't complete a lifecycle event.
   - **Solutions**:
     - Check instance health in Auto Scaling Group to ensure instances are running properly
     - Verify CodeDeploy agent is running on instances: `sudo service codedeploy-agent status`
     - Check if the agent is reporting to the service: `sudo service codedeploy-agent status`
     - Examine `/var/log/aws/codedeploy-agent/codedeploy-agent.log` for agent-specific errors
     - Check application logs in CloudWatch for application-specific errors
     - Verify network connectivity between the instance and CodeDeploy service endpoints
     - Check IAM instance profile permissions to ensure the instance can access required services

2. **Validation failures:**
   - **Issue**: Deployment validation scripts are failing, causing the deployment to fail.
   - **Solutions**:
     - Review validation script logs in `/opt/codedeploy-agent/deployment-root/[deployment-group-id]/[deployment-id]/logs/scripts.log`
     - Check application accessibility using `curl` or browser to verify the application is responding
     - Verify health check endpoints are correctly configured and responding
     - Examine application logs for errors that might be causing validation failures
     - Check if the validation script has proper execution permissions (`chmod +x`)
     - Verify environment variables or dependencies required by the validation script

3. **Rollback not triggering:**
   - **Issue**: Automatic rollbacks aren't occurring despite deployment failures.
   - **Solutions**:
     - Ensure auto-rollback is configured in the deployment group settings
     - Check CloudWatch alarms associated with the deployment group
     - Verify rollback conditions are properly set (DEPLOYMENT_FAILURE, DEPLOYMENT_STOP_ON_ALARM)
     - Check if the deployment is failing in a way that triggers the rollback conditions
     - Verify previous successful deployment exists to roll back to
     - Check IAM permissions to ensure CodeDeploy can perform rollback operations

4. **Load balancer health check failures:**
   - **Issue**: Instances are failing load balancer health checks during deployment.
   - **Solutions**:
     - Check security group rules to ensure traffic is allowed on the health check port
     - Verify application is listening on the correct port: `netstat -tulpn | grep <port>`
     - Review target group health check settings (path, port, timeout, interval)
     - Check if health check path exists and returns 200 OK: `curl -v http://localhost:<port>/<path>`
     - Examine application logs for errors during health check requests
     - Verify instance has outbound internet access if needed by the application

5. **Missing or incorrect appspec.yml:**
   - **Issue**: Deployment fails due to missing or incorrectly formatted appspec.yml file.
   - **Solutions**:
     - Verify appspec.yml exists in the root of your application source bundle
     - Check appspec.yml syntax using a YAML validator
     - Ensure the file uses the correct version (currently 0.0)
     - Verify all required sections are present (files, hooks)
     - Check that file paths and hook scripts exist and are correctly referenced
     - Ensure hook scripts have proper execution permissions

6. **Permission issues:**
   - **Issue**: Deployment fails due to permission problems on the instance.
   - **Solutions**:
     - Check that the CodeDeploy agent has permissions to access deployment files
     - Verify that hook scripts have execute permissions (`chmod +x`)
     - Check if the application needs specific file permissions to run correctly
     - Verify the instance profile has necessary permissions for S3, CloudWatch, etc.
     - Check SELinux or AppArmor settings if applicable

7. **S3 bucket access issues:**
   - **Issue**: CodeDeploy can't access deployment artifacts in S3.
   - **Solutions**:
     - Verify the S3 bucket exists and contains the deployment artifacts
     - Check bucket permissions and policies allow access from CodeDeploy
     - Ensure the instance profile has permissions to access the S3 bucket
     - Verify the correct bucket and key are specified in the deployment
     - Check for S3 endpoint connectivity issues from the instance

8. **Timeout issues:**
   - **Issue**: Deployment scripts are taking too long and timing out.
   - **Solutions**:
     - Check the timeout settings for each lifecycle event in appspec.yml
     - Optimize scripts to complete within the timeout period
     - Consider breaking long-running tasks into smaller steps
     - Add logging to scripts to identify slow operations
     - Increase timeout values if necessary (up to the maximum allowed)

### Debugging Commands

```bash
# Check CodeDeploy agent status on instances
aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["sudo service codedeploy-agent status"]' \
  --targets "Key=tag:Project,Values=codedeploy-lab"

# Get deployment events
aws deploy list-deployment-instances \
  --deployment-id "$DEPLOYMENT_ID"

# Check instance deployment status
aws deploy get-deployment-instance \
  --deployment-id "$DEPLOYMENT_ID" \
  --instance-id "i-1234567890abcdef0"

# View deployment logs
aws logs get-log-events \
  --log-group-name "/aws/codedeploy/agent" \
  --log-stream-name "i-1234567890abcdef0"

# Check CodeDeploy agent logs directly on the instance
aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["tail -n 100 /var/log/aws/codedeploy-agent/codedeploy-agent.log"]' \
  --targets "Key=tag:Project,Values=codedeploy-lab"

# Check deployment script logs on the instance
aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["find /opt/codedeploy-agent/deployment-root -name scripts.log | xargs tail -n 50"]' \
  --targets "Key=tag:Project,Values=codedeploy-lab"

# Verify application is running on the correct port
aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["netstat -tulpn | grep 80"]' \
  --targets "Key=tag:Project,Values=codedeploy-lab"

# Test application health check locally on the instance
aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["curl -v http://localhost:80/"]' \
  --targets "Key=tag:Project,Values=codedeploy-lab"
```

### Log Analysis Guide

When troubleshooting CodeDeploy issues, analyzing logs is crucial. Here's how to interpret key logs:

1. **CodeDeploy Agent Logs** (`/var/log/aws/codedeploy-agent/codedeploy-agent.log`):
   - Look for ERROR or WARNING level messages
   - Check for connectivity issues with AWS services
   - Identify agent initialization problems
   - Common patterns:
     - `ERROR -- InstanceAgent::Plugins::CodeDeployPlugin::CommandPoller: Error polling for host commands` - Indicates connectivity issues
     - `ERROR -- InstanceAgent::Plugins::CodeDeployPlugin::OnPremisesConfig: No credentials available` - IAM permission issues

2. **Deployment Scripts Logs** (`/opt/codedeploy-agent/deployment-root/[id]/[id]/logs/scripts.log`):
   - Contains output from lifecycle event scripts
   - Check for script execution errors
   - Look for non-zero exit codes
   - Identify timeouts or resource constraints

3. **CloudWatch Logs** (if configured):
   - Check for application-specific errors
   - Look for patterns that correlate with deployment times
   - Monitor resource utilization during deployments

4. **AWS CodeDeploy Console Logs**:
   - Review the Events tab for each deployment
   - Check lifecycle event status and duration
   - Look for failed events and error messages

When analyzing logs, focus on:
- Timestamps to correlate events across different logs
- Error messages and stack traces
- Resource utilization patterns
- Network connectivity issues
- Permission denied errors

## Resources Created

This lab creates the following AWS resources:

### Core Deployment Resources
- **CodeDeploy Application**: Single EC2 application
- **Deployment Group**: In-place deployment configuration
- **EC2 Instances**: 2 t3.micro instances (free tier eligible)
- **S3 Bucket**: Deployment artifact storage
- **IAM Roles**: Service roles for CodeDeploy and EC2
- **Security Group**: Basic web access configuration

### Estimated Costs (Free Tier Eligible)
- EC2 Instances: 750 hours/month free per t3.micro, then $0.0116/hour
- S3 Storage: 5GB free, then $0.023/GB/month
- CloudWatch Logs: 5GB free, then $0.50/GB ingested
- **Total estimated cost**: $0-10/month for regular use (mostly free tier)

## Cleanup

When you're finished with the lab, follow these steps to avoid ongoing charges:

1. **Run the cleanup script:**
   ```bash
   # On Linux/Mac:
   ./scripts/cleanup-codedeploy.sh
   
   # On Windows:
   bash scripts/cleanup-codedeploy.sh
   ```

2. **Verify cleanup:**
   - Check AWS Console to ensure all resources are removed
   - Confirm EC2 instances are terminated
   - Verify S3 buckets are deleted
   - Check CloudFormation stack is deleted

3. **Clean up local files:**
   ```bash
   rm -rf updated-app broken-app
   rm -f *-deployment.zip
   ```

> **Important**: Failure to delete resources may result in unexpected charges to your AWS account.

## Next Steps

After completing this lab, consider:

1. **Integrate with CodePipeline** for end-to-end CI/CD workflows
2. **Implement Lambda deployments** with alias-based traffic shifting
3. **Add custom deployment configurations** for specific rollout strategies
4. **Explore cross-region deployments** for disaster recovery
5. **Implement advanced monitoring** with custom CloudWatch metrics

## Additional Resources

### AWS Official Documentation
- [AWS CodeDeploy User Guide](https://docs.aws.amazon.com/codedeploy/latest/userguide/welcome.html) - Complete guide to CodeDeploy features and deployment strategies
- [AppSpec File Reference](https://docs.aws.amazon.com/codedeploy/latest/userguide/reference-appspec-file.html) - Detailed AppSpec file structure and configuration
- [AppSpec File Examples](https://docs.aws.amazon.com/codedeploy/latest/userguide/reference-appspec-file-example.html) - Sample AppSpec configurations for different scenarios
- [AppSpec Hooks Section](https://docs.aws.amazon.com/codedeploy/latest/userguide/reference-appspec-file-structure-hooks.html) - Lifecycle event hooks and script integration
- [AppSpec File Validation](https://docs.aws.amazon.com/codedeploy/latest/userguide/reference-appspec-file-validate.html) - Validating AppSpec files before deployment
- [CodeDeploy Agent Guide](https://docs.aws.amazon.com/codedeploy/latest/userguide/codedeploy-agent.html) - Working with the CodeDeploy agent
- [CodeDeploy Agent Installation](https://docs.aws.amazon.com/codedeploy/latest/userguide/codedeploy-agent-operations-install.html) - Installing the agent on different platforms

### Troubleshooting and Best Practices
- [EC2/On-Premises Deployment Troubleshooting](https://docs.aws.amazon.com/codedeploy/latest/userguide/troubleshooting-deployments.html) - Common deployment issues and solutions
- [CodeDeploy Agent Installation - Linux](https://docs.aws.amazon.com/codedeploy/latest/userguide/codedeploy-agent-operations-install-linux.html) - Linux-specific agent installation
- [CI/CD Best Practices](https://docs.aws.amazon.com/prescriptive-guidance/latest/strategy-cicd-litmus/cicd-best-practices.html) - AWS Prescriptive Guidance for deployment automation

### Infrastructure as Code and Integration
- [CloudFormation Templates for CodeDeploy](https://docs.aws.amazon.com/codedeploy/latest/userguide/reference-cloudformation-templates.html) - Infrastructure automation examples
- [CodePipeline Integration](https://docs.aws.amazon.com/codepipeline/latest/userguide/action-reference-CodeDeploy.html) - Using CodeDeploy in CI/CD pipelines

### Advanced Deployment Strategies
- [Deployment Configurations](https://docs.aws.amazon.com/codedeploy/latest/userguide/deployment-configurations.html) - Built-in and custom deployment configurations
- [Blue/Green Deployments](https://docs.aws.amazon.com/codedeploy/latest/userguide/deployments-create-prerequisites-auto-scaling-groups.html) - Zero-downtime deployment strategies
- [Rolling Deployments](https://docs.aws.amazon.com/codedeploy/latest/userguide/deployment-configurations-create.html) - Custom rolling deployment configurations

### Community Resources and Tutorials
- [AWS DevOps Blog: CodeDeploy](https://aws.amazon.com/blogs/devops/category/developer-tools/aws-codedeploy/) - Latest CodeDeploy features and advanced scenarios
- [Video Tutorial: AWS CodeDeploy In-Depth](https://www.youtube.com/watch?v=Wx-ain8UryM) - Comprehensive CodeDeploy walkthrough

### Supplementary Learning Resources

#### Blog Posts and Articles
- [AWS Architecture Blog: Multi-Region Deployments](https://aws.amazon.com/blogs/architecture/disaster-recovery-dr-architecture-on-aws-part-i-strategies-for-recovery-in-the-cloud/) - Cross-region deployment patterns
- [AWS Compute Blog: Container Deployments](https://aws.amazon.com/blogs/compute/deploying-applications-to-amazon-ecs-using-aws-codedeploy/) - ECS deployment strategies

#### Video Tutorials and Webinars
- [AWS re:Invent: Advanced Deployment Strategies](https://www.youtube.com/results?search_query=aws+reinvent+codedeploy) - Latest deployment techniques
- [AWS Online Tech Talks: Blue/Green Deployments](https://www.youtube.com/results?search_query=aws+blue+green+deployment) - Zero-downtime deployment strategies

#### Whitepapers and Technical Guides
- [AWS Whitepaper: Blue/Green Deployments on AWS](https://docs.aws.amazon.com/whitepapers/latest/blue-green-deployments/welcome.html) - Comprehensive deployment strategy guide
- [AWS Whitepaper: DevOps and Continuous Delivery](https://docs.aws.amazon.com/whitepapers/latest/introduction-devops-aws/introduction-devops-aws.html) - DevOps implementation patterns
- [AWS Whitepaper: Disaster Recovery](https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-workloads-on-aws/disaster-recovery-workloads-on-aws.html) - Recovery and rollback strategies
- [AWS Well-Architected Framework: Reliability](https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/welcome.html) - Reliable deployment practices

## AWS DevOps Professional Certification Relevance

### Certification Domain Mapping

This lab directly addresses multiple domains of the AWS Certified DevOps Engineer - Professional exam:

#### Domain 1: SDLC Automation (22% of exam)
- **1.1 Apply concepts required to automate a CI/CD pipeline**
  - Implementing deployment automation with CodeDeploy
  - Configuring deployment groups and strategies
  - Managing application lifecycle through appspec.yml
- **1.2 Determine source control strategies and workflows**
  - Integrating with S3 artifact storage
  - Managing deployment artifacts and versioning
- **1.3 Apply concepts required to automate and integrate testing**
  - Implementing validation hooks in deployment lifecycle
  - Automated health checks and monitoring integration

#### Domain 2: Configuration Management and Infrastructure as Code (19% of exam)
- **2.1 Determine deployment services based on deployment needs**
  - Choosing between in-place and blue-green deployment strategies
  - Understanding CodeDeploy vs other deployment services
- **2.2 Determine application and infrastructure deployment models**
  - EC2 instance deployment configurations
  - Auto Scaling Group integration patterns

#### Domain 3: Monitoring and Logging (15% of exam)
- **3.1 Determine how to set up the aggregation, storage, and analysis of logs and metrics**
  - CloudWatch Logs integration for deployment monitoring
  - Custom metrics for deployment success/failure tracking
- **3.2 Apply concepts required to automate monitoring and event management**
  - Automated rollback based on health checks
  - CloudWatch alarms for deployment failures

#### Domain 4: Policies and Standards Automation (10% of exam)
- **4.1 Apply concepts required to enforce standards for logging, metrics, monitoring, testing, and security**
  - IAM roles and policies for deployment security
  - Standardized deployment procedures through appspec.yml

### Key Exam Concepts Covered

**Deployment Strategies:**
- **In-place deployments**: Cost-effective, brief downtime acceptable
- **Blue-green deployments**: Zero-downtime, higher cost
- **Rolling deployments**: Gradual rollout with partial availability
- **Canary deployments**: Risk mitigation through limited exposure

**Critical Success Factors:**
- Health checks are mandatory for reliable deployments
- Auto-rollback configuration prevents extended outages
- Deployment groups define target scope and strategy
- AppSpec files control the entire deployment lifecycle
- IAM permissions follow least-privilege principles

**Troubleshooting Scenarios (Common Exam Topics):**
- Deployment stuck in "InProgress" → Check agent status and connectivity
- Validation failures → Review health check endpoints and scripts
- Permission errors → Verify service roles and resource policies
- Rollback not triggering → Check auto-rollback configuration and alarms

### Exam Tips and Best Practices

**Remember for the Exam:**
1. **CodeDeploy Agent**: Must be installed and running on target instances
2. **Service Roles**: Separate roles needed for CodeDeploy service and EC2 instances
3. **Health Checks**: Essential for automated rollback functionality
4. **Deployment Configurations**: Understand predefined vs custom configurations
5. **Integration Points**: How CodeDeploy fits with CodePipeline and other services

**Common Exam Scenarios:**
- Choosing deployment strategy based on requirements (downtime tolerance, cost)
- Troubleshooting failed deployments (logs, permissions, connectivity)
- Implementing cross-region deployment strategies
- Integrating with load balancers and Auto Scaling Groups

**Advanced Topics for Professional Level:**
- Custom deployment configurations for specific rollout patterns
- Cross-account deployment strategies
- Integration with third-party tools and custom scripts
- Performance optimization and cost management