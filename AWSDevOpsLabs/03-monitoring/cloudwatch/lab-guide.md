# CloudWatch Comprehensive Monitoring Lab Guide

## Objective
Learn to create custom CloudWatch metrics, build comprehensive dashboards, configure intelligent alarms, and implement centralized log aggregation for monitoring AWS resources and applications. This lab demonstrates how to implement effective monitoring strategies using CloudWatch's core features and CloudFormation for infrastructure as code.

## Learning Outcomes
By completing this lab, you will:
- Create and publish custom CloudWatch metrics from applications
- Build interactive dashboards to visualize system performance
- Configure CloudWatch alarms with appropriate thresholds and actions
- Implement log-based metrics and insights
- Set up automated responses to monitoring events
- Deploy monitoring infrastructure using CloudFormation
- Implement centralized log aggregation from multiple AWS services
- Create automated dashboard generation based on infrastructure changes

## Prerequisites
- AWS Account with administrative access
- AWS CLI configured with appropriate credentials
- Basic understanding of monitoring and observability concepts
- A sample application or EC2 instance to monitor (optional - we'll provide examples)

### Required AWS Permissions
Your AWS user/role needs the following permissions:
- CloudWatch: Full access for creating metrics, dashboards, and alarms
- EC2: Read access for monitoring instance metrics
- SNS: Create and manage topics for alarm notifications
- IAM: Create roles for CloudWatch agent (if using EC2)

### Time to Complete
Approximately 45-60 minutes

## Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Application   │───▶│   CloudWatch     │───▶│   Dashboard     │
│   (Custom       │    │   Metrics        │    │   (Visualization│
│    Metrics)     │    │                  │    │    & Alerts)    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌──────────────────┐    ┌─────────────────┐
                       │   CloudWatch     │───▶│      SNS        │
                       │    Alarms        │    │  (Notifications)│
                       └──────────────────┘    └─────────────────┘
```

### Resources Created:
- **CloudWatch Custom Metrics**: Application performance metrics
- **CloudWatch Dashboard**: Visual monitoring interface
- **CloudWatch Alarms**: Standard and composite alarms for monitoring
- **SNS Topic**: Notification delivery for alarms
- **CloudWatch Log Groups**: Application log storage and analysis
- **CloudFormation Stacks**: Infrastructure as code for monitoring resources
- **Log Aggregation System**: Centralized logging from multiple AWS services
- **Dashboard Generator**: Automated dashboard creation based on infrastructure

## Lab Steps

### Step 1: Deploy CloudFormation Templates

1. **Review the CloudFormation templates:**
   - `cloudwatch-monitoring.yaml`: Creates custom metrics, alarms, and dashboards
   - `log-aggregation.yaml`: Sets up centralized logging from multiple AWS services

2. **Deploy the templates using the provisioning script:**
   ```bash
   # Navigate to the scripts directory
   cd ~/cloudwatch-lab/scripts
   
   # Make the script executable
   chmod +x provision-cloudwatch.sh
   
   # Run the provisioning script with your email for notifications
   ./provision-cloudwatch.sh --email your.email@example.com --environment Dev
   ```

3. **Verify the CloudFormation stacks:**
   ```bash
   # List the deployed stacks
   aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE
   ```

4. **Explore the created resources in the AWS Console:**
   - Navigate to CloudFormation and examine the resources created
   - Check CloudWatch dashboards, alarms, and log groups

### Step 2: Create SNS Topic for Notifications

1. **Create an SNS topic for alarm notifications:**
   ```bash
   # Create SNS topic for CloudWatch alarms
   aws sns create-topic --name cloudwatch-alarms-topic
   ```

2. **Subscribe your email to the topic:**
   ```bash
   # Replace YOUR_EMAIL with your actual email address
   aws sns subscribe \
     --topic-arn arn:aws:sns:us-east-1:YOUR_ACCOUNT_ID:cloudwatch-alarms-topic \
     --protocol email \
     --notification-endpoint YOUR_EMAIL@example.com
   ```

3. **Confirm the subscription:**
   - Check your email and click the confirmation link sent by AWS

### Step 2: Create Custom CloudWatch Metrics

1. **Create a simple script to publish custom metrics:**
   ```bash
   # Create a directory for our monitoring scripts
   mkdir -p ~/cloudwatch-lab
   cd ~/cloudwatch-lab
   ```

2. **Create a custom metrics script:**
   ```bash
   cat > publish-metrics.py << 'EOF'
#!/usr/bin/env python3
import boto3
import random
import time
from datetime import datetime

cloudwatch = boto3.client('cloudwatch')

def publish_custom_metrics():
    # Simulate application metrics
    cpu_usage = random.uniform(10, 90)
    memory_usage = random.uniform(20, 80)
    request_count = random.randint(50, 200)
    response_time = random.uniform(100, 500)
    
    # Publish metrics to CloudWatch
    cloudwatch.put_metric_data(
        Namespace='CustomApp/Performance',
        MetricData=[
            {
                'MetricName': 'CPUUsage',
                'Value': cpu_usage,
                'Unit': 'Percent',
                'Timestamp': datetime.utcnow()
            },
            {
                'MetricName': 'MemoryUsage',
                'Value': memory_usage,
                'Unit': 'Percent',
                'Timestamp': datetime.utcnow()
            },
            {
                'MetricName': 'RequestCount',
                'Value': request_count,
                'Unit': 'Count',
                'Timestamp': datetime.utcnow()
            },
            {
                'MetricName': 'ResponseTime',
                'Value': response_time,
                'Unit': 'Milliseconds',
                'Timestamp': datetime.utcnow()
            }
        ]
    )
    
    print(f"Published metrics: CPU={cpu_usage:.1f}%, Memory={memory_usage:.1f}%, Requests={request_count}, ResponseTime={response_time:.1f}ms")

if __name__ == "__main__":
    for i in range(10):
        publish_custom_metrics()
        time.sleep(60)  # Wait 1 minute between metric publications
EOF
   ```

3. **Make the script executable and run it:**
   ```bash
   chmod +x publish-metrics.py
   python3 publish-metrics.py &
   ```

4. **Verify metrics are being published:**
   ```bash
   # List custom metrics (wait a few minutes after starting the script)
   aws cloudwatch list-metrics --namespace "CustomApp/Performance"
   ```

### Step 3: Create CloudWatch Dashboard

1. **Create a comprehensive dashboard:**
   ```bash
   cat > dashboard-config.json << 'EOF'
{
    "widgets": [
        {
            "type": "metric",
            "x": 0,
            "y": 0,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "CustomApp/Performance", "CPUUsage" ],
                    [ ".", "MemoryUsage" ]
                ],
                "period": 300,
                "stat": "Average",
                "region": "us-east-1",
                "title": "System Resource Usage",
                "yAxis": {
                    "left": {
                        "min": 0,
                        "max": 100
                    }
                }
            }
        },
        {
            "type": "metric",
            "x": 12,
            "y": 0,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "CustomApp/Performance", "RequestCount" ]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "us-east-1",
                "title": "Request Volume"
            }
        },
        {
            "type": "metric",
            "x": 0,
            "y": 6,
            "width": 24,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "CustomApp/Performance", "ResponseTime" ]
                ],
                "period": 300,
                "stat": "Average",
                "region": "us-east-1",
                "title": "Application Response Time"
            }
        }
    ]
}
EOF
   ```

2. **Create the dashboard:**
   ```bash
   aws cloudwatch put-dashboard \
     --dashboard-name "CustomApp-Performance-Dashboard" \
     --dashboard-body file://dashboard-config.json
   ```

3. **Verify dashboard creation:**
   ```bash
   aws cloudwatch list-dashboards
   ```

### Step 4: Configure CloudWatch Alarms

1. **Create an alarm for high CPU usage:**
   ```bash
   aws cloudwatch put-metric-alarm \
     --alarm-name "CustomApp-HighCPU" \
     --alarm-description "Alarm when CPU exceeds 80%" \
     --metric-name CPUUsage \
     --namespace CustomApp/Performance \
     --statistic Average \
     --period 300 \
     --threshold 80 \
     --comparison-operator GreaterThanThreshold \
     --evaluation-periods 2 \
     --alarm-actions arn:aws:sns:us-east-1:YOUR_ACCOUNT_ID:cloudwatch-alarms-topic
   ```

2. **Create an alarm for high response time:**
   ```bash
   aws cloudwatch put-metric-alarm \
     --alarm-name "CustomApp-HighResponseTime" \
     --alarm-description "Alarm when response time exceeds 400ms" \
     --metric-name ResponseTime \
     --namespace CustomApp/Performance \
     --statistic Average \
     --period 300 \
     --threshold 400 \
     --comparison-operator GreaterThanThreshold \
     --evaluation-periods 1 \
     --alarm-actions arn:aws:sns:us-east-1:YOUR_ACCOUNT_ID:cloudwatch-alarms-topic
   ```

3. **Create a composite alarm:**
   ```bash
   aws cloudwatch put-composite-alarm \
     --alarm-name "CustomApp-SystemHealth" \
     --alarm-description "Overall system health check" \
     --alarm-rule "(ALARM('CustomApp-HighCPU') OR ALARM('CustomApp-HighResponseTime'))" \
     --actions-enabled \
     --alarm-actions arn:aws:sns:us-east-1:YOUR_ACCOUNT_ID:cloudwatch-alarms-topic
   ```

4. **List all alarms to verify creation:**
   ```bash
   aws cloudwatch describe-alarms --alarm-names "CustomApp-HighCPU" "CustomApp-HighResponseTime" "CustomApp-SystemHealth"
   ```

### Step 5: Test Alarm Functionality

1. **Create a script to trigger high CPU alarm:**
   ```bash
   cat > trigger-alarm.py << 'EOF'
