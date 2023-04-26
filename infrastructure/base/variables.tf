variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "allowed_account_id" {
  type        = string
  description = "AWS account id"
}

variable "terraform_state_bucket" {
  type        = string
  description = "The name of the S3 bucket to create for storing tf state"
  default     = "resilience-atlas-terraform-state"
}

variable "bucket_name" {
  type        = string
  description = "The name of the S3 bucket to store application data"
}
