# Database Integration Lab Guide

## Objective
Learn how to implement database integration patterns with AWS RDS, demonstrating how to set up, connect to, and manage relational databases in a secure and scalable manner for application integration.

## Learning Outcomes
By completing this lab, you will:
- Deploy and configure an Amazon RDS database instance
- Implement secure database access patterns
- Set up connection pooling and management
- Configure database monitoring and logging
- Implement backup and recovery strategies
- Create application integration with RDS

## Prerequisites
- AWS Account with administrative access
- Basic understanding of SQL and relational databases
- Familiarity with networking concepts (VPC, subnets, security groups)
- AWS CLI installed and configured

### Required AWS Permissions
Your AWS user/role needs the following permissions:
- RDS: Full access for creating and managing database instances
- EC2: Full access for VPC, security groups, and EC2 instance management
- IAM: CreateRole, AttachRolePolicy for execution roles
- CloudWatch: Full access for logs and monitoring
- Secrets Manager: Full access for database credentials management
- Lambda: Full access for serverless database access (optional)

### Time to Complete
Approximately 90-120 minutes

## Architecture Overview

```
┌───────────────┐     ┌───────────────┐     ┌───────────────┐
│               │     │               │     │               │
│  EC2 Instance │────►│  RDS          │◄────┤  Lambda       │
│  (App Server) │     │  Database     │     │  Function     │
│               │     │               │     │               │
└───────┬───────┘     └───────┬───────┘     └───────────────┘
        │                     │
        │                     │
┌───────▼───────┐     ┌───────▼───────┐     ┌───────────────┐
│               │     │               │     │               │
│  Secrets      │     │  CloudWatch   │     │  RDS Proxy    │
│  Manager      │     │  Logs/Metrics │     │  (Optional)   │
│               │     │               │     │               │
└───────────────┘     └───────────────┘     └───────────────┘
```

### Resources Created:
- **RDS Database Instance**: MySQL database for application data
- **EC2 Instance**: Application server for database connectivity
- **Lambda Function**: Serverless database access
- **VPC**: Network infrastructure with public and private subnets
- **Security Groups**: Network access controls for RDS and EC2
- **Secrets Manager Secret**: Secure storage for database credentials
- **RDS Proxy**: Connection pooling for efficient database access (optional)
- **CloudWatch Alarms**: Monitoring for database performance

## Lab Steps

### Step 1: Create VPC and Networking Components

1. **Create a VPC for the database environment:**
   ```bash
   # Create VPC
   aws ec2 create-vpc \
     --cidr-block 10.0.0.0/16 \
     --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=rds-integration-vpc}]'
   
   # Get VPC ID
   VPC_ID=$(aws ec2 describe-vpcs \
     --filters "Name=tag:Name,Values=rds-integration-vpc" \
     --query 'Vpcs[0].VpcId' --output text)
   ```

2. **Create public and private subnets:**
   ```bash
   # Get availability zones
   AZ_1=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].ZoneName' --output text)
   AZ_2=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[1].ZoneName' --output text)
   
   # Create public subnet 1
   aws ec2 create-subnet \
     --vpc-id $VPC_ID \
     --cidr-block 10.0.1.0/24 \
     --availability-zone $AZ_1 \
     --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=rds-public-subnet-1}]'
   
   # Create public subnet 2
   aws ec2 create-subnet \
     --vpc-id $VPC_ID \
     --cidr-block 10.0.2.0/24 \
     --availability-zone $AZ_2 \
     --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=rds-public-subnet-2}]'
   
   # Create private subnet 1
   aws ec2 create-subnet \
     --vpc-id $VPC_ID \
     --cidr-block 10.0.3.0/24 \
     --availability-zone $AZ_1 \
     --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=rds-private-subnet-1}]'
   
   # Create private subnet 2
   aws ec2 create-subnet \
     --vpc-id $VPC_ID \
     --cidr-block 10.0.4.0/24 \
     --availability-zone $AZ_2 \
     --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=rds-private-subnet-2}]'
   ```

