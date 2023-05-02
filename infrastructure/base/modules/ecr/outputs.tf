output "pipeline_resources_arn" {
  description = "The Amazon Resource Name (ARN) assigned to the repository."
  value       = try(aws_ecr_repository.pipeline_resources.arn, "")
}

output "pipeline_resources_url" {
  description = "The URL assigned to the repository."
  value       = try(aws_ecr_repository.pipeline_resources.repository_url, "")
}
