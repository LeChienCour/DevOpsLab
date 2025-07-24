#!/usr/bin/env python3
"""
CloudWatch Log Generator

This script generates sample logs for multiple AWS services to demonstrate
log aggregation and centralized monitoring capabilities.

Usage:
  python generate-logs.py [--environment ENV] [--count COUNT] [--region REGION]
  
Options:
  --environment    Environment name (default: Dev)
  --count          Number of log entries to generate per service (default: 10)
  --region         AWS region (default: from AWS config)
"""

import argparse
import boto3
import json
import time
import random
import uuid
from datetime import datetime

def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description='Generate sample logs for CloudWatch')
    parser.add_argument('--environment', default='Dev', help='Environment name')
    parser.add_argument('--count', type=int, default=10, help='Number of log entries per service')
    parser.add_argument('--region', help='AWS region')
    return parser.parse_args()

def create_log_group_if_not_exists(logs_client, log_group_name):
    """Create a log group if it doesn't exist."""
    try:
        logs_client.create_log_group(logGroupName=log_group_name)
        print(f"Created log group: {log_group_name}")
    except logs_client.exceptions.ResourceAlreadyExistsException:
        print(f"Log group already exists: {log_group_name}")

def create_log_stream_if_not_exists(logs_client, log_group_name, log_stream_name):
    """Create a log stream if it doesn't exist."""
    try:
        logs_client.create_log_stream(
            logGroupName=log_group_name,
            logStreamName=log_stream_name
        )
        print(f"Created log stream: {log_stream_name} in {log_group_name}")
    except logs_client.exceptions.ResourceAlreadyExistsException:
        print(f"Log stream already exists: {log_stream_name} in {log_group_name}")

def put_log_events(logs_client, log_group_name, log_stream_name, log_events):
    """Put log events into a log stream."""
    try:
        response = logs_client.put_log_events(
            logGroupName=log_group_name,
            logStreamName=log_stream_name,
            logEvents=log_events
        )
        print(f"Put {len(log_events)} log events into {log_stream_name}")
        return response
    except Exception as e:
        print(f"Error putting log events: {e}")
        return None

def generate_lambda_logs(logs_client, environment, count):
    """Generate sample Lambda function logs."""
    log_group_name = f"/aws/lambda/{environment}"
    log_stream_name = f"lambda-function-{int(time.time())}"
    
    create_log_group_if_not_exists(logs_client, log_group_name)
    create_log_stream_if_not_exists(logs_client, log_group_name, log_stream_name)
    
    log_events = []
    functions = ['UserAuthentication', 'OrderProcessing', 'PaymentService', 'NotificationHandler']
    
    for i in range(count):
        function_name = random.choice(functions)
        event_time = int((time.time() + i) * 1000)
        
        # Simulate different log levels and messages
        if i % 10 == 0:
            level = "ERROR"
            message = f"Exception occurred during execution: TimeoutError"
        elif i % 5 == 0:
            level = "WARN"
            message = f"Slow execution detected, took 2500ms"
        else:
            level = "INFO"
            message = f"Function executed successfully in 120ms"
        
        log_message = {
            "timestamp": datetime.utcnow().isoformat(),
            "level": level,
            "function": function_name,
            "requestId": str(uuid.uuid4()),
            "message": message,
            "duration": random.randint(50, 3000),
            "memoryUsed": random.randint(50, 256)
        }
        
        log_events.append({
            "timestamp": event_time,
            "message": json.dumps(log_message)
        })
    
    put_log_events(logs_client, log_group_name, log_stream_name, log_events)

def generate_api_gateway_logs(logs_client, environment, count):
    """Generate sample API Gateway logs."""
    log_group_name = f"/aws/apigateway/{environment}"
    log_stream_name = f"api-gateway-{int(time.time())}"
    
    create_log_group_if_not_exists(logs_client, log_group_name)
    create_log_stream_if_not_exists(logs_client, log_group_name, log_stream_name)
    
    log_events = []
    endpoints = ['/users', '/orders', '/products', '/auth/login', '/payments']
    methods = ['GET', 'POST', 'PUT', 'DELETE']
    
    for i in range(count):
        endpoint = random.choice(endpoints)
        method = random.choice(methods)
        event_time = int((time.time() + i) * 1000)
        
        # Simulate different status codes
        if i % 20 == 0:
            status = random.randint(500, 503)
            latency = random.randint(1000, 5000)
        elif i % 10 == 0:
            status = random.randint(400, 403)
            latency = random.randint(200, 1000)
        else:
            status = 200
            latency = random.randint(50, 200)
        
        log_message = {
            "requestId": str(uuid.uuid4()),
            "ip": f"192.168.{random.randint(1, 255)}.{random.randint(1, 255)}",
            "requestTime": datetime.utcnow().isoformat(),
            "httpMethod": method,
            "resourcePath": endpoint,
            "status": status,
            "responseLatency": latency,
            "userAgent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "integrationLatency": latency - random.randint(10, 50)
        }
        
        log_events.append({
            "timestamp": event_time,
            "message": json.dumps(log_message)
        })
    
    put_log_events(logs_client, log_group_name, log_stream_name, log_events)

