variable "metastore_id" {
  description = "ID of the existing Unity Catalog metastore to use."
  type        = string
}

variable "iam_role_arn" {
  description = "IAM role ARN for the storage credential."
  type        = string
}

variable "storage_credential_name" {
  description = "Name for the Unity Catalog storage credential."
  type        = string
}

variable "external_locations" {
  description = "Map of external location name to S3 URL. One per catalog."
  type        = map(string)
}

variable "catalogs" {
  description = "Map of catalog name to configuration."
  type = map(object({
    storage_root = string
    comment      = optional(string, "")
  }))
}

variable "projects" {
  description = "Project names to create as schemas within each catalog."
  type        = list(string)
  default     = []
}

variable "force_destroy" {
  description = "Allow destroying non-empty catalogs and schemas."
  type        = bool
  default     = false
}

variable "admins" {
  description = "List of user/group principals to grant READ FILES and WRITE FILES on all external locations."
  type        = list(string)
  default     = []
}
