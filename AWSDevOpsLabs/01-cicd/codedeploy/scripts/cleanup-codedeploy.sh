#!/bin/bash

# CodeDeploy Lab Cleanup Script
# This script removes all resources created by the CodeDeploy lab

set -e

# Configuration
PROJECT_NAME="codedeploy-lab"
STACK_NAME="${PROJECT_NAME}-stack"
REGION=${AWS_DEFAULT_REGION:-us-east-1}

echo "=== CodeDeploy Lab Cleanup ==="
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "Error: AWS CLI is not configured or credentials are invalid"
    echo "Please run 'aws configure' to set up your credentials"
    exit 1
fi

# Check if stack exists
if ! aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" > /dev/null 2>&1; then
    echo "Stack $STACK_NAME not found. Nothing to clean up."
    exit 0
fi

echo "Found stack: $STACK_NAME"

# Get resource information before deletion
echo "Retrieving resource information..."
ARTIFACT_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`ArtifactBucket`].OutputValue' \
    --output text \
    --region "$REGION" 2>/dev/null || echo "")

EC2_APP=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`CodeDeployApplicationEC2`].OutputValue' \
    --output text \
    --region "$REGION" 2>/dev/null || echo "")

ECS_APP=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`CodeDeployApplicationECS`].OutputValue' \
    --output text \
    --region "$REGION" 2>/dev/null || echo "")

# Stop any running deployments
echo "Stopping any running deployments..."

