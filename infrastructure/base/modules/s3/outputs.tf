output "build_artifacts_bucket_arn" {
  description = "The Amazon Resource Name (ARN) assigned to the bucket."
  value       = try(aws_s3_bucket.build_artifacts_bucket.arn, "")
}