3. **Create and attach Internet Gateway:**
   ```bash
   # Create Internet Gateway
   aws ec2 create-internet-gateway \
     --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=rds-integration-igw}]'
   
   # Get IGW ID
   IGW_ID=$(aws ec2 describe-internet-gateways \
     --filters "Name=tag:Name,Values=rds-integration-igw" \
     --query 'InternetGateways[0].InternetGatewayId' --output text)
   
   # Attach IGW to VPC
   aws ec2 attach-internet-gateway \
     --internet-gateway-id $IGW_ID \
     --vpc-id $VPC_ID
   ```

4. **Create route tables and associations:**
   ```bash
   # Create public route table
   aws ec2 create-route-table \
     --vpc-id $VPC_ID \
     --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=rds-public-rt}]'
   
   # Get public route table ID
   PUBLIC_RT_ID=$(aws ec2 describe-route-tables \
     --filters "Name=tag:Name,Values=rds-public-rt" \
     --query 'RouteTables[0].RouteTableId' --output text)
   
   # Create route to Internet Gateway
   aws ec2 create-route \
     --route-table-id $PUBLIC_RT_ID \
     --destination-cidr-block 0.0.0.0/0 \
     --gateway-id $IGW_ID
   
   # Get public subnet IDs
   PUBLIC_SUBNET_1_ID=$(aws ec2 describe-subnets \
     --filters "Name=tag:Name,Values=rds-public-subnet-1" \
     --query 'Subnets[0].SubnetId' --output text)
   
   PUBLIC_SUBNET_2_ID=$(aws ec2 describe-subnets \
     --filters "Name=tag:Name,Values=rds-public-subnet-2" \
     --query 'Subnets[0].SubnetId' --output text)
   
   # Associate public subnets with public route table
   aws ec2 associate-route-table \
     --route-table-id $PUBLIC_RT_ID \
     --subnet-id $PUBLIC_SUBNET_1_ID
   
   aws ec2 associate-route-table \
     --route-table-id $PUBLIC_RT_ID \
     --subnet-id $PUBLIC_SUBNET_2_ID
   ```

5. **Get private subnet IDs for later use:**
   ```bash
   # Get private subnet IDs
   PRIVATE_SUBNET_1_ID=$(aws ec2 describe-subnets \
     --filters "Name=tag:Name,Values=rds-private-subnet-1" \
     --query 'Subnets[0].SubnetId' --output text)
   
   PRIVATE_SUBNET_2_ID=$(aws ec2 describe-subnets \
     --filters "Name=tag:Name,Values=rds-private-subnet-2" \
     --query 'Subnets[0].SubnetId' --output text)
   ```

### Step 2: Create Security Groups

1. **Create security group for RDS:**
   ```bash
   # Create RDS security group
   aws ec2 create-security-group \
     --group-name rds-sg \
     --description "Security group for RDS database" \
     --vpc-id $VPC_ID \
     --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=rds-sg}]'
   
   # Get RDS security group ID
   RDS_SG_ID=$(aws ec2 describe-security-groups \
     --filters "Name=group-name,Values=rds-sg" \
     --query 'SecurityGroups[0].GroupId' --output text)
   ```

2. **Create security group for EC2:**
   ```bash
   # Create EC2 security group
   aws ec2 create-security-group \
     --group-name ec2-app-sg \
     --description "Security group for EC2 application server" \
     --vpc-id $VPC_ID \
     --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=ec2-app-sg}]'
   
   # Get EC2 security group ID
   EC2_SG_ID=$(aws ec2 describe-security-groups \
     --filters "Name=group-name,Values=ec2-app-sg" \
     --query 'SecurityGroups[0].GroupId' --output text)
   
   # Allow SSH access to EC2
   aws ec2 authorize-security-group-ingress \
     --group-id $EC2_SG_ID \
     --protocol tcp \
     --port 22 \
     --cidr 0.0.0.0/0
   
   # Allow HTTP access to EC2
   aws ec2 authorize-security-group-ingress \
     --group-id $EC2_SG_ID \
     --protocol tcp \
     --port 80 \
     --cidr 0.0.0.0/0
   ```

3. **Configure RDS security group to allow access from EC2:**
   ```bash
   # Allow MySQL access from EC2 security group
   aws ec2 authorize-security-group-ingress \
     --group-id $RDS_SG_ID \
     --protocol tcp \
     --port 3306 \
     --source-group $EC2_SG_ID
   ```

### Step 3: Create DB Subnet Group and Parameter Group

