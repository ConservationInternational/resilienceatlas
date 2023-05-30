variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "allowed_account_id" {
  type        = string
  description = "AWS account id to which the resources will be deployed"
}

variable "bucket_name_prefix" {
  type        = string
  description = "The name of the S3 bucket to store build artifacts data"
}

variable "base_route53_zone_name" {
  type        = string
  description = "The name of the existing Route53 zone to use as base for the TiTiler DNS records."
}

variable "route53_prefix" {
  type        = string
  description = "Prefix to use for the Route53 zone created for the TiTiler deployments."
  default     = "tt"
}

variable "github_repo_name" {
  type        = string
  description = "The name of the Github repo where the source code is stored."
}

# GCP account config
variable "gcp_region" {
  type        = string
  description = "GCP region"
}

variable "gcp_zone" {
  type        = string
  description = "GCP zone"
}

variable "gcp_project_id" {
  type        = string
  description = "GCP project id"
}
