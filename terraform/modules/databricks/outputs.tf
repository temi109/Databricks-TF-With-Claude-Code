output "metastore_id" {
  description = "ID of the Unity Catalog metastore."
  value       = databricks_metastore.this.id
}

output "iam_role_arn" {
  description = "ARN of the IAM role for Unity Catalog."
  value       = module.iam_unity_catalog.role_arn
}

output "metastore_bucket_arn" {
  description = "ARN of the metastore S3 bucket."
  value       = module.metastore_bucket.bucket_arn
}

output "lakehouse_bucket_arn" {
  description = "ARN of the shared lakehouse S3 bucket."
  value       = module.lakehouse_bucket.bucket_arn
}

output "catalog_ids" {
  description = "Map of catalog name to catalog ID."
  value       = module.unity_catalog.catalog_ids
}
