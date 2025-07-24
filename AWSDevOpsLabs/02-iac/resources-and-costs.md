# AWS Resources and Costs for Infrastructure as Code Labs

This document provides a comprehensive list of AWS resources created by each lab in the Infrastructure as Code (IaC) module, their free tier eligibility, and estimated costs.

## CloudFormation Lab Resources

### Networking Resources
- **VPC**: Virtual Private Cloud with custom CIDR
  - **Free Tier**: Yes - VPC is always free
  - **Cost**: $0.00

- **Subnets**: Public and private subnets across availability zones
  - **Free Tier**: Yes - Subnets are always free
  - **Cost**: $0.00

- **Internet Gateway**: For public internet access
  - **Free Tier**: Yes - Internet Gateway is always free
  - **Cost**: $0.00

- **Route Tables**: For controlling network traffic
  - **Free Tier**: Yes - Route Tables are always free
  - **Cost**: $0.00

### Security Resources
- **Security Groups**: For web tier and application tier
  - **Free Tier**: Yes - Security Groups are always free
  - **Cost**: $0.00

- **IAM Roles**: For Lambda functions and EC2 instances
  - **Free Tier**: Yes - IAM is always free
  - **Cost**: $0.00

### Compute Resources
- **EC2 Instances**: For hosting the application (t3.micro)
  - **Free Tier**: Yes - 750 hours/month free (for 12 months)
  - **Cost after Free Tier**: ~$0.0116/hour per instance (~$8.50/month)

- **Lambda Function**: For custom resource implementation
  - **Free Tier**: Yes - 1M requests/month and 400,000 GB-seconds/month
  - **Cost after Free Tier**: $0.20 per 1M requests, $0.0000166667 per GB-second

### Storage Resources
- **S3 Bucket**: For storing CloudFormation templates
  - **Free Tier**: Yes - 5GB storage (for 12 months)
  - **Cost after Free Tier**: $0.023/GB/month for storage

### Total Estimated Cost
- **With Free Tier**: $0.00-$1.00/day (primarily for EC2 instances)
- **Without Free Tier**: $0.50-$1.00/day (~$15-30/month)

## Terraform Lab Resources

### Networking Resources
- **VPC**: Virtual Private Cloud with custom CIDR
  - **Free Tier**: Yes - VPC is always free
  - **Cost**: $0.00

- **Subnets**: Public and private subnets across availability zones
  - **Free Tier**: Yes - Subnets are always free
  - **Cost**: $0.00

- **Internet Gateway**: For public internet access
  - **Free Tier**: Yes - Internet Gateway is always free
  - **Cost**: $0.00

- **NAT Gateway**: For private subnet internet access
  - **Free Tier**: No
  - **Cost**: ~$0.045/hour (~$32/month) + data processing charges

- **Route Tables**: For controlling network traffic
  - **Free Tier**: Yes - Route Tables are always free
  - **Cost**: $0.00

### Compute Resources
- **ECS Cluster**: For container orchestration
  - **Free Tier**: Yes - ECS clusters are free, you pay for underlying resources
  - **Cost**: $0.00

- **ECS Service**: For running the web application
  - **Free Tier**: Yes - ECS services are free, you pay for underlying resources
  - **Cost**: $0.00

- **ECS Task Definition**: For container configuration
  - **Free Tier**: Yes - Task definitions are free
  - **Cost**: $0.00

- **Application Load Balancer**: For distributing traffic
  - **Free Tier**: No
  - **Cost**: ~$0.0225/hour (~$16/month) + data processing charges

### Storage Resources
- **S3 Bucket**: For Terraform state storage
  - **Free Tier**: Yes - 5GB storage (for 12 months)
  - **Cost after Free Tier**: $0.023/GB/month for storage

- **DynamoDB Table**: For state locking
  - **Free Tier**: Yes - 25GB storage
  - **Cost after Free Tier**: $0.25/GB/month for storage, plus throughput charges

### Monitoring Resources
- **CloudWatch Dashboard**: For application monitoring
  - **Free Tier**: No - First 3 dashboards are $3.00/month, then $0.30/dashboard/month
  - **Cost**: $3.00/month for first 3 dashboards

- **CloudWatch Alarms**: For performance alerting
  - **Free Tier**: Yes - 10 alarm metrics (for 12 months)
  - **Cost after Free Tier**: $0.10 per alarm metric per month

- **CloudWatch Log Groups**: For application logs
  - **Free Tier**: Yes - 5GB of logs ingested (for 12 months)
  - **Cost after Free Tier**: $0.50/GB for ingestion

### IAM Resources
- **IAM Roles**: For service execution
  - **Free Tier**: Yes - IAM is always free
  - **Cost**: $0.00

