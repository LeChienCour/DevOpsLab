# AWS CDK Lab Guide

## Objective
Learn how to provision and manage AWS infrastructure using the AWS Cloud Development Kit (CDK) with TypeScript. This lab demonstrates how to use programming languages to define cloud infrastructure as code, create reusable components, and deploy multi-tier applications using modern development practices required for the AWS DevOps Professional certification.

## Learning Outcomes
By completing this lab, you will:
- Master AWS CDK concepts and architecture for infrastructure as code
- Create and deploy infrastructure using TypeScript and CDK constructs
- Implement multi-tier applications with proper separation of concerns
- Compare CDK with CloudFormation and understand when to use each
- Apply CDK best practices for production-ready infrastructure
- Test infrastructure code using CDK testing frameworks

## Prerequisites
- AWS Account with administrative access
- Node.js 18+ and npm installed
- AWS CLI installed and configured with appropriate permissions
- AWS CDK CLI installed: `npm install -g aws-cdk`
- Basic TypeScript knowledge
- Text editor or IDE (VS Code recommended)

### Required AWS Permissions
Your AWS user/role needs the following permissions:
- CloudFormation: Full access for stack management
- IAM: Permission to create roles and policies
- S3: Full access for asset storage
- EC2: Full access for VPC and networking resources
- Various service permissions based on resources being deployed

### Time to Complete
Approximately 90 minutes

## Architecture Overview

This lab creates a multi-tier application infrastructure using AWS CDK:

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CDK Application                             │
│                                                                     │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐  │
│  │  Network Stack  │───▶│  Service Stack  │───▶│ Monitoring Stack│  │
│  │  (VPC, Subnets) │    │  (ECS, ALB)     │    │  (CloudWatch)   │  │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘  │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                 Custom Constructs                           │    │
│  │  (Reusable Infrastructure Components)                       │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

### Resources Created:
- **Network Stack**: VPC, public and private subnets, route tables, internet gateway
- **Service Stack**: ECS cluster, service, task definition, load balancer
- **Monitoring Stack**: CloudWatch dashboards, alarms, and log groups
- **Custom Constructs**: Reusable infrastructure components
- **CDK Bootstrap Resources**: S3 bucket, IAM roles for CDK deployment

## Lab Steps

### Step 1: Set Up the CDK Project

1. **Create a new CDK project:**
   ```bash
   # Create a directory for the CDK project
   mkdir -p devops-lab-cdk
   cd devops-lab-cdk
   
   # Initialize a new CDK project with TypeScript
   cdk init app --language typescript
   ```
   
   > **Note**: This creates a new CDK project with the TypeScript template.

2. **Install dependencies:**
   ```bash
   # Install required dependencies
   npm install
   ```
   
   Expected output:
   ```
   added XX packages, and audited XX packages in Xs
   found 0 vulnerabilities
   ```

3. **Explore the project structure:**
   ```bash
   # List the project files
   ls -la
   ```
   
   - Note the `lib` directory containing the stack definition
   - Observe the `bin` directory with the CDK app entry point
   - Understand the `cdk.json` configuration file

### Step 2: Bootstrap the CDK Environment

1. **Bootstrap the AWS environment:**
   ```bash
   # Bootstrap CDK in your AWS account/region
   cdk bootstrap
   ```
   
   > **Note**: This command creates the necessary resources for CDK deployments, including an S3 bucket for assets and IAM roles.

2. **Verify bootstrap resources:**
   ```bash
   # Check the CloudFormation stacks
   aws cloudformation list-stacks --query "StackSummaries[?contains(StackName, 'CDKToolkit')].{Name:StackName,Status:StackStatus}"
   ```
   
   Expected output:
   ```json
   [
       {
           "Name": "CDKToolkit",
           "Status": "CREATE_COMPLETE"
       }
   ]
   ```

### Step 3: Create the Network Stack

1. **Create a network stack file:**
   ```bash
   # Create a new file for the network stack
   cat > lib/network-stack.ts << 'EOF'
   import * as cdk from 'aws-cdk-lib';
   import * as ec2 from 'aws-cdk-lib/aws-ec2';
   import { Construct } from 'constructs';

   export interface NetworkStackProps extends cdk.StackProps {
     environment: string;
   }

   export class NetworkStack extends cdk.Stack {
     public readonly vpc: ec2.Vpc;
     
     constructor(scope: Construct, id: string, props: NetworkStackProps) {
       super(scope, id, props);

       // Create VPC with public and private subnets
       this.vpc = new ec2.Vpc(this, 'VPC', {
         maxAzs: 2,
         natGateways: 1,
         subnetConfiguration: [
           {
             name: 'public',
             subnetType: ec2.SubnetType.PUBLIC,
             cidrMask: 24,
           },
           {
             name: 'private',
             subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
             cidrMask: 24,
           },
         ],
       });

       // Add tags to all resources in this stack
       cdk.Tags.of(this).add('Environment', props.environment);
       cdk.Tags.of(this).add('Project', 'DevOpsLab');
       cdk.Tags.of(this).add('ManagedBy', 'CDK');

       // Output the VPC ID
       new cdk.CfnOutput(this, 'VpcId', {
         value: this.vpc.vpcId,
         description: 'The ID of the VPC',
         exportName: `${props.environment}-VpcId`,
       });
     }
   }
   EOF
   ```

