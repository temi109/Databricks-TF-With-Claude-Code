# -----------------------------------------------------------------------------
# Workspace (creates cross-account IAM role, S3 root bucket, workspace)
# -----------------------------------------------------------------------------

module "workspace" {
  source = "../modules/workspace"

  workspace_name          = "ti-databricks-tf-eu"
  region                  = "eu-west-2"
  databricks_account_id   = var.databricks_account_id
  bucket_name             = "ti-databricks-tf-eu-root-storage"
  cross_account_role_name = "ti-databricks-tf-eu-cross-account"

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# -----------------------------------------------------------------------------
# Unity Catalog (S3 buckets, IAM, metastore, catalogs, schemas)
# -----------------------------------------------------------------------------

module "databricks" {
  source = "../modules/databricks"

  providers = {
    aws                  = aws
    databricks           = databricks
    databricks.workspace = databricks.workspace
  }

  workspace_name          = "ti-databricks-tf-eu"
  region                  = "eu-west-2"
  databricks_account_id   = var.databricks_account_id
  databricks_uc_role_arn  = var.databricks_uc_role_arn
  databricks_workspace_id = module.workspace.workspace_id

  projects = {
    nyc_taxi = {
      environments = ["dev", "prod"]
    }
  }

  schemas = ["bronze", "silver", "gold"]
  admins  = ["temidayo.ibraheem@gmail.com"]

  depends_on = [module.workspace]
}

# -----------------------------------------------------------------------------
# Workspace access for admin user
# -----------------------------------------------------------------------------

data "databricks_user" "admin" {
  user_name = "temidayo.ibraheem@gmail.com"
}

resource "databricks_mws_permission_assignment" "admin_user" {
  workspace_id = module.workspace.workspace_id
  principal_id = data.databricks_user.admin.id
  permissions  = ["ADMIN"]
}
