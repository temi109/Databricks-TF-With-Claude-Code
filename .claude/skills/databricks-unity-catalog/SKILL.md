---
name: databricks-unity-catalog
description: Deploy Databricks Unity Catalog infrastructure on AWS using Terraform — creates workspace, S3 buckets, IAM roles with self-assuming trust, storage credentials, one external location per catalog, 7 medallion catalogs (bronze/silver/gold + dev variants + playpen), projects as schemas, and workspace user assignments. Uses dual Databricks providers (account-level + workspace-level) with service principal OAuth.
---

# Databricks Unity Catalog Infrastructure Skill

Deploys a complete Databricks Unity Catalog setup on AWS using modular Terraform. Uses a medallion catalog layout — 7 fixed catalogs (bronze, silver, gold + dev variants + playpen) with projects as schemas. Covers workspace creation, S3 storage, IAM plumbing, the full UC hierarchy (metastore → catalog → schema), and workspace access management.

## When to Use This Skill

**Activate when:**
- Setting up Unity Catalog for a new Databricks workspace on AWS
- Adding a new project to the medallion catalog layout
- Troubleshooting IAM trust policies for Databricks storage credentials
- Creating S3 bucket structures for the catalog/project layout
- Granting users workspace access or managing workspace permissions

## How to Use This Skill

This skill is loaded automatically when you work in this repository. Reference it by asking questions in natural language — no special invocation needed.

**Example prompts:**
- "Add a new project called `orders` to the catalogs"
- "Why is my storage credential validation failing with 'non self-assuming'?"
- "Walk me through deploying this infra from scratch"
- "What IAM permissions does the Unity Catalog role need?"
- "Add a new catalog called `staging`"
- "What's the correct order to run terraform apply?"

## This Repository's Exact Infrastructure

All resource names, regions, and IDs used in this deployment:

### Workspace
| Attribute | Value |
|-----------|-------|
| Workspace name | `ti-databricks-tf-eu` |
| Workspace URL | `https://dbc-e1000168-a972.cloud.databricks.com` |
| Region | `eu-west-2` |
| Databricks Account ID | `27c1abec-ad84-4ef9-97c0-6e6c5d130ccd` |

### AWS Resources
| Resource | Name |
|----------|------|
| Cross-account IAM role | `ti-databricks-tf-eu-cross-account` |
| Root S3 bucket | `ti-databricks-tf-eu-root-storage` |
| Metastore S3 bucket | `ti-databricks-tf-eu-metastore` |
| Lakehouse S3 bucket | `ti-databricks-tf-eu-lakehouse` |
| Unity Catalog IAM role | `ti-databricks-tf-eu-uc-role` |
| IAM access policy | `ti-databricks-tf-eu-uc-role-s3-access` |

### Databricks Unity Catalog
| Resource | Value |
|----------|-------|
| Metastore name | `ti-databricks-tf-eu-metastore` |
| Storage credential | `ti-databricks-tf-eu-storage-credential` |
| External locations | One per catalog + raw: `bronze-lakehouse`, `silver-lakehouse`, `gold-lakehouse`, `bronze-dev-lakehouse`, `silver-dev-lakehouse`, `gold-dev-lakehouse`, `playpen-lakehouse`, `raw-lakehouse` |
| Catalogs | `bronze`, `silver`, `gold`, `bronze_dev`, `silver_dev`, `gold_dev`, `playpen` |
| Schemas (projects) per catalog | `nyc_taxi` |
| Grants | `Admins` group gets `ALL PRIVILEGES` on all external locations, catalogs, and schemas |
| Admin user (workspace access) | `temidayo.ibraheem@gmail.com` |

### S3 Folder Structure (Lakehouse Bucket)
```
ti-databricks-tf-eu-lakehouse/
├── bronze/
├── silver/
├── gold/
├── bronze-dev/
├── silver-dev/
├── gold-dev/
├── playpen/
└── raw/
    └── nyc-taxi/
```

Project data folders (e.g. `nyc-taxi/`) only exist under `raw/` for external data ingestion. Catalog folders are empty prefixes — Unity Catalog manages data placement within them automatically.

### Catalog & Project Configuration (`modules/databricks/variables.tf`)
```hcl
catalogs = ["bronze", "silver", "gold", "bronze_dev", "silver_dev", "gold_dev", "playpen"]
projects = ["nyc_taxi"]
admins   = ["Admins"]
```

