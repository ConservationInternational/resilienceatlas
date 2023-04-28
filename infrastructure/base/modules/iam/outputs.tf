output "pipeline_user_arn" {
  description = "The Amazon Resource Name (ARN) assigned to the pipeline user"
  value       = try(aws_iam_user.pipeline_user.arn, "")
}

output "pipeline_user_access_key_id" {
  description = "The access key id for the pipeline user"
  value       = try(aws_iam_access_key.pipeline_user_access_key.id, "")
}

output "pipeline_user_access_key_secret" {
  description = "The access key secret for the pipeline user"
  value       = try(aws_iam_access_key.pipeline_user_access_key.secret, "")
}

output "cloud_formation_role_arn" {
  description = "The Amazon Resource Name (ARN) assigned to the cloud formation role"
  value       = try(aws_iam_role.cloud_formation_role.arn, "")
}

output "pipeline_role_arn" {
  description = "The Amazon Resource Name (ARN) assigned to the pipeline role"
  value       = try(aws_iam_role.pipeline_role.arn, "")
}
