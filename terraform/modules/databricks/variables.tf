variable "workspace_name" {
  description = "Prefix for all resource names (bucket names, IAM role)."
  type        = string
  default     = "ti-databricks-tf"
}

variable "region" {
  description = "AWS region for the Unity Catalog metastore."
  type        = string
  default     = "eu-west-2"
}

variable "databricks_account_id" {
  description = "Databricks account ID for IAM trust policy external ID."
  type        = string
}

variable "databricks_uc_role_arn" {
  description = "Databricks-controlled AWS role ARN that assumes the Unity Catalog IAM role."
  type        = string
}

variable "databricks_workspace_id" {
  description = "Databricks workspace ID."
  type        = number
}

variable "force_destroy_metastore" {
  description = "Whether to force-destroy the metastore (deletes all child resources)."
  type        = bool
  default     = false
}

variable "projects" {
  description = "Map of project name to its environments. Each project×environment pair gets a catalog with prefixed paths in the shared lakehouse bucket."
  type = map(object({
    environments = list(string)
  }))
  default = {
    nyc_taxi = {
      environments = ["dev", "prod"]
    }
  }
}

variable "schemas" {
  description = "Schema names to create within each catalog."
  type        = list(string)
  default     = ["bronze", "silver", "gold"]
}

variable "admins" {
  description = "List of user/group principals to grant READ FILES and WRITE FILES on all external locations."
  type        = list(string)
  default     = []
}