if [ ! -z "$EC2_APP" ]; then
    echo "Checking for running deployments in EC2 application: $EC2_APP"
    RUNNING_DEPLOYMENTS=$(aws deploy list-deployments \
        --application-name "$EC2_APP" \
        --include-only-statuses "InProgress" "Queued" "Ready" \
        --query 'deployments' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    if [ ! -z "$RUNNING_DEPLOYMENTS" ] && [ "$RUNNING_DEPLOYMENTS" != "None" ]; then
        for deployment_id in $RUNNING_DEPLOYMENTS; do
            echo "Stopping deployment: $deployment_id"
            aws deploy stop-deployment \
                --deployment-id "$deployment_id" \
                --auto-rollback-enabled \
                --region "$REGION" || true
        done
        
        echo "Waiting for deployments to stop..."
        sleep 30
    fi
fi

if [ ! -z "$ECS_APP" ]; then
    echo "Checking for running deployments in ECS application: $ECS_APP"
    RUNNING_ECS_DEPLOYMENTS=$(aws deploy list-deployments \
        --application-name "$ECS_APP" \
        --include-only-statuses "InProgress" "Queued" "Ready" \
        --query 'deployments' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    if [ ! -z "$RUNNING_ECS_DEPLOYMENTS" ] && [ "$RUNNING_ECS_DEPLOYMENTS" != "None" ]; then
        for deployment_id in $RUNNING_ECS_DEPLOYMENTS; do
            echo "Stopping ECS deployment: $deployment_id"
            aws deploy stop-deployment \
                --deployment-id "$deployment_id" \
                --auto-rollback-enabled \
                --region "$REGION" || true
        done
        
        echo "Waiting for ECS deployments to stop..."
        sleep 30
    fi
fi

# Scale down Auto Scaling Groups to 0
echo "Scaling down Auto Scaling Groups..."
ASG_NAMES=$(aws cloudformation describe-stack-resources \
    --stack-name "$STACK_NAME" \
    --query 'StackResources[?ResourceType==`AWS::AutoScaling::AutoScalingGroup`].PhysicalResourceId' \
    --output text \
    --region "$REGION" 2>/dev/null || echo "")

for asg_name in $ASG_NAMES; do
    if [ ! -z "$asg_name" ]; then
        echo "Scaling down Auto Scaling Group: $asg_name"
        aws autoscaling update-auto-scaling-group \
            --auto-scaling-group-name "$asg_name" \
            --min-size 0 \
            --desired-capacity 0 \
            --region "$REGION" || true
    fi
done

# Wait for instances to terminate
if [ ! -z "$ASG_NAMES" ]; then
    echo "Waiting for Auto Scaling Group instances to terminate..."
    sleep 60
    
    # Check if instances are still terminating
    for asg_name in $ASG_NAMES; do
        if [ ! -z "$asg_name" ]; then
            INSTANCE_COUNT=$(aws autoscaling describe-auto-scaling-groups \
                --auto-scaling-group-names "$asg_name" \
                --query 'AutoScalingGroups[0].Instances | length(@)' \
                --output text \
                --region "$REGION" 2>/dev/null || echo "0")
            
            if [ "$INSTANCE_COUNT" -gt 0 ]; then
                echo "Waiting for remaining instances in $asg_name to terminate..."
                sleep 60
            fi
        fi
    done
fi

# Stop ECS services
echo "Stopping ECS services..."
ECS_SERVICES=$(aws cloudformation describe-stack-resources \
    --stack-name "$STACK_NAME" \
    --query 'StackResources[?ResourceType==`AWS::ECS::Service`].PhysicalResourceId' \
    --output text \
    --region "$REGION" 2>/dev/null || echo "")

ECS_CLUSTER=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`ECSCluster`].OutputValue' \
    --output text \
    --region "$REGION" 2>/dev/null || echo "")

for service_arn in $ECS_SERVICES; do
    if [ ! -z "$service_arn" ] && [ ! -z "$ECS_CLUSTER" ]; then
        SERVICE_NAME=$(echo "$service_arn" | cut -d'/' -f2)
        echo "Scaling down ECS service: $SERVICE_NAME"
        aws ecs update-service \
            --cluster "$ECS_CLUSTER" \
            --service "$SERVICE_NAME" \
            --desired-count 0 \
            --region "$REGION" || true
    fi
done

# Wait for ECS tasks to stop
if [ ! -z "$ECS_SERVICES" ] && [ ! -z "$ECS_CLUSTER" ]; then
    echo "Waiting for ECS tasks to stop..."
    sleep 30
fi

# Empty S3 buckets
BUCKETS=$(aws cloudformation describe-stack-resources \
    --stack-name "$STACK_NAME" \
    --query 'StackResources[?ResourceType==`AWS::S3::Bucket`].PhysicalResourceId' \
    --output text \
    --region "$REGION" 2>/dev/null || echo "")

if [ ! -z "$BUCKETS" ]; then
    echo "Emptying S3 buckets..."
    for bucket in $BUCKETS; do
        if aws s3api head-bucket --bucket "$bucket" --region "$REGION" 2>/dev/null; then
            echo "Emptying bucket: $bucket"
            aws s3 rm "s3://$bucket" --recursive --region "$REGION" || true
            
            # Remove versioned objects if versioning is enabled
            aws s3api list-object-versions \
                --bucket "$bucket" \
                --query 'Versions[].{Key:Key,VersionId:VersionId}' \
                --output text \
                --region "$REGION" 2>/dev/null | while read key version; do
                if [ ! -z "$key" ] && [ ! -z "$version" ]; then
                    aws s3api delete-object \
                        --bucket "$bucket" \
                        --key "$key" \
                        --version-id "$version" \
                        --region "$REGION" || true
                fi
            done
            
            # Remove delete markers
            aws s3api list-object-versions \
                --bucket "$bucket" \
                --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' \
                --output text \
                --region "$REGION" 2>/dev/null | while read key version; do
                if [ ! -z "$key" ] && [ ! -z "$version" ]; then
                    aws s3api delete-object \
                        --bucket "$bucket" \
                        --key "$key" \
                        --version-id "$version" \
                        --region "$REGION" || true
                fi
            done
        else
            echo "Bucket $bucket not found or already deleted"
        fi
    done
fi

# Delete CloudFormation stack
echo "Deleting CloudFormation stack..."
aws cloudformation delete-stack \
    --stack-name "$STACK_NAME" \
    --region "$REGION"

echo "Waiting for stack deletion to complete..."
echo "This may take 10-15 minutes due to Load Balancer and other resource dependencies..."

# Wait for stack deletion with timeout
TIMEOUT=1800  # 30 minutes
ELAPSED=0
INTERVAL=30

while [ $ELAPSED -lt $TIMEOUT ]; do
    if ! aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" > /dev/null 2>&1; then
        echo "✅ Stack deletion successful!"
        break
    fi
    
    echo "Still deleting... (${ELAPSED}s elapsed)"
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
    
    if [ $ELAPSED -ge $TIMEOUT ]; then
        echo "⚠️  Stack deletion is taking longer than expected."
        echo "Please check the AWS Console for the current status."
        echo "The stack may still be deleting in the background."
        break
    fi
done

# Clean up local files
echo "Cleaning up local files..."
rm -f lab-session-info.txt
rm -f "${PROJECT_NAME}-keypair.pem"

# Check for any remaining resources that might need manual cleanup
echo "Checking for any remaining resources..."

# Check for any remaining CodeDeploy applications
REMAINING_APPS=$(aws deploy list-applications \
    --query "applications[?contains(@, '$PROJECT_NAME')]" \
    --output text \
    --region "$REGION" 2>/dev/null || echo "")

if [ ! -z "$REMAINING_APPS" ]; then
    echo "⚠️  Warning: Found remaining CodeDeploy applications:"
    echo "$REMAINING_APPS"
    echo "These may need to be deleted manually if they weren't part of the CloudFormation stack."
fi

# Check for any remaining Auto Scaling Groups
REMAINING_ASGS=$(aws autoscaling describe-auto-scaling-groups \
    --query "AutoScalingGroups[?contains(AutoScalingGroupName, '$PROJECT_NAME')].AutoScalingGroupName" \
    --output text \
    --region "$REGION" 2>/dev/null || echo "")

if [ ! -z "$REMAINING_ASGS" ]; then
    echo "⚠️  Warning: Found remaining Auto Scaling Groups:"
    echo "$REMAINING_ASGS"
    echo "These may need to be deleted manually."
fi

echo
echo "🎉 CodeDeploy Lab Cleanup Complete!"
echo
echo "All AWS resources have been removed (or are in the process of being removed)."
echo "You can now run the provisioning script again for a fresh lab environment."
echo
echo "If you encounter any issues, please check the AWS Console for:"
echo "- CloudFormation stack status"
echo "- Any remaining EC2 instances"
echo "- Any remaining Load Balancers"
echo "- Any remaining Auto Scaling Groups"