def generate_ec2_logs(logs_client, environment, count):
    """Generate sample EC2 instance logs."""
    log_group_name = f"/aws/ec2/{environment}"
    log_stream_name = f"ec2-instance-{int(time.time())}"
    
    create_log_group_if_not_exists(logs_client, log_group_name)
    create_log_stream_if_not_exists(logs_client, log_group_name, log_stream_name)
    
    log_events = []
    services = ['nginx', 'apache', 'mysql', 'mongodb', 'redis', 'system']
    
    for i in range(count):
        service = random.choice(services)
        event_time = int((time.time() + i) * 1000)
        
        # Simulate different log types
        if service == 'nginx' or service == 'apache':
            ip = f"192.168.{random.randint(1, 255)}.{random.randint(1, 255)}"
            path = random.choice(['/index.html', '/api/v1/users', '/static/main.css', '/login'])
            status = random.choice([200, 200, 200, 200, 404, 500])
            log_message = f"{service}: {ip} - - [{datetime.utcnow().strftime('%d/%b/%Y:%H:%M:%S +0000')}] \"GET {path} HTTP/1.1\" {status} {random.randint(200, 5000)}"
        elif service == 'mysql' or service == 'mongodb':
            operation = random.choice(['SELECT', 'INSERT', 'UPDATE', 'DELETE']) if service == 'mysql' else random.choice(['find', 'insert', 'update', 'delete'])
            duration = random.randint(1, 1000)
            log_message = f"{service}: {operation} operation completed in {duration}ms"
        elif service == 'redis':
            command = random.choice(['GET', 'SET', 'DEL', 'HSET'])
            log_message = f"{service}: {command} command executed in {random.randint(1, 50)}ms"
        else:  # system
            log_message = random.choice([
                "system: CPU usage at 85%",
                "system: Memory usage at 70%",
                "system: Disk I/O wait increased to 15%",
                "system: Started daily backup process",
                "system: Security updates installed",
                "system: Detected 3 failed SSH login attempts"
            ])
        
        log_events.append({
            "timestamp": event_time,
            "message": log_message
        })
    
    put_log_events(logs_client, log_group_name, log_stream_name, log_events)

def generate_ecs_logs(logs_client, environment, count):
    """Generate sample ECS container logs."""
    log_group_name = f"/aws/ecs/{environment}"
    log_stream_name = f"ecs-container-{int(time.time())}"
    
    create_log_group_if_not_exists(logs_client, log_group_name)
    create_log_stream_if_not_exists(logs_client, log_group_name, log_stream_name)
    
    log_events = []
    containers = ['web-frontend', 'api-service', 'auth-service', 'worker']
    
    for i in range(count):
        container = random.choice(containers)
        event_time = int((time.time() + i) * 1000)
        
        # Simulate structured container logs
        log_data = {
            "timestamp": datetime.utcnow().isoformat(),
            "container": container,
            "taskId": f"ecs-task-{uuid.uuid4().hex[:8]}",
            "clusterId": f"ecs-cluster-{environment.lower()}"
        }
        
        if container == 'web-frontend':
            log_data["level"] = random.choice(["INFO", "INFO", "WARN", "ERROR"])
            log_data["component"] = random.choice(["React", "Redux", "Router"])
            log_data["message"] = f"Rendered page in {random.randint(50, 500)}ms"
        elif container == 'api-service':
            log_data["level"] = random.choice(["INFO", "INFO", "DEBUG", "WARN"])
            log_data["endpoint"] = random.choice(["/api/users", "/api/products", "/api/orders"])
            log_data["method"] = random.choice(["GET", "POST", "PUT"])
            log_data["responseTime"] = random.randint(10, 200)
            log_data["message"] = f"Request processed in {log_data['responseTime']}ms"
        elif container == 'auth-service':
            log_data["level"] = random.choice(["INFO", "INFO", "WARN", "ERROR"])
            log_data["action"] = random.choice(["login", "logout", "token-refresh", "permission-check"])
            log_data["userId"] = f"user-{random.randint(1000, 9999)}"
            log_data["message"] = f"Auth {log_data['action']} for {log_data['userId']}"
        else:  # worker
            log_data["level"] = random.choice(["INFO", "INFO", "DEBUG"])
            log_data["job"] = random.choice(["email-sending", "report-generation", "data-processing"])
            log_data["duration"] = random.randint(100, 5000)
            log_data["message"] = f"Completed {log_data['job']} job in {log_data['duration']}ms"
        
        log_events.append({
            "timestamp": event_time,
            "message": json.dumps(log_data)
        })
    
    put_log_events(logs_client, log_group_name, log_stream_name, log_events)