### Terraform Entry Point
All deployments run from `terraform/dev/`. The `databricks_workspace_url` variable in `terraform/dev/variables.tf` must be updated after first apply (workspace URL is only known after workspace creation).

## Architecture Overview

```
Workspace (account-level provider)
├── Cross-account IAM role
├── S3 root storage bucket
└── MWS workspace

Metastore (account-level provider)
├── Metastore Assignment → workspace
├── Default Data Access  → IAM role
└── ...

Unity Catalog (workspace-level provider)
├── Storage Credential → IAM role
├── Storage Credential → IAM role
├── External Location: {catalog}-lakehouse → s3://{prefix}-lakehouse/{catalog}/   (one per catalog)
├── External Location: raw-lakehouse → s3://{prefix}-lakehouse/raw
├── Grants: Admins group → ALL PRIVILEGES on all ext locations, catalogs, schemas
├── Catalog: bronze / silver / gold / bronze_dev / silver_dev / gold_dev / playpen
│   ├── storage_root = s3://{prefix}-lakehouse/{catalog}/   (matches ext loc)
│   └── Schema: {project}   (e.g. nyc_taxi)
└── ...

S3 Buckets:
  {prefix}-metastore           → metastore root storage (shared)
  {prefix}-lakehouse           → single shared bucket with catalog prefixes + raw project folders
    ├── {catalog}/             (empty prefix — UC manages data placement)
    └── raw/{project}/         (project folders only here, for external data ingestion)

IAM:
  Role: {prefix}-uc-role       → assumed by Databricks, grants S3 access
  Trust: Databricks UC master role + self-assume (required by UC)

Workspace Access (account-level provider):
  databricks_mws_permission_assignment → admin user
```

## Module Structure

```
terraform/
├── modules/
│   ├── s3/                      # Reusable S3 bucket (encryption, public access block)
│   ├── iam-unity-catalog/       # IAM role + S3 policy for UC
│   ├── unity-catalog/           # UC resources (credential, locations, catalogs, schemas)
│   ├── databricks/              # Composition wiring S3 + IAM + UC together
│   └── workspace/               # Cross-account IAM, root S3 bucket, MWS workspace
└── dev/                         # Root config (providers, tfvars, user assignments)
```

## Provider Configuration — Dual Provider Setup

Two Databricks providers are required: **account-level** for workspace/metastore management and **workspace-level** for UC resources. Both use service principal OAuth (client_id/client_secret), NOT PAT tokens.

```hcl
provider "aws" {
  region = "eu-west-2"
}

# Account-level provider — workspace creation, metastore assignment, user management
provider "databricks" {
  host          = "https://accounts.cloud.databricks.com"
  account_id    = var.databricks_account_id
  client_id     = var.databricks_client_id
  client_secret = var.databricks_client_secret
}

# Workspace-level provider — UC resources (storage credentials, catalogs, etc.)
provider "databricks" {
  alias         = "workspace"
  host          = var.databricks_workspace_url
  client_id     = var.databricks_client_id
  client_secret = var.databricks_client_secret
}
```

### Passing Providers to Modules

Modules that need the workspace-level provider must declare a `configuration_aliases` and receive both providers explicitly:

```hcl
# In the module's versions.tf:
required_providers {
  databricks = {
    source                = "databricks/databricks"
    configuration_aliases = [databricks.workspace]
  }
}

# In the root module call:
module "databricks" {
  source = "../modules/databricks"

  providers = {
    aws                  = aws
    databricks           = databricks
    databricks.workspace = databricks.workspace
  }
  # ...
}

# Inside the composition module, pass workspace provider to unity-catalog:
module "unity_catalog" {
  source = "../unity-catalog"

  providers = {
    databricks = databricks.workspace
  }
  # ...
}
```

### Required Variables

| Variable | Description | Where to Find |
|---|---|---|
| `databricks_account_id` | Account ID (also ExternalId for trust) | Account console |
| `databricks_client_id` | Service principal client ID | Account console → Service Principals |
| `databricks_client_secret` | Service principal client secret | Generated when creating SP |
| `databricks_workspace_url` | Workspace URL (e.g. `https://dbc-xxx.cloud.databricks.com`) | Workspace settings or `terraform output` |
| `databricks_uc_role_arn` | Databricks UC master role ARN | API: `GET /api/2.1/unity-catalog/storage-credentials` → `unity_catalog_iam_arn` |

