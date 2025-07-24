# Secrets Management Lab Guide

## Objective
Learn to securely manage application secrets using AWS Secrets Manager and Systems Manager Parameter Store. This lab covers storing, retrieving, and rotating secrets in a DevOps pipeline, implementing secure secret access patterns, and integrating secrets management with containerized applications.

## Learning Outcomes
By completing this lab, you will:
- Store and manage secrets using AWS Secrets Manager and Parameter Store
- Implement automatic secret rotation for database credentials
- Integrate secrets management into CI/CD pipelines
- Configure secure secret access for containerized applications
- Set up monitoring and alerting for secret access patterns

## Prerequisites
- AWS Account with administrative access
- AWS CLI configured with appropriate permissions
- Docker installed locally
- Basic understanding of containerization and databases
- Familiarity with AWS Lambda and ECS/Fargate

### Required AWS Permissions
Your AWS user/role needs the following permissions:
- **Secrets Manager**: Full access for creating and managing secrets
- **Systems Manager**: Full access for Parameter Store operations
- **IAM**: Full access for creating roles and policies
- **Lambda**: Full access for rotation functions
- **RDS**: Full access for database operations
- **ECS**: Full access for container deployments
- **CloudWatch**: Full access for monitoring and logging

### Time to Complete
Approximately 60-75 minutes

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Secrets Management Architecture              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐                    │
│  │   Developer     │    │   CI/CD         │                    │
│  │   Workstation   │    │   Pipeline      │                    │
│  └─────────┬───────┘    └─────────┬───────┘                    │
│            │                      │                            │
│            ▼                      ▼                            │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              AWS Secrets Manager                       │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │   │
│  │  │ DB Secrets  │  │ API Keys    │  │ Certificates│   │   │
│  │  │ (Auto-Rot)  │  │             │  │             │   │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                            │                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │           Systems Manager Parameter Store              │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │   │
│  │  │ Config      │  │ Feature     │  │ Environment │   │   │
│  │  │ Values      │  │ Flags       │  │ Variables   │   │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                            │                                   │
│                            ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                Application Layer                        │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │   │
│  │  │   Lambda    │  │    ECS      │  │    EC2      │   │   │
│  │  │  Functions  │  │ Containers  │  │ Instances   │   │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                            │                                   │
│                            ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   Data Layer                           │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │   │
│  │  │    RDS      │  │  DynamoDB   │  │ External    │   │   │
│  │  │  Database   │  │             │  │ APIs        │   │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Monitoring & Alerting                     │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │   │
│  │  │ CloudTrail  │  │ CloudWatch  │  │    SNS      │   │   │
│  │  │   Logs      │  │   Metrics   │  │   Alerts    │   │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘   │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Resources Created:
- **Secrets Manager Secrets**: Database credentials with automatic rotation
- **Parameter Store Parameters**: Configuration values and API keys
- **RDS Database**: Test database for credential rotation
- **Lambda Functions**: Secret rotation and retrieval functions
- **IAM Roles**: Service roles for secure secret access
- **ECS Task**: Containerized application demonstrating secret usage
- **CloudWatch Alarms**: Monitoring for secret access patterns

## Lab Steps

### Step 1: Set Up Parameter Store for Configuration Management

1. **Create standard parameters for application configuration:**
   ```bash
   # Create application configuration parameters
   aws ssm put-parameter \
       --name "/myapp/dev/database/host" \
       --value "dev-db.example.com" \
       --type "String" \
       --description "Development database host"
   
   aws ssm put-parameter \
       --name "/myapp/dev/database/port" \
       --value "5432" \
       --type "String" \
       --description "Development database port"
   
   aws ssm put-parameter \
       --name "/myapp/dev/api/timeout" \
       --value "30" \
       --type "String" \
       --description "API timeout in seconds"
   ```

2. **Create secure string parameters for sensitive configuration:**
   ```bash
   # Create encrypted parameters using default KMS key
   aws ssm put-parameter \
       --name "/myapp/dev/api/key" \
       --value "dev-api-key-12345" \
       --type "SecureString" \
       --description "Development API key"
   
   aws ssm put-parameter \
       --name "/myapp/dev/encryption/salt" \
       --value "random-salt-value-67890" \
       --type "SecureString" \
       --description "Encryption salt for development"
   ```

