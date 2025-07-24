# AWS Config Compliance Monitoring Lab Guide

## Objective
Learn to implement compliance monitoring and automated remediation using AWS Config. This lab demonstrates how to track resource configurations, evaluate compliance against rules, and automatically remediate non-compliant resources to maintain security and governance standards.

## Learning Outcomes
By completing this lab, you will:
- Set up AWS Config to track resource configuration changes
- Create and deploy AWS Config rules for compliance monitoring
- Implement automated remediation actions for non-compliant resources
- Analyze configuration history and compliance trends
- Set up notifications for configuration changes and compliance violations
- Create custom Config rules using Lambda functions
- Build comprehensive compliance reporting and trend analysis dashboards

## Prerequisites
- AWS Account with administrative access
- AWS CLI configured with appropriate credentials
- Basic understanding of AWS security and compliance concepts
- Familiarity with IAM policies and roles
- Understanding of S3 bucket policies and encryption
- Basic Python knowledge for custom scripts

### Required AWS Permissions
Your AWS user/role needs the following permissions:
- Config: Full access for configuration recording and rules
- S3: Create and manage buckets for Config delivery
- IAM: Create roles and policies for Config service
- SNS: Create topics for notifications
- Lambda: Create functions for custom Config rules
- Systems Manager: Access for automated remediation
- CloudWatch: Create and manage dashboards
- CloudFormation: Deploy templates for infrastructure

### Time to Complete
Approximately 60-75 minutes

## Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   AWS Resources │───▶│   AWS Config     │───▶│   S3 Bucket     │
│   (EC2, S3,     │    │   Configuration  │    │   (Config       │
│    Security     │    │   Recorder       │    │    History)     │
│    Groups, etc.)│    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                       │
                                ▼                       │
                       ┌──────────────────┐            │
                       │   Config Rules   │            │
                       │   (Managed &     │            │
                       │    Custom)       │            │
                       └──────────────────┘            │
                                │                      │
                                ▼                      │
                       ┌──────────────────┐            │
                       │   Compliance     │            │
                       │   Evaluation     │            │
                       └──────────────────┘            │
                                │                      │
           ┌───────────────────┬┴──────────────┐      │
           ▼                   ▼               ▼      │
┌─────────────────┐  ┌──────────────────┐  ┌───────────────┐
│   SNS Topic     │  │   Remediation    │  │  CloudWatch   │◀─┐
│   (Notifications│  │   Actions        │  │  Metrics      │  │
│   & Alerts)     │  │   (Auto-fix)     │  │              │  │
└─────────────────┘  └──────────────────┘  └───────────────┘  │
                                                   │          │
                                                   ▼          │
                                          ┌───────────────┐   │
                                          │  Compliance   │   │
                                          │  Dashboard    │   │
                                          └───────────────┘   │
                                                   │          │
                                                   ▼          │
                                          ┌───────────────┐   │
                                          │  Trend        │───┘
                                          │  Analysis     │
                                          └───────────────┘
```

### Resources Created:
- **AWS Config Configuration Recorder**: Tracks resource configurations
- **AWS Config Delivery Channel**: Delivers configuration data to S3
- **S3 Bucket**: Stores configuration history and snapshots
- **Config Rules (Managed)**: Pre-built rules for common compliance checks
- **Config Rules (Custom)**: Lambda-based rules for specialized compliance checks
- **SNS Topic**: Notifications for compliance violations
- **IAM Roles**: Service roles for Config and remediation actions
- **Lambda Functions**: Custom Config rules and compliance metrics collection
- **SSM Documents**: Automated remediation actions
- **CloudWatch Dashboard**: Compliance reporting and trend analysis
- **CloudWatch Metrics**: Compliance status metrics for monitoring
- **Trend Analysis Reports**: Historical compliance data visualization

## Lab Steps

### Step 1: Set Up AWS Config Service

You can set up AWS Config service using either the automated script or manual steps.

#### Option 1: Use the automated provisioning script

```bash
# Make the script executable
chmod +x ./scripts/provision-config-lab.sh

