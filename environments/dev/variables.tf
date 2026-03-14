variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"
}

variable "force_destroy" {
  description = "Whether to delete all objects in the bucket before destroying it."
  type        = bool
  default     = false
}