3. **Create hierarchical parameters for different environments:**
   ```bash
   # Production parameters
   aws ssm put-parameter \
       --name "/myapp/prod/database/host" \
       --value "prod-db.example.com" \
       --type "String" \
       --description "Production database host"
   
   aws ssm put-parameter \
       --name "/myapp/prod/api/key" \
       --value "prod-api-key-98765" \
       --type "SecureString" \
       --description "Production API key"
   ```

4. **Verify parameter creation:**
   ```bash
   # List all parameters for the application
   aws ssm get-parameters-by-path \
       --path "/myapp" \
       --recursive \
       --query 'Parameters[*].[Name,Type,Value]' \
       --output table
   ```

### Step 2: Create RDS Database for Secrets Manager Integration

1. **Create a simple RDS database for testing:**
   ```bash
   # Create DB subnet group (using default VPC)
   DEFAULT_VPC=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text)
   SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$DEFAULT_VPC" --query 'Subnets[*].SubnetId' --output text)
   SUBNET1=$(echo $SUBNETS | cut -d' ' -f1)
   SUBNET2=$(echo $SUBNETS | cut -d' ' -f2)
   
   aws rds create-db-subnet-group \
       --db-subnet-group-name secrets-lab-subnet-group \
       --db-subnet-group-description "Subnet group for secrets lab" \
       --subnet-ids $SUBNET1 $SUBNET2
   ```

2. **Create security group for RDS:**
   ```bash
   # Create security group
   SG_ID=$(aws ec2 create-security-group \
       --group-name secrets-lab-rds-sg \
       --description "Security group for secrets lab RDS" \
       --vpc-id $DEFAULT_VPC \
       --query 'GroupId' --output text)
   
   # Allow PostgreSQL access from within VPC
   VPC_CIDR=$(aws ec2 describe-vpcs --vpc-ids $DEFAULT_VPC --query 'Vpcs[0].CidrBlock' --output text)
   aws ec2 authorize-security-group-ingress \
       --group-id $SG_ID \
       --protocol tcp \
       --port 5432 \
       --cidr $VPC_CIDR
   ```

3. **Create RDS instance:**
   ```bash
   aws rds create-db-instance \
       --db-instance-identifier secrets-lab-db \
       --db-instance-class db.t3.micro \
       --engine postgres \
       --master-username dbadmin \
       --master-user-password TempPassword123! \
       --allocated-storage 20 \
       --db-subnet-group-name secrets-lab-subnet-group \
       --vpc-security-group-ids $SG_ID \
       --backup-retention-period 1 \
       --no-multi-az \
       --no-publicly-accessible
   
   echo "Waiting for RDS instance to be available (this may take 5-10 minutes)..."
   aws rds wait db-instance-available --db-instance-identifier secrets-lab-db
   ```

### Step 3: Store Database Credentials in Secrets Manager

1. **Get RDS endpoint:**
   ```bash
   DB_ENDPOINT=$(aws rds describe-db-instances \
       --db-instance-identifier secrets-lab-db \
       --query 'DBInstances[0].Endpoint.Address' \
       --output text)
   echo "Database endpoint: $DB_ENDPOINT"
   ```

2. **Create database secret in Secrets Manager:**
   ```bash
   cat > db-secret.json << EOF
   {
       "username": "dbadmin",
       "password": "TempPassword123!",
       "engine": "postgres",
       "host": "$DB_ENDPOINT",
       "port": 5432,
       "dbname": "postgres"
   }
   EOF
   
   aws secretsmanager create-secret \
       --name "secrets-lab/database/credentials" \
       --description "Database credentials for secrets lab" \
       --secret-string file://db-secret.json
   ```

