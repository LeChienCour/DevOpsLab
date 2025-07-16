# CodeDeploy Lab Guide

## Objective
Implement comprehensive deployment strategies using AWS CodeDeploy for EC2 and ECS targets, including blue-green deployments, in-place deployments, and automated rollback scenarios. This lab demonstrates advanced deployment patterns required for AWS DevOps Professional certification.

## Learning Outcomes
By completing this lab, you will:
- Master blue-green and in-place deployment strategies
- Implement automated rollback scenarios and health checks
- Configure deployment groups for different environments
- Understand CodeDeploy integration with Auto Scaling Groups and Load Balancers
- Practice ECS deployment strategies with traffic shifting
- Monitor deployments and troubleshoot deployment failures

## Prerequisites
- AWS CLI installed and configured with appropriate permissions
- Basic understanding of EC2, ECS, and Load Balancers
- Familiarity with Auto Scaling Groups
- Text editor for configuration modifications

### Required AWS Permissions
Your AWS user/role needs the following permissions:
- CloudFormation: Full access for stack management
- CodeDeploy: Full access for application and deployment management
- EC2: Full access for instances, Auto Scaling Groups, and Load Balancers
- ECS: Full access for cluster and service management
- IAM: Permission to create roles and policies
- S3: Full access for artifact storage

## Architecture Overview

This lab creates a comprehensive deployment environment:

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Application   │───▶│   CodeDeploy     │───▶│   Target        │
│   Artifacts     │    │   Applications   │    │   Environments  │
│   (S3 Bucket)   │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
                       ┌──────────────────┐    ┌─────────────────┐
                       │  Deployment      │    │  Auto Scaling   │
                       │  Groups          │    │  Groups + ALB   │
                       │                  │    │                 │
                       └──────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
                       ┌──────────────────┐    ┌─────────────────┐
                       │  Health Checks   │    │  ECS Cluster    │
                       │  & Monitoring    │    │  & Services     │
                       └──────────────────┘    └─────────────────┘
