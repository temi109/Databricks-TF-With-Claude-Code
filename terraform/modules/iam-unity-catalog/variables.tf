variable "role_name" {
  description = "Name of the IAM role for Databricks Unity Catalog."
  type        = string
  default     = "databricks-uc-role"
}

variable "databricks_account_id" {
  description = "Databricks account ID, used as the external ID for STS assume-role."
  type        = string
}

variable "databricks_unity_catalog_role_arn" {
  description = "Databricks-controlled AWS role ARN that will assume this role."
  type        = string
}

variable "s3_bucket_arns" {
  description = "List of S3 bucket ARNs to grant access to."
  type        = list(string)
}

variable "tags" {
  description = "Additional tags to apply to IAM resources."
  type        = map(string)
  default     = {}
}