- **IAM Policies**: For resource access
  - **Free Tier**: Yes - IAM is always free
  - **Cost**: $0.00

### Total Estimated Cost
- **With Free Tier**: ~$50-60/month (primarily for NAT Gateway and ALB)
- **Without Free Tier**: ~$50-70/month

## AWS CDK Lab Resources

### Networking Resources
- **VPC**: Virtual Private Cloud with custom CIDR
  - **Free Tier**: Yes - VPC is always free
  - **Cost**: $0.00

- **Subnets**: Public and private subnets across availability zones
  - **Free Tier**: Yes - Subnets are always free
  - **Cost**: $0.00

- **Internet Gateway**: For public internet access
  - **Free Tier**: Yes - Internet Gateway is always free
  - **Cost**: $0.00

- **NAT Gateway**: For private subnet internet access
  - **Free Tier**: No
  - **Cost**: ~$0.045/hour (~$32/month) + data processing charges

- **Route Tables**: For controlling network traffic
  - **Free Tier**: Yes - Route Tables are always free
  - **Cost**: $0.00

### Compute Resources
- **ECS Cluster**: For container orchestration
  - **Free Tier**: Yes - ECS clusters are free, you pay for underlying resources
  - **Cost**: $0.00

- **ECS Service**: For running the web application
  - **Free Tier**: Yes - ECS services are free, you pay for underlying resources
  - **Cost**: $0.00

- **Fargate Tasks**: For running containers
  - **Free Tier**: No
  - **Cost**: ~$0.04/hour for specified resources (varies based on CPU/memory)

- **Application Load Balancer**: For distributing traffic
  - **Free Tier**: No
  - **Cost**: ~$0.0225/hour (~$16/month) + data processing charges

### Storage Resources
- **S3 Bucket**: For CDK bootstrap and assets
  - **Free Tier**: Yes - 5GB storage (for 12 months)
  - **Cost after Free Tier**: $0.023/GB/month for storage

### Monitoring Resources
- **CloudWatch Dashboard**: For application monitoring
  - **Free Tier**: No - First 3 dashboards are $3.00/month, then $0.30/dashboard/month
  - **Cost**: $3.00/month for first 3 dashboards

- **CloudWatch Alarms**: For performance alerting
  - **Free Tier**: Yes - 10 alarm metrics (for 12 months)
  - **Cost after Free Tier**: $0.10 per alarm metric per month

- **CloudWatch Log Groups**: For application logs
  - **Free Tier**: Yes - 5GB of logs ingested (for 12 months)
  - **Cost after Free Tier**: $0.50/GB for ingestion

### IAM Resources
- **IAM Roles**: For service execution
  - **Free Tier**: Yes - IAM is always free
  - **Cost**: $0.00

- **IAM Policies**: For resource access
  - **Free Tier**: Yes - IAM is always free
  - **Cost**: $0.00

### Total Estimated Cost
- **With Free Tier**: ~$50-70/month (primarily for NAT Gateway, Fargate, and ALB)
- **Without Free Tier**: ~$60-80/month

## Cost Optimization Tips

1. **Clean up resources after lab completion**
   - Always run the cleanup scripts provided with each lab
   - Verify all resources are terminated, especially NAT Gateways and Load Balancers
   - Check for any lingering EC2 instances or ECS tasks

2. **Minimize costs during active use**
   - Use smaller instance types for development and testing
   - Consider using a single NAT Gateway instead of one per AZ for non-production environments
   - Use Spot instances where appropriate for non-critical workloads

3. **Leverage free tier effectively**
   - Schedule intensive activities within the free tier period
   - Monitor free tier usage through AWS Billing dashboard
   - Set up billing alerts to notify when approaching free tier limits

4. **Optimize networking costs**
   - NAT Gateways are one of the most expensive components - consider alternatives like NAT instances for dev/test
   - Use VPC endpoints for AWS services to reduce NAT Gateway traffic
   - Consider using a single AZ for development environments to reduce redundant resources

5. **Manage state storage costs**
   - Implement lifecycle policies for S3 buckets to manage state file versions
   - Use DynamoDB on-demand capacity for infrequent state operations
   - Clean up old state files and lock entries when no longer needed

## Important Notes

- All cost estimates are approximate and may vary based on actual usage patterns
- Costs may be higher in certain AWS regions
- Free tier eligibility applies to new AWS accounts for the first 12 months
- Always check the [AWS Pricing Calculator](https://calculator.aws/#/) for the most up-to-date pricing information
- The most significant costs in these labs come from NAT Gateways and Load Balancers
- Remember to destroy all resources after completing the labs to avoid ongoing charges