## Key Implementation Details

### IAM Trust Policy — Self-Assuming Role

Databricks Unity Catalog requires the IAM role to be **self-assuming**. This must be done with **two separate statements** — the self-assume statement must NOT include the ExternalId condition:

```hcl
data "aws_caller_identity" "this" {}

data "aws_iam_policy_document" "trust" {
  # Statement 1: Databricks assumes this role (with ExternalId)
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [var.databricks_unity_catalog_role_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.databricks_account_id]
    }
  }

  # Statement 2: Self-assume (NO ExternalId — Databricks doesn't pass it)
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.this.account_id}:role/${var.role_name}"]
    }
  }
}
```

**Common mistake:** Merging both principals into one statement with ExternalId — the self-assume call from Databricks doesn't provide ExternalId, so it fails.

**Avoid circular dependency:** Use `aws_caller_identity` + `var.role_name` to construct the ARN instead of referencing `aws_iam_role.this.arn`.

### S3 Access Policy

Grant these actions on each bucket ARN and `/*`:
- `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject`
- `s3:ListBucket`, `s3:GetBucketLocation`

### Creating a New Metastore

Create a Terraform-managed metastore in the target region with its own S3 storage root, then assign it to the workspace. These use the **account-level provider**:

```hcl
resource "databricks_metastore" "this" {
  name          = "${var.workspace_name}-metastore"
  region        = var.region  # must match workspace region
  storage_root  = "s3://${module.metastore_bucket.bucket_id}/"
  force_destroy = false
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

  depends_on = [databricks_metastore_assignment.this]
}
```

### External Locations and Catalog Storage

These use the **workspace-level provider**:

- Create **one external location per catalog** pointing at the catalog root (`s3://{bucket}/{catalog}`)
- Each catalog's `storage_root` matches its external location URL (`s3://{bucket}/{catalog}`)
- The catalog `depends_on` the external location (Databricks validates the location exists)
- Projects (schemas) inherit storage from the catalog — no per-project external locations needed

In `modules/unity-catalog/variables.tf`:
```hcl
variable "external_locations" {
  description = "Map of external location name to S3 URL. One per catalog."
  type        = map(string)
}

variable "catalogs" {
  type = map(object({
    storage_root = string
    comment      = optional(string, "")
  }))
}

variable "projects" {
  description = "Project names to create as schemas within each catalog."
  type        = list(string)
  default     = []
}
```

In `modules/unity-catalog/main.tf`:
```hcl
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

resource "databricks_external_location" "this" {
  for_each = var.external_locations

  metastore_id    = var.metastore_id
  name            = each.key            # e.g. "bronze-lakehouse" or "raw-lakehouse"
  url             = each.value          # e.g. "s3://{bucket}/bronze" or "s3://{bucket}/raw"
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
  name          = each.value.schema_name  # project name, e.g. "nyc_taxi"
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
```

In `modules/databricks/main.tf`, build external locations (including `raw-lakehouse`) and catalogs from the catalogs list:
```hcl
module "unity_catalog" {
  # ...
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

  projects = var.projects
  admins   = var.admins  # e.g. ["Admins"] — grants ALL PRIVILEGES on ext locations, catalogs, schemas
}
```

### Workspace User Access

When a workspace is created via SP OAuth, users won't have access by default. Add users with `databricks_mws_permission_assignment` (account-level provider):

```hcl
data "databricks_user" "admin" {
  user_name = "user@example.com"
}

resource "databricks_mws_permission_assignment" "admin_user" {
  workspace_id = module.workspace.workspace_id
  principal_id = data.databricks_user.admin.id
  permissions  = ["ADMIN"]
}
```

This grants the user workspace access with the specified permission level. Without this, users will see "You do not have permission to access this page" even if the workspace is running.

### Flattening Catalogs × Projects

Use nested `for` with `merge(...)` to create a map from catalogs and projects:

```hcl
locals {
  catalog_project_pairs = merge([
    for catalog in var.catalogs : {
      for project in var.projects :
      "${catalog}_${project}" => {
        catalog = catalog
        project = project
      }
    }
  ]...)
}
```

### S3 Project Folders

Create empty S3 objects as folder markers for catalog-level prefixes and raw/project folders in the shared lakehouse bucket. Project subfolders only exist under `raw/` — catalog folders are empty prefixes managed by Unity Catalog:

