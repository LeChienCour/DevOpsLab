# IAM Best Practices Lab Guide

## Objective
Learn to implement IAM best practices including least-privilege policies, role-based access control, and security monitoring. This lab will guide you through creating secure IAM policies, implementing cross-account access, and setting up IAM monitoring and alerting.

## Learning Outcomes
By completing this lab, you will:
- Create least-privilege IAM policies using the principle of least privilege
- Implement role-based access control for different user types
- Set up cross-account IAM roles for secure resource sharing
- Configure IAM monitoring and alerting for security events
- Understand IAM policy evaluation logic and troubleshooting

## Prerequisites
- AWS Account with administrative access
- AWS CLI configured with appropriate permissions
- Basic understanding of JSON syntax
- Familiarity with AWS services (EC2, S3, Lambda)

### Required AWS Permissions
Your AWS user/role needs the following permissions:
- **IAM**: Full access for creating users, roles, and policies
- **CloudTrail**: Read access for monitoring IAM events
- **CloudWatch**: Full access for creating alarms and monitoring
- **S3**: Full access for creating test buckets
- **EC2**: Read access for testing permissions

### Time to Complete
Approximately 45-60 minutes

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    IAM Security Architecture                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │   Dev User  │    │  Ops User   │    │ Audit User  │     │
│  │             │    │             │    │             │     │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘     │
│         │                  │                  │            │
│         ▼                  ▼                  ▼            │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │  Dev Role   │    │  Ops Role   │    │ Audit Role  │     │
│  │ (Limited)   │    │ (Elevated)  │    │(Read-Only)  │     │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘     │
│         │                  │                  │            │
│         └──────────────────┼──────────────────┘            │
│                            ▼                               │
│                 ┌─────────────────────┐                    │
│                 │   AWS Resources     │                    │
│                 │  (S3, EC2, Lambda)  │                    │
│                 └─────────────────────┘                    │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Monitoring & Alerting                  │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │   │
│  │  │ CloudTrail  │  │ CloudWatch  │  │    SNS      │ │   │
│  │  │   Logs      │  │   Alarms    │  │   Alerts    │ │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘ │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Resources Created:
- **IAM Users**: Test users for different roles (dev, ops, audit)
- **IAM Roles**: Role-based access control roles
- **IAM Policies**: Custom least-privilege policies
- **S3 Bucket**: Test bucket for permission validation
- **CloudWatch Alarms**: IAM security monitoring
- **SNS Topic**: Alert notifications for security events

## Lab Steps

### Step 1: Create Test S3 Bucket for Permission Testing

1. **Create a test S3 bucket:**
   ```bash
   # Create a unique bucket name with your account ID
   ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
   BUCKET_NAME="iam-lab-test-bucket-${ACCOUNT_ID}"
   aws s3 mb s3://${BUCKET_NAME}
   ```

2. **Upload a test file:**
   ```bash
   echo "This is a test file for IAM permissions" > test-file.txt
   aws s3 cp test-file.txt s3://${BUCKET_NAME}/
   ```

3. **Verify bucket creation:**
   ```bash
   aws s3 ls s3://${BUCKET_NAME}
   ```
   
   Expected output:
   ```
   2024-01-XX XX:XX:XX         42 test-file.txt
   ```

### Step 2: Create Least-Privilege IAM Policies

1. **Create a developer policy with limited S3 access:**
   ```bash
   cat > dev-policy.json << 'EOF'
   {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Effect": "Allow",
               "Action": [
                   "s3:GetObject",
                   "s3:PutObject",
                   "s3:DeleteObject"
               ],
               "Resource": "arn:aws:s3:::iam-lab-test-bucket-*/*"
           },
           {
               "Effect": "Allow",
               "Action": [
                   "s3:ListBucket"
               ],
               "Resource": "arn:aws:s3:::iam-lab-test-bucket-*"
           },
           {
               "Effect": "Allow",
               "Action": [
                   "ec2:DescribeInstances",
                   "ec2:DescribeImages"
               ],
               "Resource": "*"
           }
       ]
   }
   EOF
   
   aws iam create-policy \
       --policy-name DevLimitedAccessPolicy \
       --policy-document file://dev-policy.json
   ```