3. **Set up automatic rotation:**
   ```bash
   # First, create a Lambda function for rotation
   cat > rotation-function.py << 'EOF'
   import json
   import boto3
   import logging
   import os
   import psycopg2
   from botocore.exceptions import ClientError
   
   logger = logging.getLogger()
   logger.setLevel(logging.INFO)
   
   def lambda_handler(event, context):
       """AWS Secrets Manager rotation function for PostgreSQL"""
       
       service = boto3.client('secretsmanager')
       
       # Get the secret ARN and token from the event
       secret_arn = event['SecretId']
       token = event['ClientRequestToken']
       step = event['Step']
       
       logger.info(f"Rotation step: {step} for secret: {secret_arn}")
       
       try:
           if step == "createSecret":
               create_secret(service, secret_arn, token)
           elif step == "setSecret":
               set_secret(service, secret_arn, token)
           elif step == "testSecret":
               test_secret(service, secret_arn, token)
           elif step == "finishSecret":
               finish_secret(service, secret_arn, token)
           else:
               logger.error(f"Invalid step parameter: {step}")
               raise ValueError(f"Invalid step parameter: {step}")
               
       except Exception as e:
           logger.error(f"Rotation failed: {str(e)}")
           raise e
       
       return {"statusCode": 200}
   
   def create_secret(service, secret_arn, token):
       """Generate a new secret version with a new password"""
       try:
           service.get_secret_value(SecretId=secret_arn, VersionId=token, VersionStage="AWSPENDING")
           logger.info("Secret version already exists")
       except ClientError:
           # Generate new password
           current_secret = service.get_secret_value(SecretId=secret_arn, VersionStage="AWSCURRENT")
           secret_dict = json.loads(current_secret['SecretString'])
           
           # Generate new password (simplified for demo)
           import random
           import string
           new_password = ''.join(random.choices(string.ascii_letters + string.digits, k=16))
           secret_dict['password'] = new_password
           
           service.put_secret_value(
               SecretId=secret_arn,
               ClientRequestToken=token,
               SecretString=json.dumps(secret_dict),
               VersionStages=['AWSPENDING']
           )
           logger.info("New secret version created")
   
   def set_secret(service, secret_arn, token):
       """Update the database with the new password"""
       logger.info("Setting new password in database (simplified for demo)")
       # In a real implementation, you would connect to the database and update the password
       
   def test_secret(service, secret_arn, token):
       """Test the new secret by connecting to the database"""
       logger.info("Testing new secret (simplified for demo)")
       # In a real implementation, you would test the database connection
       
   def finish_secret(service, secret_arn, token):
       """Finalize the rotation by updating the AWSCURRENT version"""
       service.update_secret_version_stage(
           SecretId=secret_arn,
           VersionStage="AWSCURRENT",
           ClientRequestToken=token,
           RemoveFromVersionId=service.describe_secret(SecretId=secret_arn)['VersionIdsToStages']
       )
       logger.info("Rotation completed successfully")
   EOF
   
   # Create deployment package
   zip rotation-function.zip rotation-function.py
   ```

4. **Create IAM role for rotation Lambda:**
   ```bash
   cat > rotation-trust-policy.json << 'EOF'
   {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Effect": "Allow",
               "Principal": {
                   "Service": "lambda.amazonaws.com"
               },
               "Action": "sts:AssumeRole"
           }
       ]
   }
   EOF
   
   aws iam create-role \
       --role-name SecretsManagerRotationRole \
       --assume-role-policy-document file://rotation-trust-policy.json
   
   # Attach necessary policies
   aws iam attach-role-policy \
       --role-name SecretsManagerRotationRole \
       --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
   
   aws iam attach-role-policy \
       --role-name SecretsManagerRotationRole \
       --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite
   ```

5. **Create rotation Lambda function:**
   ```bash
   ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
   
   aws lambda create-function \
       --function-name secrets-rotation-function \
       --runtime python3.9 \
       --role arn:aws:iam::${ACCOUNT_ID}:role/SecretsManagerRotationRole \
       --handler rotation-function.lambda_handler \
       --zip-file fileb://rotation-function.zip \
       --timeout 60 \
       --description "Secrets Manager rotation function for PostgreSQL"
   ```

### Step 4: Create Application Roles for Secret Access

1. **Create ECS task role for secret access:**
   ```bash
   cat > ecs-trust-policy.json << 'EOF'
   {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Effect": "Allow",
               "Principal": {
                   "Service": "ecs-tasks.amazonaws.com"
               },
               "Action": "sts:AssumeRole"
           }
       ]
   }
   EOF
   
   aws iam create-role \
       --role-name ECSSecretsAccessRole \
       --assume-role-policy-document file://ecs-trust-policy.json
   ```