1. **Create DB subnet group:**
   ```bash
   # Create DB subnet group
   aws rds create-db-subnet-group \
     --db-subnet-group-name rds-subnet-group \
     --db-subnet-group-description "Subnet group for RDS database" \
     --subnet-ids $PRIVATE_SUBNET_1_ID $PRIVATE_SUBNET_2_ID \
     --tags Key=Name,Value=rds-subnet-group
   ```

2. **Create DB parameter group:**
   ```bash
   # Create DB parameter group
   aws rds create-db-parameter-group \
     --db-parameter-group-name rds-mysql-params \
     --db-parameter-group-family mysql8.0 \
     --description "Parameter group for MySQL 8.0" \
     --tags Key=Name,Value=rds-mysql-params
   
   # Modify parameter group settings
   aws rds modify-db-parameter-group \
     --db-parameter-group-name rds-mysql-params \
     --parameters "ParameterName=max_connections,ParameterValue=200,ApplyMethod=immediate" \
     "ParameterName=general_log,ParameterValue=1,ApplyMethod=immediate" \
     "ParameterName=slow_query_log,ParameterValue=1,ApplyMethod=immediate" \
     "ParameterName=long_query_time,ParameterValue=2,ApplyMethod=immediate"
   ```

### Step 4: Store Database Credentials in Secrets Manager

1. **Create a secret for database credentials:**
   ```bash
   # Generate a random password
   DB_PASSWORD=$(openssl rand -base64 16)
   
   # Create secret
   aws secretsmanager create-secret \
     --name rds-db-credentials \
     --description "RDS database credentials" \
     --secret-string "{\"username\":\"admin\",\"password\":\"$DB_PASSWORD\",\"dbname\":\"appdb\",\"engine\":\"mysql\"}"
   
   # Get secret ARN
   SECRET_ARN=$(aws secretsmanager describe-secret \
     --secret-id rds-db-credentials \
     --query 'ARN' --output text)
   ```

### Step 5: Create RDS Database Instance

1. **Create RDS database instance:**
   ```bash
   # Create RDS instance
   aws rds create-db-instance \
     --db-instance-identifier rds-mysql-instance \
     --db-instance-class db.t3.micro \
     --engine mysql \
     --engine-version 8.0 \
     --allocated-storage 20 \
     --master-username admin \
     --master-user-password $DB_PASSWORD \
     --db-name appdb \
     --db-subnet-group-name rds-subnet-group \
     --vpc-security-group-ids $RDS_SG_ID \
     --db-parameter-group-name rds-mysql-params \
     --backup-retention-period 7 \
     --preferred-backup-window 03:00-04:00 \
     --preferred-maintenance-window sun:04:00-sun:05:00 \
     --multi-az \
     --storage-type gp2 \
     --storage-encrypted \
     --enable-performance-insights \
     --performance-insights-retention-period 7 \
     --enable-cloudwatch-logs-exports '["error","general","slowquery"]' \
     --deletion-protection \
     --tags Key=Name,Value=rds-mysql-instance
   ```

2. **Wait for database to be available:**
   ```bash
   # Wait for database to be available
   echo "Waiting for RDS instance to be available. This may take several minutes..."
   aws rds wait db-instance-available --db-instance-identifier rds-mysql-instance
   
   # Get RDS endpoint
   RDS_ENDPOINT=$(aws rds describe-db-instances \
     --db-instance-identifier rds-mysql-instance \
     --query 'DBInstances[0].Endpoint.Address' --output text)
   
   echo "RDS endpoint: $RDS_ENDPOINT"
   ```

### Step 6: Create EC2 Instance for Database Access

1. **Create IAM role for EC2:**
   ```bash
   # Create trust policy document
   cat > ec2-trust-policy.json << EOF
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
   
   # Create IAM role
   aws iam create-role \
     --role-name ec2-rds-role \
     --assume-role-policy-document file://ec2-trust-policy.json
   
   # Create policy document for Secrets Manager access
   cat > secrets-policy.json << EOF
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "secretsmanager:GetSecretValue"
         ],
         "Resource": "$SECRET_ARN"
       }
     ]
   }
   EOF
   
   # Create policy
   aws iam create-policy \
     --policy-name ec2-secrets-policy \
     --policy-document file://secrets-policy.json
   
   # Get policy ARN
   POLICY_ARN=$(aws iam list-policies \
     --query 'Policies[?PolicyName==`ec2-secrets-policy`].Arn' \
     --output text)
   
   # Attach policy to role
   aws iam attach-role-policy \
     --role-name ec2-rds-role \
     --policy-arn $POLICY_ARN
   
   # Attach SSM policy for session manager access
   aws iam attach-role-policy \
     --role-name ec2-rds-role \
     --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
   
   # Create instance profile
   aws iam create-instance-profile \
     --instance-profile-name ec2-rds-profile
   
   # Add role to instance profile
   aws iam add-role-to-instance-profile \
     --instance-profile-name ec2-rds-profile \
     --role-name ec2-rds-role
   ```