2. **Create an operations policy with elevated permissions:**
   ```bash
   cat > ops-policy.json << 'EOF'
   {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Effect": "Allow",
               "Action": [
                   "s3:*"
               ],
               "Resource": [
                   "arn:aws:s3:::iam-lab-test-bucket-*",
                   "arn:aws:s3:::iam-lab-test-bucket-*/*"
               ]
           },
           {
               "Effect": "Allow",
               "Action": [
                   "ec2:*"
               ],
               "Resource": "*",
               "Condition": {
                   "StringEquals": {
                       "ec2:Region": ["us-east-1", "us-west-2"]
                   }
               }
           },
           {
               "Effect": "Allow",
               "Action": [
                   "iam:ListRoles",
                   "iam:PassRole"
               ],
               "Resource": "*"
           }
       ]
   }
   EOF
   
   aws iam create-policy \
       --policy-name OpsElevatedAccessPolicy \
       --policy-document file://ops-policy.json
   ```

3. **Create an audit policy with read-only access:**
   ```bash
   cat > audit-policy.json << 'EOF'
   {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Effect": "Allow",
               "Action": [
                   "s3:GetObject",
                   "s3:ListBucket"
               ],
               "Resource": [
                   "arn:aws:s3:::iam-lab-test-bucket-*",
                   "arn:aws:s3:::iam-lab-test-bucket-*/*"
               ]
           },
           {
               "Effect": "Allow",
               "Action": [
                   "ec2:Describe*",
                   "iam:Get*",
                   "iam:List*",
                   "cloudtrail:LookupEvents"
               ],
               "Resource": "*"
           }
       ]
   }
   EOF
   
   aws iam create-policy \
       --policy-name AuditReadOnlyPolicy \
       --policy-document file://audit-policy.json
   ```

### Step 3: Create IAM Roles for Different Access Patterns

1. **Create a trust policy for EC2 instances:**
   ```bash
   cat > ec2-trust-policy.json << 'EOF'
   {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Effect": "Allow",
               "Principal": {
                   "Service": "ec2.amazonaws.com"
               },
               "Action": "sts:AssumeRole"
           }
       ]
   }
   EOF
   ```

2. **Create developer role:**
   ```bash
   aws iam create-role \
       --role-name DevRole \
       --assume-role-policy-document file://ec2-trust-policy.json
   
   # Get the policy ARN
   DEV_POLICY_ARN=$(aws iam list-policies --query 'Policies[?PolicyName==`DevLimitedAccessPolicy`].Arn' --output text)
   
   # Attach the policy to the role
   aws iam attach-role-policy \
       --role-name DevRole \
       --policy-arn $DEV_POLICY_ARN
   ```

3. **Create operations role:**
   ```bash
   aws iam create-role \
       --role-name OpsRole \
       --assume-role-policy-document file://ec2-trust-policy.json
   
   # Get the policy ARN
   OPS_POLICY_ARN=$(aws iam list-policies --query 'Policies[?PolicyName==`OpsElevatedAccessPolicy`].Arn' --output text)
   
   # Attach the policy to the role
   aws iam attach-role-policy \
       --role-name OpsRole \
       --policy-arn $OPS_POLICY_ARN
   ```

4. **Create audit role:**
   ```bash
   aws iam create-role \
       --role-name AuditRole \
       --assume-role-policy-document file://ec2-trust-policy.json
   
   # Get the policy ARN
   AUDIT_POLICY_ARN=$(aws iam list-policies --query 'Policies[?PolicyName==`AuditReadOnlyPolicy`].Arn' --output text)
   
   # Attach the policy to the role
   aws iam attach-role-policy \
       --role-name AuditRole \
       --policy-arn $AUDIT_POLICY_ARN
   ```

### Step 4: Create Cross-Account Access Role