2. **Create custom policy for secret access:**
   ```bash
   cat > secrets-access-policy.json << 'EOF'
   {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Effect": "Allow",
               "Action": [
                   "secretsmanager:GetSecretValue"
               ],
               "Resource": [
                   "arn:aws:secretsmanager:*:*:secret:secrets-lab/*"
               ]
           },
           {
               "Effect": "Allow",
               "Action": [
                   "ssm:GetParameter",
                   "ssm:GetParameters",
                   "ssm:GetParametersByPath"
               ],
               "Resource": [
                   "arn:aws:ssm:*:*:parameter/myapp/*"
               ]
           }
       ]
   }
   EOF
   
   aws iam create-policy \
       --policy-name SecretsAccessPolicy \
       --policy-document file://secrets-access-policy.json
   
   # Attach policy to role
   POLICY_ARN=$(aws iam list-policies --query 'Policies[?PolicyName==`SecretsAccessPolicy`].Arn' --output text)
   aws iam attach-role-policy \
       --role-name ECSSecretsAccessRole \
       --policy-arn $POLICY_ARN
   ```

### Step 5: Create Sample Application with Secret Integration

1. **Create a simple Python application that uses secrets:**
   ```bash
   mkdir -p sample-app
   cat > sample-app/app.py << 'EOF'
   import json
   import boto3
   import os
   import logging
   from botocore.exceptions import ClientError
   
   # Configure logging
   logging.basicConfig(level=logging.INFO)
   logger = logging.getLogger(__name__)
   
   class SecretsManager:
       def __init__(self):
           self.secrets_client = boto3.client('secretsmanager')
           self.ssm_client = boto3.client('ssm')
       
       def get_secret(self, secret_name):
           """Retrieve secret from AWS Secrets Manager"""
           try:
               response = self.secrets_client.get_secret_value(SecretId=secret_name)
               return json.loads(response['SecretString'])
           except ClientError as e:
               logger.error(f"Error retrieving secret {secret_name}: {e}")
               raise
       
       def get_parameter(self, parameter_name, decrypt=False):
           """Retrieve parameter from Systems Manager Parameter Store"""
           try:
               response = self.ssm_client.get_parameter(
                   Name=parameter_name,
                   WithDecryption=decrypt
               )
               return response['Parameter']['Value']
           except ClientError as e:
               logger.error(f"Error retrieving parameter {parameter_name}: {e}")
               raise
       
       def get_parameters_by_path(self, path, decrypt=False):
           """Retrieve multiple parameters by path"""
           try:
               response = self.ssm_client.get_parameters_by_path(
                   Path=path,
                   Recursive=True,
                   WithDecryption=decrypt
               )
               return {param['Name']: param['Value'] for param in response['Parameters']}
           except ClientError as e:
               logger.error(f"Error retrieving parameters from path {path}: {e}")
               raise
   
   def main():
       """Main application function"""
       secrets_manager = SecretsManager()
       
       try:
           # Get database credentials from Secrets Manager
           logger.info("Retrieving database credentials...")
           db_credentials = secrets_manager.get_secret("secrets-lab/database/credentials")
           logger.info(f"Database host: {db_credentials['host']}")
           
           # Get application configuration from Parameter Store
           logger.info("Retrieving application configuration...")
           app_config = secrets_manager.get_parameters_by_path("/myapp/dev", decrypt=True)
           
           for param_name, param_value in app_config.items():
               if 'key' in param_name.lower() or 'password' in param_name.lower():
                   logger.info(f"{param_name}: [REDACTED]")
               else:
                   logger.info(f"{param_name}: {param_value}")
           
           # Simulate application startup
           logger.info("Application started successfully with secrets loaded")
           
           # In a real application, you would use these credentials to connect to services
           # For example: connect to database, authenticate with APIs, etc.
           
       except Exception as e:
           logger.error(f"Application startup failed: {e}")
           raise
   
   if __name__ == "__main__":
       main()
   EOF
   ```

2. **Create Dockerfile for the application:**
   ```bash
   cat > sample-app/Dockerfile << 'EOF'
   FROM python:3.9-slim
   
   # Install required packages
   RUN pip install boto3
   
   # Copy application code
   COPY app.py /app/app.py
   
   # Set working directory
   WORKDIR /app
   
   # Run the application
   CMD ["python", "app.py"]
   EOF
   ```

3. **Create requirements.txt:**
   ```bash
   cat > sample-app/requirements.txt << 'EOF'
   boto3>=1.26.0
   botocore>=1.29.0
   EOF
   ```

### Step 6: Deploy Application Using ECS with Secrets

