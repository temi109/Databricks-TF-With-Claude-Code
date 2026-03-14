output "role_arn" {
  description = "ARN of the IAM role for Databricks Unity Catalog."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the IAM role."
  value       = aws_iam_role.this.name
}

output "policy_arn" {
  description = "ARN of the S3 access policy."
  value       = aws_iam_policy.this.arn
}
