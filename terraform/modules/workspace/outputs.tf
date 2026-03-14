output "workspace_id" {
  description = "The Databricks workspace ID."
  value       = databricks_mws_workspaces.this.workspace_id
}

output "workspace_url" {
  description = "The URL of the Databricks workspace."
  value       = databricks_mws_workspaces.this.workspace_url
}

output "workspace_token" {
  description = "Temporary token for the new workspace."
  value       = databricks_mws_workspaces.this.token[0].token_value
  sensitive   = true
}

output "cross_account_role_arn" {
  description = "ARN of the cross-account IAM role."
  value       = aws_iam_role.cross_account.arn
}

output "root_bucket_arn" {
  description = "ARN of the workspace root S3 bucket."
  value       = aws_s3_bucket.root_storage.arn
}
