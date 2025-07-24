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

## Prerequisites
- AWS Account with administrative access
- AWS CLI configured with appropriate credentials
- Basic understanding of AWS security and compliance concepts
- Familiarity with IAM policies and roles
- Understanding of S3 bucket policies and encryption

### Required AWS Permissions
Your AWS user/role needs the following permissions:
- Config: Full access for configuration recording and rules
- S3: Create and manage buckets for Config delivery
- IAM: Create roles and policies for Config service
- SNS: Create topics for notifications
- Lambda: Create functions for custom Config rules (optional)
- Systems Manager: Access for automated remediation

### Time to Complete
Approximately 50-65 minutes

## Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   AWS Resources │───▶│   AWS Config     │───▶│   S3 Bucket     │
│   (EC2, S3,     │    │   Configuration  │    │   (Config       │
│    Security     │    │   Recorder       │    │    History)     │
│    Groups, etc.)│    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌──────────────────┐    ┌─────────────────┐
                       │   Config Rules   │───▶│   SNS Topic     │
                       │   (Compliance    │    │   (Notifications│
                       │    Evaluation)   │    │   & Alerts)     │
                       └──────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │   Remediation    │
                       │   Actions        │
                       │   (Auto-fix)     │
                       └──────────────────┘
```

### Resources Created:
- **AWS Config Configuration Recorder**: Tracks resource configurations
- **AWS Config Delivery Channel**: Delivers configuration data to S3
- **S3 Bucket**: Stores configuration history and snapshots
- **Config Rules**: Evaluate resource compliance
- **SNS Topic**: Notifications for compliance violations
- **IAM Roles**: Service roles for Config and remediation actions

## Lab Steps

### Step 1: Set Up AWS Config Service

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

3. **Create IAM role for AWS Config:**
   ```bash
   cat > config-trust-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "config.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

   aws iam create-role \
     --role-name AWSConfigRole \
     --assume-role-policy-document file://config-trust-policy.json
   ```

4. **Attach AWS managed policy to Config role:**
   ```bash
   aws iam attach-role-policy \
     --role-name AWSConfigRole \
     --policy-arn arn:aws:iam::aws:policy/service-role/ConfigRole
   ```

5. **Create SNS topic for Config notifications:**
   ```bash
   SNS_TOPIC_ARN=$(aws sns create-