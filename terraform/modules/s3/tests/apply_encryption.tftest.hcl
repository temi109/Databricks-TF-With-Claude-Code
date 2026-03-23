# Integration tests that require real AWS credentials.
# These create and destroy real S3 resources.
# Run only in a sandbox/test AWS account.
#
# Key design: encryption 'rule' is a SET type in the AWS provider schema.
# Cannot use rule[0] - must use a 'for' expression to iterate the set.
# Inner 'apply_server_side_encryption_by_default' is a LIST (always 1 element),
# so [0] is valid on that inner attribute.

provider "aws" {
  region = "us-east-1"
}

variables {
  # bucket_name must be unique per run - use a fixed suffix for reproducibility
  bucket_name   = "tf-test-apply-enc-01"
  force_destroy = true # Required: allows cleanup after each run block
}

run "sse_s3_encryption_applied" {
  command = apply

  variables {
    encryption_type = "AES256"
  }

  # rule is a SET - must iterate with 'for', cannot use [0]
  assert {
    condition = length([
      for rule in aws_s3_bucket_server_side_encryption_configuration.this.rule :
      rule if rule.apply_server_side_encryption_by_default[0].sse_algorithm == "AES256"
    ]) == 1
    error_message = "Expected one encryption rule with AES256 algorithm."
  }

  assert {
    condition = length([
      for rule in aws_s3_bucket_server_side_encryption_configuration.this.rule :
      rule if(
        rule.apply_server_side_encryption_by_default[0].kms_master_key_id == null ||
        rule.apply_server_side_encryption_by_default[0].kms_master_key_id == ""
      )
    ]) == 1
    error_message = "No KMS key should be set when using AES256 encryption."
  }
}

run "computed_outputs_populated" {
  command = apply

  assert {
    condition     = output.bucket_arn != ""
    error_message = "bucket_arn output must be non-empty after apply."
  }

  assert {
    condition     = can(regex("^arn:aws:s3:::", output.bucket_arn))
    error_message = "bucket_arn must match the expected S3 ARN format."
  }

  assert {
    condition     = output.bucket_region == "us-east-1"
    error_message = "bucket_region must match the provider region."
  }

  assert {
    condition     = output.bucket_id == "tf-test-apply-enc-01"
    error_message = "bucket_id must match the bucket_name variable."
  }
}

run "lifecycle_transition_applied" {
  command = apply

  variables {
    bucket_name        = "tf-test-apply-lifecycle-01"
    versioning_enabled = true
    lifecycle_rules = [
      {
        id                                 = "archive-old-objects"
        enabled                            = true
        transition_days                    = 30
        transition_storage_class           = "STANDARD_IA"
        expiration_days                    = 365
        noncurrent_version_expiration_days = 90
      }
    ]
  }

  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.this) == 1
    error_message = "Lifecycle configuration resource should be created."
  }

  # rule is a SET on the lifecycle configuration resource too
  assert {
    condition = length([
      for rule in aws_s3_bucket_lifecycle_configuration.this[0].rule :
      rule if rule.id == "archive-old-objects" && rule.status == "Enabled"
    ]) == 1
    error_message = "Lifecycle rule 'archive-old-objects' must exist and be Enabled."
  }
}