1. **Build and push Docker image to ECR:**
   ```bash
   # Create ECR repository
   aws ecr create-repository --repository-name secrets-lab-app
   
   # Get login token
   aws ecr get-login-password --region $(aws configure get region) | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.$(aws configure get region).amazonaws.com
   
   # Build and tag image
   cd sample-app
   docker build -t secrets-lab-app .
   docker tag secrets-lab-app:latest ${ACCOUNT_ID}.dkr.ecr.$(aws configure get region).amazonaws.com/secrets-lab-app:latest
   
   # Push image
   docker push ${ACCOUNT_ID}.dkr.ecr.$(aws configure get region).amazonaws.com/secrets-lab-app:latest
   cd ..
   ```

2. **Create ECS cluster:**
   ```bash
   aws ecs create-cluster --cluster-name secrets-lab-cluster
   ```

3. **Create ECS task definition with secrets:**
   ```bash
   cat > task-definition.json << EOF
   {
       "family": "secrets-lab-task",
       "networkMode": "awsvpc",
       "requiresCompatibilities": ["FARGATE"],
       "cpu": "256",
       "memory": "512",
       "executionRoleArn": "arn:aws:iam::${ACCOUNT_ID}:role/ecsTaskExecutionRole",
       "taskRoleArn": "arn:aws:iam::${ACCOUNT_ID}:role/ECSSecretsAccessRole",
       "containerDefinitions": [
           {
               "name": "secrets-app",
               "image": "${ACCOUNT_ID}.dkr.ecr.$(aws configure get region).amazonaws.com/secrets-lab-app:latest",
               "essential": true,
               "logConfiguration": {
                   "logDriver": "awslogs",
                   "options": {
                       "awslogs-group": "/ecs/secrets-lab",
                       "awslogs-region": "$(aws configure get region)",
                       "awslogs-stream-prefix": "ecs"
                   }
               },
               "environment": [
                   {
                       "name": "AWS_DEFAULT_REGION",
                       "value": "$(aws configure get region)"
                   }
               ]
           }
       ]
   }
   EOF
   
   # Create CloudWatch log group
   aws logs create-log-group --log-group-name /ecs/secrets-lab
   
   # Register task definition
   aws ecs register-task-definition --cli-input-json file://task-definition.json
   ```

4. **Run the task:**
   ```bash
   # Get subnet IDs
   SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$DEFAULT_VPC" --query 'Subnets[*].SubnetId' --output text | tr '\t' ',')
   
   # Run task
   aws ecs run-task \
       --cluster secrets-lab-cluster \
       --task-definition secrets-lab-task \
       --launch-type FARGATE \
       --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_IDS],assignPublicIp=ENABLED}"
   ```

### Step 7: Set Up Monitoring and Alerting

1. **Create CloudWatch alarms for secret access:**
   ```bash
   # Create SNS topic for alerts
   aws sns create-topic --name secrets-security-alerts
   TOPIC_ARN=$(aws sns list-topics --query 'Topics[?contains(TopicArn, `secrets-security-alerts`)].TopicArn' --output text)
   
   # Create metric filter for secret access
   aws logs put-metric-filter \
       --log-group-name /aws/lambda/secrets-rotation-function \
       --filter-name SecretAccessCount \
       --filter-pattern '[timestamp, request_id, level="ERROR"]' \
       --metric-transformations \
           metricName=SecretAccessErrors,metricNamespace=SecretsManager,metricValue=1
   
   # Create alarm for secret access errors
   aws cloudwatch put-metric-alarm \
       --alarm-name "Secrets-Access-Errors" \
       --alarm-description "Alarm for secret access errors" \
       --metric-name SecretAccessErrors \
       --namespace SecretsManager \
       --statistic Sum \
       --period 300 \
       --threshold 1 \
       --comparison-operator GreaterThanOrEqualToThreshold \
       --evaluation-periods 1 \
       --alarm-actions $TOPIC_ARN
   ```

2. **Test secret retrieval:**
   ```bash
   # Test retrieving the database secret
   aws secretsmanager get-secret-value \
       --secret-id "secrets-lab/database/credentials" \
       --query 'SecretString' \
       --output text | jq .
   
   # Test retrieving parameters
   aws ssm get-parameters-by-path \
       --path "/myapp/dev" \
       --recursive \
       --with-decryption \
       --query 'Parameters[*].[Name,Value]' \
       --output table
   ```

## Troubleshooting Guide

### Common Issues and Solutions

