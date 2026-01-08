output "ecr_repository_arn" {
  description = "The Amazon Resource Name (ARN) assigned to the ECR repository."
  value       = try(aws_ecr_repository.repository.arn, "")
}

output "ecr_repository_url" {
  description = "The URL assigned to the ECR repository."
  value       = try(aws_ecr_repository.repository.repository_url, "")
}
