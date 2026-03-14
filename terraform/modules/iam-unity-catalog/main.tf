data "aws_caller_identity" "this" {}

# Step 1: Trust policy with only Databricks principal (for initial role creation)
data "aws_iam_policy_document" "databricks_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [var.databricks_unity_catalog_role_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.databricks_account_id]
    }
  }
}

# Step 2: Full trust policy including self-assume (applied after role exists)
data "aws_iam_policy_document" "full_trust" {
  # Databricks assumes this role — ExternalId prevents confused deputy
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [var.databricks_unity_catalog_role_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.databricks_account_id]
    }
  }

  # Role must be able to self-assume for Unity Catalog validation (no ExternalId)
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.this.arn]
    }
  }
}

data "aws_iam_policy_document" "s3_access" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = flatten([
      for arn in var.s3_bucket_arns : [
        arn,
        "${arn}/*",
      ]
    ])
  }
}

# Create role with Databricks-only trust (avoids chicken-and-egg with self-assume)
resource "aws_iam_role" "this" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.databricks_trust.json
  tags               = var.tags

  lifecycle {
    ignore_changes = [assume_role_policy]
  }
}

# After role exists, update trust policy to add self-assume
resource "terraform_data" "self_assume_trust" {
  depends_on = [aws_iam_role.this]

  input = data.aws_iam_policy_document.full_trust.json

  provisioner "local-exec" {
    command = <<-EOF
      aws iam update-assume-role-policy \
        --role-name '${var.role_name}' \
        --policy-document '${data.aws_iam_policy_document.full_trust.json}'
    EOF
  }
}

resource "aws_iam_policy" "this" {
  name   = "${var.role_name}-s3-access"
  policy = data.aws_iam_policy_document.s3_access.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}