```hcl
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
  key     = each.value.key  # e.g. "bronze/" or "raw/nyc-taxi/"
  content = ""
}
```

### Finding the UC Role ARN

If the user doesn't know the Databricks UC master role ARN, fetch it from the existing managed storage credential:

```bash
curl -s "https://<workspace>/api/2.1/unity-catalog/storage-credentials" \
  -H "Authorization: Bearer <token>" | jq '.storage_credentials[].databricks_aws_iam_role.unity_catalog_iam_arn'
```

## Deployment Order

Resources must be created in this order due to dependencies:

1. **Workspace** — cross-account IAM role, S3 root bucket, MWS workspace
2. **S3 buckets** — metastore bucket + lakehouse bucket + project folders
3. **IAM** — UC role with self-assuming trust + S3 access policy
4. **Metastore** — create, assign to workspace, configure data access (account-level provider)
5. **Unity Catalog** — storage credential, external locations, catalogs, schemas (workspace-level provider)
6. **User access** — `databricks_mws_permission_assignment` for admin users (account-level provider)

Steps 2-4 can be applied together. Step 5 requires the workspace-level provider (needs workspace URL). Step 6 can be applied alongside or after step 5.

## Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| `non self-assuming` | Trust policy missing self-assume, or ExternalId on self-assume statement | Use two separate trust statements, no ExternalId on self-assume |
| `Workspace is not in the same region as metastore` | Created a metastore in wrong region | Set `region` to match the workspace region (e.g. `eu-west-2`) |
| `External Location does not exist` | Catalog `storage_root` points to URL not covered by an external location | Create external location at bucket root, then set catalog `storage_root` to same URL |
| `Metastore storage root URL does not exist` | System metastore has no default storage | Set explicit `storage_root` on each catalog |
| IAM propagation delay | Trust policy just updated, Databricks hasn't seen it yet | Wait 30-60s and re-run `terraform apply` |
| `You do not have permission to access this page` | User not assigned to workspace | Add `databricks_mws_permission_assignment` for the user with appropriate permissions |
| Catalogs not visible in workspace | Metastore not assigned, or user lacks permissions | Verify `databricks_metastore_assignment` exists and user has workspace ADMIN or catalog grants |
| `cannot delete external location: ... has 1 dependent catalogs` | Databricks blocks deletion of an ext location that covers a catalog's `storage_root` | Use `databricks external-locations delete <name> --force --profile <profile>` via CLI, then `terraform state rm` the resource, then re-apply |
| `Input path url '...' overlaps with an existing external location` | Trying to create a parent-path ext location while a child-path one still exists | Delete the child ext locations first (with `--force` if they have catalog dependents), then apply |
| CLI commands show wrong workspace / "does not exist" | `~/.databrickscfg` [DEFAULT] profile points at a different workspace than Terraform manages | Add a named profile with the correct `host`, `client_id`, `client_secret` and pass `--profile <name>` to CLI commands |

## Adding a New Project

Add the project name to the `projects` list in the root config:

```hcl
module "databricks" {
  source = "../modules/databricks"

  catalogs = ["bronze", "silver", "gold", "bronze_dev", "silver_dev", "gold_dev", "playpen"]
  projects = ["nyc_taxi", "new_project"]
}
```

This automatically creates:
- An S3 folder marker: `raw/new-project/` for external data ingestion
- A `new_project` schema in every catalog (e.g. `bronze.new_project`, `gold_dev.new_project`)
- `ALL PRIVILEGES` grants for the `Admins` group on each new schema

**No new external locations or catalogs are created** — the project schema is a child of the existing catalogs, which already have external locations covering `s3://{bucket}/{catalog}`. Project subfolders are only created under `raw/`, not under each catalog.

## Adding a New Catalog

Add the catalog name to the `catalogs` list:

```hcl
catalogs = ["bronze", "silver", "gold", "bronze_dev", "silver_dev", "gold_dev", "playpen", "staging"]
```

This automatically creates:
- A new `staging` catalog with `storage_root = s3://{bucket}/staging`
- A new `staging-lakehouse` external location
- An S3 catalog-level folder marker: `staging/`
- A schema for each project in the new catalog
- `ALL PRIVILEGES` grants for the `Admins` group on the new external location, catalog, and schemas
