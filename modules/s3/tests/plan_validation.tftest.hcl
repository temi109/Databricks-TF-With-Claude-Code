variables {
  bucket_name = "test-plan-validation-bucket-01"
  environment = "dev"
}

provider "aws" {
  region = "us-east-1"

  access_key = "mock_access_key"
  secret_key = "mock_secret_key"

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

run "bucket_name_is_set_correctly" {
  command = plan

  assert {
    condition     = aws_s3_bucket.this.bucket == "test-plan-validation-bucket-01"
    error_message = "Bucket name does not match the variable value."
  }

  assert {
    condition     = aws_s3_bucket.this.force_destroy == false
    error_message = "force_destroy should default to false."
  }
}

run "public_access_block_always_enabled" {
  command = plan

  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_acls == true
    error_message = "block_public_acls must always be true."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_policy == true
    error_message = "block_public_policy must always be true."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this.ignore_public_acls == true
    error_message = "ignore_public_acls must always be true."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this.restrict_public_buckets == true
    error_message = "restrict_public_buckets must always be true."
  }
}

run "versioning_not_created_when_disabled" {
  command = plan

  variables {
    versioning_enabled = false
  }

  assert {
    condition     = length(aws_s3_bucket_versioning.this) == 0
    error_message = "Versioning resource should not be created when versioning_enabled is false."
  }
}

run "versioning_created_when_enabled" {
  command = plan

  variables {
    versioning_enabled = true
  }

  assert {
    condition     = length(aws_s3_bucket_versioning.this) == 1
    error_message = "Versioning resource should be created when versioning_enabled is true."
  }
}

run "kms_without_key_fails_precondition" {
  command = plan

  variables {
    encryption_type   = "aws:kms"
    kms_master_key_id = null
  }

  expect_failures = [
    aws_s3_bucket_server_side_encryption_configuration.this
  ]
}

run "invalid_environment_rejected" {
  command = plan

  variables {
    environment = "production"
  }

  expect_failures = [
    var.environment
  ]
}

run "tags_are_merged_correctly" {
  command = plan

  variables {
    environment = "staging"
    tags = {
      Owner = "platform-team"
    }
  }

  assert {
    condition     = aws_s3_bucket.this.tags["Environment"] == "staging"
    error_message = "Environment tag must reflect the environment variable."
  }

  assert {
    condition     = aws_s3_bucket.this.tags["Owner"] == "platform-team"
    error_message = "Custom tags must be merged onto the bucket."
  }

  assert {
    condition     = aws_s3_bucket.this.tags["ManagedBy"] == "terraform"
    error_message = "ManagedBy tag must always be set to 'terraform'."
  }
}