2. **Create a service stack file:**
   ```bash
   # Create a new file for the service stack
   cat > lib/service-stack.ts << 'EOF'
   import * as cdk from 'aws-cdk-lib';
   import * as ec2 from 'aws-cdk-lib/aws-ec2';
   import * as ecs from 'aws-cdk-lib/aws-ecs';
   import * as elbv2 from 'aws-cdk-lib/aws-elasticloadbalancingv2';
   import { Construct } from 'constructs';

   export interface ServiceStackProps extends cdk.StackProps {
     vpc: ec2.Vpc;
     environment: string;
   }

   export class ServiceStack extends cdk.Stack {
     public readonly loadBalancerDnsName: string;
     
     constructor(scope: Construct, id: string, props: ServiceStackProps) {
       super(scope, id, props);

       // Create ECS Cluster
       const cluster = new ecs.Cluster(this, 'Cluster', {
         vpc: props.vpc,
         containerInsights: true,
       });

       // Create Task Definition
       const taskDefinition = new ecs.FargateTaskDefinition(this, 'TaskDef', {
         memoryLimitMiB: 512,
         cpu: 256,
       });

       // Add Container to Task Definition
       const container = taskDefinition.addContainer('WebContainer', {
         image: ecs.ContainerImage.fromRegistry('amazon/amazon-ecs-sample'),
         logging: ecs.LogDrivers.awsLogs({ streamPrefix: 'web-app' }),
         environment: {
           'ENVIRONMENT': props.environment,
         },
       });

       container.addPortMappings({
         containerPort: 80,
         protocol: ecs.Protocol.TCP,
       });

       // Create Security Group for the Service
       const serviceSecurityGroup = new ec2.SecurityGroup(this, 'ServiceSG', {
         vpc: props.vpc,
         description: 'Security group for the Fargate service',
         allowAllOutbound: true,
       });

       // Create ALB
       const alb = new elbv2.ApplicationLoadBalancer(this, 'ALB', {
         vpc: props.vpc,
         internetFacing: true,
       });

       // Create ALB Listener
       const listener = alb.addListener('Listener', {
         port: 80,
         open: true,
       });

       // Create Target Group
       const targetGroup = listener.addTargets('WebService', {
         port: 80,
         targets: [
           new elbv2.EcsTarget({
             containerName: 'WebContainer',
             containerPort: 80,
             newTargetGroupId: 'ECS',
             taskDefinition,
           }),
         ],
         healthCheck: {
           path: '/',
           interval: cdk.Duration.seconds(60),
           timeout: cdk.Duration.seconds(5),
         },
       });

       // Create ECS Service
       const service = new ecs.FargateService(this, 'Service', {
         cluster,
         taskDefinition,
         desiredCount: 2,
         securityGroups: [serviceSecurityGroup],
         assignPublicIp: false,
       });

       // Allow ALB to access the service
       serviceSecurityGroup.addIngressRule(
         ec2.Peer.anyIpv4(),
         ec2.Port.tcp(80),
         'Allow HTTP traffic from ALB'
       );

       // Store the DNS name for output
       this.loadBalancerDnsName = alb.loadBalancerDnsName;

       // Add tags to all resources in this stack
       cdk.Tags.of(this).add('Environment', props.environment);
       cdk.Tags.of(this).add('Project', 'DevOpsLab');
       cdk.Tags.of(this).add('ManagedBy', 'CDK');

       // Output the ALB DNS name
       new cdk.CfnOutput(this, 'AlbDnsName', {
         value: alb.loadBalancerDnsName,
         description: 'The DNS name of the load balancer',
         exportName: `${props.environment}-AlbDnsName`,
       });
     }
   }
   EOF
   ```

