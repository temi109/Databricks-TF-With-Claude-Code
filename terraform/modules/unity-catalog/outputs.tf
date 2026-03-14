output "metastore_id" {
  description = "ID of the Unity Catalog metastore."
  value       = var.metastore_id
}

output "catalog_ids" {
  description = "Map of catalog name to catalog ID."
  value = {
    for k, v in databricks_catalog.this : k => v.id
  }
}

output "schema_ids" {
  description = "Map of catalog_schema key to schema ID."
  value = {
    for k, v in databricks_schema.this : k => v.id
  }
}

output "storage_credential_id" {
  description = "ID of the storage credential."
  value       = databricks_storage_credential.this.id
}

output "external_location_ids" {
  description = "Map of catalog name to external location ID."
  value = {
    for k, v in databricks_external_location.this : k => v.id
  }
}