1. **Create a cross-account trust policy:**
   ```bash
   # Replace TRUSTED_ACCOUNT_ID with an actual account ID you want to grant access to
   cat > cross-account-trust-policy.json << 'EOF'
   {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Effect": "Allow",
               "Principal": {
                   "AWS": "arn:aws:iam::TRUSTED_ACCOUNT_ID:root"
               },
               "Action": "sts:AssumeRole",
               "Condition": {
                   "StringEquals": {
                       "sts:ExternalId": "unique-external-id-12345"
                   },
                   "Bool": {
                       "aws:MultiFactorAuthPresent": "true"
                   }
               }
           }
       ]
   }
   EOF
   
   # Note: This is for demonstration - replace TRUSTED_ACCOUNT_ID with actual account
   echo "Cross-account trust policy created (update TRUSTED_ACCOUNT_ID before use)"
   ```

2. **Create cross-account role (demonstration only):**
   ```bash
   # This would create the role if you have a trusted account ID
   # aws iam create-role \
   #     --role-name CrossAccountAccessRole \
   #     --assume-role-policy-document file://cross-account-trust-policy.json
   
   echo "Cross-account role creation skipped - update trust policy with real account ID first"
   ```

### Step 5: Set Up IAM Monitoring and Alerting

1. **Create SNS topic for security alerts:**
   ```bash
   aws sns create-topic --name iam-security-alerts
   
   # Get the topic ARN
   TOPIC_ARN=$(aws sns list-topics --query 'Topics[?contains(TopicArn, `iam-security-alerts`)].TopicArn' --output text)
   echo "SNS Topic ARN: $TOPIC_ARN"
   ```

2. **Subscribe to the topic (replace with your email):**
   ```bash
   # Replace YOUR_EMAIL with your actual email address
   # aws sns subscribe \
   #     --topic-arn $TOPIC_ARN \
   #     --protocol email \
   #     --notification-endpoint YOUR_EMAIL@example.com
   
   echo "Subscribe to SNS topic with your email address using the command above"
   ```

3. **Create CloudWatch alarm for root account usage:**
   ```bash
   aws logs create-log-group --log-group-name CloudTrail/IAMEvents
   
   # Create metric filter for root account usage
   aws logs put-metric-filter \
       --log-group-name CloudTrail/IAMEvents \
       --filter-name RootAccountUsage \
       --filter-pattern '{ $.userIdentity.type = "Root" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != "AwsServiceEvent" }' \
       --metric-transformations \
           metricName=RootAccountUsageCount,metricNamespace=IAMSecurity,metricValue=1
   
   # Create alarm
   aws cloudwatch put-metric-alarm \
       --alarm-name "Root-Account-Usage" \
       --alarm-description "Alarm for root account usage" \
       --metric-name RootAccountUsageCount \
       --namespace IAMSecurity \
       --statistic Sum \
       --period 300 \
       --threshold 1 \
       --comparison-operator GreaterThanOrEqualToThreshold \
       --evaluation-periods 1 \
       --alarm-actions $TOPIC_ARN
   ```

### Step 6: Test IAM Policies and Permissions

1. **Create test users to validate policies:**
   ```bash
   # Create test users
   aws iam create-user --user-name test-dev-user
   aws iam create-user --user-name test-ops-user
   aws iam create-user --user-name test-audit-user
   
   # Attach policies to users
   aws iam attach-user-policy --user-name test-dev-user --policy-arn $DEV_POLICY_ARN
   aws iam attach-user-policy --user-name test-ops-user --policy-arn $OPS_POLICY_ARN
   aws iam attach-user-policy --user-name test-audit-user --policy-arn $AUDIT_POLICY_ARN
   ```

2. **Create access keys for testing (optional - for demonstration only):**
   ```bash
   echo "Access keys can be created for testing, but should be deleted immediately after testing"
   echo "Use IAM roles instead of access keys in production environments"
   ```