#!/usr/bin/env python3
import boto3
from datetime import datetime

cloudwatch = boto3.client('cloudwatch')

# Publish high CPU metric to trigger alarm
cloudwatch.put_metric_data(
    Namespace='CustomApp/Performance',
    MetricData=[
        {
            'MetricName': 'CPUUsage',
            'Value': 85.0,  # Above our 80% threshold
            'Unit': 'Percent',
            'Timestamp': datetime.utcnow()
        }
    ]
)

print("Published high CPU metric to trigger alarm")
EOF
   ```

2. **Run the alarm trigger script:**
   ```bash
   python3 trigger-alarm.py
   ```

3. **Monitor alarm state:**
   ```bash
   # Check alarm state (may take a few minutes to trigger)
   aws cloudwatch describe-alarms --alarm-names "CustomApp-HighCPU" --query 'MetricAlarms[0].StateValue'
   ```

### Step 6: Explore CloudWatch Insights

1. **Create a log group for application logs:**
   ```bash
   aws logs create-log-group --log-group-name "/aws/customapp/application"
   ```

2. **Create sample log entries:**
   ```bash
   cat > generate-logs.py << 'EOF'
#!/usr/bin/env python3
import boto3
import json
import time
from datetime import datetime

logs_client = boto3.client('logs')
log_group = '/aws/customapp/application'
log_stream = f'app-{int(time.time())}'

