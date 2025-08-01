# Development Environment Outputs

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "database_subnet_ids" {
  description = "IDs of the database subnets"
  value       = module.vpc.database_subnet_ids
}

output "application_url" {
  description = "URL to access the application"
  value       = module.web_app.application_url
}

output "web_app_url" {
  description = "URL to access the web application (alias for application_url)"
  value       = module.web_app.application_url
}

output "load_balancer_dns_name" {
  description = "DNS name of the load balancer"
  value       = module.web_app.load_balancer_dns_name
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.web_app.ecs_cluster_name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.web_app.ecs_service_name
}

output "dev_assets_bucket_name" {
  description = "Name of the development assets S3 bucket"
  value       = aws_s3_bucket.dev_assets.bucket
}

output "cloudwatch_dashboard_url" {
  description = "URL to the CloudWatch dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.dev_dashboard.dashboard_name}"
}

# Useful information for developers
output "development_info" {
  description = "Development environment information"
  value = {
    environment     = "dev"
    region         = var.aws_region
    vpc_id         = module.vpc.vpc_id
    application_url = module.web_app.application_url
    
    # Useful for debugging
    ecs_cluster_name = module.web_app.ecs_cluster_name
    ecs_service_name = module.web_app.ecs_service_name
    log_group_name   = module.web_app.cloudwatch_log_group_name
    
    # Cost optimization info
    nat_gateway_count = length(module.vpc.nat_gateway_ids)
    ecs_desired_count = 1
    
    # Access information
    ssh_access_enabled = var.enable_ssh_access
  }
}

# Export values for use in other configurations
output "terraform_workspace" {
  description = "Current Terraform workspace"
  value       = terraform.workspace
}

output "deployment_timestamp" {
  description = "Timestamp of deployment"
  value       = timestamp()
}