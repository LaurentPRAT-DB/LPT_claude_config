# Authorization for Databricks Apps

Databricks Apps supports two complementary authorization models. Use one or both depending on your app's needs.

**Docs**: https://docs.databricks.com/aws/en/dev-tools/databricks-apps/auth

---

## App Authorization (Service Principal)

Each app gets a dedicated service principal. Databricks auto-injects credentials:

- `DATABRICKS_CLIENT_ID` — OAuth client ID
- `DATABRICKS_CLIENT_SECRET` — OAuth client secret

**You don't need to read these manually.** The SDK `Config()` detects them automatically:

```python
from databricks.sdk.core import Config
from databricks import sql

cfg = Config()  # Auto-detects SP credentials from environment
conn = sql.connect(
    server_hostname=cfg.host,
    http_path="/sql/1.0/warehouses/<id>",
    credentials_provider=lambda: cfg.authenticate,
)
```

**Use for**: background tasks, shared data access, logging, external service calls.

**Limitation**: all users share the same permissions — no per-user access control.

---

## User Authorization (On-Behalf-Of)

Allows the app to act with the identity of the current user. Databricks forwards the user's access token to the app via HTTP header.

**Use for**: user-specific data queries, Unity Catalog row/column filters, audit trails.

**Prerequisite**: workspace admin must enable user authorization (Public Preview). Add scopes when creating/editing the app in the UI.

### Retrieving the User Token Per Framework

```python
# Streamlit
import streamlit as st
user_token = st.context.headers.get("x-forwarded-access-token")

# Dash / Flask
from flask import request
user_token = request.headers.get("x-forwarded-access-token")

# Gradio
import gradio as gr
def handler(message, request: gr.Request):
    user_token = request.headers.get("x-forwarded-access-token")

# FastAPI
from fastapi import Request
async def endpoint(request: Request):
    user_token = request.headers.get("x-forwarded-access-token")

# Reflex
user_token = session.http_conn.headers.get("x-forwarded-access-token")
```

### Querying with User Token

```python
from databricks.sdk.core import Config
from databricks import sql

cfg = Config()
user_token = get_user_token()  # Per-framework method above

conn = sql.connect(
    server_hostname=cfg.host,
    http_path="/sql/1.0/warehouses/<id>",
    access_token=user_token,  # User's token, not SP credentials
)
```

---

## Combining Both Models

Use app auth for shared operations and user auth for user-specific data:

```python
from databricks.sdk.core import Config
from databricks import sql

cfg = Config()

def get_app_connection(warehouse_http_path: str):
    """App auth — shared data, logging, background tasks."""
    return sql.connect(
        server_hostname=cfg.host,
        http_path=warehouse_http_path,
        credentials_provider=lambda: cfg.authenticate,
    )

def get_user_connection(warehouse_http_path: str, user_token: str):
    """User auth — respects Unity Catalog row/column filters."""
    return sql.connect(
        server_hostname=cfg.host,
        http_path=warehouse_http_path,
        access_token=user_token,
    )
```

---

## OAuth Scopes

When adding user authorization, select only the scopes your app needs:

| Scope | Grants Access To |
|-------|-----------------|
| `sql` | SQL warehouse queries |
| `files.files` | Files and directories |
| `dashboards.genie` | Genie spaces |
| `iam.access-control:read` | Access control (default) |
| `iam.current-user:read` | Current user identity (default) |

**Best practice**: request minimum required scopes. Databricks blocks access outside approved scopes even if the user has broader permissions.

---

## When to Use Which

| Scenario | Model |
|----------|-------|
| All users see same data | App auth only |
| User-specific row/column filters | User auth |
| Background jobs, logging | App auth |
| Audit trail per user | User auth |
| Mixed shared + personal data | Both |

---

## CRITICAL: OBO Gotchas (Learned from Production)

### 1. user_api_scopes NOT Auto-Applied

**Problem**: Setting `user_api_scopes` in `app.yaml` alone does NOT enable OBO.

**Solution**: You MUST also run the CLI command:
```bash
databricks apps update <app-name> --json '{"user_api_scopes": ["sql"]}' -p <profile>
```

Verify with:
```bash
databricks apps get <app-name> -p <profile>
# Look for "effective_user_api_scopes" in output
```

### 2. Scope Format

Use simple scope names, NOT expanded forms:
- ✅ Correct: `sql`
- ❌ Wrong: `sql:read`, `sql.statement-execution:execute`

### 3. Per-Router OBO Configuration

**CRITICAL**: ALL backend routes querying system tables MUST use user's OBO token.

```python
# ❌ WRONG - SP auth fails on system tables
def get_workspace_client():
    return WorkspaceClient()  # Uses SP credentials

# ✅ CORRECT - Use OBO for system table access
def get_workspace_client_obo(request: Request):
    token = request.headers.get("x-forwarded-access-token")
    if token:
        return WorkspaceClient(token=token)  # User's permissions
    return WorkspaceClient()  # Fallback to SP for non-user requests
```

**Why**: SP auth → limited system table permissions → 500 errors. OBO → user's existing permissions → works.

### 4. System Table workspace_id is BIGINT

**Problem**: Quoting workspace_id in SQL returns 0 rows.

```sql
-- ❌ WRONG (string comparison fails silently)
WHERE workspace_id = '1234567890'

-- ✅ CORRECT (BIGINT comparison)
WHERE workspace_id = 1234567890
```

### 5. Detecting OBO User

The `gap-auth` response header contains the authenticated user's email:
```python
user_email = response.headers.get("gap-auth")
```

### 6. System Tables result_state Values Differ from Jobs API

**Problem**: System tables use different status values than Jobs API.

```python
# Jobs API response
job_run.state.result_state == "SUCCESS"

# System tables (job_run_timeline)
result_state == "SUCCEEDED"  # NOT "SUCCESS"
```

**System table values**: `SUCCEEDED`, `FAILED`, `TIMED_OUT`, `SKIPPED`, `CANCELLED`, `ERROR`

---

## Best Practices

- Never log, print, or write tokens to files
- Grant service principal minimum required permissions on resources
- Use `CAN MANAGE` only for trusted developers; `CAN USE` for app users
- Enforce peer review for app code before production deployment
- Always use OBO for system table queries (users typically have access already)
- Verify OBO is enabled: `databricks apps get <name>` → check `effective_user_api_scopes`
- Cookbook auth examples: [Streamlit](https://apps-cookbook.dev/docs/streamlit/authentication/users_get_current) · [Dash](https://apps-cookbook.dev/docs/dash/authentication/users_get_current) · [Reflex](https://apps-cookbook.dev/docs/reflex/authentication/users_get_current)
