#!/bin/bash

# Security Scanning Lab Provisioning Script
# This script provisions the security scanning lab environment with
# CodeGuru Reviewer, ECR scanning, and SAST/DAST tools integration

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
STACK_NAME_PREFIX="security-scanning-lab"
REGION=${AWS_DEFAULT_REGION:-us-east-1}
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
APPLICATION_NAME="scanning-lab"
ENVIRONMENT="dev"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if AWS CLI is configured
check_aws_cli() {
    print_status "Checking AWS CLI configuration..."
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI is not configured or credentials are invalid."
        exit 1
    fi
    
    print_success "AWS CLI is properly configured"
}

# Function to check required permissions
check_permissions() {
    print_status "Checking required permissions..."
    
    # Check CodeGuru permissions
    if ! aws codeguru-reviewer list-repository-associations --max-results 1 &> /dev/null; then
        print_error "Insufficient CodeGuru Reviewer permissions."
        exit 1
    fi
    
    # Check ECR permissions
    if ! aws ecr describe-repositories --max-items 1 &> /dev/null; then
        print_error "Insufficient ECR permissions."
        exit 1
    fi
    
    # Check CodeBuild permissions
    if ! aws codebuild list-projects --max-results 1 &> /dev/null; then
        print_error "Insufficient CodeBuild permissions."
        exit 1
    fi
    
    print_success "Required permissions verified"
}

# Function to deploy CloudFormation stack
deploy_stack() {
    local template_file=$1
    local stack_name=$2
    local parameters=$3
    
    print_status "Deploying stack: ${stack_name}"
    
    # Check if stack exists
    if aws cloudformation describe-stacks --stack-name "$stack_name" --region "$REGION" &> /dev/null; then
        print_status "Stack exists, updating..."
        aws cloudformation update-stack \
            --stack-name "$stack_name" \
            --template-body "file://$template_file" \
            --parameters "$parameters" \
            --capabilities CAPABILITY_NAMED_IAM \
            --region "$REGION" || {
                if [[ $? -eq 255 ]]; then
                    print_warning "No updates to perform for stack $stack_name"
                else
                    print_error "Failed to update stack $stack_name"
                    return 1
                fi
            }
    else
        print_status "Creating new stack..."
        aws cloudformation create-stack \
            --stack-name "$stack_name" \
            --template-body "file://$template_file" \
            --parameters "$parameters" \
            --capabilities CAPABILITY_NAMED_IAM \
            --region "$REGION"
    fi
    
    # Wait for stack operation to complete
    print_status "Waiting for stack operation to complete..."
    aws cloudformation wait stack-create-complete --stack-name "$stack_name" --region "$REGION" 2>/dev/null || \
    aws cloudformation wait stack-update-complete --stack-name "$stack_name" --region "$REGION" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        print_success "Stack $stack_name deployed successfully"
    else
        print_error "Stack $stack_name deployment failed"
        return 1
    fi
}

# Function to deploy CodeGuru Reviewer integration
deploy_codeguru_integration() {
    local stack_name="${STACK_NAME_PREFIX}-codeguru"
    local template_file="templates/codeguru-reviewer-integration.yaml"
    
    if [ ! -f "$template_file" ]; then
        print_error "Template file not found: $template_file"
        return 1
    fi
    
    # Prompt for notification email
    read -p "Enter email address for CodeGuru notifications: " notification_email
    if [ -z "$notification_email" ]; then
        notification_email="admin@example.com"
        print_warning "Using default email: $notification_email"
    fi
    
    local parameters="ParameterKey=ApplicationName,ParameterValue=${APPLICATION_NAME} ParameterKey=Environment,ParameterValue=${ENVIRONMENT} ParameterKey=NotificationEmail,ParameterValue=${notification_email}"
    
    deploy_stack "$template_file" "$stack_name" "$parameters"
}

# Function to deploy container image scanning
deploy_container_scanning() {
    local stack_name="${STACK_NAME_PREFIX}-container-scanning"
    local template_file="templates/container-image-scanning.yaml"
    
    if [ ! -f "$template_file" ]; then
        print_error "Template file not found: $template_file"
        return 1
    fi
    
    # Prompt for notification email
    read -p "Enter email address for vulnerability notifications: " notification_email
    if [ -z "$notification_email" ]; then
        notification_email="security@example.com"
        print_warning "Using default email: $notification_email"
    fi
    
    local parameters="ParameterKey=ApplicationName,ParameterValue=${APPLICATION_NAME} ParameterKey=Environment,ParameterValue=${ENVIRONMENT} ParameterKey=NotificationEmail,ParameterValue=${notification_email}"
    
    deploy_stack "$template_file" "$stack_name" "$parameters"
}

