# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Commands

All Terraform commands run from `terraform/dev/` (the only environment entry point). The CI pipeline targets `terraform/modules/s3/` for module-level testing.

```bash
# Plan / apply
cd terraform/dev
terraform init
terraform plan
terraform apply -auto-approve

# Format check (run from modules/s3 or recursively from root)
terraform fmt -check -recursive

# Validate
terraform init -backend=false && terraform validate

# Lint (requires tflint installed)
tflint --init && tflint --format compact

# Run mock unit tests (no AWS credentials needed)
cd terraform/modules/s3
terraform init -backend=false
terraform test -filter=tests/mock_unit.tftest.hcl -verbose

# Run plan validation tests
terraform test -filter=tests/plan_validation.tftest.hcl -verbose

# Run integration tests (creates real AWS resources, auto-destroys)
terraform test -filter=tests/apply_encryption.tftest.hcl -verbose
```

---

## Architecture

### Module dependency graph

```
terraform/dev/  (root entry point)
├── module.workspace        → modules/workspace/
└── module.databricks       → modules/databricks/
    ├── module.metastore_bucket  → modules/s3/
    ├── module.lakehouse_bucket  → modules/s3/
    ├── module.iam_unity_catalog → modules/iam-unity-catalog/
    └── module.unity_catalog     → modules/unity-catalog/
```

`module.databricks` depends on `module.workspace` outputs (workspace ID, workspace URL) to configure the workspace-level Databricks provider.

### Dual Databricks provider pattern

The repo uses two Databricks provider aliases:
- **Account-level** (`databricks.mws`): Used by `workspace` module and `databricks` module for metastore/metastore-assignment resources. Authenticates via `host = "https://accounts.cloud.databricks.com"`.
- **Workspace-level** (`databricks.workspace`): Used by `unity-catalog` module for storage credentials, external locations, catalogs, and schemas. Its `host` comes from `module.workspace.workspace_url` output.

This provider split is why `modules/unity-catalog/` takes an `iam_role_arn` input rather than creating the IAM role itself.

### Multi-project / multi-environment catalog layout

Projects and environments are configured in `modules/databricks/variables.tf` as a map:
```hcl
projects = { nyc_taxi = { environments = ["dev", "prod"] } }
schemas  = ["raw", "bronze", "silver", "gold"]
```

The `databricks` module flattens this into:
- One catalog per `{project}_{environment}` (e.g. `nyc_taxi_dev`, `nyc_taxi_prod`)
- Four schemas per catalog (`raw`, `bronze`, `silver`, `gold`)
- S3 folder prefixes under the shared lakehouse bucket: `{env}/{project}/{schema}/`
- One external location per environment pointing to `s3://…/{env}/`

### IAM trust policy — self-assume requirement

Unity Catalog storage credential validation requires the IAM role to self-assume (no ExternalId). The trust policy in `modules/iam-unity-catalog/main.tf` includes both:
1. Databricks principal with `sts:ExternalId = databricks_account_id`
2. Self-assume: `arn:aws:iam::{account_id}:role/{role_name}` — computed from `data.aws_caller_identity` + `var.role_name` to avoid circular references

### S3 module

`modules/s3/` is the most complete module with its own tests and examples. It supports:
- SSE-S3 (default) or KMS encryption (with a `precondition` requiring `kms_master_key_id` when `encryption_type = "aws:kms"`)
- Optional versioning and lifecycle rules (STANDARD_IA → GLACIER → expiration)
- Validation on `bucket_name` (regex) and `environment` (enum)

### CI pipeline (`.github/workflows/ci.yml`)

4 stages, all scoped to `modules/s3/`:
1. **Static analysis** — fmt, validate, tflint (every push)
2. **Mock unit tests** — no AWS credentials, free (every push)
3. **Plan + Infracost** — PR only; fails if monthly cost increase > $50
4. **Integration tests** — main branch only; real AWS resources, auto-destroyed

---

## Databricks CLI / Authentication

PAT authentication is used (not OAuth). Configure `~/.databrickscfg`:

```bash
cat > ~/.databrickscfg << 'EOF'
[DEFAULT]
host  = https://dbc-e1000168-a972.cloud.databricks.com
token = dapi_your_token_here
EOF
chmod 600 ~/.databrickscfg
```

Generate PAT: Databricks workspace → User Settings → Developer → Access Tokens.

Tokens persist until expiration — no session management needed.