1. **Secret not found or access denied:**
   - Verify the secret name and ARN are correct
   - Check IAM permissions for the calling role/user
   - Ensure the secret exists in the correct region

2. **Parameter Store access denied:**
   - Verify parameter path and name are correct
   - Check IAM permissions for SSM actions
   - Ensure WithDecryption=true for SecureString parameters

3. **ECS task fails to start:**
   - Check CloudWatch logs for error messages
   - Verify task role has necessary permissions
   - Ensure ECR image is accessible

4. **Rotation function fails:**
   - Check Lambda function logs in CloudWatch
   - Verify database connectivity from Lambda
   - Ensure rotation role has necessary permissions

### Debugging Commands

```bash
# Check secret metadata
aws secretsmanager describe-secret --secret-id SECRET_NAME

# List all parameters in a path
aws ssm get-parameters-by-path --path "/myapp" --recursive

# Check ECS task status
aws ecs describe-tasks --cluster CLUSTER_NAME --tasks TASK_ARN

# View CloudWatch logs
aws logs get-log-events --log-group-name LOG_GROUP_NAME --log-stream-name LOG_STREAM_NAME

# Test IAM permissions
aws iam simulate-principal-policy \
    --policy-source-arn ROLE_ARN \
    --action-names secretsmanager:GetSecretValue \
    --resource-arns SECRET_ARN
```

## Resources Created

This lab creates the following AWS resources:

### Secrets and Configuration Management
- **Secrets Manager Secrets**: 1 database credential secret
- **Parameter Store Parameters**: 6 configuration parameters (3 standard, 3 secure)
- **Lambda Function**: 1 rotation function

### Database and Networking
- **RDS Instance**: 1 PostgreSQL database (db.t3.micro)
- **DB Subnet Group**: 1 subnet group for RDS
- **Security Group**: 1 security group for database access

### Container Infrastructure
- **ECR Repository**: 1 repository for application image
- **ECS Cluster**: 1 Fargate cluster
- **ECS Task Definition**: 1 task definition with secrets integration

### IAM and Security
- **IAM Roles**: 2 roles (rotation role, ECS task role)
- **IAM Policies**: 1 custom policy for secrets access

### Monitoring
- **CloudWatch Log Groups**: 2 log groups (Lambda, ECS)
- **CloudWatch Alarms**: 1 alarm for secret access errors
- **SNS Topic**: 1 topic for security alerts

### Estimated Costs
- **Secrets Manager**: $0.40/secret/month + $0.05/10,000 API calls
- **Parameter Store**: Free for standard parameters, $0.05/10,000 API calls for advanced
- **RDS (db.t3.micro)**: ~$13/month (free tier eligible for 12 months)
- **Lambda**: Free tier covers most usage
- **ECS Fargate**: $0.04048/vCPU/hour + $0.004445/GB/hour
- **ECR**: $0.10/GB/month for storage
- **CloudWatch**: $0.50/GB ingested + $0.03/GB stored
- **Total estimated cost**: $15-20/month (mostly RDS costs)

## Cleanup

When you're finished with the lab, follow these steps to avoid ongoing charges:

1. **Stop and delete ECS resources:**
   ```bash
   # Stop running tasks
   TASK_ARNS=$(aws ecs list-tasks --cluster secrets-lab-cluster --query 'taskArns' --output text)
   if [ ! -z "$TASK_ARNS" ]; then
       aws ecs stop-task --cluster secrets-lab-cluster --task $TASK_ARNS
   fi
   
   # Delete cluster
   aws ecs delete-cluster --cluster secrets-lab-cluster
   
   # Delete ECR repository
   aws ecr delete-repository --repository-name secrets-lab-app --force
   ```

2. **Delete Lambda function and IAM roles:**
   ```bash
   # Delete Lambda function
   aws lambda delete-function --function-name secrets-rotation-function
   
   # Detach and delete IAM policies and roles
   aws iam detach-role-policy --role-name SecretsManagerRotationRole --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
   aws iam detach-role-policy --role-name SecretsManagerRotationRole --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite
   aws iam delete-role --role-name SecretsManagerRotationRole
   
   aws iam detach-role-policy --role-name ECSSecretsAccessRole --policy-arn $POLICY_ARN
   aws iam delete-role --role-name ECSSecretsAccessRole
   aws iam delete-policy --policy-arn $POLICY_ARN
   ```

