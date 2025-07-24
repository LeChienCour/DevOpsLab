# VPC Module Variables

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_count" {
  description = "Number of public subnets"
  type        = number
  default     = 2

  validation {
    condition     = var.public_subnet_count >= 1 && var.public_subnet_count <= 6
    error_message = "Public subnet count must be between 1 and 6."
  }
}

variable "private_subnet_count" {
  description = "Number of private subnets"
  type        = number
  default     = 2

  validation {
    condition     = var.private_subnet_count >= 1 && var.private_subnet_count <= 6
    error_message = "Private subnet count must be between 1 and 6."
  }
}

variable "database_subnet_count" {
  description = "Number of database subnets"
  type        = number
  default     = 2

  validation {
    condition     = var.database_subnet_count >= 2 && var.database_subnet_count <= 6
    error_message = "Database subnet count must be between 2 and 6 for RDS subnet group requirements."
  }
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "nat_gateway_count" {
  description = "Number of NAT Gateways (should match public subnet count for HA)"
  type        = number
  default     = 1

  validation {
    condition     = var.nat_gateway_count >= 1 && var.nat_gateway_count <= 6
    error_message = "NAT Gateway count must be between 1 and 6."
  }
}

variable "enable_vpc_endpoints" {
  description = "Enable VPC endpoints for S3 and DynamoDB"
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "DevOpsLab"
    ManagedBy = "Terraform"
  }
}