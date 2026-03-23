locals {
  # Flatten catalogs × projects into a map for S3 folder creation
  catalog_project_pairs = merge([
    for catalog in var.catalogs : {
      for project in var.projects :
      "${catalog}_${project}" => {
        catalog = catalog
        project = project
      }
    }
  ]...)

  # Raw folder + project subfolders in the lakehouse bucket
  raw_project_folders = {
    for project in var.projects :
    "raw_${project}" => {
      bucket_id = module.lakehouse_bucket.bucket_id
      key       = "raw/${replace(project, "_", "-")}/"
    }
  }
}

# -----------------------------------------------------------------------------
# Metastore S3 Bucket
# -----------------------------------------------------------------------------

module "metastore_bucket" {
  source = "../s3"

  bucket_name   = "${var.workspace_name}-metastore"
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
# Lakehouse S3 Bucket (Databricks-managed storage for catalog data)
# -----------------------------------------------------------------------------

module "lakehouse_bucket" {
  source = "../s3"

  bucket_name   = "${var.workspace_name}-lakehouse"
  force_destroy = false

  tags = {
    Purpose = "unity-catalog-lakehouse"
  }
}

# -----------------------------------------------------------------------------
# S3 Project Folders (catalog prefixes + raw project folders in lakehouse bucket)
# -----------------------------------------------------------------------------

locals {
  bucket_project_folders = merge(
    {
      for catalog in var.catalogs :
      catalog => {
        bucket_id = module.lakehouse_bucket.bucket_id
        key       = "${replace(catalog, "_", "-")}/"
      }
    },
    local.raw_project_folders
  )
}

resource "aws_s3_object" "project_folders" {
  for_each = local.bucket_project_folders

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

  external_locations = merge(
    {
      for catalog in var.catalogs :
      "${replace(catalog, "_", "-")}-lakehouse" => "s3://${module.lakehouse_bucket.bucket_id}/${replace(catalog, "_", "-")}"
    },
    {
      "raw-lakehouse" = "s3://${module.lakehouse_bucket.bucket_id}/raw"
    }
  )

  catalogs = {
    for catalog in var.catalogs :
    catalog => {
      storage_root = "s3://${module.lakehouse_bucket.bucket_id}/${replace(catalog, "_", "-")}"
      comment      = "${catalog} catalog"
    }
  }

  projects      = var.projects
  admins        = var.admins
  force_destroy = false

  depends_on = [
    module.iam_unity_catalog,
    databricks_metastore_data_access.this,
    databricks_metastore_assignment.this,
  ]
}