# Create log stream
logs_client.create_log_stream(
    logGroupName=log_group,
    logStreamName=log_stream
)

# Generate sample log events
log_events = []
for i in range(10):
    event = {
        'timestamp': int(time.time() * 1000),
        'message': json.dumps({
            'level': 'INFO',
            'message': f'Processing request {i+1}',
            'response_time': 150 + (i * 10),
            'status_code': 200
        })
    }
    log_events.append(event)
    time.sleep(1)

# Put log events
logs_client.put_log_events(
    logGroupName=log_group,
    logStreamName=log_stream,
    logEvents=log_events
)

print(f"Generated {len(log_events)} log events in stream {log_stream}")
EOF
   ```

3. **Run the log generation script:**
   ```bash
   python3 generate-logs.py
   ```

4. **Query logs using CloudWatch Insights:**
   ```bash
   # Start a query (replace START_TIME and END_TIME with appropriate epoch timestamps)
   aws logs start-query \
     --log-group-name "/aws/customapp/application" \
     --start-time 1640995200 \
     --end-time 1640998800 \
     --query-string 'fields @timestamp, message | filter message like /response_time/ | sort @timestamp desc'
   ```

## Troubleshooting Guide

### Common Issues and Solutions

1. **Metrics not appearing in CloudWatch:**
   - Verify AWS credentials and region configuration
   - Check that the namespace and metric names are correct
   - Ensure sufficient IAM permissions for CloudWatch:PutMetricData
   - Wait up to 15 minutes for metrics to appear in the console

2. **Dashboard not displaying data:**
   - Verify the metric names and namespace in the dashboard configuration
   - Check the time range - custom metrics may not have historical data
   - Ensure the region in the dashboard matches where metrics are published

3. **Alarms not triggering:**
   - Verify the alarm threshold and comparison operator
   - Check that the metric has sufficient data points for evaluation
   - Confirm SNS topic ARN is correct and subscription is confirmed
   - Review alarm history: `aws cloudwatch describe-alarm-history --alarm-name "CustomApp-HighCPU"`

4. **SNS notifications not received:**
   - Check spam folder for confirmation and alarm emails
   - Verify email subscription is confirmed
   - Test SNS topic: `aws sns publish --topic-arn YOUR_TOPIC_ARN --message "Test message"`

### Debugging Commands

```bash
# Check CloudWatch agent status (if using EC2)
sudo systemctl status amazon-cloudwatch-agent

