variable "bucket_name" {
  description = "Name of the S3 bucket. Must be globally unique."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9\\-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be 3-63 chars, lowercase alphanumeric or hyphens, and cannot start or end with a hyphen."
  }

  nullable = false
}

variable "environment" {
  description = "Deployment environment. Used for tagging."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }

  nullable = false
}

variable "tags" {
  description = "Additional tags to merge onto all resources."
  type        = map(string)
  default     = {}
}

variable "force_destroy" {
  description = "Whether to delete all objects in the bucket before destroying it. Set true only for non-production environments."
  type        = bool
  default     = false
}

variable "versioning_enabled" {
  description = "Enable S3 versioning for the bucket."
  type        = bool
  default     = false
}

variable "encryption_type" {
  description = "Server-side encryption type. 'AES256' for SSE-S3, 'aws:kms' for KMS."
  type        = string
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "aws:kms"], var.encryption_type)
    error_message = "encryption_type must be 'AES256' or 'aws:kms'."
  }
}

variable "kms_master_key_id" {
  description = "KMS key ARN or ID when encryption_type is 'aws:kms'. Ignored for AES256."
  type        = string
  default     = null
}

variable "lifecycle_rules" {
  description = "List of lifecycle rule configurations for cost optimization."
  type = list(object({
    id                                 = string
    enabled                            = bool
    expiration_days                    = optional(number, null)
    noncurrent_version_expiration_days = optional(number, null)
    transition_days                    = optional(number, null)
    transition_storage_class           = optional(string, "STANDARD_IA")
  }))
  default = []
}