3. **Test policy simulation:**
   ```bash
   # Simulate S3 access for dev user
   aws iam simulate-principal-policy \
       --policy-source-arn "arn:aws:iam::${ACCOUNT_ID}:user/test-dev-user" \
       --action-names s3:GetObject \
       --resource-arns "arn:aws:s3:::${BUCKET_NAME}/test-file.txt"
   
   # Simulate EC2 access for dev user
   aws iam simulate-principal-policy \
       --policy-source-arn "arn:aws:iam::${ACCOUNT_ID}:user/test-dev-user" \
       --action-names ec2:TerminateInstances \
       --resource-arns "*"
   ```

## Troubleshooting Guide

### Common Issues and Solutions

1. **Policy attachment fails with "Policy does not exist" error:**
   - Verify the policy ARN is correct using `aws iam list-policies`
   - Ensure the policy was created successfully
   - Check for typos in policy names

2. **Access denied when testing permissions:**
   - Verify the policy is attached to the correct user/role
   - Check policy syntax using the IAM policy simulator
   - Ensure resource ARNs match exactly (including account ID)

3. **CloudWatch alarms not triggering:**
   - Verify CloudTrail is enabled and logging to CloudWatch
   - Check the metric filter pattern syntax
   - Ensure the log group exists and has data

4. **Cross-account role assumption fails:**
   - Verify the external ID matches exactly
   - Ensure MFA is enabled if required by the condition
   - Check that the trusted account ID is correct

### Debugging Commands

```bash
# Check if a policy exists
aws iam get-policy --policy-arn arn:aws:iam::ACCOUNT_ID:policy/PolicyName

# List all policies attached to a user
aws iam list-attached-user-policies --user-name USERNAME

# List all policies attached to a role
aws iam list-attached-role-policies --role-name ROLENAME

# Simulate policy permissions
aws iam simulate-principal-policy \
    --policy-source-arn USER_OR_ROLE_ARN \
    --action-names ACTION_NAME \
    --resource-arns RESOURCE_ARN

# Check CloudTrail events for IAM actions
aws logs filter-log-events \
    --log-group-name CloudTrail/IAMEvents \
    --start-time $(date -d '1 hour ago' +%s)000 \
    --filter-pattern '{ $.eventSource = "iam.amazonaws.com" }'
```

## Resources Created

This lab creates the following AWS resources:

### Identity and Access Management
- **IAM Policies**: 3 custom policies (DevLimitedAccessPolicy, OpsElevatedAccessPolicy, AuditReadOnlyPolicy)
- **IAM Roles**: 3 roles (DevRole, OpsRole, AuditRole)
- **IAM Users**: 3 test users (test-dev-user, test-ops-user, test-audit-user)

### Storage
- **S3 Bucket**: Test bucket for permission validation

### Monitoring
- **SNS Topic**: Security alert notifications
- **CloudWatch Log Group**: IAM event logging
- **CloudWatch Alarm**: Root account usage monitoring
- **CloudWatch Metric Filter**: Root account usage detection

### Estimated Costs
- **IAM**: Free (no charges for users, roles, or policies)
- **S3 Bucket**: $0.023/GB/month (minimal for test file)
- **CloudWatch Logs**: $0.50/GB ingested + $0.03/GB stored
- **CloudWatch Alarms**: $0.10/alarm/month
- **SNS**: $0.50/million requests + $0.06/100,000 email notifications
- **Total estimated cost**: $1-3/month (mostly monitoring costs)

## Cleanup

When you're finished with the lab, follow these steps to avoid ongoing charges:

1. **Delete test users and their access keys:**
   ```bash
   # List and delete access keys if any were created
   aws iam list-access-keys --user-name test-dev-user
   aws iam list-access-keys --user-name test-ops-user
   aws iam list-access-keys --user-name test-audit-user
   
   # Detach policies from users
   aws iam detach-user-policy --user-name test-dev-user --policy-arn $DEV_POLICY_ARN
   aws iam detach-user-policy --user-name test-ops-user --policy-arn $OPS_POLICY_ARN
   aws iam detach-user-policy --user-name test-audit-user --policy-arn $AUDIT_POLICY_ARN
   
   # Delete users
   aws iam delete-user --user-name test-dev-user
   aws iam delete-user --user-name test-ops-user
   aws iam delete-user --user-name test-audit-user
   ```

