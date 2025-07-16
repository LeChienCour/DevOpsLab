#!/bin/bash
# Universal provisioning script for AWS DevOps Labs

set -e

LAB_ID=$1
SESSION_ID=$2

if [ -z "$LAB_ID" ] || [ -z "$SESSION_ID" ]; then
    echo "Usage: $0 <lab-id> <session-id>"
    exit 1
fi

echo "Provisioning lab: $LAB_ID"
echo "Session ID: $SESSION_ID"

# Set common variables
STACK_NAME="devops-lab-${LAB_ID}-${SESSION_ID}"
REGION=${AWS_DEFAULT_REGION:-us-east-1}

# Tag all resources with session information
TAGS="Key=LabSession,Value=${SESSION_ID} Key=LabId,Value=${LAB_ID} Key=Environment,Value=lab Key=AutoCleanup,Value=true"

echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo "Tags: $TAGS"

# Check if lab directory exists
LAB_DIR="$(dirname "$0")/../$(python3 -c "
import yaml
with open('config/labs.yaml', 'r') as f:
    labs = yaml.safe_load(f)
    print(labs['labs']['$LAB_ID']['path'])
")"

if [ ! -d "$LAB_DIR" ]; then
    echo "Error: Lab directory not found: $LAB_DIR"
    exit 1
fi

echo "Lab directory: $LAB_DIR"

# Look for CloudFormation templates
if [ -f "$LAB_DIR/templates/main.yaml" ]; then
    echo "Deploying CloudFormation stack..."
    aws cloudformation deploy \
        --template-file "$LAB_DIR/templates/main.yaml" \
        --stack-name "$STACK_NAME" \
        --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
        --tags $TAGS \
        --region "$REGION"
    
    echo "Stack deployed successfully: $STACK_NAME"
elif [ -f "$LAB_DIR/scripts/provision.sh" ]; then
    echo "Running lab-specific provisioning script..."
    cd "$LAB_DIR"
    ./scripts/provision.sh "$SESSION_ID"
else
    echo "No provisioning method found for lab: $LAB_ID"
    echo "Please check lab documentation for manual setup instructions."
fi

echo "Provisioning completed for lab: $LAB_ID"