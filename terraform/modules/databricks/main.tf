locals {
  # Flatten projects × environments into a map keyed by "project_env"
  catalog_entries = merge([
    for project, cfg in var.projects : {
      for env in cfg.environments :
      "${replace(project, "_", "-")}-${env}" => {
        project      = project
        environment  = env
        catalog_name = "${project}_${env}"
      }
    }
  ]...)

  environments = toset([
    for entry in values(local.catalog_entries) : entry.environment
  ])
}

# -----------------------------------------------------------------------------
# Metastore S3 Bucket
# -----------------------------------------------------------------------------

module "metastore_bucket" {
  source = "../s3"

  bucket_name   = "${var.workspace_name}-metastore"
  environment   = "shared"
  force_destroy = var.force_destroy_metastore

  tags = {
    Purpose = "unity-catalog-metastore"
  }
}

# -----------------------------------------------------------------------------
# Metastore (account-level provider)
# -----------------------------------------------------------------------------

resource "databricks_metastore" "this" {
  name          = "${var.workspace_name}-metastore"
  region        = var.region
  storage_root  = "s3://${module.metastore_bucket.bucket_id}/"
  force_destroy = var.force_destroy_metastore
}

resource "databricks_metastore_assignment" "this" {
  metastore_id = databricks_metastore.this.id
  workspace_id = var.databricks_workspace_id
}

resource "databricks_metastore_data_access" "this" {
  metastore_id = databricks_metastore.this.id
  name         = "${var.workspace_name}-metastore-data-access"

  aws_iam_role {
    role_arn = module.iam_unity_catalog.role_arn
  }

  is_default = true

  depends_on = [
    module.iam_unity_catalog,
    databricks_metastore_assignment.this,
  ]
}

# -----------------------------------------------------------------------------
# Lakehouse S3 Bucket (single shared bucket with env/project prefixes)
# -----------------------------------------------------------------------------

module "lakehouse_bucket" {
  source = "../s3"

  bucket_name   = "${var.workspace_name}-lakehouse"
  environment   = "shared"
  force_destroy = false

  tags = {
    Purpose = "unity-catalog-lakehouse"
  }
}

# -----------------------------------------------------------------------------
# S3 Schema Folders
# -----------------------------------------------------------------------------

locals {
  bucket_schema_folders = merge([
    for key, entry in local.catalog_entries : {
      for schema in var.schemas :
      "${key}_${schema}" => {
        bucket_id = module.lakehouse_bucket.bucket_id
        key       = "${entry.environment}/${replace(entry.project, "_", "-")}/${schema}/"
      }
    }
  ]...)
}

resource "aws_s3_object" "schema_folders" {
  for_each = local.bucket_schema_folders

  bucket  = each.value.bucket_id
  key     = each.value.key
  content = ""
}

# -----------------------------------------------------------------------------
# IAM
# -----------------------------------------------------------------------------

module "iam_unity_catalog" {
  source = "../iam-unity-catalog"

  role_name                         = "${var.workspace_name}-uc-role"
  databricks_account_id             = var.databricks_account_id
  databricks_unity_catalog_role_arn = var.databricks_uc_role_arn

  s3_bucket_arns = [
    module.metastore_bucket.bucket_arn,
    module.lakehouse_bucket.bucket_arn,
  ]

  tags = {
    Purpose = "unity-catalog"
  }
}

# -----------------------------------------------------------------------------
# Unity Catalog (workspace-level provider)
# -----------------------------------------------------------------------------

module "unity_catalog" {
  source = "../unity-catalog"

  providers = {
    databricks = databricks.workspace
  }

  metastore_id            = databricks_metastore.this.id
  iam_role_arn            = module.iam_unity_catalog.role_arn
  storage_credential_name = "${var.workspace_name}-storage-credential"

  external_locations = {
    for env in local.environments :
    "${env}-lakehouse" => "s3://${module.lakehouse_bucket.bucket_id}/${env}"
  }

  catalogs = {
    for key, entry in local.catalog_entries :
    entry.catalog_name => {
      storage_root = "s3://${module.lakehouse_bucket.bucket_id}/${entry.environment}/${replace(entry.project, "_", "-")}"
      comment      = "${entry.project} ${entry.environment} catalog"
    }
  }

  schemas       = var.schemas
  admins        = var.admins
  force_destroy = false

  depends_on = [
    module.iam_unity_catalog,
    databricks_metastore_data_access.this,
    databricks_metastore_assignment.this,
  ]
}
