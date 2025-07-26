#!/bin/bash
# Universal cleanup script for AWS DevOps Labs

set -e

SESSION_ID=$1
VERIFY_CLEANUP=${2:-true}

if [ -z "$SESSION_ID" ]; then
    echo "Usage: $0 <session-id> [verify-cleanup]"
    echo "  session-id: The session identifier to clean up"
    echo "  verify-cleanup: Whether to verify cleanup completion (default: true)"
    exit 1
fi

echo "=========================================="
echo "AWS DevOps Labs - Universal Cleanup"
echo "=========================================="
echo "Session ID: $SESSION_ID"
echo "Verify Cleanup: $VERIFY_CLEANUP"

REGION=${AWS_DEFAULT_REGION:-us-east-1}
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CLEANUP_LOG="/tmp/cleanup-${SESSION_ID}.log"

echo "Region: $REGION"
echo "Account ID: $ACCOUNT_ID"
echo "Cleanup Log: $CLEANUP_LOG"

# Initialize cleanup log
echo "Cleanup started at $(date)" > "$CLEANUP_LOG"

# Function to log cleanup actions
log_action() {
    echo "$1" | tee -a "$CLEANUP_LOG"
}

# Function to check if resource exists
resource_exists() {
    local resource_type=$1
    local resource_id=$2
    
    case $resource_type in
        "stack")
            aws cloudformation describe-stacks --stack-name "$resource_id" --region "$REGION" >/dev/null 2>&1
            ;;
        "instance")
            aws ec2 describe-instances --instance-ids "$resource_id" --region "$REGION" --query "Reservations[].Instances[?State.Name!='terminated']" --output text | grep -q .
            ;;
        "function")
            aws lambda get-function --function-name "$resource_id" --region "$REGION" >/dev/null 2>&1
            ;;
        "bucket")
            aws s3api head-bucket --bucket "$resource_id" >/dev/null 2>&1
            ;;
    esac
}

