# Workspace outputs
output "workspace_id" {
  description = "The Databricks workspace ID."
  value       = module.workspace.workspace_id
}

output "workspace_url" {
  description = "The URL of the Databricks workspace."
  value       = module.workspace.workspace_url
}

# Unity Catalog outputs
output "metastore_id" {
  description = "ID of the Unity Catalog metastore."
  value       = module.databricks.metastore_id
}

output "iam_role_arn" {
  description = "ARN of the IAM role for Unity Catalog."
  value       = module.databricks.iam_role_arn
}

output "catalog_ids" {
  description = "Map of catalog name to catalog ID."
  value       = module.databricks.catalog_ids
}