# Run the script with your email for notifications
./scripts/provision-config-lab.sh --email your-email@example.com
```

#### Option 2: Set up AWS Config manually

1. **Create S3 bucket for Config delivery:**
   ```bash
   # Create unique bucket name
   BUCKET_NAME="aws-config-bucket-$(date +%s)-$(whoami)"
   ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
   REGION=$(aws configure get region)
   
   aws s3 mb s3://$BUCKET_NAME --region $REGION
   echo "Created bucket: $BUCKET_NAME"
   ```

2. **Create bucket policy for AWS Config:**
   ```bash
   cat > config-bucket-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AWSConfigBucketPermissionsCheck",
            "Effect": "Allow",
            "Principal": {
                "Service": "config.amazonaws.com"
            },
            "Action": "s3:GetBucketAcl",
            "Resource": "arn:aws:s3:::$BUCKET_NAME",
            "Condition": {
                "StringEquals": {
                    "AWS:SourceAccount": "$ACCOUNT_ID"
                }
            }
        },
        {
            "Sid": "AWSConfigBucketExistenceCheck",
            "Effect": "Allow",
            "Principal": {
                "Service": "config.amazonaws.com"
            },
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::$BUCKET_NAME",
            "Condition": {
                "StringEquals": {
                    "AWS:SourceAccount": "$ACCOUNT_ID"
                }
            }
        },
        {
            "Sid": "AWSConfigBucketDelivery",
            "Effect": "Allow",
            "Principal": {
                "Service": "config.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::$BUCKET_NAME/AWSLogs/$ACCOUNT_ID/Config/*",
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control",
                    "AWS:SourceAccount": "$ACCOUNT_ID"
                }
            }
        }
    ]
}
EOF

   aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy file://config-bucket-policy.json
   ```

3. **Deploy AWS Config setup using CloudFormation:**
   ```bash
   # Create SNS topic for Config notifications
   SNS_TOPIC_ARN=$(aws sns create-topic --name ConfigComplianceNotifications --output text)
   echo "Created SNS topic: $SNS_TOPIC_ARN"
   
   # Subscribe to SNS topic (replace with your email)
   aws sns subscribe \
     --topic-arn $SNS_TOPIC_ARN \
     --protocol email \
     --notification-endpoint your-email@example.com
   
   echo "Please check your email to confirm the subscription"
   
   # Deploy AWS Config setup
   aws cloudformation deploy \
     --template-file ./templates/config-setup.yaml \
     --stack-name ConfigSetup \
     --parameter-overrides \
       ConfigBucketName=$BUCKET_NAME \
       SNSTopicARN=$SNS_TOPIC_ARN \
     --capabilities CAPABILITY_NAMED_IAM
   ```

### Step 2: Create and Deploy AWS Config Rules

#### Option 1: Deploy managed Config rules using CloudFormation

```bash
aws cloudformation deploy \
  --template-file ./templates/managed-config-rules.yaml \
  --stack-name ManagedConfigRules \
  --parameter-overrides \
    SNSTopicARN=$SNS_TOPIC_ARN \
  --capabilities CAPABILITY_IAM
```

#### Option 2: Deploy custom Config rules using CloudFormation

```bash
aws cloudformation deploy \
  --template-file ./templates/custom-config-rules.yaml \
  --stack-name CustomConfigRules \
  --parameter-overrides \
    SNSTopicARN=$SNS_TOPIC_ARN \
    ApprovedInstanceTypes="t2.micro,t3.micro,t3.small,t4g.micro,t4g.small" \
  --capabilities CAPABILITY_IAM
```

### Step 3: Implement Automated Remediation Workflows

```bash
aws cloudformation deploy \
  --template-file ./templates/remediation-workflows.yaml \
  --stack-name ConfigRemediation \
  --parameter-overrides \
    SNSTopicARN=$SNS_TOPIC_ARN \
  --capabilities CAPABILITY_NAMED_IAM
```

### Step 4: Create Enhanced Compliance Dashboard with Trend Analysis

```bash
aws cloudformation deploy \
  --template-file ./templates/enhanced-compliance-dashboard.yaml \
  --stack-name ConfigComplianceDashboard \
  --parameter-overrides \
    ConfigBucketName=$BUCKET_NAME \
  --capabilities CAPABILITY_IAM