2. **Create user data script for EC2 instance:**
   ```bash
   # Create user data script
   cat > ec2-user-data.sh << EOF
   #!/bin/bash
   yum update -y
   yum install -y httpd mysql jq aws-cli
   
   # Start and enable Apache
   systemctl start httpd
   systemctl enable httpd
   
   # Install PHP
   amazon-linux-extras enable php7.4
   yum clean metadata
   yum install -y php php-mysqlnd
   
   # Create a simple PHP application to test database connection
   cat > /var/www/html/index.php << 'END'
   <?php
   // Get database credentials from Secrets Manager
   \$secret_name = "rds-db-credentials";
   \$region = "$(aws configure get region)";
   
   \$cmd = "aws secretsmanager get-secret-value --secret-id " . \$secret_name . " --region " . \$region;
   \$secret = shell_exec(\$cmd);
   \$secretJson = json_decode(\$secret, true);
   \$secretData = json_decode(\$secretJson['SecretString'], true);
   
   \$host = "$RDS_ENDPOINT";
   \$username = \$secretData['username'];
   \$password = \$secretData['password'];
   \$dbname = \$secretData['dbname'];
   
   echo "<h1>RDS Connection Test</h1>";
   
   try {
       // Create connection
       \$conn = new mysqli(\$host, \$username, \$password, \$dbname);
       
       // Check connection
       if (\$conn->connect_error) {
           die("Connection failed: " . \$conn->connect_error);
       }
       
       echo "<p>Connected to database successfully!</p>";
       
       // Create table if not exists
       \$sql = "CREATE TABLE IF NOT EXISTS users (
           id INT AUTO_INCREMENT PRIMARY KEY,
           name VARCHAR(100) NOT NULL,
           email VARCHAR(100) NOT NULL,
           created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
       )";
       
       if (\$conn->query(\$sql) === TRUE) {
           echo "<p>Table 'users' created or already exists.</p>";
       } else {
           echo "<p>Error creating table: " . \$conn->error . "</p>";
       }
       
       // Insert sample data
       \$sql = "INSERT INTO users (name, email) VALUES ('Test User', 'test@example.com')";
       if (\$conn->query(\$sql) === TRUE) {
           echo "<p>Sample user inserted successfully.</p>";
       } else {
           echo "<p>Error inserting data: " . \$conn->error . "</p>";
       }
       
       // Query data
       \$sql = "SELECT * FROM users";
       \$result = \$conn->query(\$sql);
       
       if (\$result->num_rows > 0) {
           echo "<h2>Users:</h2>";
           echo "<table border='1'>";
           echo "<tr><th>ID</th><th>Name</th><th>Email</th><th>Created At</th></tr>";
           
           while(\$row = \$result->fetch_assoc()) {
               echo "<tr>";
               echo "<td>" . \$row["id"] . "</td>";
               echo "<td>" . \$row["name"] . "</td>";
               echo "<td>" . \$row["email"] . "</td>";
               echo "<td>" . \$row["created_at"] . "</td>";
               echo "</tr>";
           }
           
           echo "</table>";
       } else {
           echo "<p>No users found.</p>";
       }
       
       \$conn->close();
   } catch (Exception \$e) {
       echo "<p>Error: " . \$e->getMessage() . "</p>";
   }
   ?>
   END
   
   # Restart Apache
   systemctl restart httpd
   EOF
   ```