2. **Delete IAM roles:**
   ```bash
   # Detach policies from roles
   aws iam detach-role-policy --role-name DevRole --policy-arn $DEV_POLICY_ARN
   aws iam detach-role-policy --role-name OpsRole --policy-arn $OPS_POLICY_ARN
   aws iam detach-role-policy --role-name AuditRole --policy-arn $AUDIT_POLICY_ARN
   
   # Delete roles
   aws iam delete-role --role-name DevRole
   aws iam delete-role --role-name OpsRole
   aws iam delete-role --role-name AuditRole
   ```

3. **Delete custom IAM policies:**
   ```bash
   aws iam delete-policy --policy-arn $DEV_POLICY_ARN
   aws iam delete-policy --policy-arn $OPS_POLICY_ARN
   aws iam delete-policy --policy-arn $AUDIT_POLICY_ARN
   ```

4. **Delete S3 bucket and contents:**
   ```bash
   aws s3 rm s3://${BUCKET_NAME} --recursive
   aws s3 rb s3://${BUCKET_NAME}
   ```

5. **Delete monitoring resources:**
   ```bash
   # Delete CloudWatch alarm
   aws cloudwatch delete-alarms --alarm-names "Root-Account-Usage"
   
   # Delete metric filter
   aws logs delete-metric-filter \
       --log-group-name CloudTrail/IAMEvents \
       --filter-name RootAccountUsage
   
   # Delete log group
   aws logs delete-log-group --log-group-name CloudTrail/IAMEvents
   
   # Delete SNS topic
   aws sns delete-topic --topic-arn $TOPIC_ARN
   ```

6. **Clean up local files:**
   ```bash
   rm -f dev-policy.json ops-policy.json audit-policy.json
   rm -f ec2-trust-policy.json cross-account-trust-policy.json
   rm -f test-file.txt
   ```

> **Important**: Always verify that all resources have been deleted to avoid unexpected charges.

## Next Steps

After completing this lab, consider:

1. **Implement IAM Access Analyzer** to identify unused permissions and external access
2. **Set up AWS Config** to monitor IAM configuration changes
3. **Explore AWS Organizations** for centralized IAM management across multiple accounts
4. **Learn about IAM Identity Center** (formerly AWS SSO) for enterprise identity management
5. **Practice with AWS IAM Policy Simulator** for complex permission scenarios

## Certification Exam Tips

This lab covers several key areas for the AWS DevOps Professional exam:

- **Domain 1**: SDLC Automation (IAM for CI/CD pipelines)
- **Domain 2**: Configuration Management and IaC (IAM as code)
- **Domain 3**: Monitoring and Logging (IAM event monitoring)
- **Domain 4**: Policies and Standards Automation (IAM policy automation)
- **Domain 6**: Incident and Event Response (IAM security monitoring)

Key concepts to remember:
- **Principle of Least Privilege**: Always grant minimum permissions necessary
- **IAM Policy Evaluation Logic**: Explicit deny always wins, then explicit allow
- **Cross-Account Access**: Use roles with external ID and MFA conditions
- **IAM Monitoring**: CloudTrail + CloudWatch for comprehensive IAM auditing
- **Policy Conditions**: Use conditions to restrict access by time, IP, MFA, etc.
- **Resource-Based vs Identity-Based Policies**: Understand when to use each
- **IAM Roles vs Users**: Prefer roles for applications and cross-account access

## Additional Resources

- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [IAM Policy Language Reference](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements.html)
- [AWS IAM Policy Simulator](https://policysim.aws.amazon.com/)
- [IAM Access Analyzer](https://docs.aws.amazon.com/IAM/latest/UserGuide/what-is-access-analyzer.html)
- [AWS Security Blog - IAM](https://aws.amazon.com/blogs/security/category/security-identity-compliance/aws-identity-and-access-management/)
- [AWS Well-Architected Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html)