# View recent metric data
aws cloudwatch get-metric-statistics \
  --namespace "CustomApp/Performance" \
  --metric-name "CPUUsage" \
  --start-time 2023-01-01T00:00:00Z \
  --end-time 2023-01-01T01:00:00Z \
  --period 300 \
  --statistics Average

# List all custom metrics
aws cloudwatch list-metrics --namespace "CustomApp/Performance"

# Check alarm history
aws cloudwatch describe-alarm-history --alarm-name "CustomApp-HighCPU"
```

## Resources Created

This lab creates the following AWS resources:

### Monitoring and Alerting
- **CloudWatch Custom Metrics**: Application performance metrics in CustomApp/Performance namespace
- **CloudWatch Dashboard**: Visual monitoring interface with multiple widgets
- **CloudWatch Alarms**: 3 alarms (CPU, Response Time, Composite)
- **SNS Topic**: Notification delivery system for alarms
- **CloudWatch Log Group**: Application log storage and analysis

### Estimated Costs
- CloudWatch Custom Metrics: $0.30/metric/month (10+ metrics = $3.00+/month)
- CloudWatch Alarms: $0.10/alarm/month (5+ alarms = $0.50+/month)
- CloudWatch Dashboard: $3.00/month per dashboard (2+ dashboards = $6.00+/month)
- SNS: $0.50 per 1 million requests (minimal cost for notifications)
- CloudWatch Logs: $0.50/GB ingested, $0.03/GB stored (varies with log volume)
- Lambda Function (Log Processor): Minimal cost for short executions
- **Total estimated cost**: $10.00-15.00/month (not free tier eligible for dashboards)

> **Cost Optimization Tip**: Delete resources promptly after completing the lab to minimize charges. Consider using the AWS Free Tier for initial exploration.

## Cleanup

When you're finished with the lab, follow these steps to avoid ongoing charges:

1. **Stop any running scripts:**
   ```bash
   # Find and kill the Python processes
   pkill -f publish-metrics.py
   pkill -f generate-logs.py
   pkill -f dashboard-generator.py
   ```

2. **Delete CloudFormation stacks:**
   ```bash
   # Delete the monitoring stack
   aws cloudformation delete-stack --stack-name cloudwatch-monitoring-lab
   
   # Delete the log aggregation stack
   aws cloudformation delete-stack --stack-name cloudwatch-log-aggregation-lab
   ```

3. **Verify stack deletion:**
   ```bash
   # Check stack deletion status
   aws cloudformation list-stacks --stack-status-filter DELETE_IN_PROGRESS DELETE_COMPLETE
   ```

4. **Delete any manually created dashboards:**
   ```bash
   aws cloudwatch delete-dashboards --dashboard-names "InfrastructureDashboard"
   ```

5. **Remove cron jobs:**
   ```bash
   # Edit crontab to remove any scheduled tasks
   crontab -e
   ```

6. **Clean up local files:**
   ```bash
   rm -rf ~/cloudwatch-lab
   ```

> **Important**: Custom metrics data is retained for 15 months. While you won't be charged for storage, the metrics will remain visible in CloudWatch.

## Next Steps

After completing this lab, consider:

1. **Explore CloudWatch Container Insights** for monitoring containerized applications
2. **Set up CloudWatch Application Insights** for automatic application monitoring
3. **Implement custom metrics in your own applications** using AWS SDKs
4. **Create more sophisticated dashboards** with annotations and markdown widgets
5. **Explore CloudWatch Synthetics** for proactive monitoring with canaries
6. **Implement cross-account and cross-region monitoring** for multi-account architectures
7. **Set up CloudWatch Contributor Insights** to analyze high-cardinality data
8. **Create CloudWatch Metric Math expressions** for advanced metric analysis
9. **Integrate with AWS EventBridge** for automated remediation workflows

## Certification Exam Tips

This lab covers several key areas for the AWS DevOps Professional exam:

- **Domain 1**: SDLC Automation (Monitoring and logging in CI/CD pipelines)
- **Domain 2**: Configuration Management and IaC (Infrastructure monitoring)
- **Domain 3**: Monitoring and Logging (Core CloudWatch functionality)
- **Domain 4**: Policies and Standards Automation (Automated alerting and response)

Key concepts to remember:
- CloudWatch metrics have a maximum resolution of 1 second for high-resolution metrics
- Standard resolution metrics are stored at 1-minute intervals
- Alarms can be in three states: OK, ALARM, or INSUFFICIENT_DATA
- Composite alarms allow complex logic combining multiple alarms
- Custom metrics require explicit publishing via API calls or CloudWatch agent
- Dashboard widgets support various visualization types and can span multiple regions
- CloudFormation can be used to define and deploy monitoring infrastructure as code
- Log aggregation centralizes logs from multiple sources for unified analysis
- Metric filters extract metrics from log data for additional monitoring capabilities
- Automated dashboard generation can adapt to infrastructure changes

## Additional Resources

- [Amazon CloudWatch User Guide](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/)
- [CloudWatch Custom Metrics Best Practices](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/publishingMetrics.html)
- [Building Dashboards with CloudWatch](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/create_dashboard.html)
- [CloudWatch Alarms Best Practices](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)
- [AWS Well-Architected Framework - Reliability Pillar](https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/welcome.html)
- [CloudWatch Logs Insights Syntax](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html)
- [CloudFormation Resource Types for CloudWatch](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/AWS_CloudWatch.html)
- [Centralized Logging with CloudWatch Logs](https://aws.amazon.com/blogs/architecture/central-logging-in-multi-account-environments/)
- [CloudWatch Composite Alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Create_Composite_Alarm.html)
- [CloudWatch Anomaly Detection](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Anomaly_Detection.html)
##
# Step 7: Implement Centralized Log Aggregation

1. **Generate sample logs from multiple AWS services:**
   ```bash
   # Navigate to the scripts directory
   cd ~/cloudwatch-lab/scripts
   
   # Make the script executable
   chmod +x generate-logs.py
   
   # Generate sample logs for multiple services
   python3 generate-logs.py --environment Dev --count 20
   ```

2. **Verify logs are being aggregated:**
   ```bash
   # Get the centralized log group name
   CENTRAL_LOG_GROUP=$(aws cloudformation describe-stacks --stack-name cloudwatch-log-aggregation-lab --query "Stacks[0].Outputs[?OutputKey=='CentralizedLogGroupName'].OutputValue" --output text)
   
   # Query the centralized logs
   aws logs start-query \
     --log-group-name "$CENTRAL_LOG_GROUP" \
     --start-time $(date -d '1 hour ago' +%s) \
     --end-time $(date +%s) \
     --query-string 'fields @timestamp, @message | sort @timestamp desc | limit 20'
   ```

3. **Explore the logs dashboard:**
   ```bash
   # Get the logs dashboard URL
   aws cloudformation describe-stacks --stack-name cloudwatch-log-aggregation-lab --query "Stacks[0].Outputs[?OutputKey=='LogsDashboardURL'].OutputValue" --output text
   ```

4. **Create a log metric filter for error tracking:**
   ```bash
   # Create a metric filter for errors across all services
   aws logs put-metric-filter \
     --log-group-name "$CENTRAL_LOG_GROUP" \
     --filter-name "AllServicesErrors" \
     --filter-pattern "ERROR" \
     --metric-transformations \
         metricName=AllErrors,metricNamespace=LogMetrics/Centralized,metricValue=1
   ```

### Step 8: Generate Dynamic Dashboards Based on Infrastructure

1. **Run the dashboard generator script:**
   ```bash
   # Navigate to the scripts directory
   cd ~/cloudwatch-lab/scripts
   
   # Make the script executable
   chmod +x dashboard-generator.py
   
   # Generate a dashboard for all resources
   python3 dashboard-generator.py --stack-name all --output infrastructure-dashboard.json
   ```

2. **Apply the generated dashboard:**
   ```bash
   # Apply the dashboard to CloudWatch
   python3 dashboard-generator.py --stack-name all --apply --dashboard-name InfrastructureDashboard
   ```

3. **Explore the generated dashboard:**
   ```bash
   # Get the dashboard URL
   REGION=$(aws configure get region)
   echo "Dashboard URL: https://$REGION.console.aws.amazon.com/cloudwatch/home?region=$REGION#dashboards:name=InfrastructureDashboard"
   ```

4. **Set up automated dashboard generation:**
   ```bash
   # Create a cron job to update the dashboard daily
   (crontab -l 2>/dev/null; echo "0 0 * * * cd ~/cloudwatch-lab/scripts && python3 dashboard-generator.py --stack-name all --apply --dashboard-name InfrastructureDashboard") | crontab -
   ```

## Advanced Topics

### Creating Composite Alarms

Composite alarms combine multiple alarms using logical operators (AND, OR, NOT) to create more sophisticated alerting conditions:

```bash
# Create a composite alarm that triggers when both CPU and Memory are high
aws cloudwatch put-composite-alarm \
  --alarm-name "HighResourceUsage" \
  --alarm-rule "(ALARM(HighCPUAlarm) AND ALARM(HighMemoryAlarm))" \
  --alarm-actions arn:aws:sns:us-east-1:YOUR_ACCOUNT_ID:cloudwatch-alarms-topic