3. **Launch EC2 instance:**
   ```bash
   # Get latest Amazon Linux 2 AMI ID
   AMI_ID=$(aws ec2 describe-images \
     --owners amazon \
     --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" "Name=state,Values=available" \
     --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
     --output text)
   
   # Launch EC2 instance
   aws ec2 run-instances \
     --image-id $AMI_ID \
     --instance-type t2.micro \
     --key-name your-key-pair \
     --subnet-id $PUBLIC_SUBNET_1_ID \
     --security-group-ids $EC2_SG_ID \
     --user-data file://ec2-user-data.sh \
     --iam-instance-profile Name=ec2-rds-profile \
     --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=rds-app-server}]' \
     --associate-public-ip-address
   
   # Get instance ID
   INSTANCE_ID=$(aws ec2 describe-instances \
     --filters "Name=tag:Name,Values=rds-app-server" "Name=instance-state-name,Values=pending,running" \
     --query 'Reservations[0].Instances[0].InstanceId' \
     --output text)
   
   # Wait for instance to be running
   aws ec2 wait instance-running --instance-ids $INSTANCE_ID
   
   # Get public IP address
   PUBLIC_IP=$(aws ec2 describe-instances \
     --instance-ids $INSTANCE_ID \
     --query 'Reservations[0].Instances[0].PublicIpAddress' \
     --output text)
   
   echo "EC2 instance public IP: $PUBLIC_IP"
   ```

### Step 7: Create Lambda Function for Serverless Database Access

1. **Create IAM role for Lambda:**
   ```bash
   # Create trust policy document
   cat > lambda-trust-policy.json << EOF
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
   
   # Create IAM role
   aws iam create-role \
     --role-name lambda-rds-role \
     --assume-role-policy-document file://lambda-trust-policy.json
   
   # Attach policies
   aws iam attach-role-policy \
     --role-name lambda-rds-role \
     --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
   
   aws iam attach-role-policy \
     --role-name lambda-rds-role \
     --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole
   
   # Attach Secrets Manager policy
   aws iam attach-role-policy \
     --role-name lambda-rds-role \
     --policy-arn $POLICY_ARN
   ```

2. **Create Lambda function code:**
   ```bash
   # Create directory for Lambda code
   mkdir -p lambda-functions/rds-query
   
   # Create Lambda function code
   cat > lambda-functions/rds-query/index.js << EOF
   const AWS = require('aws-sdk');
   const mysql = require('mysql2/promise');
   
   // Initialize the Secrets Manager client
   const secretsManager = new AWS.SecretsManager();
   
   async function getDbCredentials() {
     const data = await secretsManager.getSecretValue({ SecretId: 'rds-db-credentials' }).promise();
     return JSON.parse(data.SecretString);
   }
   
   exports.handler = async (event) => {
     try {
       // Get database credentials from Secrets Manager
       const credentials = await getDbCredentials();
       
       // Create database connection
       const connection = await mysql.createConnection({
         host: '$RDS_ENDPOINT',
         user: credentials.username,
         password: credentials.password,
         database: credentials.dbname
       });
       
       console.log('Connected to database successfully');
       
       // Execute query
       const [rows] = await connection.execute('SELECT * FROM users');
       
       // Close connection
       await connection.end();
       
       return {
         statusCode: 200,
         headers: {
           'Content-Type': 'application/json'
         },
         body: JSON.stringify({
           message: 'Query executed successfully',
           data: rows
         })
       };
     } catch (error) {
       console.error('Error:', error);
       
       return {
         statusCode: 500,
         headers: {
           'Content-Type': 'application/json'
         },
         body: JSON.stringify({
           message: 'Error executing query',
           error: error.message
         })
       };
     }
   };
   EOF
   
   # Create package.json
   cat > lambda-functions/rds-query/package.json << EOF
   {
     "name": "rds-query-function",
     "version": "1.0.0",
     "description": "Lambda function for RDS database access",
     "main": "index.js",
     "dependencies": {
       "mysql2": "^2.3.3"
     }
   }
   EOF
   ```

3. **Install dependencies and create deployment package:**
   ```bash
   # Install dependencies
   cd lambda-functions/rds-query
   npm install
   
   # Create ZIP file for Lambda deployment
   zip -r function.zip index.js node_modules
   cd ../../
   ```

