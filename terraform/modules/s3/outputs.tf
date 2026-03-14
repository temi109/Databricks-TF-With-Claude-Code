output "bucket_id" {
  description = "The name/ID of the S3 bucket."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "The ARN of the S3 bucket."
  value       = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  description = "The bucket domain name."
  value       = aws_s3_bucket.this.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "The bucket region-specific domain name."
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

output "bucket_region" {
  description = "AWS region where the bucket resides."
  value       = aws_s3_bucket.this.region
}

output "versioning_enabled" {
  description = "Whether versioning is enabled on the bucket."
  value       = var.versioning_enabled
}
