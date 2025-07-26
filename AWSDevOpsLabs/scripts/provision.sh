#!/bin/bash
# Universal provisioning script for AWS DevOps Labs

set -e

LAB_ID=$1
SESSION_ID=$2
BUDGET_LIMIT=${3:-50}  # Default budget limit of $50

if [ -z "$LAB_ID" ] || [ -z "$SESSION_ID" ]; then
    echo "Usage: $0 <lab-id> <session-id> [budget-limit]"
    echo "  lab-id: The lab identifier"
    echo "  session-id: Unique session identifier"
    echo "  budget-limit: Optional budget limit in USD (default: 50)"
    exit 1
fi

echo "=========================================="
echo "AWS DevOps Labs - Universal Provisioning"
echo "=========================================="
echo "Lab ID: $LAB_ID"
echo "Session ID: $SESSION_ID"
echo "Budget Limit: \$${BUDGET_LIMIT}"

# Set common variables
STACK_NAME="devops-lab-${LAB_ID}-${SESSION_ID}"
REGION=${AWS_DEFAULT_REGION:-us-east-1}
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Comprehensive resource tagging strategy
TAGS="Key=Project,Value=AWSDevOpsLabs"
TAGS="$TAGS Key=ManagedBy,Value=LabManager"
TAGS="$TAGS Key=SessionId,Value=${SESSION_ID}"
TAGS="$TAGS Key=LabId,Value=${LAB_ID}"
TAGS="$TAGS Key=Environment,Value=lab"
TAGS="$TAGS Key=AutoCleanup,Value=true"
TAGS="$TAGS Key=CreatedAt,Value=${TIMESTAMP}"
TAGS="$TAGS Key=Owner,Value=${USER:-unknown}"
TAGS="$TAGS Key=BudgetLimit,Value=${BUDGET_LIMIT}"

echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo "Account ID: $ACCOUNT_ID"
echo "Timestamp: $TIMESTAMP"