def generate_rds_logs(logs_client, environment, count):
    """Generate sample RDS database logs."""
    log_group_name = f"/aws/rds/{environment}"
    log_stream_name = f"rds-instance-{int(time.time())}"
    
    create_log_group_if_not_exists(logs_client, log_group_name)
    create_log_stream_if_not_exists(logs_client, log_group_name, log_stream_name)
    
    log_events = []
    log_types = ['error', 'slowquery', 'general', 'audit']
    
    for i in range(count):
        log_type = random.choice(log_types)
        event_time = int((time.time() + i) * 1000)
        
        if log_type == 'error':
            if i % 10 == 0:
                log_message = f"ERROR: could not connect to server: Connection refused"
            else:
                log_message = random.choice([
                    "ERROR: relation \"users\" does not exist",
                    "ERROR: duplicate key value violates unique constraint \"users_pkey\"",
                    "ERROR: null value in column \"email\" violates not-null constraint",
                    "ERROR: permission denied for table orders"
                ])
        elif log_type == 'slowquery':
            query_time = random.uniform(1.0, 10.0)
            queries = [
                "SELECT * FROM users WHERE last_login > '2023-01-01'",
                "UPDATE orders SET status = 'shipped' WHERE order_date < '2023-06-01'",
                "SELECT o.*, u.name FROM orders o JOIN users u ON o.user_id = u.id",
                "SELECT COUNT(*) FROM products GROUP BY category"
            ]
            log_message = f"# Query_time: {query_time:.2f} Lock_time: 0.000000 Rows_sent: {random.randint(1, 1000)} Rows_examined: {random.randint(1000, 10000)}\n{random.choice(queries)};"
        elif log_type == 'general':
            log_message = random.choice([
                f"{datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')} [Note] InnoDB: Creating shared tablespace for temporary tables",
                f"{datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')} [Note] Event Scheduler: Loaded {random.randint(1, 20)} events",
                f"{datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')} [Note] Access denied for user 'app_user'@'10.0.0.{random.randint(1, 255)}' (using password: YES)",
                f"{datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')} [Note] {random.randint(1, 100)} connections created"
            ])
        else:  # audit
            log_message = random.choice([
                f"AUDIT: {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')} {random.randint(10000, 99999)} QUERY: SELECT * FROM users WHERE id = 123",
                f"AUDIT: {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')} {random.randint(10000, 99999)} CONNECT: Connection accepted: User=admin Host=10.0.0.{random.randint(1, 255)}",
                f"AUDIT: {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')} {random.randint(10000, 99999)} QUERY: GRANT SELECT ON products TO 'analyst'",
                f"AUDIT: {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')} {random.randint(10000, 99999)} DISCONNECT: User=app_user Host=10.0.0.{random.randint(1, 255)}"
            ])
        
        log_events.append({
            "timestamp": event_time,
            "message": log_message
        })
    
    put_log_events(logs_client, log_group_name, log_stream_name, log_events)

def main():
    """Main function."""
    args = parse_args()
    
    # Create boto3 client
    session = boto3.Session(region_name=args.region)
    logs_client = session.client('logs')
    
    print(f"=== Generating CloudWatch Logs for Environment: {args.environment} ===")
    print(f"Generating {args.count} log entries per service...")
    
    # Generate logs for different services
    generate_lambda_logs(logs_client, args.environment, args.count)
    generate_api_gateway_logs(logs_client, args.environment, args.count)
    generate_ec2_logs(logs_client, args.environment, args.count)
    generate_ecs_logs(logs_client, args.environment, args.count)
    generate_rds_logs(logs_client, args.environment, args.count)
    
    print("Log generation complete!")
    print("You can now view these logs in the CloudWatch console or through the centralized logging dashboard.")

if __name__ == "__main__":
    main()