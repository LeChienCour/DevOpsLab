# Development Environment Configuration
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "dev"
      Project     = "DevOpsLab"
      ManagedBy   = "Terraform"
      CostCenter  = "Development"
    }
  }
}

# Local values for environment-specific configuration
locals {
  environment = "dev"
  
  common_tags = {
    Environment = local.environment
    Project     = "DevOpsLab"
    ManagedBy   = "Terraform"
    CostCenter  = "Development"
  }

  # Development-specific configurations
  vpc_config = {
    cidr_block              = "10.0.0.0/16"
    public_subnet_count     = 2
    private_subnet_count    = 2
    database_subnet_count   = 2
    enable_nat_gateway      = true
    nat_gateway_count       = 1  # Single NAT for cost savings in dev
    enable_vpc_endpoints    = false
    enable_flow_logs        = false
  }

  web_app_config = {
    app_name                    = "devops-webapp"
    container_image            = "nginx:alpine"
    container_port             = 80
    cpu                        = 256
    memory                     = 512
    desired_count              = 1  # Minimal for dev
    enable_autoscaling         = false
    min_capacity               = 1
    max_capacity               = 3
    enable_deletion_protection = false
    log_retention_days         = 7
    
    environment_variables = {
      ENVIRONMENT = local.environment
      APP_NAME    = "DevOps Lab Web App"
      LOG_LEVEL   = "DEBUG"
    }
  }
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  environment             = local.environment
  vpc_cidr               = local.vpc_config.cidr_block
  public_subnet_count    = local.vpc_config.public_subnet_count
  private_subnet_count   = local.vpc_config.private_subnet_count
  database_subnet_count  = local.vpc_config.database_subnet_count
  enable_nat_gateway     = local.vpc_config.enable_nat_gateway
  nat_gateway_count      = local.vpc_config.nat_gateway_count
  enable_vpc_endpoints   = local.vpc_config.enable_vpc_endpoints
  enable_flow_logs       = local.vpc_config.enable_flow_logs
  
  common_tags = local.common_tags
}

# Web Application Module
module "web_app" {
  source = "../../modules/web-app"

  environment                = local.environment
  app_name                  = local.web_app_config.app_name
  vpc_id                    = module.vpc.vpc_id
  public_subnet_ids         = module.vpc.public_subnet_ids
  private_subnet_ids        = module.vpc.private_subnet_ids
  
  container_image           = local.web_app_config.container_image
  container_port            = local.web_app_config.container_port
  cpu                       = local.web_app_config.cpu
  memory                    = local.web_app_config.memory
  desired_count             = local.web_app_config.desired_count
  
  enable_autoscaling        = local.web_app_config.enable_autoscaling
  min_capacity              = local.web_app_config.min_capacity
  max_capacity              = local.web_app_config.max_capacity
  
  enable_deletion_protection = local.web_app_config.enable_deletion_protection
  log_retention_days        = local.web_app_config.log_retention_days
  environment_variables     = local.web_app_config.environment_variables
  
  common_tags = local.common_tags
}

# Development-specific resources
resource "aws_s3_bucket" "dev_assets" {
  bucket = "devops-lab-dev-assets-${random_id.bucket_suffix.hex}"

  tags = merge(local.common_tags, {
    Name    = "Development Assets Bucket"
    Purpose = "Development"
  })
}

resource "aws_s3_bucket_versioning" "dev_assets" {
  bucket = aws_s3_bucket.dev_assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "dev_assets" {
  bucket = aws_s3_bucket.dev_assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "dev_assets" {
  bucket = aws_s3_bucket.dev_assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# CloudWatch Dashboard for Development
resource "aws_cloudwatch_dashboard" "dev_dashboard" {
  dashboard_name = "DevOpsLab-${local.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", module.web_app.load_balancer_arn],
            [".", "TargetResponseTime", ".", "."],
            [".", "HTTPCode_ELB_5XX_Count", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Application Load Balancer Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", module.web_app.ecs_service_name, "ClusterName", module.web_app.ecs_cluster_name],
            [".", "MemoryUtilization", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "ECS Service Metrics"
          period  = 300
        }
      }
    ]
  })
}

# Development-specific alarms (less strict)
resource "aws_cloudwatch_metric_alarm" "high_response_time" {
  alarm_name          = "${local.environment}-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "10"  # More lenient for dev
  alarm_description   = "This metric monitors ALB response time"
  alarm_actions       = []  # No actions in dev

  dimensions = {
    LoadBalancer = module.web_app.load_balancer_arn
  }

  tags = local.common_tags
}