# Get lab configuration
LAB_CONFIG=$(python3 -c "
import yaml
import sys
try:
    with open('config/labs.yaml', 'r') as f:
        labs = yaml.safe_load(f)
        lab = labs['labs'].get('$LAB_ID')
        if lab:
            print(f\"{lab['path']}|{lab.get('estimated_cost', 0)}|{lab.get('name', 'Unknown')}\")
        else:
            sys.exit(1)
except Exception as e:
    print(f\"Error: {e}\", file=sys.stderr)
    sys.exit(1)
")

if [ $? -ne 0 ]; then
    echo "Error: Lab '$LAB_ID' not found in configuration"
    exit 1
fi

IFS='|' read -r LAB_PATH ESTIMATED_COST LAB_NAME <<< "$LAB_CONFIG"
LAB_DIR="$(dirname "$0")/../$LAB_PATH"

if [ ! -d "$LAB_DIR" ]; then
    echo "Error: Lab directory not found: $LAB_DIR"
    exit 1
fi

echo "Lab Name: $LAB_NAME"
echo "Lab Directory: $LAB_DIR"
echo "Estimated Cost: \$${ESTIMATED_COST}"

# Check if estimated cost exceeds budget
if (( $(echo "$ESTIMATED_COST > $BUDGET_LIMIT" | bc -l) )); then
    echo "WARNING: Estimated cost (\$${ESTIMATED_COST}) exceeds budget limit (\$${BUDGET_LIMIT})"
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Provisioning cancelled by user"
        exit 1
    fi
fi

# Create budget alert for this session
echo "Setting up budget monitoring..."
python3 -c "
import boto3
import json
from datetime import datetime, timedelta

try:
    budgets_client = boto3.client('budgets', region_name='us-east-1')
    
    budget_name = f'DevOpsLab-{\"$SESSION_ID\"}'
    
    budget = {
        'BudgetName': budget_name,
        'BudgetLimit': {
            'Amount': str($BUDGET_LIMIT),
            'Unit': 'USD'
        },
        'TimeUnit': 'MONTHLY',
        'TimePeriod': {
            'Start': datetime.now().replace(day=1),
            'End': (datetime.now().replace(day=1) + timedelta(days=32)).replace(day=1)
        },
        'BudgetType': 'COST',
        'CostFilters': {
            'TagKey': ['SessionId'],
            'TagValue': ['$SESSION_ID']
        }
    }
    
    notifications = [{
        'NotificationType': 'ACTUAL',
        'ComparisonOperator': 'GREATER_THAN',
        'Threshold': 80.0,
        'ThresholdType': 'PERCENTAGE'
    }]
    
    budgets_client.create_budget(
        AccountId='$ACCOUNT_ID',
        Budget=budget,
        NotificationsWithSubscribers=[{
            'Notification': notifications[0],
            'Subscribers': []
        }]
    )
    print('✓ Budget alert created successfully')
except Exception as e:
    print(f'Warning: Could not create budget alert: {e}')
"

# Look for provisioning methods in order of preference
echo "Starting resource provisioning..."

if [ -f "$LAB_DIR/templates/main.yaml" ] || [ -f "$LAB_DIR/templates/infrastructure.yaml" ]; then
    # CloudFormation deployment
    TEMPLATE_FILE="$LAB_DIR/templates/main.yaml"
    if [ ! -f "$TEMPLATE_FILE" ]; then
        TEMPLATE_FILE="$LAB_DIR/templates/infrastructure.yaml"
    fi
    
    echo "Deploying CloudFormation stack from: $TEMPLATE_FILE"
    
    # Check for parameters file
    PARAMS_FILE="$LAB_DIR/templates/parameters.json"
    PARAMS_ARG=""
    if [ -f "$PARAMS_FILE" ]; then
        echo "Using parameters file: $PARAMS_FILE"
        PARAMS_ARG="--parameter-overrides file://$PARAMS_FILE"
    fi
    
    aws cloudformation deploy \
        --template-file "$TEMPLATE_FILE" \
        --stack-name "$STACK_NAME" \
        --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
        --tags $TAGS \
        --region "$REGION" \
        $PARAMS_ARG
    
    if [ $? -eq 0 ]; then
        echo "✓ CloudFormation stack deployed successfully: $STACK_NAME"
        
        # Get stack outputs
        echo "Stack outputs:"
        aws cloudformation describe-stacks \
            --stack-name "$STACK_NAME" \
            --region "$REGION" \
            --query "Stacks[0].Outputs[*].[OutputKey,OutputValue,Description]" \
            --output table
    else
        echo "✗ CloudFormation deployment failed"
        exit 1
    fi

elif [ -f "$LAB_DIR/scripts/provision-${LAB_ID}.sh" ]; then
    # Lab-specific provisioning script
    echo "Running lab-specific provisioning script..."
    cd "$LAB_DIR"
    chmod +x "scripts/provision-${LAB_ID}.sh"
    ./scripts/provision-${LAB_ID}.sh "$SESSION_ID" "$TAGS"
    
elif [ -f "$LAB_DIR/scripts/provision.sh" ]; then
    # Generic lab provisioning script
    echo "Running generic lab provisioning script..."
    cd "$LAB_DIR"
    chmod +x scripts/provision.sh
    ./scripts/provision.sh "$SESSION_ID" "$TAGS"

elif [ -f "$LAB_DIR/cdk.json" ]; then
    # CDK deployment
    echo "Deploying CDK application..."
    cd "$LAB_DIR"
    
    # Install dependencies if needed
    if [ -f "package.json" ]; then
        npm install
    elif [ -f "requirements.txt" ]; then
        pip install -r requirements.txt
    fi
    
    # Deploy CDK stack
    cdk deploy --require-approval never \
        --context sessionId="$SESSION_ID" \
        --context labId="$LAB_ID" \
        --tags Project=AWSDevOpsLabs \
        --tags SessionId="$SESSION_ID" \
        --tags LabId="$LAB_ID"

elif [ -f "$LAB_DIR/main.tf" ]; then
    # Terraform deployment
    echo "Deploying Terraform configuration..."
    cd "$LAB_DIR"
    
    terraform init
    terraform plan \
        -var="session_id=$SESSION_ID" \
        -var="lab_id=$LAB_ID"
    terraform apply -auto-approve \
        -var="session_id=$SESSION_ID" \
        -var="lab_id=$LAB_ID"

else
    echo "No automated provisioning method found for lab: $LAB_ID"
    echo "Available methods:"
    echo "  - CloudFormation: templates/main.yaml or templates/infrastructure.yaml"
    echo "  - Lab-specific script: scripts/provision-${LAB_ID}.sh"
    echo "  - Generic script: scripts/provision.sh"
    echo "  - CDK: cdk.json"
    echo "  - Terraform: main.tf"
    echo ""
    echo "Please check lab documentation for manual setup instructions."
    echo "Lab guide: $LAB_DIR/lab-guide.md"
    exit 1
fi

# Record provisioning completion
echo "Recording provisioning completion..."
python3 -c "
import json
from datetime import datetime

session_data = {
    'session_id': '$SESSION_ID',
    'lab_id': '$LAB_ID',
    'stack_name': '$STACK_NAME',
    'region': '$REGION',
    'provisioned_at': datetime.now().isoformat(),
    'estimated_cost': $ESTIMATED_COST,
    'budget_limit': $BUDGET_LIMIT,
    'status': 'provisioned'
}

print(json.dumps(session_data, indent=2))
"

echo ""
echo "=========================================="
echo "✓ Provisioning completed successfully!"
echo "=========================================="
echo "Lab: $LAB_NAME"
echo "Session ID: $SESSION_ID"
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo "Estimated Cost: \$${ESTIMATED_COST}"
echo "Budget Limit: \$${BUDGET_LIMIT}"
echo ""
echo "Next steps:"
echo "1. Follow the lab guide: $LAB_DIR/lab-guide.md"
echo "2. Monitor costs in AWS Billing Dashboard"
echo "3. Run cleanup when finished: ./scripts/cleanup.sh $SESSION_ID"
echo ""
echo "IMPORTANT: All resources are tagged for automatic cleanup"