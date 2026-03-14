data "aws_caller_identity" "this" {}

# Full trust policy: Databricks principal + self-assume
# Self-assume ARN is computed from account ID + role name (avoids circular reference)
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
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.this.account_id}:role/${var.role_name}"]
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

resource "aws_iam_role" "this" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.full_trust.json
  tags               = var.tags
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
