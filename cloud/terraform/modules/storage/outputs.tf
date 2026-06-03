output "artifacts_bucket_name" {
  description = "Name of the S3 bucket used for logs, metrics, AI outputs and reports."
  value       = aws_s3_bucket.artifacts.bucket
}

output "artifacts_bucket_arn" {
  description = "ARN of the S3 bucket used for logs, metrics, AI outputs and reports."
  value       = aws_s3_bucket.artifacts.arn
}
