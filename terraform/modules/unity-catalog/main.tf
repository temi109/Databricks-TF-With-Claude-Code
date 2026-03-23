locals {
  catalog_project_pairs = merge([
    for cat_key, cat in var.catalogs : {
      for project in var.projects :
      "${cat_key}_${project}" => {
        catalog_name = cat_key
        schema_name  = project
      }
    }
  ]...)
}

resource "databricks_storage_credential" "this" {
  name         = var.storage_credential_name
  metastore_id = var.metastore_id

  aws_iam_role {
    role_arn = var.iam_role_arn
  }
}

# One external location per catalog — covers the catalog root
resource "databricks_external_location" "this" {
  for_each = var.external_locations

  metastore_id    = var.metastore_id
  name            = each.key
  url             = each.value
  credential_name = databricks_storage_credential.this.name
  comment         = "${each.key} external location"
}

resource "databricks_grants" "external_location" {
  for_each = length(var.admins) > 0 ? var.external_locations : {}

  external_location = databricks_external_location.this[each.key].name

  dynamic "grant" {
    for_each = var.admins
    content {
      principal  = grant.value
      privileges = ["ALL PRIVILEGES"]
    }
  }
}

resource "databricks_catalog" "this" {
  for_each = var.catalogs

  metastore_id  = var.metastore_id
  name          = each.key
  comment       = each.value.comment
  storage_root  = each.value.storage_root
  force_destroy = var.force_destroy

  depends_on = [databricks_external_location.this]
}

resource "databricks_grants" "catalog" {
  for_each = length(var.admins) > 0 ? var.catalogs : {}

  catalog = databricks_catalog.this[each.key].name

  dynamic "grant" {
    for_each = var.admins
    content {
      principal  = grant.value
      privileges = ["ALL PRIVILEGES"]
    }
  }
}

resource "databricks_schema" "this" {
  for_each = local.catalog_project_pairs

  catalog_name  = databricks_catalog.this[each.value.catalog_name].name
  name          = each.value.schema_name
  force_destroy = var.force_destroy
}

resource "databricks_grants" "schema" {
  for_each = length(var.admins) > 0 ? local.catalog_project_pairs : {}

  schema = "${databricks_catalog.this[each.value.catalog_name].name}.${databricks_schema.this[each.key].name}"

  dynamic "grant" {
    for_each = var.admins
    content {
      principal  = grant.value
      privileges = ["ALL PRIVILEGES"]
    }
  }
}
