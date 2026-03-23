# Complete usage: KMS encryption, versioning, lifecycle rules, and custom tags.

module "s3_bucket" {
  source = "../../"

  bucket_name        = var.bucket_name
  force_destroy      = var.force_destroy
  versioning_enabled = true
  encryption_type    = var.encryption_type
  kms_master_key_id  = var.kms_master_key_id

  lifecycle_rules = [
    {
      id                                 = "transition-to-ia"
      enabled                            = true
      transition_days                    = 30
      transition_storage_class           = "STANDARD_IA"
      expiration_days                    = 365
      noncurrent_version_expiration_days = 90
    },
    {
      id                                 = "glacier-archive"
      enabled                            = true
      transition_days                    = 90
      transition_storage_class           = "GLACIER"
      expiration_days                    = null
      noncurrent_version_expiration_days = null
    }
  ]

  tags = {
    Owner      = "platform-team"
    CostCenter = "cc-1234"
    DataClass  = "confidential"
  }
}
