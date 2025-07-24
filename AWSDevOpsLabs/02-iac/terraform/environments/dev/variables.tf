# Development Environment Variables

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "DevOpsLab"
}

# Override variables for development-specific needs
variable "enable_detailed_monitoring" {
  description = "Enable detailed monitoring (costs extra)"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "enable_multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "instance_type" {
  description = "Instance type for development"
  type        = string
  default     = "t3.micro"
}

# Development team access
variable "developer_ips" {
  description = "List of developer IP addresses for access"
  type        = list(string)
  default     = []
}

variable "enable_ssh_access" {
  description = "Enable SSH access for debugging"
  type        = bool
  default     = true
}

# Cost control variables
variable "auto_shutdown_schedule" {
  description = "Schedule for auto-shutdown (cron expression)"
  type        = string
  default     = "cron(0 18 * * MON-FRI *)"  # Shutdown at 6 PM weekdays
}

variable "auto_startup_schedule" {
  description = "Schedule for auto-startup (cron expression)"
  type        = string
  default     = "cron(0 8 * * MON-FRI *)"   # Start at 8 AM weekdays
}