3. **Delete RDS database:**
   ```bash
   # Delete RDS instance (skip final snapshot for lab)
   aws rds delete-db-instance \
       --db-instance-identifier secrets-lab-db \
       --skip-final-snapshot
   
   # Wait for deletion to complete
   aws rds wait db-instance-deleted --db-instance-identifier secrets-lab-db
   
   # Delete subnet group and security group
   aws rds delete-db-subnet-group --db-subnet-group-name secrets-lab-subnet-group
   aws ec2 delete-security-group --group-id $SG_ID
   ```

4. **Delete secrets and parameters:**
   ```bash
   # Delete Secrets Manager secret
   aws secretsmanager delete-secret \
       --secret-id "secrets-lab/database/credentials" \
       --force-delete-without-recovery
   
   # Delete Parameter Store parameters
   aws ssm delete-parameter --name "/myapp/dev/database/host"
   aws ssm delete-parameter --name "/myapp/dev/database/port"
   aws ssm delete-parameter --name "/myapp/dev/api/timeout"
   aws ssm delete-parameter --name "/myapp/dev/api/key"
   aws ssm delete-parameter --name "/myapp/dev/encryption/salt"
   aws ssm delete-parameter --name "/myapp/prod/database/host"
   aws ssm delete-parameter --name "/myapp/prod/api/key"
   ```

5. **Delete monitoring resources:**
   ```bash
   # Delete CloudWatch alarms and log groups
   aws cloudwatch delete-alarms --alarm-names "Secrets-Access-Errors"
   aws logs delete-log-group --log-group-name /ecs/secrets-lab
   aws logs delete-log-group --log-group-name /aws/lambda/secrets-rotation-function
   
   # Delete SNS topic
   aws sns delete-topic --topic-arn $TOPIC_ARN
   ```

6. **Clean up local files:**
   ```bash
   rm -rf sample-app/
   rm -f db-secret.json rotation-function.py rotation-function.zip
   rm -f rotation-trust-policy.json ecs-trust-policy.json secrets-access-policy.json
   rm -f task-definition.json
   ```

> **Important**: Verify all resources are deleted to avoid unexpected charges, especially the RDS instance.

## Next Steps

After completing this lab, consider:

1. **Implement AWS Config** to monitor secrets and parameter compliance
2. **Explore AWS AppConfig** for dynamic configuration management
3. **Set up AWS Certificate Manager** for SSL/TLS certificate management
4. **Learn about AWS Key Management Service (KMS)** for advanced encryption
5. **Implement HashiCorp Vault** integration for hybrid secret management
6. **Practice with AWS Systems Manager Session Manager** for secure instance access

## Certification Exam Tips

This lab covers several key areas for the AWS DevOps Professional exam:

- **Domain 1**: SDLC Automation (secrets in CI/CD pipelines)
- **Domain 2**: Configuration Management and IaC (secrets as code)
- **Domain 3**: Monitoring and Logging (secrets access monitoring)
- **Domain 4**: Policies and Standards Automation (secrets policy automation)
- **Domain 5**: Incident and Event Response (secrets security monitoring)
- **Domain 6**: High Availability, Fault Tolerance, and Disaster Recovery (secrets backup and rotation)

Key concepts to remember:
- **Secrets Manager vs Parameter Store**: Use Secrets Manager for credentials with rotation, Parameter Store for configuration
- **Automatic Rotation**: Critical for database credentials and API keys
- **IAM Integration**: Least privilege access to secrets and parameters
- **Encryption**: All secrets encrypted at rest and in transit
- **Monitoring**: CloudTrail and CloudWatch for secrets access auditing
- **Cost Optimization**: Parameter Store is cheaper for simple configuration values
- **Regional Replication**: Secrets Manager supports cross-region replication

## Additional Resources

- [AWS Secrets Manager User Guide](https://docs.aws.amazon.com/secretsmanager/latest/userguide/)
- [AWS Systems Manager Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)
- [AWS Secrets Manager Rotation](https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html)
- [ECS Secrets Management](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/specifying-sensitive-data.html)
- [AWS Security Blog - Secrets Management](https://aws.amazon.com/blogs/security/category/security-identity-compliance/secrets-management/)
- [Best Practices for Managing AWS Access Keys](https://docs.aws.amazon.com/general/latest/gr/aws-access-keys-best-practices.html)