```

### Cross-Account Monitoring

To implement cross-account monitoring:

1. Create a CloudWatch dashboard that includes metrics from multiple accounts
2. Set up cross-account IAM roles with appropriate permissions
3. Configure CloudWatch to assume these roles when accessing metrics

Example CloudFormation snippet for cross-account role:

```yaml
CrossAccountRole:
  Type: AWS::IAM::Role
  Properties:
    AssumeRolePolicyDocument:
      Version: '2012-10-17'
      Statement:
        - Effect: Allow
          Principal:
            AWS: 'arn:aws:iam::MONITORING_ACCOUNT_ID:root'
          Action: 'sts:AssumeRole'
    ManagedPolicyArns:
      - 'arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess'
```

### Anomaly Detection

CloudWatch can automatically detect anomalies in your metrics:

```bash
# Create an anomaly detection alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "AnomalyCPUUsage" \
  --metric-name "CPUUsage" \
  --namespace "CustomApp/Performance" \
  --statistic "Average" \
  --period 300 \
  --evaluation-periods 1 \
  --threshold-metric-id "ad1" \
  --comparison-operator "GreaterThanUpperThreshold" \
  --alarm-actions arn:aws:sns:us-east-1:YOUR_ACCOUNT_ID:cloudwatch-alarms-topic \
  --threshold-metric-id "ad1" \
  --anomaly-detection-threshold 2
```