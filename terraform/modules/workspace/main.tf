data "aws_caller_identity" "this" {}

# -----------------------------------------------------------------------------
# S3 Root Storage Bucket (bare — Databricks configures policies during deploy)
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "root_storage" {
  bucket        = var.bucket_name
  force_destroy = true

  tags = merge(var.tags, {
    Purpose = "databricks-workspace-root-storage"
  })
}

data "databricks_aws_bucket_policy" "this" {
  bucket = aws_s3_bucket.root_storage.id
}

resource "aws_s3_bucket_policy" "root_storage" {
  bucket = aws_s3_bucket.root_storage.id
  policy = data.databricks_aws_bucket_policy.this.json
}

resource "aws_s3_bucket_versioning" "root_storage" {
  bucket = aws_s3_bucket.root_storage.id

  versioning_configuration {
    status = "Enabled"
  }
}

# -----------------------------------------------------------------------------
# Cross-Account IAM Role (Databricks-recommended policies)
# -----------------------------------------------------------------------------

data "databricks_aws_assume_role_policy" "this" {
  external_id = var.databricks_account_id
}

data "databricks_aws_crossaccount_policy" "this" {}

resource "aws_iam_role" "cross_account" {
  name               = var.cross_account_role_name
  assume_role_policy = data.databricks_aws_assume_role_policy.this.json
  tags               = var.tags
}

resource "aws_iam_policy" "cross_account" {
  name   = "${var.cross_account_role_name}-policy"
  policy = data.databricks_aws_crossaccount_policy.this.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "cross_account" {
  role       = aws_iam_role.cross_account.name
  policy_arn = aws_iam_policy.cross_account.arn
}

# S3 access for the root storage bucket
data "aws_iam_policy_document" "root_storage_access" {
  statement {
    effect    = "Allow"
    actions   = ["s3:*"]
    resources = [
      aws_s3_bucket.root_storage.arn,
      "${aws_s3_bucket.root_storage.arn}/*",
    ]
  }
}

resource "aws_iam_policy" "root_storage_access" {
  name   = "${var.cross_account_role_name}-root-storage"
  policy = data.aws_iam_policy_document.root_storage_access.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "root_storage_access" {
  role       = aws_iam_role.cross_account.name
  policy_arn = aws_iam_policy.root_storage_access.arn
}

# -----------------------------------------------------------------------------
# Databricks MWS Configuration
# -----------------------------------------------------------------------------

resource "databricks_mws_credentials" "this" {
  account_id       = var.databricks_account_id
  credentials_name = "${var.workspace_name}-credentials"
  role_arn         = aws_iam_role.cross_account.arn

  depends_on = [
    aws_iam_role_policy_attachment.cross_account,
    aws_iam_role_policy_attachment.root_storage_access,
  ]
}

resource "databricks_mws_storage_configurations" "this" {
  account_id                 = var.databricks_account_id
  storage_configuration_name = "${var.workspace_name}-storage"
  bucket_name                = aws_s3_bucket.root_storage.id
}

resource "databricks_mws_workspaces" "this" {
  account_id     = var.databricks_account_id
  workspace_name = var.workspace_name
  aws_region     = var.region

  credentials_id           = databricks_mws_credentials.this.credentials_id
  storage_configuration_id = databricks_mws_storage_configurations.this.storage_configuration_id

  token {}
}