```

### Step 5: Test Compliance Rules and Remediation

1. **Create non-compliant resources:**

   a. **Create non-compliant S3 bucket (no encryption):**
   ```bash
   aws s3 mb s3://non-compliant-bucket-$(date +%s)
   ```

   b. **Create non-compliant security group (open SSH):**
   ```bash
   aws ec2 create-security-group \
     --group-name non-compliant-sg \
     --description "Non-compliant security group with open SSH"
   
   SG_ID=$(aws ec2 describe-security-groups \
     --group-names non-compliant-sg \
     --query 'SecurityGroups[0].GroupId' \
     --output text)
   
   aws ec2 authorize-security-group-ingress \
     --group-id $SG_ID \
     --protocol tcp \
     --port 22 \
     --cidr 0.0.0.0/0
   ```

   c. **Create EC2 instance with non-approved instance type (if available in your account):**
   ```bash
   # This requires an existing VPC and subnet
   # Replace subnet-id with your subnet ID
   aws ec2 run-instances \
     --image-id ami-0c55b159cbfafe1f0 \
     --instance-type m5.large \
     --subnet-id subnet-12345678 \
     --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=non-compliant-instance}]'
   ```

2. **Wait for Config evaluation (or trigger manually):**
   ```bash
   aws configservice start-config-rules-evaluation \
     --config-rule-names s3-bucket-server-side-encryption-enabled restricted-ssh ec2-approved-instance-types
   ```

3. **Check compliance status:**
   ```bash
   aws configservice describe-compliance-by-config-rule \
     --config-rule-names s3-bucket-server-side-encryption-enabled restricted-ssh ec2-approved-instance-types
   ```

4. **Generate compliance report:**
   ```bash
   python3 ./scripts/generate-compliance-report.py --bucket $BUCKET_NAME --output compliance-report.html
   ```

5. **Trigger automated remediation:**
   ```bash
   # For S3 bucket encryption (automatic remediation)
   # The remediation should happen automatically, but you can also trigger it manually:
   
   # Get the resource ID of the non-compliant bucket
   BUCKET_ID=$(aws configservice get-compliance-details-by-config-rule \
     --config-rule-name s3-bucket-server-side-encryption-enabled \
     --compliance-types NON_COMPLIANT \
     --query 'EvaluationResults[0].EvaluationResultIdentifier.EvaluationResultQualifier.ResourceId' \
     --output text)
   
   # Execute remediation
   aws configservice start-remediation-execution \
     --config-rule-name s3-bucket-server-side-encryption-enabled \
     --resource-keys resourceId=$BUCKET_ID,resourceType=AWS::S3::Bucket
   
   # For S3 public access block (automatic remediation)
   aws configservice start-remediation-execution \
     --config-rule-name s3-public-access-blocked \
     --resource-keys resourceId=$BUCKET_ID,resourceType=AWS::S3::Bucket
   ```

6. **Use the remediation script for bulk remediation:**
   ```bash
   python3 ./scripts/remediate-compliance-violations.py --dry-run
   
   # If the dry run looks good, run the actual remediation
   python3 ./scripts/remediate-compliance-violations.py --interactive
   ```

7. **Verify remediation:**
   ```bash
   # Check S3 bucket encryption
   aws s3api get-bucket-encryption --bucket $BUCKET_ID
   
   # Check S3 bucket public access block
   aws s3api get-public-access-block --bucket $BUCKET_ID
   ```

### Step 6: Analyze Compliance Trends

1. **Access the CloudWatch dashboard:**
   ```bash
   echo "Dashboard URL: https://$REGION.console.aws.amazon.com/cloudwatch/home?region=$REGION#dashboards:name=AWS-Config-Compliance-Dashboard"
   ```

2. **View the trend analysis report:**
   ```bash
   echo "Trend Report URL: https://s3.console.aws.amazon.com/s3/object/$BUCKET_NAME/compliance-history/trend-report.html"
   ```

3. **Generate a custom compliance report:**
   ```bash
   python3 ./scripts/generate-compliance-report.py --bucket $BUCKET_NAME --key compliance-reports/custom-report.html
   
   echo "Custom Report URL: https://s3.console.aws.amazon.com/s3/object/$BUCKET_NAME/compliance-reports/custom-report.html"
   ```

## Advanced Topics

### Creating Custom Config Rules

In this lab, we've created several custom Config rules using Lambda functions:

1. **IAM User MFA Rule**: Checks if IAM users have MFA enabled
2. **S3 Public Access Block Rule**: Checks if S3 buckets have public access blocked
3. **EC2 Instance Types Rule**: Checks if EC2 instances are using approved instance types

To create your own custom rule:

1. **Create a Lambda function:**
   ```python
   # Example Lambda function for a custom rule
   import boto3
   import json
   
   def evaluate_compliance(configuration_item, rule_parameters):
       # Your compliance logic here
       return 'COMPLIANT' or 'NON_COMPLIANT'
   
   def lambda_handler(event, context):
       # Parse the invocation event
       invoking_event = json.loads(event['invokingEvent'])
       rule_parameters = json.loads(event['ruleParameters']) if 'ruleParameters' in event else {}
       
       # Get the configuration item
       configuration_item = invoking_event['configurationItem']
       
       # Evaluate compliance
       compliance_type = evaluate_compliance(configuration_item, rule_parameters)
       
       # Build the evaluation response
       evaluation = {
           'ComplianceResourceType': configuration_item['resourceType'],
           'ComplianceResourceId': configuration_item['resourceId'],
           'ComplianceType': compliance_type,
           'OrderingTimestamp': configuration_item['configurationItemCaptureTime']
       }
       
       # Submit the evaluation results
       config = boto3.client('config')
       config.put_evaluations(
           Evaluations=[evaluation],
           ResultToken=event['resultToken']
       )
   ```

2. **Create a Config rule that uses your Lambda function:**
   ```bash
   aws configservice put-config-rule --config-rule file://your-custom-rule.json
   ```

### Creating Custom Remediation Actions

To create a custom remediation action:

1. **Create an SSM document:**
   ```json
   {
     "schemaVersion": "0.3",
     "description": "Custom remediation action",
     "assumeRole": "{{AutomationAssumeRole}}",
     "parameters": {
       "AutomationAssumeRole": {
         "type": "String",
         "description": "Role to assume for remediation"
       },
       "ResourceId": {
         "type": "String",
         "description": "Resource to remediate"
       }
     },
     "mainSteps": [
       {
         "name": "RemediateResource",
         "action": "aws:executeAwsApi",
         "inputs": {
           "Service": "service-name",
           "Api": "api-name",
           "Parameters": {
             "Parameter1": "value1",
             "Parameter2": "value2"
           }
         }
       }
     ]
   }
   ```

2. **Create a remediation configuration:**
   ```bash
   aws configservice put-remediation-configuration \
     --config-rule-name your-config-rule \
     --remediation-configuration file://your-remediation-config.json
   ```

## Cleanup Instructions

You can clean up all resources using the following steps:

1. **Delete CloudFormation stacks:**
   ```bash
   aws cloudformation delete-stack --stack-name ConfigComplianceDashboard
   aws cloudformation delete-stack --stack-name ConfigRemediation
   aws cloudformation delete-stack --stack-name CustomConfigRules
   aws cloudformation delete-stack --stack-name ManagedConfigRules
   aws cloudformation delete-stack --stack-name ConfigSetup
   ```

2. **Delete non-compliant resources:**
   ```bash
   # Delete non-compliant S3 bucket
   aws s3 rm s3://$BUCKET_ID --recursive
   aws s3 rb s3://$BUCKET_ID
   
   # Delete non-compliant security group
   aws ec2 delete-security-group --group-id $SG_ID
   
   # Terminate non-compliant EC2 instance
   aws ec2 terminate-instances --instance-ids $INSTANCE_ID
   ```

3. **Delete SNS topic:**
   ```bash
   aws sns delete-topic --topic-arn $SNS_TOPIC_ARN
   ```

4. **Empty and delete Config S3 bucket:**
   ```bash
   aws s3 rm s3://$BUCKET_NAME --recursive
   aws s3 rb s3://$BUCKET_NAME
   ```

## Additional Resources

- [AWS Config Documentation](https://docs.aws.amazon.com/config/latest/developerguide/WhatIsConfig.html)
- [AWS Config Managed Rules](https://docs.aws.amazon.com/config/latest/developerguide/managed-rules-by-aws-config.html)
- [AWS Config Custom Rules](https://docs.aws.amazon.com/config/latest/developerguide/evaluate-config_develop-rules.html)
- [AWS Config Remediation](https://docs.aws.amazon.com/config/latest/developerguide/remediation.html)
- [AWS Config Conformance Packs](https://docs.aws.amazon.com/config/latest/developerguide/conformance-packs.html)
- [AWS Security Hub Integration](https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-standards-fsbp-controls.html)