# Function to deploy SAST/DAST integration
deploy_sast_dast_integration() {
    local stack_name="${STACK_NAME_PREFIX}-sast-dast"
    local template_file="templates/sast-dast-integration.yaml"
    
    if [ ! -f "$template_file" ]; then
        print_error "Template file not found: $template_file"
        return 1
    fi
    
    # Prompt for target application URL
    read -p "Enter target application URL for DAST scanning (default: https://example.com): " target_url
    if [ -z "$target_url" ]; then
        target_url="https://example.com"
    fi
    
    # Prompt for notification email
    read -p "Enter email address for security notifications: " notification_email
    if [ -z "$notification_email" ]; then
        notification_email="security@example.com"
        print_warning "Using default email: $notification_email"
    fi
    
    local parameters="ParameterKey=ApplicationName,ParameterValue=${APPLICATION_NAME} ParameterKey=Environment,ParameterValue=${ENVIRONMENT} ParameterKey=TargetApplicationURL,ParameterValue=${target_url} ParameterKey=NotificationEmail,ParameterValue=${notification_email}"
    
    deploy_stack "$template_file" "$stack_name" "$parameters"
}

# Function to create sample vulnerable code
create_sample_code() {
    print_status "Creating sample vulnerable code for testing..."
    
    mkdir -p sample-code
    
    # Create Python file with security issues
    cat > sample-code/vulnerable_app.py << 'EOF'
import os
import subprocess
import sqlite3
from flask import Flask, request, render_template_string

app = Flask(__name__)

# Hardcoded credentials (security issue)
DATABASE_PASSWORD = "admin123"
API_KEY = "sk-1234567890abcdef"

@app.route('/search')
def search():
    query = request.args.get('q')
    # SQL injection vulnerability
    conn = sqlite3.connect('app.db')
    cursor = conn.cursor()
    cursor.execute(f"SELECT * FROM users WHERE name = '{query}'")
    results = cursor.fetchall()
    conn.close()
    return str(results)

@app.route('/execute')
def execute():
    cmd = request.args.get('cmd')
    # Command injection vulnerability
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return result.stdout

@app.route('/template')
def template():
    name = request.args.get('name')
    # Template injection vulnerability
    template = f"<h1>Hello {name}!</h1>"
    return render_template_string(template)

@app.route('/file')
def read_file():
    filename = request.args.get('file')
    # Path traversal vulnerability
    with open(f"/app/files/{filename}", 'r') as f:
        return f.read()

if __name__ == '__main__':
    # Debug mode enabled (security issue)
    app.run(debug=True, host='0.0.0.0')
EOF
    
    # Create JavaScript file with security issues
    cat > sample-code/vulnerable_app.js << 'EOF'
const express = require('express');
const mysql = require('mysql');
const app = express();

// Hardcoded credentials
const DB_PASSWORD = "admin123";
const JWT_SECRET = "secret123";

// Insecure database connection
const db = mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: DB_PASSWORD,
    database: 'app'
});

app.get('/search', (req, res) => {
    const query = req.query.q;
    // SQL injection vulnerability
    const sql = `SELECT * FROM users WHERE name = '${query}'`;
    db.query(sql, (err, results) => {
        if (err) throw err;
        res.json(results);
    });
});

app.get('/eval', (req, res) => {
    const code = req.query.code;
    // Code injection vulnerability
    const result = eval(code);
    res.json({result: result});
});

app.get('/redirect', (req, res) => {
    const url = req.query.url;
    // Open redirect vulnerability
    res.redirect(url);
});

// Insecure cookie settings
app.use((req, res, next) => {
    res.cookie('session', 'value', {
        httpOnly: false,
        secure: false,
        sameSite: 'none'
    });
    next();
});

app.listen(3000, () => {
    console.log('Server running on port 3000');
});
EOF
    
    # Create requirements.txt
    cat > sample-code/requirements.txt << 'EOF'
Flask==1.0.2
requests==2.20.0
pyyaml==3.13
EOF
    
    # Create package.json
    cat > sample-code/package.json << 'EOF'
{
  "name": "vulnerable-app",
  "version": "1.0.0",
  "dependencies": {
    "express": "4.16.0",
    "mysql": "2.15.0",
    "lodash": "4.17.4"
  }
}
EOF
    
    print_success "Sample vulnerable code created in sample-code/ directory"
}