4. **Create Lambda function:**
   ```bash
   # Get role ARN
   LAMBDA_ROLE_ARN=$(aws iam get-role --role-name lambda-rds-role --query 'Role.Arn' --output text)
   
   # Create Lambda function
   aws lambda create-function \
     --function-name rds-query-function \
     --runtime nodejs18.x \
     --handler index.handler \
     --role $LAMBDA_ROLE_ARN \
     --zip-file fileb://lambda-functions/rds-query/function.zip \
     --timeout 30 \
     --memory-size 128 \
     --vpc-config SubnetIds=$PRIVATE_SUBNET_1_ID,$PRIVATE_SUBNET_2_ID,SecurityGroupIds=$RDS_SG_ID
   ```

### Step 8: Set Up CloudWatch Monitoring for RDS

1. **Create CloudWatch alarms for RDS:**
   ```bash
   # Create CPU utilization alarm
   aws cloudwatch put-metric-alarm \
     --alarm-name rds-cpu-utilization \
     --alarm-description "Alarm when CPU exceeds 80%" \
     --metric-name CPUUtilization \
     --namespace AWS/RDS \
     --statistic Average \
     --period 300 \
     --threshold 80 \
     --comparison-operator GreaterThanThreshold \
     --dimensions Name=DBInstanceIdentifier,Value=rds-mysql-instance \
     --evaluation-periods 2 \
     --alarm-actions arn:aws:sns:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):rds-alarms
   
   # Create free storage space alarm
   aws cloudwatch put-metric-alarm \
     --alarm-name rds-free-storage-space \
     --alarm-description "Alarm when free storage space is less than 10%" \
     --metric-name FreeStorageSpace \
     --namespace AWS/RDS \
     --statistic Average \
     --period 300 \
     --threshold 2000000000 \
     --comparison-operator LessThanThreshold \
     --dimensions Name=DBInstanceIdentifier,Value=rds-mysql-instance \
     --evaluation-periods 2 \
     --alarm-actions arn:aws:sns:$(aws configure get region):$(aws sts get-caller-identity --query Account --output text):rds-alarms
   ```

### Step 9: Test Database Connectivity

1. **Test EC2 to RDS connectivity:**
   ```bash
   echo "Wait a few minutes for the EC2 instance to complete initialization..."
   echo "Then access the web application at: http://$PUBLIC_IP"
   ```

2. **Test Lambda to RDS connectivity:**
   ```bash
   # Invoke Lambda function
   aws lambda invoke \
     --function-name rds-query-function \
     --payload '{}' \
     response.json
   
   # Check response
   cat response.json
   ```

## Troubleshooting Guide

### Common Issues and Solutions

1. **EC2 cannot connect to RDS:**
   - Verify security group rules allow traffic from EC2 to RDS on port 3306
   - Check that EC2 and RDS are in the same VPC
   - Ensure RDS is in "available" state
   - Verify network ACLs allow traffic between subnets

2. **Lambda cannot connect to RDS:**
   - Verify Lambda is configured with the correct VPC, subnets, and security groups
   - Check that Lambda execution role has VPC access permissions
   - Ensure Lambda timeout is sufficient (database connections can take time)
   - Verify Lambda security group has access to RDS

3. **Database credential issues:**
   - Check that Secrets Manager secret contains the correct credentials
   - Verify IAM permissions for accessing Secrets Manager
   - Ensure the secret name matches in the application code

4. **Performance issues:**
   - Check RDS CloudWatch metrics for CPU, memory, and I/O bottlenecks
   - Review slow query logs for inefficient queries
   - Consider scaling up the RDS instance or implementing read replicas

### Debugging Commands

```bash
# Check EC2 system log
aws ec2 get-console-output --instance-id $INSTANCE_ID

# Check if EC2 can reach RDS
aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters commands="nc -zv $RDS_ENDPOINT 3306"

# Check Lambda function logs
aws logs get-log-events \
  --log-group-name /aws/lambda/rds-query-function \
  --log-stream-name $(aws logs describe-log-streams \
    --log-group-name /aws/lambda/rds-query-function \
    --order-by LastEventTime \
    --descending \
    --limit 1 \
    --query 'logStreams[0].logStreamName' \
    --output text)

# Check RDS logs
aws rds describe-db-log-files \
  --db-instance-identifier rds-mysql-instance

aws rds download-db-log-file-portion \
  --db-instance-identifier rds-mysql-instance \
  --log-file-name error/mysql-error.log
```

## Resources Created

