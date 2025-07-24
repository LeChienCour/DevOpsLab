#!/bin/bash
# Script to provision the AWS Config compliance monitoring lab

set -e

# Parse command line arguments
REGION=$(aws configure get region)
STACK_NAME="ConfigComplianceLab"
BUCKET_SUFFIX=$(date +%s)
BUCKET_NAME="config-compliance-lab-${BUCKET_SUFFIX}"
EMAIL=""

print_usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -r, --region REGION    AWS region (default: from AWS CLI config)"
    echo "  -s, --stack-name NAME  CloudFormation stack name (default: ConfigComplianceLab)"
    echo "  -b, --bucket NAME      S3 bucket name (default: config-compliance-lab-timestamp)"
    echo "  -e, --email EMAIL      Email address for notifications (required)"
    echo "  -h, --help             Display this help message"
}

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -r|--region)
            REGION="$2"
            shift
            shift
            ;;
        -s|--stack-name)
            STACK_NAME="$2"
            shift
            shift
            ;;
        -b|--bucket)
            BUCKET_NAME="$2"
            shift
            shift
            ;;
        -e|--email)
            EMAIL="$2"
            shift
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$EMAIL" ]; then
    echo "Error: Email address is required"
    print_usage
    exit 1
fi

echo "Provisioning AWS Config compliance monitoring lab..."
echo "Region: $REGION"
echo "Stack Name: $STACK_NAME"
echo "Bucket Name: $BUCKET_NAME"
echo "Email: $EMAIL"

# Create S3 bucket for Config delivery
echo "Creating S3 bucket for Config delivery..."
aws s3 mb s3://$BUCKET_NAME --region $REGION

# Create bucket policy for AWS Config
echo "Creating bucket policy for AWS Config..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

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

# Create SNS topic for Config notifications
echo "Creating SNS topic for Config notifications..."
SNS_TOPIC_ARN=$(aws sns create-topic --name ConfigComplianceNotifications --output text)
echo "SNS Topic ARN: $SNS_TOPIC_ARN"

# Subscribe to SNS topic
echo "Subscribing to SNS topic..."
aws sns subscribe \
  --topic-arn $SNS_TOPIC_ARN \
  --protocol email \
  --notification-endpoint $EMAIL

echo "Please check your email to confirm the subscription"

# Deploy CloudFormation stacks
echo "Deploying CloudFormation stacks..."

# Deploy AWS Config setup stack
echo "Deploying AWS Config setup..."
aws cloudformation deploy \
  --template-file ../templates/config-setup.yaml \
  --stack-name ${STACK_NAME}-Setup \
  --parameter-overrides \
    ConfigBucketName=$BUCKET_NAME \
    SNSTopicARN=$SNS_TOPIC_ARN \
  --capabilities CAPABILITY_NAMED_IAM

# Deploy managed Config rules
echo "Deploying managed Config rules..."
aws cloudformation deploy \
  --template-file ../templates/managed-config-rules.yaml \
  --stack-name ${STACK_NAME}-ManagedRules \
  --parameter-overrides \
    SNSTopicARN=$SNS_TOPIC_ARN \
  --capabilities CAPABILITY_IAM

# Deploy custom Config rules
echo "Deploying custom Config rules..."
aws cloudformation deploy \
  --template-file ../templates/custom-config-rules.yaml \
  --stack-name ${STACK_NAME}-CustomRules \
  --parameter-overrides \
    SNSTopicARN=$SNS_TOPIC_ARN \
    ApprovedInstanceTypes="t2.micro,t3.micro,t3.small,t4g.micro,t4g.small" \
  --capabilities CAPABILITY_IAM

# Deploy remediation workflows
echo "Deploying remediation workflows..."
aws cloudformation deploy \
  --template-file ../templates/remediation-workflows.yaml \
  --stack-name ${STACK_NAME}-Remediation \
  --parameter-overrides \
    SNSTopicARN=$SNS_TOPIC_ARN \
  --capabilities CAPABILITY_NAMED_IAM

# Deploy enhanced compliance dashboard
echo "Deploying enhanced compliance dashboard..."
aws cloudformation deploy \
  --template-file ../templates/enhanced-compliance-dashboard.yaml \
  --stack-name ${STACK_NAME}-Dashboard \
  --parameter-overrides \
    ConfigBucketName=$BUCKET_NAME \
  --capabilities CAPABILITY_IAM

# Create directory for compliance history
aws s3api put-object --bucket $BUCKET_NAME --key compliance-history/

echo "AWS Config compliance monitoring lab provisioned successfully!"
echo "Dashboard URL: https://$REGION.console.aws.amazon.com/cloudwatch/home?region=$REGION#dashboards:name=AWS-Config-Compliance-Dashboard"
echo "Config Rules URL: https://$REGION.console.aws.amazon.com/config/home?region=$REGION#/rules"

# Cleanup temporary files
rm -f config-bucket-policy.json

echo "Please wait a few minutes for AWS Config to evaluate your resources"
echo "You can then run the following command to generate a compliance report:"
echo "python3 generate-compliance-report.py --bucket $BUCKET_NAME --key compliance-reports/report.html"