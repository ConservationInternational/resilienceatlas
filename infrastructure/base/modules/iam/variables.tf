variable "ecr_repository_arn" {
  type        = string
  description = "The Amazon Resource Name (ARN) assigned to the pipeline ECR repository"
}
variable "build_artifacts_bucket_arn" {
  type        = string
  description = "The Amazon Resource Name (ARN) assigned to the build artifacts bucket."
}