This lab creates the following AWS resources:

### Compute
- **EC2 Instance**: t2.micro instance for application server
- **Lambda Function**: Node.js function for serverless database access

### Database
- **RDS Instance**: MySQL 8.0 database with Multi-AZ deployment
- **DB Subnet Group**: For placing RDS in private subnets
- **DB Parameter Group**: Custom parameters for MySQL configuration

### Networking
- **VPC**: Virtual private cloud with public and private subnets
- **Subnets**: Two public and two private subnets across different AZs
- **Internet Gateway**: For internet access from public subnets
- **Route Tables**: For controlling network traffic
- **Security Groups**: For EC2 and RDS access control

### Security
- **IAM Roles**: For EC2 and Lambda execution
- **IAM Policies**: For Secrets Manager access
- **Secrets Manager Secret**: For secure database credential storage

### Monitoring
- **CloudWatch Alarms**: For RDS performance monitoring
- **CloudWatch Logs**: For RDS, EC2, and Lambda logging

### Estimated Costs
- RDS (db.t3.micro, Multi-AZ): ~$45/month
- EC2 (t2.micro): ~$8.50/month
- Lambda: Free tier includes 1M requests/month
- Secrets Manager: $0.40/secret/month + $0.05/10,000 API calls
- CloudWatch: Free tier includes 5GB of logs and 10 metrics
- **Total estimated cost**: $55-65/month (not free tier eligible for Multi-AZ RDS)

## Cleanup

When you're finished with the lab, follow these steps to avoid ongoing charges:

1. **Delete Lambda function:**
   ```bash
   # Delete Lambda function
   aws lambda delete-function --function-name rds-query-function
   ```

2. **Terminate EC2 instance:**
   ```bash
   # Terminate EC2 instance
   aws ec2 terminate-instances --instance-ids $INSTANCE_ID
   
   # Wait for instance to terminate
   aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID
   ```

3. **Delete RDS instance:**
   ```bash
   # Disable deletion protection
   aws rds modify-db-instance \
     --db-instance-identifier rds-mysql-instance \
     --no-deletion-protection \
     --apply-immediately
   
   # Delete RDS instance
   aws rds delete-db-instance \
     --db-instance-identifier rds-mysql-instance \
     --skip-final-snapshot
   
   # Wait for RDS instance to be deleted
   echo "Waiting for RDS instance to be deleted. This may take several minutes..."
   aws rds wait db-instance-deleted --db-instance-identifier rds-mysql-instance
   ```

4. **Delete DB subnet group and parameter group:**
   ```bash
   # Delete DB subnet group
   aws rds delete-db-subnet-group --db-subnet-group-name rds-subnet-group
   
   # Delete DB parameter group
   aws rds delete-db-parameter-group --db-parameter-group-name rds-mysql-params
   ```

5. **Delete Secrets Manager secret:**
   ```bash
   # Delete secret
   aws secretsmanager delete-secret \
     --secret-id rds-db-credentials \
     --force-delete-without-recovery
   ```

6. **Delete IAM roles and policies:**
   ```bash
   # Detach policies from Lambda role
   aws iam detach-role-policy \
     --role-name lambda-rds-role \
     --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
   
   aws iam detach-role-policy \
     --role-name lambda-rds-role \
     --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole
   
   aws iam detach-role-policy \
     --role-name lambda-rds-role \
     --policy-arn $POLICY_ARN
   
   # Delete Lambda role
   aws iam delete-role --role-name lambda-rds-role
   
   # Remove role from instance profile
   aws iam remove-role-from-instance-profile \
     --instance-profile-name ec2-rds-profile \
     --role-name ec2-rds-role
   
   # Delete instance profile
   aws iam delete-instance-profile --instance-profile-name ec2-rds-profile
   
   # Detach policies from EC2 role
   aws iam detach-role-policy \
     --role-name ec2-rds-role \
     --policy-arn $POLICY_ARN
   
   aws iam detach-role-policy \
     --role-name ec2-rds-role \
     --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
   
   # Delete EC2 role
   aws iam delete-role --role-name ec2-rds-role
   
   # Delete custom policy
   aws iam delete-policy --policy-arn $POLICY_ARN
   ```

