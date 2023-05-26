output "build_artifacts_bucket_arn" {
  description = "The Amazon Resource Name (ARN) assigned to the bucket."
  value       = try(aws_s3_bucket.bucket.arn, "")
}

output "bucket_name" {
  value = aws_s3_bucket.bucket.bucket
}
