# Databricks CLI Reference

Quick reference for Databricks CLI syntax and common patterns. You have PAT access so use that.

---

## Authentication Setup

**Setup:**
```bash
cat > ~/.databrickscfg << 'EOF'
[DEFAULT]
host = https://your-workspace.cloud.databricks.com
token = dapi_your_token_here
EOF

chmod 600 ~/.databrickscfg
```

**No Session Start Required** - Token persists until expiration

**Generate PAT:** User Settings → Developer → Access Tokens

---