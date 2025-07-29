# AWS DevOps Labs Simple Pricing Helper

## Overview

The AWS DevOps Labs Simple Pricing Helper provides basic cost estimation and Free Tier awareness for laboratory exercises. This lightweight system helps users understand approximate costs without the complexity of real-time pricing APIs.

## Features

### 1. Simple Cost Estimation
- Basic cost calculation using standard AWS pricing
- Free Tier consideration for common services
- No complex API calls or caching required
- Support for EC2, S3, Lambda, CodeBuild, and other services

### 2. Free Tier Awareness
- Built-in Free Tier limits for major services
- Simple overage calculation
- Basic recommendations for staying within limits

### 3. Lab Manager Integration
- Integrated with existing lab management system
- Enhanced cost display in lab listings
- Simple pricing analysis commands

## Installation

### Prerequisites
- Python 3.8 or higher
- AWS CLI configured with appropriate credentials
- boto3 library

### Setup
1. Install required dependencies:
```bash
pip install -r requirements-pricing.txt
```

2. Configure AWS credentials:
```bash
aws configure
```

3. Verify installation:
```bash
python scripts/pricing_cli.py --help
```

## Usage

### Command Line Interface

#### Get Service Pricing
```bash
# Get EC2 pricing for us-east-1
python scripts/pricing_cli.py service-pricing EC2 --region us-east-1

# Get Lambda pricing in table format
python scripts/pricing_cli.py service-pricing Lambda --format table
```

#### Analyze Lab Costs
```bash
# Analyze cost for a specific lab
python scripts/pricing_cli.py analyze-lab config/sample-lab-config.json --duration 2.0

# Get cost summary
python scripts/pricing_cli.py analyze-lab config/sample-lab-config.json --format summary
```

#### Generate Reports
```bash
# Generate report for multiple labs
python scripts/pricing_cli.py lab-report config/sample-lab-config.json config/monitoring-lab-config.json --output report.json

# Generate cost optimization report
python scripts/pricing_cli.py optimize config/sample-lab-config.json --output optimization.json
```

#### Track Free Tier Usage
```bash
# Show Free Tier usage status
python scripts/pricing_cli.py free-tier-usage

# Get Free Tier summary
python scripts/pricing_cli.py free-tier-usage --format summary
```

#### Compare Regional Pricing
```bash
# Compare EC2 and Lambda pricing across regions
python scripts/pricing_cli.py regional-pricing EC2 Lambda --regions us-east-1 us-west-2 eu-west-1
```

#### Set Budget Thresholds
```bash
# Set warning threshold to 80%
python scripts/pricing_cli.py set-threshold warning 0.8

# Set critical threshold to 95%
python scripts/pricing_cli.py set-threshold critical 0.95
```

### Lab Manager Integration

#### List Labs with Pricing
```bash
# List all labs with pricing information
python lab-manager.py list --pricing

# List labs in specific category with pricing
python lab-manager.py list --category cicd --pricing --detailed
```

#### Analyze Specific Lab
```bash
# Show detailed pricing analysis for a lab
python lab-manager.py pricing cicd-codepipeline
```

#### Check Free Tier Status
```bash
# Show current Free Tier usage status
python lab-manager.py free-tier
```

#### Generate Cost Report
```bash
# Generate comprehensive cost report
python lab-manager.py cost-report

# Save report to file
python lab-manager.py cost-report --output cost-analysis.json
```

### Python API

#### Basic Usage
```python
from scripts.pricing_analyzer import AWSPricingDataIntegration
from scripts.free_tier_tracker import FreeTierTracker
from scripts.cost_comparison import CostComparisonSystem

# Initialize components
pricing_analyzer = AWSPricingDataIntegration()
free_tier_tracker = FreeTierTracker()
cost_comparison = CostComparisonSystem()

# Get EC2 pricing
ec2_pricing = pricing_analyzer.get_ec2_pricing(['t3.micro', 't3.small'], ['us-east-1'])

# Track lab session usage
usage_data = {
    'EC2': {'hours': 2.0, 'instance_type': 't3.micro'},
    'S3': {'storage_gb': 1.0, 'get_requests': 1000, 'put_requests': 100}
}
result = free_tier_tracker.track_lab_session_usage('my-lab', 'session-001', usage_data)

# Create cost comparison
lab_config = {
    'lab_id': 'test-lab',
    'resources': {
        'EC2': {'instance_type': 't3.micro', 'count': 1},
        'S3': {'storage_gb': 1.0, 'get_requests': 1000, 'put_requests': 100}
    }
}
comparison = cost_comparison.create_side_by_side_comparison(lab_config, 2.0)
```

## Configuration

