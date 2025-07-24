# Backend Setup Variables

variable "aws_region" {
  description = "AWS region for backend resources"
  type        = string
  default     = "us-east-1"
}

variable "bucket_prefix" {
  description = "Prefix for S3 bucket name"
  type        = string
  default     = "devops-lab"
}

variable "table_prefix" {
  description = "Prefix for DynamoDB table name"
  type        = string
  default     = "devops-lab"
}

variable "policy_prefix" {
  description = "Prefix for IAM policy name"
  type        = string
  default     = "devops-lab"
}

variable "group_prefix" {
  description = "Prefix for IAM group name"
  type        = string
  default     = "devops-lab"
}