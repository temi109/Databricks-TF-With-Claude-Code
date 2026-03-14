locals {
  common_tags = merge(
    {
      Environment = var.environment
      ManagedBy   = "terraform"
      Module      = "s3"
    },
    var.tags
  )
}

resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy

  tags = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.encryption_type
      kms_master_key_id = var.encryption_type == "aws:kms" ? var.kms_master_key_id : null
    }

    bucket_key_enabled = var.encryption_type == "aws:kms" ? true : false
  }

  lifecycle {
    precondition {
      condition     = var.encryption_type != "aws:kms" || var.kms_master_key_id != null
      error_message = "kms_master_key_id must be provided when encryption_type is 'aws:kms'."
    }
  }
}

resource "aws_s3_bucket_versioning" "this" {
  count = var.versioning_enabled ? 1 : 0

  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count = length(var.lifecycle_rules) > 0 ? 1 : 0

  bucket = aws_s3_bucket.this.id

  dynamic "rule" {
    for_each = var.lifecycle_rules

    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"

      filter {}

      dynamic "expiration" {
        for_each = rule.value.expiration_days != null ? [rule.value.expiration_days] : []

        content {
          days = expiration.value
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_version_expiration_days != null ? [rule.value.noncurrent_version_expiration_days] : []

        content {
          noncurrent_days = noncurrent_version_expiration.value
        }
      }

      dynamic "transition" {
        for_each = rule.value.transition_days != null ? [rule.value] : []

        content {
          days          = transition.value.transition_days
          storage_class = transition.value.transition_storage_class
        }
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}