### Pricing CLI Configuration
The pricing CLI uses a configuration file `pricing_cli_config.json`:

```json
{
  "default_region": "us-east-1",
  "budget_thresholds": {
    "warning": 0.75,
    "critical": 0.90
  },
  "report_format": "json",
  "cache_duration_hours": 24,
  "default_budget_limit": 10.0
}
```

### Lab Configuration Format
Lab configurations should follow this format:

```json
{
  "lab_id": "cicd-pipeline-lab",
  "name": "CI/CD Pipeline Lab",
  "description": "Complete CI/CD pipeline using CodePipeline, CodeBuild, and CodeDeploy",
  "resources": {
    "EC2": {
      "instance_type": "t3.micro",
      "count": 2,
      "description": "Application servers for deployment"
    },
    "S3": {
      "storage_gb": 2.0,
      "get_requests": 5000,
      "put_requests": 500,
      "description": "Artifact storage and static website hosting"
    },
    "Lambda": {
      "requests": 50000,
      "gb_seconds": 2000,
      "description": "Build notifications and automation functions"
    },
    "CodeBuild": {
      "build_minutes": 60,
      "description": "Build and test automation"
    }
  },
  "estimated_duration_hours": 3.0,
  "difficulty": "intermediate",
  "prerequisites": ["basic-aws-knowledge", "git-fundamentals"]
}
```

## Free Tier Information

### Legacy Free Tier (Accounts created before July 15, 2025)
- 12-month Free Tier period from account creation
- EC2: 750 hours/month of t2.micro or t3.micro instances
- S3: 5 GB standard storage, 20,000 GET requests, 2,000 PUT requests
- Lambda: 1 million requests and 400,000 GB-seconds compute time per month
- CodeBuild: 100 build minutes per month
- CloudWatch: 10 custom metrics, 10 alarms, 1 million API requests

### New Free Tier (Accounts created on/after July 15, 2025)
- 6-month Free Tier period or until $200 credits exhausted
- Expanded instance types: t3.micro, t3.small, t4g.micro, t4g.small, c7i-flex.large, m7i-flex.large
- Same service limits but with credit-based billing

## Cost Optimization Tips

### Maximize Free Tier Benefits
1. Use Free Tier eligible instance types (t3.micro, t2.micro)
2. Monitor monthly usage to stay within limits
3. Implement automatic shutdown after lab completion
4. Leverage always-free services (IAM, CloudFormation, VPC)

### Standard Pricing Optimization
1. Use Spot instances for non-critical lab components (60-90% savings)
2. Implement resource tagging for accurate cost tracking
3. Schedule labs during off-peak hours for potential savings
4. Use smaller instance types and scale up only when necessary

### Multi-Lab Session Management
1. Share resources across related labs to reduce duplication
2. Implement bulk cleanup procedures to prevent orphaned resources
3. Set up cost alerts at 50%, 75%, and 90% of estimated budgets
4. Consider regional optimization based on pricing differences

## Troubleshooting

### Common Issues

#### AWS Credentials Not Configured
```
Error: AWS credentials not found. Please configure AWS credentials.
```
**Solution:** Run `aws configure` or set up AWS credentials using environment variables.

#### Pricing API Access Issues
```
Error: Access denied to AWS Pricing API
```
**Solution:** Ensure your AWS credentials have the necessary permissions for the Pricing API.

#### Cache Issues
```
Warning: Error loading cache file
```
**Solution:** Clear the pricing cache using the CLI or manually delete cache files.

#### Module Import Errors
```
Warning: Pricing analysis modules not available
```
**Solution:** Ensure all required Python modules are installed and the scripts directory is in the Python path.

### Getting Help

1. Check the troubleshooting section in the main README
2. Review AWS documentation for service-specific pricing information
3. Use the `--help` flag with any CLI command for detailed usage information
4. Check the test files for usage examples

## Testing

Run the test suite to verify functionality:

```bash
# Test pricing analyzer
python -m pytest tests/test_pricing_analyzer.py -v

# Test Free Tier tracker
python -m pytest tests/test_free_tier_tracker.py -v

# Test cost comparison system
python -m pytest tests/test_cost_comparison.py -v

# Test pricing CLI
python -m pytest tests/test_pricing_cli.py -v

# Run all pricing tests
python -m pytest tests/test_*pricing* tests/test_*tier* tests/test_*cost* -v
```

## Contributing

When contributing to the pricing analysis system:

1. Follow the existing code structure and patterns
2. Add comprehensive tests for new functionality
3. Update documentation for any new features
4. Ensure backward compatibility with existing lab configurations
5. Test with both Free Tier and standard pricing scenarios

## License

This pricing analysis system is part of the AWS DevOps Labs project and follows the same licensing terms.