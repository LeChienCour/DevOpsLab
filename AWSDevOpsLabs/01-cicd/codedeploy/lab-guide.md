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
   cd AWSDevOpsLabs/01-cicd/codedeploy
   ```

2. **Review the infrastructure template:**
   - Open `templates/codedeploy-infrastructure.yaml`
   - Examine the EC2 instances and deployment group configuration
   - Note the basic deployment strategy and IAM roles

3. **Review the deployment configurations:**
   ```bash
   ls -la deployment-configs/
   cat deployment-configs/appspec-ec2.yml
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
   INSTANCE_IP=$(grep "Instance IP:" lab-session-info.txt | head -1 | cut -d' ' -f3)
   echo "Application URL: http://$INSTANCE_IP"
   
   # Test the application
   curl -s "http://$INSTANCE_IP" | grep -o '<title>.*</title>'
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
   ARTIFACT_BUCKET=$(grep "Artifact Bucket:" lab-session-info.txt | cut -d' ' -f3)
   EC2_APP=$(grep "EC2 Application:" lab-session-info.txt | cut -d' ' -f3)
   DEPLOYMENT_GROUP=$(grep "Deployment Group:" lab-session-info.txt | cut -d' ' -f3)
   
   # Upload to S3
   aws s3 cp updated-app-deployment.zip "s3://$ARTIFACT_BUCKET/"
   
   # Start deployment
   DEPLOYMENT_ID=$(aws deploy create-deployment \
     --application-name "$EC2_APP" \
     --deployment-group-name "$DEPLOYMENT_GROUP" \
     --s3-location bucket="$ARTIFACT_BUCKET",key=updated-app-deployment.zip,bundleType=zip \
     --query 'deploymentId' \
     --output text)
   
   echo "Deployment started: $DEPLOYMENT_ID"
   ```

3. **Monitor the deployment:**
   ```bash
   # Watch deployment progress
   aws deploy get-deployment --deployment-id "$DEPLOYMENT_ID"
   
   # Monitor in AWS Console
   echo "Monitor at: https://console.aws.amazon.com/codesuite/codedeploy/deployments/$DEPLOYMENT_ID"
   ```

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
   BROKEN_DEPLOYMENT_ID=$(aws deploy create-deployment \
     --application-name "$EC2_APP" \
     --deployment-group-name "$DEPLOYMENT_GROUP" \
     --s3-location bucket="$ARTIFACT_BUCKET",key=broken-app-deployment.zip,bundleType=zip \
     --auto-rollback-configuration enabled=true,events=DEPLOYMENT_FAILURE,DEPLOYMENT_STOP_ON_ALARM \
     --query 'deploymentId' \
     --output text)
   
   echo "Broken Deployment (will rollback): $BROKEN_DEPLOYMENT_ID"
   ```

3. **Monitor the rollback:**
   ```bash
   # Watch the deployment fail and rollback
   watch -n 15 "aws deploy get-deployment --deployment-id $BROKEN_DEPLOYMENT_ID --query 'deploymentInfo.[status,errorInformation.message]' --output table"
   ```

### Step 5: Monitor and Troubleshoot Deployments

1. **Analyze deployment performance:**
   ```bash
   # Get deployment statistics
   aws deploy list-deployments \
     --application-name "$EC2_APP" \
     --query 'deployments[0:5]' \
     --output table
   
   # Get detailed deployment info
   aws deploy batch-get-deployments \
     --deployment-ids "$DEPLOYMENT_ID" \
     --query 'deploymentsInfo[*].[deploymentId,status,startTime,completeTime]' \
     --output table
   ```

2. **Review deployment logs:**
   ```bash
   # Get deployment events
   aws deploy list-deployment-instances \
     --deployment-id "$DEPLOYMENT_ID"
   
   # Check instance deployment status
   INSTANCE_ID=$(aws ec2 describe-instances \
     --filters "Name=tag:Project,Values=codedeploy-lab" \
     --query 'Reservations[0].Instances[0].InstanceId' \
     --output text)
   
   aws deploy get-deployment-instance \
     --deployment-id "$DEPLOYMENT_ID" \
     --instance-id "$INSTANCE_ID"
   ```

3. **Set up basic monitoring:**
   ```bash
   # Create alarm for deployment failures
   aws cloudwatch put-metric-alarm \
     --alarm-name "CodeDeploy-Lab-Failures" \
     --alarm-description "Alert on CodeDeploy failures" \
     --metric-name "FailedDeployments" \
     --namespace "AWS/CodeDeploy" \
     --statistic "Sum" \
     --period 300 \
     --threshold 1 \
     --comparison-operator "GreaterThanOrEqualToThreshold" \
     --evaluation-periods 1
   ```

## Troubleshooting Guide

### Common Issues and Solutions

1. **Deployment stuck in "InProgress":**
   - Check instance health in Auto Scaling Group
   - Verify CodeDeploy agent is running on instances
   - Check application logs in CloudWatch

2. **Validation failures:**
   - Review validation script logs
   - Check application accessibility
   - Verify health check endpoints

3. **Rollback not triggering:**
   - Ensure auto-rollback is configured
   - Check CloudWatch alarms
   - Verify rollback conditions

4. **Load balancer health check failures:**
   - Check security group rules
   - Verify application is listening on correct port
   - Review target group health check settings

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
```

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

When you're finished with the lab:

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

## Next Steps

After completing this lab, consider:

1. **Integrate with CodePipeline** for end-to-end CI/CD workflows
2. **Implement Lambda deployments** with alias-based traffic shifting
3. **Add custom deployment configurations** for specific rollout strategies
4. **Explore cross-region deployments** for disaster recovery
5. **Implement advanced monitoring** with custom CloudWatch metrics

## Certification Exam Tips

This lab covers several key areas for the AWS DevOps Professional exam:

- **Domain 1**: SDLC Automation (Deployment automation and strategies)
- **Domain 2**: Configuration Management (Infrastructure deployment)
- **Domain 3**: Monitoring and Logging (Deployment monitoring and alerting)
- **Domain 4**: Policies and Standards (Rollback policies and health checks)

Key concepts to remember:
- Blue-green deployments provide zero-downtime updates
- In-place deployments are cost-effective but may have brief downtime
- Auto-rollback requires proper health checks and alarms
- Deployment groups define target environments and strategies
- AppSpec files control the deployment lifecycle
- Health checks are critical for successful deployments