3. **Create a monitoring stack file:**
   ```bash
   # Create a new file for the monitoring stack
   cat > lib/monitoring-stack.ts << 'EOF'
   import * as cdk from 'aws-cdk-lib';
   import * as cloudwatch from 'aws-cdk-lib/aws-cloudwatch';
   import { Construct } from 'constructs';

   export interface MonitoringStackProps extends cdk.StackProps {
     environment: string;
     loadBalancerDnsName: string;
   }

   export class MonitoringStack extends cdk.Stack {
     constructor(scope: Construct, id: string, props: MonitoringStackProps) {
       super(scope, id, props);

       // Create CloudWatch Dashboard
       const dashboard = new cloudwatch.Dashboard(this, 'Dashboard', {
         dashboardName: `DevOpsLab-${props.environment}`,
       });

       // Add widgets to the dashboard
       dashboard.addWidgets(
         new cloudwatch.TextWidget({
           markdown: `# DevOps Lab ${props.environment} Environment\n\nApplication URL: http://${props.loadBalancerDnsName}`,
           width: 24,
           height: 2,
         }),
         new cloudwatch.GraphWidget({
           title: 'ALB Request Count',
           left: [
             new cloudwatch.Metric({
               namespace: 'AWS/ApplicationELB',
               metricName: 'RequestCount',
               statistic: 'Sum',
               period: cdk.Duration.minutes(1),
               dimensionsMap: {
                 LoadBalancer: 'app/ALB',
               },
             }),
           ],
           width: 12,
           height: 6,
         }),
         new cloudwatch.GraphWidget({
           title: 'ALB Target Response Time',
           left: [
             new cloudwatch.Metric({
               namespace: 'AWS/ApplicationELB',
               metricName: 'TargetResponseTime',
               statistic: 'Average',
               period: cdk.Duration.minutes(1),
               dimensionsMap: {
                 LoadBalancer: 'app/ALB',
               },
             }),
           ],
           width: 12,
           height: 6,
         })
       );

       // Create CloudWatch Alarm
       const alarm = new cloudwatch.Alarm(this, 'HighResponseTimeAlarm', {
         metric: new cloudwatch.Metric({
           namespace: 'AWS/ApplicationELB',
           metricName: 'TargetResponseTime',
           statistic: 'Average',
           period: cdk.Duration.minutes(1),
           dimensionsMap: {
             LoadBalancer: 'app/ALB',
           },
         }),
         threshold: 5,
         evaluationPeriods: 3,
         datapointsToAlarm: 2,
         alarmDescription: 'Alarm if response time is high',
       });

       // Add tags to all resources in this stack
       cdk.Tags.of(this).add('Environment', props.environment);
       cdk.Tags.of(this).add('Project', 'DevOpsLab');
       cdk.Tags.of(this).add('ManagedBy', 'CDK');

       // Output the dashboard URL
       new cdk.CfnOutput(this, 'DashboardUrl', {
         value: `https://${this.region}.console.aws.amazon.com/cloudwatch/home?region=${this.region}#dashboards:name=${dashboard.dashboardName}`,
         description: 'URL to the CloudWatch Dashboard',
         exportName: `${props.environment}-DashboardUrl`,
       });
     }
   }
   EOF
   ```

4. **Update the main app file:**
   ```bash
   # Update the main app file
   cat > bin/devops-lab-cdk.ts << 'EOF'
   #!/usr/bin/env node
   import 'source-map-support/register';
   import * as cdk from 'aws-cdk-lib';
   import { NetworkStack } from '../lib/network-stack';
   import { ServiceStack } from '../lib/service-stack';
   import { MonitoringStack } from '../lib/monitoring-stack';

   const app = new cdk.App();

   // Define environment
   const environment = app.node.tryGetContext('environment') || 'dev';

   // Create the network stack
   const networkStack = new NetworkStack(app, `${environment}-NetworkStack`, {
     environment,
     description: 'Network infrastructure for the DevOps Lab',
   });

   // Create the service stack
   const serviceStack = new ServiceStack(app, `${environment}-ServiceStack`, {
     vpc: networkStack.vpc,
     environment,
     description: 'Service infrastructure for the DevOps Lab',
   });

   // Create the monitoring stack
   const monitoringStack = new MonitoringStack(app, `${environment}-MonitoringStack`, {
     environment,
     loadBalancerDnsName: serviceStack.loadBalancerDnsName,
     description: 'Monitoring infrastructure for the DevOps Lab',
   });

   // Add dependencies
   serviceStack.addDependency(networkStack);
   monitoringStack.addDependency(serviceStack);
   EOF
   ```

### Step 4: Create a Custom Construct

1. **Create a directory for constructs:**
   ```bash
   # Create a directory for custom constructs
   mkdir -p lib/constructs
   ```

2. **Create a custom construct:**
   ```bash
   # Create a file for a custom construct
   cat > lib/constructs/web-service.ts << 'EOF'
   import * as cdk from 'aws-cdk-lib';
   import * as ec2 from 'aws-cdk-lib/aws-ec2';
   import * as ecs from 'aws-cdk-lib/aws-ecs';
   import * as elbv2 from 'aws-cdk-lib/aws-elasticloadbalancingv2';
   import { Construct } from 'constructs';

   export interface WebServiceProps {
     vpc: ec2.Vpc;
     serviceName: string;
     containerImage: string;
     containerPort: number;
     desiredCount: number;
     environment?: { [key: string]: string };
     memoryLimitMiB?: number;
     cpu?: number;
   }

   export class WebService extends Construct {
     public readonly service: ecs.FargateService;
     public readonly loadBalancer: elbv2.ApplicationLoadBalancer;
     
     constructor(scope: Construct, id: string, props: WebServiceProps) {
       super(scope, id);

       // Create ECS Cluster
       const cluster = new ecs.Cluster(this, 'Cluster', {
         vpc: props.vpc,
         containerInsights: true,
       });

       // Create Task Definition
       const taskDefinition = new ecs.FargateTaskDefinition(this, 'TaskDef', {
         memoryLimitMiB: props.memoryLimitMiB || 512,
         cpu: props.cpu || 256,
       });

       // Add Container to Task Definition
       const container = taskDefinition.addContainer('Container', {
         image: ecs.ContainerImage.fromRegistry(props.containerImage),
         logging: ecs.LogDrivers.awsLogs({ streamPrefix: props.serviceName }),
         environment: props.environment,
       });

       container.addPortMappings({
         containerPort: props.containerPort,
         protocol: ecs.Protocol.TCP,
       });

       // Create Security Group for the Service
       const serviceSecurityGroup = new ec2.SecurityGroup(this, 'ServiceSG', {
         vpc: props.vpc,
         description: `Security group for ${props.serviceName}`,
         allowAllOutbound: true,
       });

       // Create ALB
       this.loadBalancer = new elbv2.ApplicationLoadBalancer(this, 'ALB', {
         vpc: props.vpc,
         internetFacing: true,
       });

       // Create ALB Listener
       const listener = this.loadBalancer.addListener('Listener', {
         port: 80,
         open: true,
       });

       // Create Target Group
       const targetGroup = listener.addTargets('WebService', {
         port: props.containerPort,
         targets: [
           new elbv2.EcsTarget({
             containerName: 'Container',
             containerPort: props.containerPort,
             newTargetGroupId: 'ECS',
             taskDefinition,
           }),
         ],
         healthCheck: {
           path: '/',
           interval: cdk.Duration.seconds(60),
           timeout: cdk.Duration.seconds(5),
         },
       });

       // Create ECS Service
       this.service = new ecs.FargateService(this, 'Service', {
         cluster,
         taskDefinition,
         desiredCount: props.desiredCount,
         securityGroups: [serviceSecurityGroup],
         assignPublicIp: false,
       });

       // Allow ALB to access the service
       serviceSecurityGroup.addIngressRule(
         ec2.Peer.anyIpv4(),
         ec2.Port.tcp(props.containerPort),
         'Allow traffic from ALB'
       );
     }
   }
   EOF
   ```

3. **Update the service stack to use the custom construct:**
   ```bash
   # Update the service stack to use the custom construct
   cat > lib/service-stack.ts << 'EOF'
   import * as cdk from 'aws-cdk-lib';
   import * as ec2 from 'aws-cdk-lib/aws-ec2';
   import { Construct } from 'constructs';
   import { WebService } from './constructs/web-service';

   export interface ServiceStackProps extends cdk.StackProps {
     vpc: ec2.Vpc;
     environment: string;
   }

   export class ServiceStack extends cdk.Stack {
     public readonly loadBalancerDnsName: string;
     
     constructor(scope: Construct, id: string, props: ServiceStackProps) {
       super(scope, id, props);

       // Create Web Service using custom construct
       const webService = new WebService(this, 'WebService', {
         vpc: props.vpc,
         serviceName: `${props.environment}-web-app`,
         containerImage: 'amazon/amazon-ecs-sample',
         containerPort: 80,
         desiredCount: props.environment === 'prod' ? 2 : 1,
         environment: {
           'ENVIRONMENT': props.environment,
           'APP_NAME': 'DevOps Lab Web App',
         },
         memoryLimitMiB: 512,
         cpu: 256,
       });

       // Store the DNS name for output
       this.loadBalancerDnsName = webService.loadBalancer.loadBalancerDnsName;

       // Add tags to all resources in this stack
       cdk.Tags.of(this).add('Environment', props.environment);
       cdk.Tags.of(this).add('Project', 'DevOpsLab');
       cdk.Tags.of(this).add('ManagedBy', 'CDK');

       // Output the ALB DNS name
       new cdk.CfnOutput(this, 'AlbDnsName', {
         value: webService.loadBalancer.loadBalancerDnsName,
         description: 'The DNS name of the load balancer',
         exportName: `${props.environment}-AlbDnsName`,
       });
     }
   }
   EOF
   ```

### Step 5: Synthesize and Deploy the CDK App

1. **Synthesize the CloudFormation templates:**
   ```bash
   # Synthesize the CloudFormation templates
   cdk synth
   ```
   
   - This command generates CloudFormation templates from your CDK code
   - The templates are stored in the `cdk.out` directory

2. **Review the generated templates:**
   ```bash
   # List the generated templates
   ls -la cdk.out
   
   # View the network stack template
   cat cdk.out/dev-NetworkStack.template.json
   ```
   
   - Note how the CDK code is translated to CloudFormation
   - Observe the resources and their properties

3. **Deploy the stacks:**
   ```bash
   # Deploy the stacks
   cdk deploy --all
   ```
   
   > **Note**: This command deploys all stacks to your AWS account. It will take approximately 15-20 minutes to complete.

4. **Monitor the deployment:**
   ```bash
   # Check the CloudFormation stack status
   aws cloudformation list-stacks --query "StackSummaries[?contains(StackName, 'dev-')].{Name:StackName,Status:StackStatus}"
   ```
   
   Expected output when complete:
   ```json
   [
       {
           "Name": "dev-NetworkStack",
           "Status": "CREATE_COMPLETE"
       },
       {
           "Name": "dev-ServiceStack",
           "Status": "CREATE_COMPLETE"
       },
       {
           "Name": "dev-MonitoringStack",
           "Status": "CREATE_COMPLETE"
       }
   ]
   ```

### Step 6: Test the Deployed Application

1. **Get the application URL:**
   ```bash
   # Get the load balancer DNS name
   aws cloudformation describe-stacks --stack-name dev-ServiceStack --query "Stacks[0].Outputs[?OutputKey=='AlbDnsName'].OutputValue" --output text
   ```

2. **Access the application:**
   - Open the URL in a web browser
   - Verify that the application is running correctly

3. **View the CloudWatch dashboard:**
   ```bash
   # Get the dashboard URL
   aws cloudformation describe-stacks --stack-name dev-MonitoringStack --query "Stacks[0].Outputs[?OutputKey=='DashboardUrl'].OutputValue" --output text
   ```
   
   - Open the URL in a web browser
   - Explore the metrics and graphs

### Step 7: Make Changes and Update the Stacks

1. **Modify the service configuration:**
   ```bash
   # Update the desired count in the service stack
   sed -i 's/desiredCount: props.environment === .prod. ? 2 : 1/desiredCount: props.environment === .prod. ? 2 : 2/' lib/service-stack.ts
   ```
   
   > **Note**: On Windows, use a text editor to make this change.

2. **View the differences:**
   ```bash
   # See what changes will be made
   cdk diff
   ```
   
   - Note the resources that will be modified
   - Understand the impact of the changes

3. **Deploy the changes:**
   ```bash
   # Deploy the updated stacks
   cdk deploy --all
   ```
   
   - Observe how CDK handles the updates
   - Note that only the necessary resources are updated

### Step 8: Clean Up Resources

1. **Destroy the CDK stacks:**
   ```bash
   # Destroy all stacks
   cdk destroy --all
   ```
   
   > **Note**: This command removes all resources created by CDK. It will take approximately 10-15 minutes to complete.

2. **Verify resource cleanup:**
   ```bash
   # Check that stacks have been removed
   aws cloudformation list-stacks --query "StackSummaries[?contains(StackName, 'dev-')].{Name:StackName,Status:StackStatus}"
   ```
   
   Expected output:
   ```json
   [
       {
           "Name": "dev-MonitoringStack",
           "Status": "DELETE_COMPLETE"
       },
       {
           "Name": "dev-ServiceStack",
           "Status": "DELETE_COMPLETE"
       },
       {
           "Name": "dev-NetworkStack",
           "Status": "DELETE_COMPLETE"
       }
   ]
   ```

## Troubleshooting Guide



### Common Issues and Solutions

1. **CDK bootstrap errors:**
   - **Issue**: CDK bootstrap process fails, preventing deployment of CDK applications.
   - **Solutions**:
     - Verify AWS credentials are correctly configured in the AWS CLI or environment variables
     - Check that you have sufficient permissions for creating bootstrap resources
     - Try running `aws sts get-caller-identity` to verify your identity and permissions
     - Ensure you're targeting the correct AWS region
     - Check for existing bootstrap stacks that might be in a failed state
     - Verify network connectivity to AWS CloudFormation and S3 services
     - Check for organization SCPs that might restrict bootstrap resource creation
     - Try using the `--force` flag if updating an existing bootstrap stack
     - Verify that the AWS account has sufficient quotas for bootstrap resources
     - Check CloudTrail logs for specific permission errors during bootstrap

2. **Synthesis errors:**
   - **Issue**: CDK fails to synthesize CloudFormation templates from TypeScript code.
   - **Solutions**:
     - Check for TypeScript compilation errors with `npm run build`
     - Verify that all imports are correct and packages are installed
     - Ensure all required properties are provided to constructs
     - Check for circular dependencies between constructs or stacks
     - Look for missing or incorrect property types
     - Verify that construct IDs are unique within their scope
     - Check for deprecated APIs or constructs that need updating
     - Ensure node version compatibility with CDK version
     - Look for syntax errors in TypeScript code
     - Try running with `--verbose` flag for more detailed error messages

3. **Deployment failures:**
   - **Issue**: CDK deployment fails when creating or updating CloudFormation stacks.
   - **Solutions**:
     - Check CloudFormation events for specific error messages
     - Verify that service quotas allow creating the resources
     - Check for permission issues in the CloudFormation logs
     - Ensure resource names are unique and valid
     - Look for dependencies on resources that failed to create
     - Check for resource-specific constraints (e.g., VPC limits)
     - Verify that all required parameters are provided
     - Check for drift in previously deployed resources
     - Try deploying individual stacks to isolate issues
     - Consider using `--no-rollback` to keep failed resources for debugging

4. **Custom construct issues:**
   - **Issue**: Custom constructs fail to work as expected.
   - **Solutions**:
     - Verify that the construct is properly imported and referenced
     - Check that all required properties are provided with valid values
     - Ensure the construct is properly integrated with other resources
     - Test the construct in isolation if possible
     - Check for scope issues (passing the wrong scope to the construct)
     - Verify that IDs are unique within the construct's scope
     - Look for logical errors in the construct implementation
     - Check for compatibility issues with the CDK version
     - Ensure the construct follows CDK best practices
     - Try simplifying the construct to identify specific issues

5. **Asset publishing issues:**
   - **Issue**: CDK fails to publish assets to S3 during deployment.
   - **Solutions**:
     - Check S3 permissions in the bootstrap role
     - Verify network connectivity to S3
     - Check for asset size limits
     - Ensure the bootstrap bucket exists and is accessible
     - Look for S3 bucket policy restrictions
     - Check for asset hash calculation issues
     - Verify that the asset directory is included in the build
     - Try clearing the CDK cache (`~/.cdk/cache`)
     - Check for file permission issues in asset directories
     - Verify AWS credentials have S3 permissions

6. **Version compatibility issues:**
   - **Issue**: Incompatibilities between CDK, construct libraries, and TypeScript versions.
   - **Solutions**:
     - Ensure all AWS CDK packages have matching versions
     - Check for compatibility between CDK version and construct library versions
     - Verify TypeScript version compatibility
     - Check for deprecated APIs or constructs
     - Look for breaking changes in CDK release notes
     - Consider using npm-check-updates to identify version issues
     - Try locking dependencies to known working versions
     - Check for peer dependency conflicts
     - Verify node version compatibility
     - Consider using CDK's built-in compatibility checking

7. **Context and environment issues:**
   - **Issue**: Problems with CDK context values or environment configuration.
   - **Solutions**:
     - Check `cdk.json` and `cdk.context.json` for correct values
     - Verify environment variables are set correctly
     - Check for context values that might be missing or incorrect
     - Ensure AWS account and region are correctly specified
     - Try using `cdk context --clear` to reset cached context values
     - Check for environment-specific configurations that might conflict
     - Verify that context providers can access required AWS services
     - Look for hardcoded values that should be context-dependent
     - Check for missing environment information in the CDK app
     - Verify AWS credentials match the target environment

8. **Stack dependency issues:**
   - **Issue**: Problems with dependencies between stacks.
   - **Solutions**:
     - Check for circular dependencies between stacks
     - Verify that references between stacks use proper cross-stack references
     - Ensure dependent stacks are deployed in the correct order
     - Check for output values that might be missing or incorrect
     - Verify that stack dependencies are explicitly defined
     - Look for resource references that cross stack boundaries incorrectly
     - Try deploying stacks individually to identify dependency issues
     - Check for naming conflicts between exported values
     - Verify that all required exports are available
     - Consider using the `--exclusively` flag to test individual stacks

### Debugging Commands

```bash
# Enable CDK debug logging
export CDK_DEBUG=true

