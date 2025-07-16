#!/bin/bash
# Universal cleanup script for AWS DevOps Labs

set -e

SESSION_ID=$1

if [ -z "$SESSION_ID" ]; then
    echo "Usage: $0 <session-id>"
    exit 1
fi

echo "Cleaning up resources for session: $SESSION_ID"

REGION=${AWS_DEFAULT_REGION:-us-east-1}

# Find all CloudFormation stacks with the session tag
echo "Finding CloudFormation stacks..."
STACKS=$(aws cloudformation describe-stacks \
    --region "$REGION" \
    --query "Stacks[?Tags[?Key=='LabSession' && Value=='$SESSION_ID']].StackName" \
    --output text)

if [ -n "$STACKS" ]; then
    for STACK in $STACKS; do
        echo "Deleting stack: $STACK"
        aws cloudformation delete-stack \
            --stack-name "$STACK" \
            --region "$REGION"
        
        echo "Waiting for stack deletion to complete..."
        aws cloudformation wait stack-delete-complete \
            --stack-name "$STACK" \
            --region "$REGION"
        
        echo "Stack deleted: $STACK"
    done
else
    echo "No CloudFormation stacks found for session: $SESSION_ID"
fi

# Clean up other resources by tags
echo "Cleaning up EC2 instances..."
INSTANCES=$(aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=tag:LabSession,Values=$SESSION_ID" "Name=instance-state-name,Values=running,stopped" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)

if [ -n "$INSTANCES" ]; then
    echo "Terminating instances: $INSTANCES"
    aws ec2 terminate-instances \
        --instance-ids $INSTANCES \
        --region "$REGION"
else
    echo "No EC2 instances found for session: $SESSION_ID"
fi

# Clean up S3 buckets (be careful with this)
echo "Finding S3 buckets..."
BUCKETS=$(aws s3api list-buckets \
    --query "Buckets[].Name" \
    --output text | xargs -I {} aws s3api get-bucket-tagging --bucket {} --query "TagSet[?Key=='LabSession' && Value=='$SESSION_ID']" --output text 2>/dev/null | grep -l "$SESSION_ID" || true)

if [ -n "$BUCKETS" ]; then
    for BUCKET in $BUCKETS; do
        echo "Emptying and deleting bucket: $BUCKET"
        aws s3 rm s3://$BUCKET --recursive
        aws s3api delete-bucket --bucket $BUCKET --region "$REGION"
    done
else
    echo "No S3 buckets found for session: $SESSION_ID"
fi

echo "Cleanup completed for session: $SESSION_ID"
echo "Please verify in AWS console that all resources have been removed."