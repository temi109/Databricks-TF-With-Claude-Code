# Minimal usage: SSE-S3 encryption and public access blocked by default.
# No versioning, no lifecycle rules.

module "s3_bucket" {
  source = "../../"

  bucket_name = var.bucket_name
  environment = var.environment
}