# View CloudFormation events for a stack
aws cloudformation describe-stack-events --stack-name dev-ServiceStack

# Check CDK metadata
cdk metadata

# Validate the CDK app
cdk doctor

# List all stacks in the app
cdk ls

# Synthesize without deploying to check for issues
cdk synth

# Show differences between deployed stacks and current code
cdk diff

# Deploy with verbose logging
cdk deploy --verbose --all

# Check context values
cdk context --list

# Clear cached context values
cdk context --clear

# Check bootstrap status
cdk bootstrap --show-template

# List resources in a deployed stack
aws cloudformation list-stack-resources --stack-name dev-NetworkStack

# Check for specific resource in a stack
aws cloudformation describe-stack-resource --stack-name dev-ServiceStack --logical-resource-id ALB

# View the actual CloudFormation template generated
cat cdk.out/dev-ServiceStack.template.json | jq

# Check TypeScript compilation
npm run build -- --verbose

# Verify CDK and dependency versions
npm list @aws-cdk/core aws-cdk
```

### Log Analysis Guide

When troubleshooting CDK issues, analyzing logs and generated artifacts is essential:

1. **CDK Synthesis Logs**:
   - Enable verbose logging with `CDK_DEBUG=true`
   - Look for warnings about deprecated constructs or APIs
   - Check for missing or invalid property errors
   - Identify construct initialization issues
   - Look for context value resolution problems
   - Common patterns:
     - `Error: No credential providers` - Authentication issues
     - `Missing required property` - Construct configuration errors
     - `is not a construct` - Incorrect object passed as scope
     - `Maximum call stack size exceeded` - Circular dependencies

2. **Generated CloudFormation Templates**:
   - Examine the templates in the `cdk.out` directory
   - Check for resource properties that might be invalid
   - Look for missing or incorrect dependencies
   - Verify that references are correctly resolved
   - Check for resource limits that might be exceeded
   - Verify that parameter values are correctly passed

3. **CloudFormation Deployment Logs**:
   - Check stack events for specific resource failures
   - Look for permission errors during resource creation
   - Identify service quota issues
   - Check for resource property validation errors
   - Look for timing and dependency issues

4. **TypeScript Compilation Errors**:
   - Check for type mismatches in construct properties
   - Look for missing imports or undefined references
   - Verify that all required properties are provided
   - Check for incorrect property names or types
   - Look for deprecated API usage

When analyzing CDK issues, consider:
- The multi-layered nature of CDK (TypeScript → CDK → CloudFormation → AWS Resources)
- The distinction between synthesis errors and deployment errors
- Context values and how they affect resource generation
- Construct hierarchy and scope inheritance
- Cross-stack references and their limitations
- Asset packaging and publishing process
- Bootstrap resources and their role in deployment

## Resources Created

This lab creates the following AWS resources:

### Networking Resources
- **VPC**: Virtual Private Cloud with custom CIDR
- **Subnets**: Public and private subnets across availability zones
- **Internet Gateway**: For public internet access
- **NAT Gateway**: For private subnet internet access
- **Route Tables**: For controlling network traffic

### Compute Resources
- **ECS Cluster**: For container orchestration
- **ECS Service**: For running the web application
- **ECS Task Definition**: For container configuration
- **Application Load Balancer**: For distributing traffic

### Monitoring Resources
- **CloudWatch Dashboard**: For application monitoring
- **CloudWatch Alarms**: For performance alerting
- **CloudWatch Log Groups**: For application logs

### CDK Resources
- **S3 Bucket**: For CDK assets and templates
- **IAM Roles**: For CDK deployment

### Estimated Costs
- VPC and Networking: $0.00/day (free)
- NAT Gateway: ~$0.045/hour (~$32/month)
- ECS (Fargate): ~$0.04/hour for specified resources
- Application Load Balancer: ~$0.0225/hour (~$16/month)
- CloudWatch: Minimal for basic monitoring
- **Total estimated cost**: ~$50-60/month (can be reduced by destroying when not in use)

## Cleanup

When you're finished with the lab, follow these steps to avoid ongoing charges:

1. **Destroy all CDK stacks:**
   ```bash
   # Destroy all stacks
   cdk destroy --all
   ```

2. **Verify resource cleanup:**
   ```bash
   # Check that stacks have been removed
   aws cloudformation list-stacks --query "StackSummaries[?contains(StackName, 'dev-')].{Name:StackName,Status:StackStatus}"
   ```
   
   - Ensure all stacks show "DELETE_COMPLETE" status
   - Check the AWS Console for any remaining resources

3. **Clean up local files:**
   ```bash
   # Remove the CDK project directory
   cd ..
   rm -rf devops-lab-cdk
   ```

> **Important**: Failure to delete resources may result in unexpected charges to your AWS account. The NAT Gateway and Application Load Balancer are the most expensive components.

## Next Steps

After completing this lab, consider:

1. **Explore CDK Patterns** for common architectural patterns
2. **Implement CDK Pipelines** for CI/CD automation
3. **Create unit tests** for your CDK constructs
4. **Explore CDK Aspects** for cross-cutting concerns
5. **Compare with other IaC tools** like CloudFormation and Terraform

## AWS DevOps Professional Certification Relevance

### Certification Domain Mapping

This lab comprehensively addresses multiple domains of the AWS Certified DevOps Engineer - Professional exam:

#### Domain 2: Configuration Management and Infrastructure as Code (19% of exam)
- **2.1 Determine deployment services based on deployment needs**
  - CDK vs CloudFormation vs Terraform comparison and selection criteria
  - High-level programming abstractions for complex infrastructure
  - AWS-native integration and service coverage
- **2.2 Determine application and infrastructure deployment models**
  - Programmatic infrastructure definition with TypeScript/Python/Java
  - Construct-based modular architecture and reusability
  - Multi-stack applications and environment management
- **2.3 Determine how to implement lifecycle hooks on a deployment**
  - Custom constructs and resource lifecycle management
  - Asset bundling and deployment automation

#### Domain 1: SDLC Automation (22% of exam)
- **1.1 Apply concepts required to automate a CI/CD pipeline**
  - CDK integration with AWS CodePipeline and CI/CD workflows
  - Infrastructure and application code co-location and versioning
  - Automated infrastructure testing with CDK testing frameworks
- **1.2 Determine source control strategies and workflows**
  - Infrastructure as Code with version control integration
  - GitOps workflows with CDK applications
- **1.4 Apply concepts required to automate security checks**
  - Security scanning integration with CDK applications
  - Policy as Code implementation with CDK aspects

#### Domain 3: Monitoring and Logging (15% of exam)
- **3.1 Determine how to set up the aggregation, storage, and analysis of logs and metrics**
  - CloudWatch integration through CDK constructs
  - Programmatic dashboard and alarm creation
- **3.2 Apply concepts required to automate monitoring and event management**
  - Event-driven architecture with CDK
  - Automated monitoring setup and configuration

#### Domain 4: Policies and Standards Automation (10% of exam)
- **4.1 Apply concepts required to enforce standards for logging, metrics, monitoring, testing, and security**
  - CDK Aspects for cross-cutting concerns and policy enforcement
  - Standardized infrastructure patterns through construct libraries
  - Compliance automation and governance
- **4.2 Determine how to optimize cost through automation**
  - Resource optimization through programmatic logic
  - Cost-aware infrastructure patterns and automation

#### Domain 6: High Availability, Fault Tolerance, and Disaster Recovery (14% of exam)
- **6.1 Determine appropriate use of multi-AZ versus multi-region architectures**
  - Multi-region deployment strategies with CDK
  - Cross-region resource management and replication
- **6.2 Determine how to implement high availability, scalability, and fault tolerance**
  - High-level constructs for resilient architecture patterns
  - Automated scaling and recovery mechanisms

### Key Exam Concepts Covered

**CDK Core Concepts:**
- **Constructs**: Reusable infrastructure components at different abstraction levels
- **Stacks**: Deployment units that map to CloudFormation stacks
- **Apps**: Top-level CDK applications containing multiple stacks
- **Synthesis**: Process of generating CloudFormation templates from CDK code
- **Bootstrap**: CDK deployment infrastructure setup

**CDK Architecture Patterns:**
- **L1 Constructs (CFN Resources)**: Direct CloudFormation resource mappings
- **L2 Constructs (AWS Constructs)**: Higher-level AWS service abstractions
- **L3 Constructs (Patterns)**: Opinionated architectural patterns
- **Custom Constructs**: Organization-specific reusable components

**Advanced CDK Features:**
- **Aspects**: Cross-cutting concerns and policy enforcement
- **Context**: Environment-specific configuration and feature flags
- **Assets**: Code and file bundling for Lambda functions and containers
- **Pipelines**: Self-mutating CI/CD pipelines with CDK
- **Testing**: Unit and integration testing for infrastructure code

**Troubleshooting Scenarios (High-Frequency Exam Topics):**
- Bootstrap failures → AWS permissions and environment setup
- Synthesis errors → TypeScript compilation and construct configuration
- Deployment failures → CloudFormation stack issues and resource constraints
- Asset publishing → S3 permissions and network connectivity
- Version compatibility → CDK and construct library version alignment

### Exam Tips and Best Practices

**Remember for the Exam:**
1. **Abstraction Levels**: Understand L1, L2, and L3 construct differences
2. **Synthesis Process**: CDK generates CloudFormation templates
3. **Bootstrap Requirements**: CDK needs bootstrap resources for deployment
4. **Programming Benefits**: Logic, loops, and conditions in infrastructure code
5. **AWS Integration**: Native AWS service support and best practices

**Common Exam Scenarios:**
- Choosing between CDK, CloudFormation, and Terraform for specific use cases
- Implementing complex infrastructure logic with programming constructs
- Creating reusable infrastructure components and patterns
- Integrating CDK with CI/CD pipelines and automation workflows
- Troubleshooting CDK deployment and synthesis issues

**Advanced Topics for Professional Level:**
- **CDK Pipelines**: Self-updating CI/CD infrastructure
- **Construct Hub**: Publishing and consuming community constructs
- **CDK for Terraform (CDKTF)**: Multi-cloud infrastructure with CDK
- **CDK for Kubernetes (CDK8s)**: Kubernetes resource management
- **Custom Resource Providers**: Extending CDK with custom logic
- **Testing Strategies**: Unit, integration, and snapshot testing

**CDK vs Other IaC Tools:**
- **vs CloudFormation**: Higher abstraction, programming languages, better defaults
- **vs Terraform**: AWS-focused vs multi-cloud, different state management
- **vs Pulumi**: Similar concept, different ecosystem and language support
- **vs SAM**: Application-focused vs general infrastructure

**Performance and Optimization:**
- **Synthesis Performance**: Large applications and optimization strategies
- **Deployment Speed**: Stack organization and dependency management
- **Asset Optimization**: Bundle size and deployment efficiency
- **Cost Optimization**: Resource right-sizing and lifecycle management
- **Security**: Least-privilege IAM and security best practices

**Development Workflow:**
- **Local Development**: CDK CLI commands and development workflow
- **Testing**: Unit tests, integration tests, and snapshot testing
- **CI/CD Integration**: Automated testing and deployment pipelines
- **Version Management**: CDK and construct library versioning strategies
- **Debugging**: Common issues and troubleshooting techniques

**Enterprise Considerations:**
- **Governance**: Policy enforcement through aspects and custom constructs
- **Standardization**: Organization-wide construct libraries and patterns
- **Multi-Account**: Cross-account deployment and resource sharing
- **Compliance**: Automated compliance checking and reporting
- **Cost Management**: Resource optimization and cost allocation

## Additional Resources

### AWS Official Documentation
- [AWS CDK Developer Guide](https://docs.aws.amazon.com/cdk/v2/guide/home.html) - Complete guide to CDK concepts and usage
- [CDK Best Practices](https://docs.aws.amazon.com/cdk/v2/guide/best-practices.html) - Guidelines for developing and deploying with CDK
- [Introduction to CDK Stacks](https://docs.aws.amazon.com/cdk/v2/guide/stacks.html) - Understanding CDK stack organization
- [CDK Apps](https://docs.aws.amazon.com/cdk/v2/guide/apps.html) - CDK application structure and lifecycle
- [Working with CDK Library](https://docs.aws.amazon.com/cdk/v2/guide/work-with.html) - Using CDK constructs and libraries
- [CDK Resources](https://docs.aws.amazon.com/cdk/v2/guide/resources.html) - Understanding CDK resources and CloudFormation mapping

### CDK API References and Tools
- [CDK API Reference](https://docs.aws.amazon.com/cdk/api/v2/) - Complete API documentation for all CDK constructs
- [CDK Tools Integration](https://docs.aws.amazon.com/cdk/v2/guide/tools.html) - Using CDK with other development tools
- [AWS Toolkit for VS Code CDK](https://docs.aws.amazon.com/toolkit-for-vscode/latest/userguide/aws-cdk-apps.html) - IDE integration for CDK development

### Advanced CDK Concepts
- [CDK Constructs](https://docs.aws.amazon.com/cdk/v2/guide/constructs.html) - Building reusable infrastructure components
- [CDK Aspects](https://docs.aws.amazon.com/cdk/v2/guide/aspects.html) - Cross-cutting concerns and validation
- [CDK Context](https://docs.aws.amazon.com/cdk/v2/guide/context.html) - Environment-specific configuration
- [CDK Assets](https://docs.aws.amazon.com/cdk/v2/guide/assets.html) - Managing code and file assets
- [CDK Bootstrapping](https://docs.aws.amazon.com/cdk/v2/guide/bootstrapping.html) - Setting up CDK deployment infrastructure

### Testing and Validation
- [CDK Testing](https://docs.aws.amazon.com/cdk/v2/guide/testing.html) - Unit and integration testing for CDK applications
- [CDK Assertions](https://docs.aws.amazon.com/cdk/v2/guide/testing.html#testing_assertions) - Testing framework for CDK constructs
- [CDK Validation](https://docs.aws.amazon.com/cdk/v2/guide/aspects.html#aspects_validation) - Validating infrastructure configurations

### DevOps and CI/CD Integration
- [Introduction to DevOps on AWS - CDK](https://docs.aws.amazon.com/whitepapers/latest/introduction-devops-aws/aws-cdk.html) - CDK in DevOps workflows
- [CI/CD Best Practices](https://docs.aws.amazon.com/prescriptive-guidance/latest/strategy-cicd-litmus/cicd-best-practices.html) - AWS Prescriptive Guidance for CI/CD pipelines
- [CDK Pipelines](https://docs.aws.amazon.com/cdk/v2/guide/cdk_pipeline.html) - Self-mutating CI/CD pipelines with CDK

### Migration and Comparison
- [Migrating to CDK v2](https://docs.aws.amazon.com/cdk/v2/guide/migrating-v2.html) - Upgrading from CDK v1 to v2
- [CDK vs CloudFormation](https://docs.aws.amazon.com/cdk/v2/guide/home.html#why_use_cdk) - When to use CDK vs native CloudFormation
- [Infrastructure as Code Comparison](https://aws.amazon.com/architecture/infrastructure-as-code/) - CDK vs other IaC tools

### Community Resources and Learning
- [AWS CDK Examples](https://github.com/aws-samples/aws-cdk-examples) - Official CDK example repository
- [CDK Workshop](https://cdkworkshop.com/) - Interactive CDK learning experience
- [CDK Patterns](https://cdkpatterns.com/) - Common CDK architecture patterns
- [Construct Hub](https://constructs.dev/) - Community-contributed CDK constructs
- [AWS CDK Community](https://github.com/aws/aws-cdk/discussions) - Community discussions and support

### Advanced Topics and Integrations
- [CDK for Kubernetes (CDK8s)](https://cdk8s.io/) - Define Kubernetes applications with CDK
- [CDK for Terraform (CDKTF)](https://developer.hashicorp.com/terraform/cdktf) - Use CDK with Terraform providers
- [Projen](https://projen.io/) - Project scaffolding and management for CDK projects
- [AWS Solutions Constructs](https://docs.aws.amazon.com/solutions/latest/constructs/welcome.html) - Pre-architected patterns and constructs

### Video Tutorials and Courses
- [Video Tutorial: AWS CDK Complete Course](https://www.youtube.com/watch?v=T-H4nJQyMig) - Comprehensive CDK walkthrough
- [AWS CDK Crash Course](https://www.youtube.com/watch?v=D4Asp5g4fp8) - Quick introduction to CDK concepts
- [AWS re:Invent CDK Sessions](https://www.youtube.com/results?search_query=aws+reinvent+cdk) - Latest CDK features and best practices

### Supplementary Learning Resources

#### Blog Posts and Articles
- [AWS DevOps Blog: CDK Best Practices](https://aws.amazon.com/blogs/devops/best-practices-for-developing-cloud-applications-with-aws-cdk/) - Official CDK best practices
- [AWS Architecture Blog: CDK Patterns](https://aws.amazon.com/blogs/architecture/field-notes-working-with-aws-cloudformation-and-aws-cloud-development-kit-cdk/) - Architecture patterns with CDK
- [Medium: Advanced CDK Techniques](https://medium.com/aws-in-plain-english/aws-cdk-best-practices-9b5b75b9c1b4) - Community best practices
- [Dev.to: CDK vs CloudFormation](https://dev.to/aws-builders/aws-cdk-vs-cloudformation-which-one-to-choose-2kn9) - Tool comparison and selection

#### Video Tutorials and Webinars
- [AWS Online Tech Talks: CDK](https://www.youtube.com/results?search_query=aws+online+tech+talks+cdk) - Expert insights and patterns
- [A Cloud Guru: AWS CDK Deep Dive](https://acloudguru.com/course/aws-cdk-deep-dive) - Comprehensive CDK training
- [Pluralsight: Infrastructure as Code with CDK](https://www.pluralsight.com/courses/aws-cdk-infrastructure-code) - Platform-specific training
- [FreeCodeCamp: CDK Tutorial](https://www.youtube.com/watch?v=T-H4nJQyMig) - Free comprehensive CDK course

#### Whitepapers and Technical Guides
- [AWS Whitepaper: Infrastructure as Code](https://docs.aws.amazon.com/whitepapers/latest/introduction-devops-aws/infrastructure-as-code.html) - IaC principles with AWS tools
- [AWS Whitepaper: Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html) - Architecture best practices
- [AWS Whitepaper: Serverless Application Lens](https://docs.aws.amazon.com/wellarchitected/latest/serverless-applications-lens/welcome.html) - Serverless architecture with CDK
- [CNCF Whitepaper: Cloud Native Infrastructure](https://www.cncf.io/reports/cloud-native-infrastructure-whitepaper/) - Modern infrastructure approaches

#### Third-Party Resources
- [CDK8s: Kubernetes with CDK](https://cdk8s.io/) - Kubernetes resource management
- [CDKTF: Terraform with CDK](https://developer.hashicorp.com/terraform/cdktf) - Multi-cloud CDK approach
- [Projen: CDK Project Management](https://projen.io/) - Advanced project scaffolding
- [AWS Solutions Constructs](https://aws.amazon.com/solutions/constructs/) - Pre-built architecture patterns

#### Industry Best Practices
- [Google Cloud: Infrastructure as Code](https://cloud.google.com/docs/terraform/best-practices-for-terraform) - Multi-cloud IaC patterns
- [Microsoft Azure: ARM vs CDK](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/) - Cross-cloud infrastructure comparison
- [Pulumi vs CDK Comparison](https://www.pulumi.com/docs/intro/vs/cloud_template_transpilers/) - Modern IaC tool comparison
- [CNCF Landscape: Infrastructure Tools](https://landscape.cncf.io/category=provisioning&format=card-mode&grouping=category) - Cloud-native infrastructure ecosystem

#### Books and Extended Learning
- [AWS CDK in Action](https://www.manning.com/books/aws-cdk-in-action) - Comprehensive CDK book
- [Cloud Native DevOps with Kubernetes](https://www.oreilly.com/library/view/cloud-native-devops/9781492040750/) - Modern DevOps practices
- [Infrastructure as Code: Managing Servers in the Cloud](https://www.oreilly.com/library/view/infrastructure-as-code/9781491924334/) - IaC principles and practices
- [Building Microservices](https://www.oreilly.com/library/view/building-microservices/9781491950340/) - Microservices architecture patterns### Ad
ditional Troubleshooting Tips for AWS CDK

#### Common CDK Error Messages and Solutions

1. **"Error: Cannot find module"**
   - **Solution**: Run `npm install` to install dependencies, or check that the module is listed in `package.json`.

2. **"Error: No stack defined"**
   - **Solution**: Ensure you've defined at least one stack in your CDK app and that it's properly instantiated.

3. **"Error: Asset not found"**
   - **Solution**: Check that asset files exist and are accessible, and verify that the CDK bootstrap environment is properly set up.

4. **"Error: SSM Parameter not found"**
   - **Solution**: Verify that the SSM parameter exists in the target account and region, or use `usePreviousValue` if appropriate.

5. **"Error: Maximum call stack size exceeded"**
   - **Solution**: Check for circular dependencies between constructs or stacks.

#### Analyzing CDK Logs

When analyzing CDK logs for troubleshooting:

1. **Enable CDK debugging**: Set `CDK_DEBUG=true` to get more detailed logs.

2. **Check synthesis errors**: Look for errors during the synthesis phase before deployment.

3. **Examine CloudFormation errors**: Since CDK generates CloudFormation templates, check CloudFormation events for deployment errors.

4. **Review asset bundling logs**: Check for errors during asset bundling and publishing.

5. **Inspect construct initialization**: Look for errors during construct initialization and property validation.

#### Advanced Debugging Techniques

1. **Use `cdk synth`**: Generate CloudFormation templates without deploying to check for synthesis issues.

2. **Use `cdk diff`**: Compare local changes with deployed stacks to understand what will change.

3. **Use `cdk doctor`**: Check for common issues with your CDK environment.

4. **Examine generated templates**: Look at the generated CloudFormation templates in the `cdk.out` directory.

5. **Use context inspection**: Run `cdk context` to examine context values that might affect behavior.

#### CDK Best Practices to Avoid Issues

1. **Use constructs effectively**: Leverage high-level constructs for best practices and sensible defaults.

2. **Implement proper environment handling**: Explicitly specify account and region for production deployments.

3. **Use proper construct initialization**: Follow the construct initialization pattern with scope, id, and props.

4. **Implement proper tagging**: Use `Tags.of(scope).add()` for consistent tagging.

5. **Use aspects for cross-cutting concerns**: Apply aspects to modify multiple constructs at once.

6. **Implement proper testing**: Use CDK's testing framework to validate constructs.

7. **Use proper asset handling**: Understand how assets are bundled and published.

8. **Implement proper context handling**: Use context values for environment-specific configurations.

#### CDK-Specific Troubleshooting

1. **Bootstrap issues**: If bootstrap fails, check IAM permissions and try with `--force` flag.

2. **TypeScript compilation errors**: Run `npm run build` to check for TypeScript errors before deployment.

3. **Asset publishing failures**: Check S3 permissions and network connectivity.

4. **Cross-stack references**: Ensure exports are properly defined and referenced.

5. **Custom resource issues**: Check Lambda function logs for custom resource handlers.

#### Comparing Generated CloudFormation with CDK Code

When troubleshooting complex issues:

1. **Generate the template**: Run `cdk synth > template.yaml` to save the generated template.

2. **Compare with expectations**: Review the template to ensure it matches your CDK code's intent.

3. **Check for missing resources**: Verify that all expected resources are in the template.

4. **Check for unexpected configurations**: Look for resource properties that don't match expectations.

5. **Validate the template**: Use `aws cloudformation validate-template` to check for template errors.