# Get current cost estimate before cleanup
log_action "Getting current cost estimate..."
CURRENT_COST=$(python3 -c "
import boto3
from datetime import datetime, timedelta

try:
    ce_client = boto3.client('ce', region_name='us-east-1')
    
    end_date = datetime.now().strftime('%Y-%m-%d')
    start_date = (datetime.now() - timedelta(days=7)).strftime('%Y-%m-%d')
    
    response = ce_client.get_cost_and_usage(
        TimePeriod={'Start': start_date, 'End': end_date},
        Granularity='DAILY',
        Metrics=['BlendedCost'],
        GroupBy=[{'Type': 'TAG', 'Key': 'SessionId'}]
    )
    
    total_cost = 0.0
    for result in response['ResultsByTime']:
        for group in result['Groups']:
            if '$SESSION_ID' in str(group['Keys']):
                cost = float(group['Metrics']['BlendedCost']['Amount'])
                total_cost += cost
    
    print(f'{total_cost:.2f}')
except Exception as e:
    print('0.00')
")

log_action "Current estimated cost for session: \$${CURRENT_COST}"

# Find all CloudFormation stacks with the session tag
log_action "Finding CloudFormation stacks..."
STACKS=$(aws cloudformation describe-stacks \
    --region "$REGION" \
    --query "Stacks[?Tags[?Key=='SessionId' && Value=='$SESSION_ID'] || Tags[?Key=='LabSession' && Value=='$SESSION_ID']].StackName" \
    --output text)

if [ -n "$STACKS" ]; then
    log_action "Found CloudFormation stacks: $STACKS"
    for STACK in $STACKS; do
        log_action "Deleting stack: $STACK"
        
        # Get stack resources before deletion for verification
        STACK_RESOURCES=$(aws cloudformation list-stack-resources \
            --stack-name "$STACK" \
            --region "$REGION" \
            --query "StackResourceSummaries[].{Type:ResourceType,Id:PhysicalResourceId}" \
            --output json 2>/dev/null || echo "[]")
        
        aws cloudformation delete-stack \
            --stack-name "$STACK" \
            --region "$REGION"
        
        log_action "Waiting for stack deletion to complete..."
        if aws cloudformation wait stack-delete-complete \
            --stack-name "$STACK" \
            --region "$REGION" \
            --cli-read-timeout 1800 \
            --cli-connect-timeout 60; then
            log_action "✓ Stack deleted successfully: $STACK"
        else
            log_action "⚠ Stack deletion may have failed or timed out: $STACK"
            
            # Check if stack still exists
            if resource_exists "stack" "$STACK"; then
                log_action "✗ Stack still exists: $STACK"
                
                # Try to get stack events for troubleshooting
                log_action "Stack events for troubleshooting:"
                aws cloudformation describe-stack-events \
                    --stack-name "$STACK" \
                    --region "$REGION" \
                    --query "StackEvents[?ResourceStatus=='DELETE_FAILED'][].{Resource:LogicalResourceId,Status:ResourceStatus,Reason:ResourceStatusReason}" \
                    --output table >> "$CLEANUP_LOG" 2>&1 || true
            fi
        fi
    done
else
    log_action "No CloudFormation stacks found for session: $SESSION_ID"
fi

# Clean up EC2 instances
log_action "Cleaning up EC2 instances..."
INSTANCES=$(aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=tag:SessionId,Values=$SESSION_ID" "Name=instance-state-name,Values=running,stopped,stopping" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)

if [ -n "$INSTANCES" ]; then
    log_action "Found EC2 instances: $INSTANCES"
    for INSTANCE in $INSTANCES; do
        log_action "Terminating instance: $INSTANCE"
        aws ec2 terminate-instances \
            --instance-ids "$INSTANCE" \
            --region "$REGION" >/dev/null
        
        # Wait for termination
        log_action "Waiting for instance termination: $INSTANCE"
        aws ec2 wait instance-terminated \
            --instance-ids "$INSTANCE" \
            --region "$REGION" \
            --cli-read-timeout 600 || log_action "⚠ Instance termination timeout: $INSTANCE"
    done
    log_action "✓ EC2 instances cleanup completed"
else
    log_action "No EC2 instances found for session: $SESSION_ID"
fi

# Clean up Lambda functions
log_action "Cleaning up Lambda functions..."
FUNCTIONS=$(aws lambda list-functions \
    --region "$REGION" \
    --query "Functions[].FunctionName" \
    --output text)

for FUNCTION in $FUNCTIONS; do
    TAGS=$(aws lambda list-tags \
        --resource "arn:aws:lambda:$REGION:$ACCOUNT_ID:function:$FUNCTION" \
        --region "$REGION" \
        --query "Tags.SessionId" \
        --output text 2>/dev/null || echo "None")
    
    if [ "$TAGS" = "$SESSION_ID" ]; then
        log_action "Deleting Lambda function: $FUNCTION"
        aws lambda delete-function \
            --function-name "$FUNCTION" \
            --region "$REGION"
        log_action "✓ Lambda function deleted: $FUNCTION"
    fi
done

# Clean up S3 buckets
log_action "Cleaning up S3 buckets..."
BUCKETS=$(aws s3api list-buckets --query "Buckets[].Name" --output text)

for BUCKET in $BUCKETS; do
    TAGS=$(aws s3api get-bucket-tagging \
        --bucket "$BUCKET" \
        --query "TagSet[?Key=='SessionId'].Value" \
        --output text 2>/dev/null || echo "None")
    
    if [ "$TAGS" = "$SESSION_ID" ]; then
        log_action "Emptying and deleting bucket: $BUCKET"
        
        # Empty bucket first
        aws s3 rm "s3://$BUCKET" --recursive >/dev/null 2>&1 || true
        
        # Delete bucket
        aws s3api delete-bucket \
            --bucket "$BUCKET" \
            --region "$REGION" 2>/dev/null || log_action "⚠ Could not delete bucket: $BUCKET"
        
        log_action "✓ S3 bucket processed: $BUCKET"
    fi
done

# Clean up IAM roles (be very careful)
log_action "Cleaning up IAM roles..."
ROLES=$(aws iam list-roles \
    --query "Roles[].RoleName" \
    --output text)

for ROLE in $ROLES; do
    TAGS=$(aws iam list-role-tags \
        --role-name "$ROLE" \
        --query "Tags[?Key=='SessionId'].Value" \
        --output text 2>/dev/null || echo "None")
    
    if [ "$TAGS" = "$SESSION_ID" ]; then
        log_action "Deleting IAM role: $ROLE"
        
        # Detach policies first
        ATTACHED_POLICIES=$(aws iam list-attached-role-policies \
            --role-name "$ROLE" \
            --query "AttachedPolicies[].PolicyArn" \
            --output text 2>/dev/null || echo "")
        
        for POLICY in $ATTACHED_POLICIES; do
            aws iam detach-role-policy \
                --role-name "$ROLE" \
                --policy-arn "$POLICY" 2>/dev/null || true
        done
        
        # Delete inline policies
        INLINE_POLICIES=$(aws iam list-role-policies \
            --role-name "$ROLE" \
            --query "PolicyNames" \
            --output text 2>/dev/null || echo "")
        
        for POLICY in $INLINE_POLICIES; do
            aws iam delete-role-policy \
                --role-name "$ROLE" \
                --policy-name "$POLICY" 2>/dev/null || true
        done
        
        # Delete instance profiles
        INSTANCE_PROFILES=$(aws iam list-instance-profiles-for-role \
            --role-name "$ROLE" \
            --query "InstanceProfiles[].InstanceProfileName" \
            --output text 2>/dev/null || echo "")
        
        for PROFILE in $INSTANCE_PROFILES; do
            aws iam remove-role-from-instance-profile \
                --instance-profile-name "$PROFILE" \
                --role-name "$ROLE" 2>/dev/null || true
            aws iam delete-instance-profile \
                --instance-profile-name "$PROFILE" 2>/dev/null || true
        done
        
        # Finally delete the role
        aws iam delete-role --role-name "$ROLE" 2>/dev/null || log_action "⚠ Could not delete role: $ROLE"
        log_action "✓ IAM role processed: $ROLE"
    fi
done

# Delete budget if it exists
log_action "Cleaning up budget alerts..."
python3 -c "
import boto3

try:
    budgets_client = boto3.client('budgets', region_name='us-east-1')
    budget_name = f'DevOpsLab-{\"$SESSION_ID\"}'
    
    budgets_client.delete_budget(
        AccountId='$ACCOUNT_ID',
        BudgetName=budget_name
    )
    print('✓ Budget alert deleted')
except Exception as e:
    print(f'Budget cleanup: {e}')
" >> "$CLEANUP_LOG"

# Verification phase
if [ "$VERIFY_CLEANUP" = "true" ]; then
    log_action ""
    log_action "=========================================="
    log_action "Verifying cleanup completion..."
    log_action "=========================================="
    
    VERIFICATION_FAILED=false
    
    # Verify CloudFormation stacks
    REMAINING_STACKS=$(aws cloudformation describe-stacks \
        --region "$REGION" \
        --query "Stacks[?Tags[?Key=='SessionId' && Value=='$SESSION_ID']].StackName" \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$REMAINING_STACKS" ]; then
        log_action "✗ Remaining CloudFormation stacks: $REMAINING_STACKS"
        VERIFICATION_FAILED=true
    else
        log_action "✓ No remaining CloudFormation stacks"
    fi
    
    # Verify EC2 instances
    REMAINING_INSTANCES=$(aws ec2 describe-instances \
        --region "$REGION" \
        --filters "Name=tag:SessionId,Values=$SESSION_ID" "Name=instance-state-name,Values=running,stopped,stopping" \
        --query "Reservations[].Instances[].InstanceId" \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$REMAINING_INSTANCES" ]; then
        log_action "✗ Remaining EC2 instances: $REMAINING_INSTANCES"
        VERIFICATION_FAILED=true
    else
        log_action "✓ No remaining EC2 instances"
    fi
    
    # Final cost check
    FINAL_COST=$(python3 -c "
import boto3
from datetime import datetime, timedelta

try:
    ce_client = boto3.client('ce', region_name='us-east-1')
    
    end_date = datetime.now().strftime('%Y-%m-%d')
    start_date = (datetime.now() - timedelta(days=1)).strftime('%Y-%m-%d')
    
    response = ce_client.get_cost_and_usage(
        TimePeriod={'Start': start_date, 'End': end_date},
        Granularity='DAILY',
        Metrics=['BlendedCost'],
        GroupBy=[{'Type': 'TAG', 'Key': 'SessionId'}]
    )
    
    total_cost = 0.0
    for result in response['ResultsByTime']:
        for group in result['Groups']:
            if '$SESSION_ID' in str(group['Keys']):
                cost = float(group['Metrics']['BlendedCost']['Amount'])
                total_cost += cost
    
    print(f'{total_cost:.2f}')
except Exception as e:
    print('0.00')
")
    
    log_action "Final cost estimate: \$${FINAL_COST}"
    
    if [ "$VERIFICATION_FAILED" = "true" ]; then
        log_action ""
        log_action "⚠ CLEANUP VERIFICATION FAILED"
        log_action "Some resources may still exist. Please check AWS console manually."
        log_action "Cleanup log: $CLEANUP_LOG"
        exit 1
    else
        log_action ""
        log_action "✓ CLEANUP VERIFICATION SUCCESSFUL"
        log_action "All tracked resources have been removed."
    fi
fi

log_action ""
log_action "=========================================="
log_action "Cleanup Summary"
log_action "=========================================="
log_action "Session ID: $SESSION_ID"
log_action "Cleanup completed at: $(date)"
log_action "Initial cost estimate: \$${CURRENT_COST}"
log_action "Final cost estimate: \$${FINAL_COST:-0.00}"
log_action "Cleanup log: $CLEANUP_LOG"
log_action ""
log_action "Next steps:"
log_action "1. Review cleanup log for any warnings"
log_action "2. Check AWS Billing Dashboard for final costs"
log_action "3. Verify in AWS console that all resources are removed"

echo ""
echo "Cleanup completed for session: $SESSION_ID"
echo "Check cleanup log: $CLEANUP_LOG"