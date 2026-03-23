variable "force_destroy" {
  description = "Whether to delete all objects in the bucket before destroying it."
  type        = bool
  default     = false
}

# Databricks account variables
variable "databricks_account_id" {
  description = "Databricks account ID."
  type        = string
}

variable "databricks_client_id" {
  description = "Service principal client ID for account-level auth."
  type        = string
  sensitive   = true
}

variable "databricks_client_secret" {
  description = "Service principal client secret for account-level auth."
  type        = string
  sensitive   = true
}

variable "databricks_workspace_url" {
  description = "URL of the Databricks workspace for workspace-level provider."
  type        = string
}

variable "databricks_uc_role_arn" {
  description = "Databricks-controlled AWS role ARN that assumes the Unity Catalog IAM role."
  type        = string
}
