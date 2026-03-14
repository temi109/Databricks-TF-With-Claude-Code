variable "workspace_name" {
  description = "Name for the Databricks workspace."
  type        = string
}

variable "region" {
  description = "AWS region for the workspace."
  type        = string
}

variable "databricks_account_id" {
  description = "Databricks account ID."
  type        = string
}

variable "bucket_name" {
  description = "Name for the workspace root S3 bucket."
  type        = string
}

variable "cross_account_role_name" {
  description = "Name for the cross-account IAM role."
  type        = string
}

variable "tags" {
  description = "Tags to apply to AWS resources."
  type        = map(string)
  default     = {}
}
