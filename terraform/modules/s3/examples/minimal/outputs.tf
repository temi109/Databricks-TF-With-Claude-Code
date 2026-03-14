output "bucket_arn" {
  description = "ARN of the created S3 bucket."
  value       = module.s3_bucket.bucket_arn
}

output "bucket_id" {
  description = "Name/ID of the created S3 bucket."
  value       = module.s3_bucket.bucket_id
}