7. **Delete CloudWatch alarms:**
   ```bash
   # Delete CloudWatch alarms
   aws cloudwatch delete-alarms \
     --alarm-names rds-cpu-utilization rds-free-storage-space
   ```

8. **Delete VPC resources:**
   ```bash
   # Delete security groups
   aws ec2 delete-security-group --group-id $EC2_SG_ID
   aws ec2 delete-security-group --group-id $RDS_SG_ID
   
   # Disassociate route tables
   aws ec2 disassociate-route-table \
     --association-id $(aws ec2 describe-route-tables \
       --filters "Name=route-table-id,Values=$PUBLIC_RT_ID" \
       --query 'RouteTables[0].Associations[0].RouteTableAssociationId' \
       --output text)
   
   aws ec2 disassociate-route-table \
     --association-id $(aws ec2 describe-route-tables \
       --filters "Name=route-table-id,Values=$PUBLIC_RT_ID" \
       --query 'RouteTables[0].Associations[1].RouteTableAssociationId' \
       --output text)
   
   # Delete route tables
   aws ec2 delete-route-table --route-table-id $PUBLIC_RT_ID
   
   # Detach and delete internet gateway
   aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
   aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID
   
   # Delete subnets
   aws ec2 delete-subnet --subnet-id $PUBLIC_SUBNET_1_ID
   aws ec2 delete-subnet --subnet-id $PUBLIC_SUBNET_2_ID
   aws ec2 delete-subnet --subnet-id $PRIVATE_SUBNET_1_ID
   aws ec2 delete-subnet --subnet-id $PRIVATE_SUBNET_2_ID
   
   # Delete VPC
   aws ec2 delete-vpc --vpc-id $VPC_ID
   ```

9. **Verify cleanup:**
   ```bash
   # Verify RDS instance is deleted
   aws rds describe-db-instances \
     --query 'DBInstances[?DBInstanceIdentifier==`rds-mysql-instance`]' || echo "RDS instance deleted successfully"
   
   # Verify EC2 instance is terminated
   aws ec2 describe-instances \
     --filters "Name=instance-id,Values=$INSTANCE_ID" \
     --query 'Reservations[].Instances[].State.Name' || echo "EC2 instance terminated successfully"
   
   # Verify Lambda function is deleted
   aws lambda get-function --function-name rds-query-function || echo "Lambda function deleted successfully"
   ```

> **Important**: Failure to delete resources may result in unexpected charges to your AWS account.

## Next Steps

After completing this lab, consider:

1. **Implement RDS Proxy** for efficient connection pooling
2. **Set up read replicas** for read scaling and reduced primary instance load
3. **Implement automated database backups** to S3 with lifecycle policies
4. **Create a disaster recovery strategy** with cross-region replication
5. **Implement database encryption** for data at rest and in transit
6. **Set up enhanced monitoring** for deeper insights into database performance

## Certification Exam Tips

This lab covers several key areas for the AWS DevOps Professional exam:

- **Domain 1**: SDLC Automation (Database integration patterns)
- **Domain 2**: Configuration Management and IaC (RDS configuration, parameter groups)
- **Domain 3**: Monitoring and Logging (CloudWatch integration, RDS logging)
- **Domain 4**: Policies and Standards Automation (IAM roles, security groups)
- **Domain 5**: Incident and Event Response (Database monitoring, alarms)
- **Domain 6**: High Availability and Elasticity (Multi-AZ deployment)

Key concepts to remember:
- RDS Multi-AZ provides high availability with automatic failover
- Security groups control network access to database instances
- Secrets Manager securely stores and rotates database credentials
- Parameter groups allow customization of database engine settings
- CloudWatch metrics and alarms help monitor database performance
- Lambda functions in VPC require specific networking configurations
- EC2 instances can access RDS securely using IAM roles and Secrets Manager

## Additional Resources

- [Amazon RDS User Guide](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Welcome.html)
- [AWS Database Blog](https://aws.amazon.com/blogs/database/)
- [RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)
- [Secrets Manager User Guide](https://docs.aws.amazon.com/secretsmanager/latest/userguide/intro.html)
- [AWS Lambda with RDS Tutorial](https://docs.aws.amazon.com/lambda/latest/dg/services-rds.html)
- [Database Migration Strategies](https://aws.amazon.com/blogs/database/database-migration-what-do-you-need-to-know-before-you-start/)