```

### Deployment Strategies Covered:
- **Blue-Green EC2**: Zero-downtime deployments with automatic traffic switching
- **In-Place EC2**: Rolling updates with health checks
- **ECS Blue-Green**: Container deployments with traffic shifting
- **Automated Rollback**: Failure detection and automatic rollback

## Lab Steps

### Step 1: Provision the CodeDeploy Environment

1. **Navigate to the CodeDeploy lab directory:**
   ```bash
   cd AWSDevOpsLabs/01-cicd/codedeploy
   ```

2. **Review the infrastructure template:**
   - Open `templates/codedeploy-infrastructure.yaml`
   - Examine the Auto Scaling Groups, Load Balancer, and ECS cluster
   - Note the different deployment groups and their configurations

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
   - The script creates a complete deployment environment
   - CloudFormation stack creation takes 10-15 minutes
   - Auto Scaling Group instances need additional time to initialize

6. **Verify the initial deployment:**
   - Use the Load Balancer URL from the output
   - Confirm the application is accessible
   - Note the initial deployment information

### Step 2: Understand the Deployment Environment

1. **Explore the created resources:**
   - Go to AWS Console → EC2 → Auto Scaling Groups
   - Find your Auto Scaling Group and examine the instances
   - Go to EC2 → Load Balancers and check the target group health

2. **Review CodeDeploy applications:**
   - Go to AWS Console → CodeDeploy → Applications
   - Examine the EC2 and ECS applications
   - Review the deployment groups and their configurations

3. **Check the sample application:**
   ```bash
   # Get the Load Balancer URL from the session info
   ALB_URL=$(grep "Load Balancer URL:" lab-session-info.txt | cut -d' ' -f4)
   echo "Application URL: $ALB_URL"
   
   # Test the application
   curl -s "$ALB_URL" | grep -o '<title>.*</title>'
   ```

### Step 3: Perform Blue-Green Deployment

1. **Prepare a new version of the application:**
   ```bash
   # Create an updated version
   mkdir -p updated-app/{scripts,css,js}
   
   # Copy the original deployment scripts
   cp -r deployment-configs/scripts updated-app/
   cp deployment-configs/appspec-ec2.yml updated-app/appspec.yml
   
   # Create updated HTML with version 3.0.0
   cat > updated-app/index.html << 'EOF'
   <!DOCTYPE html>
   <html lang="en">
   <head>
       <meta charset="UTF-8">
       <meta name="viewport" content="width=device-width, initial-scale=1.0">
       <title>CodeDeploy Lab Application - Updated</title>
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
               backdrop-filter: blur(10px);
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
               <h2>✅ Blue-Green Deployment Successful!</h2>
               <p class="version">Version 3.0.0</p>
               <p>This is the updated version deployed via Blue-Green strategy.</p>
               <p><strong>Deployment Time:</strong> <span id="deploy-time"></span></p>
               <p><strong>Instance ID:</strong> <span id="instance-id"></span></p>
               <p><strong>Strategy:</strong> Blue-Green Deployment</p>
           </div>
           <div style="margin-top: 30px;">
               <h3>🎯 New Features in v3.0.0:</h3>
               <ul>
                   <li>Enhanced UI with gradient background</li>
                   <li>Improved deployment information display</li>
                   <li>Better visual indicators for deployment success</li>
                   <li>Optimized performance and loading times</li>
               </ul>
           </div>
       </div>
       <script>
           // Load instance metadata
           fetch('http://169.254.169.254/latest/meta-data/instance-id')
               .then(response => response.text())
               .then(data => document.getElementById('instance-id').textContent = data)
               .catch(() => document.getElementById('instance-id').textContent = 'Unknown');
           
           document.getElementById('deploy-time').textContent = new Date().toLocaleString();
       </script>
   </body>
   </html>
   EOF
   
   # Create the deployment package
   cd updated-app && zip -r ../updated-app-deployment.zip . && cd ..
   ```

2. **Upload the new version:**
   ```bash
   # Get the artifact bucket name
   ARTIFACT_BUCKET=$(grep "Artifact Bucket:" lab-session-info.txt | cut -d' ' -f3)
   
   # Upload the updated application
   aws s3 cp updated-app-deployment.zip "s3://$ARTIFACT_BUCKET/"
   ```

3. **Start the blue-green deployment:**
   ```bash
   # Get deployment information
   EC2_APP=$(grep "EC2 Application:" lab-session-info.txt | cut -d' ' -f3)
   BLUE_GREEN_DG=$(grep "Blue-Green Deployment Group:" lab-session-info.txt | cut -d' ' -f4)
   
   # Create the deployment
   DEPLOYMENT_ID=$(aws deploy create-deployment \
     --application-name "$EC2_APP" \
     --deployment-group-name "$BLUE_GREEN_DG" \
     --s3-location bucket="$ARTIFACT_BUCKET",key=updated-app-deployment.zip,bundleType=zip \
     --query 'deploymentId' \
     --output text)
   
   echo "Blue-Green Deployment started: $DEPLOYMENT_ID"
   ```

4. **Monitor the blue-green deployment:**
   ```bash
   # Watch deployment status
   watch -n 10 "aws deploy get-deployment --deployment-id $DEPLOYMENT_ID --query 'deploymentInfo.status' --output text"
   
   # Or check in AWS Console → CodeDeploy → Deployments
   ```

5. **Observe the blue-green process:**
   - Go to AWS Console → EC2 → Auto Scaling Groups
   - Watch as new instances (Green fleet) are created
   - Monitor the Load Balancer target groups
   - Observe traffic switching from Blue to Green fleet

### Step 4: Test In-Place Deployment

1. **Create another version for in-place deployment:**
   ```bash
   # Create version 4.0.0 for in-place deployment
   mkdir -p inplace-app/{scripts,css,js}
   
   # Copy deployment scripts
   cp -r deployment-configs/scripts inplace-app/
   cp deployment-configs/appspec-ec2.yml inplace-app/appspec.yml
   
   # Create in-place version
   cat > inplace-app/index.html << 'EOF'
   <!DOCTYPE html>
   <html lang="en">
   <head>
       <meta charset="UTF-8">
       <meta name="viewport" content="width=device-width, initial-scale=1.0">
       <title>CodeDeploy Lab - In-Place Update</title>
       <style>
           body { 
               font-family: Arial, sans-serif; 
               margin: 40px; 
               background: linear-gradient(135deg, #6f42c1 0%, #e83e8c 100%);
               color: white;
           }
           .container { 
               max-width: 800px; 
               margin: 0 auto; 
               background: rgba(255,255,255,0.1);
               padding: 40px;
               border-radius: 15px;
               backdrop-filter: blur(10px);
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
           .rolling { 
               animation: pulse 2s infinite; 
           }
           @keyframes pulse {
               0% { opacity: 1; }
               50% { opacity: 0.7; }
               100% { opacity: 1; }
           }
       </style>
   </head>
   <body>
       <div class="container">
           <h1 class="rolling">🔄 CodeDeploy Lab Application</h1>
           <div class="status">
               <h2>✅ In-Place Deployment Successful!</h2>
               <p class="version">Version 4.0.0</p>
               <p>This version was deployed using In-Place (Rolling) strategy.</p>
               <p><strong>Deployment Time:</strong> <span id="deploy-time"></span></p>
               <p><strong>Instance ID:</strong> <span id="instance-id"></span></p>
               <p><strong>Strategy:</strong> In-Place Rolling Deployment</p>
           </div>
           <div style="margin-top: 30px;">
               <h3>🎯 In-Place Deployment Features:</h3>
               <ul>
                   <li>Rolling updates across existing instances</li>
                   <li>Maintains minimum healthy capacity</li>
                   <li>Faster deployment (no new instances)</li>
                   <li>Cost-effective for development environments</li>
               </ul>
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
   cd inplace-app && zip -r ../inplace-app-deployment.zip . && cd ..
   ```

2. **Upload and deploy the in-place version:**
   ```bash
   # Upload to S3
   aws s3 cp inplace-app-deployment.zip "s3://$ARTIFACT_BUCKET/"
   
   # Get in-place deployment group
   IN_PLACE_DG=$(grep "In-Place Deployment Group:" lab-session-info.txt | cut -d' ' -f4)
   
   # Start in-place deployment
   INPLACE_DEPLOYMENT_ID=$(aws deploy create-deployment \
     --application-name "$EC2_APP" \
     --deployment-group-name "$IN_PLACE_DG" \
     --s3-location bucket="$ARTIFACT_BUCKET",key=inplace-app-deployment.zip,bundleType=zip \
     --query 'deploymentId' \
     --output text)
   
   echo "In-Place Deployment started: $INPLACE_DEPLOYMENT_ID"
   ```

3. **Monitor the in-place deployment:**
   ```bash
   # Watch deployment progress
   aws deploy get-deployment --deployment-id "$INPLACE_DEPLOYMENT_ID"
   
   # Monitor in AWS Console
   echo "Monitor at: https://console.aws.amazon.com/codesuite/codedeploy/deployments/$INPLACE_DEPLOYMENT_ID"
   ```

### Step 5: Test Rollback Scenarios

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
     --deployment-group-name "$BLUE_GREEN_DG" \
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

### Step 6: Advanced Deployment Monitoring

1. **Set up CloudWatch monitoring:**
   ```bash
   # Create custom metric filter for deployment logs
   aws logs put-metric-filter \
     --log-group-name "/aws/codedeploy/agent" \
     --filter-name "DeploymentErrors" \
     --filter-pattern "ERROR" \
     --metric-transformations \
       metricName=DeploymentErrors,metricNamespace=CodeDeploy,metricValue=1
   ```

2. **Create deployment dashboard:**
   ```bash
   # Create CloudWatch dashboard
   cat > dashboard-config.json << 'EOF'
   {
     "widgets": [
       {
         "type": "metric",
         "properties": {
           "metrics": [
             ["AWS/CodeDeploy", "Deployments", "ApplicationName", "REPLACE_APP_NAME"]
           ],
           "period": 300,
           "stat": "Sum",
           "region": "us-east-1",
           "title": "CodeDeploy Deployments"
         }
       }
     ]
   }
   EOF
   
   # Replace placeholder and create dashboard
   sed "s/REPLACE_APP_NAME/$EC2_APP/g" dashboard-config.json > dashboard-final.json
   aws cloudwatch put-dashboard \
     --dashboard-name "CodeDeploy-Lab-Dashboard" \
     --dashboard-body file://dashboard-final.json
   ```

3. **Monitor deployment metrics:**
   ```bash
   # Get deployment statistics
   aws deploy list-deployments \
     --application-name "$EC2_APP" \
     --query 'deployments[0:5]' \
     --output table
   
   # Get detailed deployment info
   aws deploy batch-get-deployments \
     --deployment-ids "$DEPLOYMENT_ID" "$INPLACE_DEPLOYMENT_ID" \
     --query 'deploymentsInfo[*].[deploymentId,status,startTime,completeTime]' \
     --output table
   ```

### Step 7: ECS Deployment (Advanced)

1. **Test ECS blue-green deployment:**
   ```bash
   # Get ECS application info
   ECS_APP=$(grep "ECS Application:" lab-session-info.txt | cut -d' ' -f3)
   ECS_DG=$(grep "ECS Deployment Group:" lab-session-info.txt | cut -d' ' -f4)
   
   # Create ECS task definition update
   cat > ecs-taskdef.json << 'EOF'
   {
     "family": "codedeploy-lab-task",
     "networkMode": "awsvpc",
     "requiresCompatibilities": ["FARGATE"],
     "cpu": "256",
     "memory": "512",
     "executionRoleArn": "REPLACE_EXECUTION_ROLE",
     "taskRoleArn": "REPLACE_TASK_ROLE",
     "containerDefinitions": [
       {
         "name": "web-app",
         "image": "nginx:alpine",
         "portMappings": [
           {
             "containerPort": 80,
             "protocol": "tcp"
           }
         ],
         "logConfiguration": {
           "logDriver": "awslogs",
           "options": {
             "awslogs-group": "/ecs/codedeploy-lab",
             "awslogs-region": "us-east-1",
             "awslogs-stream-prefix": "ecs"
           }
         }
       }
     ]
   }
   EOF
   
   echo "ECS deployment configuration created"
   echo "Note: ECS deployments require additional setup and are demonstrated in the console"
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
- **CodeDeploy Applications**: EC2 and ECS applications
- **Deployment Groups**: Blue-green and in-place deployment configurations
- **Auto Scaling Group**: EC2 instances for deployment targets
- **Application Load Balancer**: Traffic distribution and health checks

### Supporting Infrastructure
- **ECS Cluster**: Container deployment environment
- **ECS Service**: Container service with deployment configuration
- **S3 Bucket**: Deployment artifact storage
- **IAM Roles**: Service roles for CodeDeploy, EC2, and ECS
- **Security Groups**: Network access control
- **CloudWatch Alarms**: Deployment monitoring and rollback triggers

### Estimated Costs
- EC2 Instances: $0.0116/hour per t3.micro instance (2-6 instances)
- Application Load Balancer: $0.0225/hour + $0.008/LCU-hour
- ECS Fargate: $0.04048/vCPU/hour + $0.004445/GB/hour
- S3 Storage: $0.023/GB/month
- CloudWatch: $0.50/GB ingested
- **Total estimated cost**: $15-30/day for active lab use

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
   - Check AWS Console for remaining resources
   - Confirm Auto Scaling Groups are deleted
   - Verify Load Balancers are removed
   - Check ECS cluster is deleted

3. **Clean up local files:**
   ```bash
   rm -rf updated-app inplace-app broken-app
   rm -f *-deployment.zip
   rm -f dashboard-*.json ecs-taskdef.json
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