# Function to run initial security scans
run_initial_scans() {
    print_status "Running initial security scans..."
    
    # Get CodeBuild project names from CloudFormation outputs
    local sast_project=$(aws cloudformation describe-stacks \
        --stack-name "${STACK_NAME_PREFIX}-sast-dast" \
        --query 'Stacks[0].Outputs[?OutputKey==`SASTScanProjectName`].OutputValue' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    local dast_project=$(aws cloudformation describe-stacks \
        --stack-name "${STACK_NAME_PREFIX}-sast-dast" \
        --query 'Stacks[0].Outputs[?OutputKey==`DASTScanProjectName`].OutputValue' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "")
    
    # Start SAST scan
    if [ -n "$sast_project" ]; then
        print_status "Starting SAST security scan..."
        aws codebuild start-build --project-name "$sast_project" --region "$REGION" &> /dev/null || true
        print_success "SAST scan initiated"
    fi
    
    # Start DAST scan
    if [ -n "$dast_project" ]; then
        print_status "Starting DAST security scan..."
        aws codebuild start-build --project-name "$dast_project" --region "$REGION" &> /dev/null || true
        print_success "DAST scan initiated"
    fi
}

# Function to display lab information
display_lab_info() {
    print_success "Security Scanning Lab provisioned successfully!"
    echo
    echo "=== Lab Resources ==="
    echo "CloudFormation Stacks:"
    echo "  - ${STACK_NAME_PREFIX}-codeguru"
    echo "  - ${STACK_NAME_PREFIX}-container-scanning"
    echo "  - ${STACK_NAME_PREFIX}-sast-dast"
    echo
    echo "Security Scanning Tools:"
    echo "  - CodeGuru Reviewer (automated code analysis)"
    echo "  - ECR Image Scanning (container vulnerability scanning)"
    echo "  - SAST Tools (Bandit, ESLint, Semgrep)"
    echo "  - DAST Tools (OWASP ZAP, Nikto, Nmap)"
    echo
    echo "=== Next Steps ==="
    echo "1. Review the lab guide: lab-guide.md"
    echo "2. Test with sample vulnerable code: cd sample-code"
    echo "3. Push code to trigger CodeGuru analysis"
    echo "4. Build and push container images to ECR for scanning"
    echo "5. Monitor security scan results in S3 and CloudWatch"
    echo
    echo "=== Important Commands ==="
    
    # Get project names from CloudFormation outputs
    local sast_project=$(aws cloudformation describe-stacks \
        --stack-name "${STACK_NAME_PREFIX}-sast-dast" \
        --query 'Stacks[0].Outputs[?OutputKey==`SASTScanProjectName`].OutputValue' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "N/A")
    
    local dast_project=$(aws cloudformation describe-stacks \
        --stack-name "${STACK_NAME_PREFIX}-sast-dast" \
        --query 'Stacks[0].Outputs[?OutputKey==`DASTScanProjectName`].OutputValue' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "N/A")
    
    local ecr_repo=$(aws cloudformation describe-stacks \
        --stack-name "${STACK_NAME_PREFIX}-container-scanning" \
        --query 'Stacks[0].Outputs[?OutputKey==`ECRRepositoryURI`].OutputValue' \
        --output text \
        --region "$REGION" 2>/dev/null || echo "N/A")
    
    echo "# Run SAST scan:"
    echo "aws codebuild start-build --project-name $sast_project"
    echo
    echo "# Run DAST scan:"
    echo "aws codebuild start-build --project-name $dast_project"
    echo
    echo "# Push container image for scanning:"
    echo "docker tag myapp:latest $ecr_repo:latest"
    echo "docker push $ecr_repo:latest"
    echo
    echo "=== Cleanup ==="
    echo "Run cleanup script when finished: scripts/cleanup-scanning-lab.sh"
    echo
}

# Function to validate deployment
validate_deployment() {
    print_status "Validating deployment..."
    
    # Check CloudFormation stacks
    local stacks=("${STACK_NAME_PREFIX}-codeguru" "${STACK_NAME_PREFIX}-container-scanning" "${STACK_NAME_PREFIX}-sast-dast")
    
    for stack in "${stacks[@]}"; do
        local status=$(aws cloudformation describe-stacks \
            --stack-name "$stack" \
            --query 'Stacks[0].StackStatus' \
            --output text \
            --region "$REGION" 2>/dev/null || echo "NOT_FOUND")
        
        if [[ "$status" == "CREATE_COMPLETE" || "$status" == "UPDATE_COMPLETE" ]]; then
            print_success "Stack $stack: $status"
        else
            print_error "Stack $stack: $status"
            return 1
        fi
    done
    
    print_success "Deployment validation completed successfully"
}

# Main execution
main() {
    echo "=== Security Scanning Lab Provisioning ==="
    echo
    
    # Pre-flight checks
    check_aws_cli
    check_permissions
    
    # Deploy infrastructure
    deploy_codeguru_integration
    deploy_container_scanning
    deploy_sast_dast_integration
    
    # Create sample resources
    create_sample_code
    
    # Run initial scans
    run_initial_scans
    
    # Validate and display information
    validate_deployment
    display_lab_info
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --validate     Only run validation checks"
        echo
        echo "Environment Variables:"
        echo "  AWS_DEFAULT_REGION    AWS region (default: us-east-1)"
        echo
        exit 0
        ;;
    --validate)
        validate_deployment
        exit 0
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac