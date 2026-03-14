# Cost-free unit tests using Terraform 1.7+ mock providers.
# No real AWS credentials required. Runs entirely offline.

mock_provider "aws" {
  mock_resource "aws_s3_bucket" {
    defaults = {
      id                          = "mock-bucket-id"
      arn                         = "arn:aws:s3:::mock-bucket-id"
      bucket_domain_name          = "mock-bucket-id.s3.amazonaws.com"
      bucket_regional_domain_name = "mock-bucket-id.s3.us-east-1.amazonaws.com"
      region                      = "us-east-1"
    }
  }

  mock_resource "aws_s3_bucket_public_access_block" {
    defaults = {
      id = "mock-bucket-id"
    }
  }

  mock_resource "aws_s3_bucket_server_side_encryption_configuration" {
    defaults = {
      id = "mock-bucket-id"
    }
  }

  mock_resource "aws_s3_bucket_versioning" {
    defaults = {
      id = "mock-bucket-id"
    }
  }

  mock_resource "aws_s3_bucket_lifecycle_configuration" {
    defaults = {
      id = "mock-bucket-id"
    }
  }
}

variables {
  bucket_name   = "mock-unit-test-bucket-01"
  environment   = "dev"
  force_destroy = true
}

run "mock_outputs_wired_correctly" {
  command = apply

  assert {
    condition     = output.bucket_id == "mock-bucket-id"
    error_message = "bucket_id output should return the mock bucket ID."
  }

  assert {
    condition     = output.bucket_arn == "arn:aws:s3:::mock-bucket-id"
    error_message = "bucket_arn output should return the mock ARN."
  }

  assert {
    condition     = output.bucket_region == "us-east-1"
    error_message = "bucket_region output should return the mock region."
  }
}

run "force_destroy_true_passed_through" {
  command = apply

  variables {
    force_destroy = true
  }

  assert {
    condition     = aws_s3_bucket.this.force_destroy == true
    error_message = "force_destroy should be true when variable is set."
  }
}

run "force_destroy_false_passed_through" {
  command = apply

  variables {
    force_destroy = false
  }

  assert {
    condition     = aws_s3_bucket.this.force_destroy == false
    error_message = "force_destroy should be false when variable is false."
  }
}

run "versioning_enabled_creates_resource" {
  command = apply

  variables {
    versioning_enabled = true
  }

  assert {
    condition     = length(aws_s3_bucket_versioning.this) == 1
    error_message = "Versioning resource must exist when versioning_enabled = true."
  }
}

run "versioning_disabled_no_resource" {
  command = apply

  variables {
    versioning_enabled = false
  }

  assert {
    condition     = length(aws_s3_bucket_versioning.this) == 0
    error_message = "Versioning resource must not exist when versioning_enabled = false."
  }
}
