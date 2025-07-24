# AWS Resources and Costs for CI/CD Labs

This document provides a comprehensive list of AWS resources created by each lab in the CI/CD module, their free tier eligibility, and estimated costs.

## CodeDeploy Lab Resources

### Core Resources
- **CodeDeploy Application**: Single EC2 application
  - **Free Tier**: Yes - AWS CodeDeploy is free for deployments to EC2 instances
  - **Cost**: $0.00

- **Deployment Group**: In-place deployment configuration
  - **Free Tier**: Yes
  - **Cost**: $0.00

- **EC2 Instances**: 2 x t3.micro instances
  - **Free Tier**: Yes - 750 hours/month free per t3.micro (for 12 months)
  - **Cost after Free Tier**: $0.0116/hour per instance (~$17/month for both)

- **S3 Bucket**: Deployment artifact storage
  - **Free Tier**: Yes - 5GB storage, 20,000 GET requests, 2,000 PUT requests (for 12 months)
  - **Cost after Free Tier**: $0.023/GB/month for storage, $0.005 per 1,000 GET requests, $0.05 per 1,000 PUT requests

- **IAM Roles**: Service roles for CodeDeploy and EC2
  - **Free Tier**: Yes - IAM is always free
  - **Cost**: $0.00

- **Security Group**: Basic web access configuration
  - **Free Tier**: Yes - Security Groups are always free
  - **Cost**: $0.00

### Monitoring Resources
- **CloudWatch Logs**: Deployment and application logs
  - **Free Tier**: Yes - 5GB of logs ingested and 5GB of logs stored (for 12 months)
  - **Cost after Free Tier**: $0.50/GB for ingestion, $0.03/GB for storage

- **CloudWatch Alarms**: Basic deployment monitoring
  - **Free Tier**: Yes - 10 alarm metrics (for 12 months)
  - **Cost after Free Tier**: $0.10 per alarm metric per month

### Total Estimated Cost
- **With Free Tier**: $0-5/month (primarily for CloudWatch usage beyond free tier)
- **Without Free Tier**: $20-30/month

## CodePipeline Lab Resources

### Core Resources
- **CodePipeline**: Multi-stage pipeline with source, build, test, deploy stages
  - **Free Tier**: No - First active pipeline is free for the first month only
  - **Cost**: $1.00/month per active pipeline

- **S3 Source Bucket**: Source code storage with versioning
  - **Free Tier**: Yes - 5GB storage (for 12 months)
  - **Cost after Free Tier**: $0.023/GB/month for storage, additional cost for versioning

- **CodeBuild Projects**: Separate projects for build and test phases
  - **Free Tier**: Yes - 100 build minutes/month (for 12 months)
  - **Cost after Free Tier**: $0.005/minute for build time on general1.small compute type

- **S3 Buckets**: Artifact storage and static website hosting
  - **Free Tier**: Yes - 5GB storage (for 12 months)
  - **Cost after Free Tier**: $0.023/GB/month for storage

### Supporting Resources
- **IAM Roles**: Service roles for CodePipeline and CodeBuild
  - **Free Tier**: Yes - IAM is always free
  - **Cost**: $0.00

- **S3 Bucket Policies**: Access control for pipeline resources
  - **Free Tier**: Yes - S3 bucket policies are always free
  - **Cost**: $0.00

- **CloudWatch Logs**: Log groups for build and test execution logs
  - **Free Tier**: Yes - 5GB of logs ingested (for 12 months)
  - **Cost after Free Tier**: $0.50/GB for ingestion

### Total Estimated Cost
- **With Free Tier**: $1-5/month (primarily for CodePipeline)
- **Without Free Tier**: $5-15/month (depends on build frequency and duration)

## CodeBuild Lab Resources

### Core Resources
- **CodeBuild Project**: Single Node.js build project with basic caching
  - **Free Tier**: Yes - 100 build minutes/month (for 12 months)
  - **Cost after Free Tier**: $0.005/minute for build time on general1.small compute type

- **S3 Source Bucket**: Source code storage
  - **Free Tier**: Yes - 5GB storage (for 12 months)
  - **Cost after Free Tier**: $0.023/GB/month for storage

- **S3 Artifact Bucket**: Build output storage
  - **Free Tier**: Yes - 5GB storage (for 12 months)
  - **Cost after Free Tier**: $0.023/GB/month for storage

- **IAM Service Role**: Permissions for CodeBuild operations
  - **Free Tier**: Yes - IAM is always free
  - **Cost**: $0.00

- **CloudWatch Log Group**: Build execution logs
  - **Free Tier**: Yes - 5GB of logs ingested (for 12 months)
  - **Cost after Free Tier**: $0.50/GB for ingestion

### Total Estimated Cost
- **With Free Tier**: $0-5/month (primarily for build minutes beyond free tier)
- **Without Free Tier**: $5-10/month (depends on build frequency and duration)

## Cost Optimization Tips

1. **Clean up resources after lab completion**
   - Always run the cleanup scripts provided with each lab
   - Verify all resources are terminated, especially EC2 instances and NAT Gateways

2. **Minimize costs during active use**
   - Use smaller instance types for development and testing
   - Implement auto-scaling to reduce instances during low-usage periods
   - Set up CloudWatch alarms to alert on unexpected usage or costs

3. **Leverage free tier effectively**
   - Schedule intensive activities within the free tier period
   - Monitor free tier usage through AWS Billing dashboard
   - Set up billing alerts to notify when approaching free tier limits

4. **Optimize storage costs**
   - Implement lifecycle policies for S3 buckets to archive or delete old artifacts
   - Clean up unused Docker images and build caches
   - Monitor and clean up CloudWatch Logs

## Important Notes

- All cost estimates are approximate and may vary based on actual usage patterns
- Costs may be higher in certain AWS regions
- Free tier eligibility applies to new AWS accounts for the first 12 months
- Some services like CodePipeline have a free tier for the first month only
- Always check the [AWS Pricing Calculator](https://calculator.aws/#/) for the most up-to-date pricing information