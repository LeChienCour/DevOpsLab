# Terraform Backend Setup - S3 + DynamoDB
# This creates the infrastructure needed for remote state management

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
      Project   = "DevOpsLab"
      ManagedBy = "Terraform"
      Purpose   = "Backend"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# S3 Bucket for Terraform State
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.bucket_prefix}-terraform-state-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"

  tags = {
    Name        = "Terraform State Bucket"
    Environment = "shared"
    Purpose     = "TerraformState"
  }
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Server Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "terraform_state_lifecycle"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# DynamoDB Table for State Locking
resource "aws_dynamodb_table" "terraform_locks" {
  name           = "${var.table_prefix}-terraform-locks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Terraform State Lock Table"
    Environment = "shared"
    Purpose     = "TerraformStateLock"
  }
}

# IAM Policy for Terraform Backend Access
resource "aws_iam_policy" "terraform_backend" {
  name        = "${var.policy_prefix}-terraform-backend-policy"
  description = "IAM policy for Terraform backend access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketVersioning"
        ]
        Resource = aws_s3_bucket.terraform_state.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.terraform_state.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = aws_dynamodb_table.terraform_locks.arn
      }
    ]
  })

  tags = {
    Name        = "Terraform Backend Policy"
    Environment = "shared"
    Purpose     = "TerraformBackend"
  }
}

# IAM Group for Terraform Users
resource "aws_iam_group" "terraform_users" {
  name = "${var.group_prefix}-terraform-users"
}

# Attach policy to group
resource "aws_iam_group_policy_attachment" "terraform_backend" {
  group      = aws_iam_group.terraform_users.name
  policy_arn = aws_iam_policy.terraform_backend.arn
}

# Output backend configuration template
resource "local_file" "backend_config" {
  content = templatefile("${path.module}/backend-config.tpl", {
    bucket         = aws_s3_bucket.terraform_state.bucket
    region         = data.aws_region.current.name
    dynamodb_table = aws_dynamodb_table.terraform_locks.name
  })
  filename = "${path.module}/../backend-config.tf"
}

# Output backend configuration for different environments
resource "local_file" "backend_config_dev" {
  content = templatefile("${path.module}/backend-config.tpl", {
    bucket         = aws_s3_bucket.terraform_state.bucket
    region         = data.aws_region.current.name
    dynamodb_table = aws_dynamodb_table.terraform_locks.name
    key            = "dev/terraform.tfstate"
  })
  filename = "${path.module}/../environments/dev/backend.tf"
}

resource "local_file" "backend_config_staging" {
  content = templatefile("${path.module}/backend-config.tpl", {
    bucket         = aws_s3_bucket.terraform_state.bucket
    region         = data.aws_region.current.name
    dynamodb_table = aws_dynamodb_table.terraform_locks.name
    key            = "staging/terraform.tfstate"
  })
  filename = "${path.module}/../environments/staging/backend.tf"
}

resource "local_file" "backend_config_prod" {
  content = templatefile("${path.module}/backend-config.tpl", {
    bucket         = aws_s3_bucket.terraform_state.bucket
    region         = data.aws_region.current.name
    dynamodb_table = aws_dynamodb_table.terraform_locks.name
    key            = "prod/terraform.tfstate"
  })
  filename = "${path.module}/../environments/prod/backend.tf"
}