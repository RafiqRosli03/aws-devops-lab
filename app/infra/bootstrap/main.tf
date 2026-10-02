# ---------------------------------------------------------------------------
# BOOTSTRAP - creates the Terraform remote-state backend.
# Run this ONCE, before the main env. Uses LOCAL state (chicken-and-egg:
# the remote state store can't store its own creation).
# ---------------------------------------------------------------------------
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]
}

variable "region" {
  type    = string
  default = "ap-southeast-5"
}

variable "account_id" {
  type    = string
  default = "497862079645"
}

variable "state_bucket_name" {
  type        = string
  default     = "devops-lab-tfstate-497862079645"
  description = "Globally-unique S3 bucket name for Terraform state."
}

variable "lock_table_name" {
  type    = string
  default = "devops-lab-tf-locks"
}

# --- S3 bucket for state ---
resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket_name
  tags   = { Project = "devops-lab", Purpose = "terraform-state" }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- DynamoDB table for state locking ---
resource "aws_dynamodb_table" "locks" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  tags = { Project = "devops-lab", Purpose = "terraform-lock" }
}

output "state_bucket" {
  value = aws_s3_bucket.state.id
}

output "lock_table" {
  value = aws_dynamodb_table.locks.name
}
