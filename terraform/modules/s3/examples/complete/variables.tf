variable "bucket_name" {
  description = "Name of the S3 bucket."
  type        = string
}

variable "force_destroy" {
  description = "Whether to delete all objects before destroying the bucket."
  type        = bool
  default     = false
}

variable "encryption_type" {
  description = "Server-side encryption type: 'AES256' or 'aws:kms'."
  type        = string
  default     = "aws:kms"
}

variable "kms_master_key_id" {
  description = "KMS key ARN when encryption_type is 'aws:kms'."
  type        = string
  default     = null
}
