# Health Check Patterns for Databricks Apps

Comprehensive health check patterns for production Databricks Apps, ensuring reliability and quick issue detection.

## Why Health Checks Matter

Databricks Apps have unique failure modes:
- **OBO not enabled** - `user_api_scopes` not applied via CLI
- **SP auth limitations** - Service Principal can't access system tables
- **SQL warehouse issues** - Warehouse stopped, wrong ID, no permissions
- **Cache table access** - Missing grants for OBO users
- **Multi-workspace drift** - Config works in dev but fails in prod

A comprehensive health endpoint catches these issues early.

## Health Endpoint Patterns

### Level 1: Basic Health (Minimum)

```python
from fastapi import APIRouter

router = APIRouter()

@router.get("/api/health")
async def health():
    """Basic liveness check - confirms app is running."""
    return {"status": "healthy"}
```

**Use case**: Kubernetes liveness probe, basic uptime monitoring.

### Level 2: Readiness Check (Recommended)

```python
import os
from fastapi import APIRouter, Request
from datetime import datetime

router = APIRouter()

@router.get("/api/health")
async def health_readiness(request: Request):
    """Readiness check - confirms app can serve requests."""
    checks = {}
    overall = "healthy"

    # Check 1: OBO Authentication Available
    user_token = request.headers.get("x-forwarded-access-token")
    if user_token:
        checks["obo_auth"] = "enabled"
    else:
        checks["obo_auth"] = "not_available"
        # Not necessarily unhealthy - could be local dev or SP-only mode

    # Check 2: Environment Configuration
    required_vars = ["DATABRICKS_HOST", "DATABRICKS_WAREHOUSE_ID"]
    missing = [v for v in required_vars if not os.getenv(v)]
    if missing:
        checks["environment"] = f"missing: {missing}"
        overall = "degraded"
    else:
        checks["environment"] = "configured"

    return {
        "status": overall,
        "checks": checks,
        "version": os.getenv("APP_VERSION", "unknown"),
        "workspace": os.getenv("DATABRICKS_HOST", "unknown"),
        "timestamp": datetime.utcnow().isoformat(),
    }
```

**Use case**: Kubernetes readiness probe, deployment validation.

### Level 3: Comprehensive Health (Production)

```python
import os
import asyncio
from fastapi import APIRouter, Request
from datetime import datetime
from typing import Optional
from databricks.sdk import WorkspaceClient

router = APIRouter()

async def check_sql_warehouse(ws: WorkspaceClient, warehouse_id: str) -> dict:
    """Verify SQL warehouse is accessible and running."""
    try:
        result = ws.statement_execution.execute_statement(
            warehouse_id=warehouse_id,
            statement="SELECT 1 as health_check",
            wait_timeout="10s"
        )
        if result.status.state.value == "SUCCEEDED":
            return {"status": "healthy", "latency_ms": "< 10000"}
        else:
            return {"status": "degraded", "state": result.status.state.value}
    except Exception as e:
        error_msg = str(e)
        if "WAREHOUSE_NOT_FOUND" in error_msg:
            return {"status": "unhealthy", "error": "Warehouse not found"}
        elif "PERMISSION_DENIED" in error_msg:
            return {"status": "unhealthy", "error": "No warehouse access"}
        elif "does not have any running clusters" in error_msg:
            return {"status": "degraded", "error": "Warehouse stopped"}
        else:
            return {"status": "unhealthy", "error": error_msg[:100]}

async def check_obo_permissions(ws: WorkspaceClient, request: Request) -> dict:
    """Verify OBO user can access required resources."""
    user_token = request.headers.get("x-forwarded-access-token")
    if not user_token:
        return {"status": "not_configured", "note": "OBO not enabled or local dev"}

    try:
        # Create OBO client
        obo_ws = WorkspaceClient(
            host=os.getenv("DATABRICKS_HOST"),
            token=user_token
        )
        # Try to get current user - validates token
        user = obo_ws.current_user.me()
        return {
            "status": "healthy",
            "user": user.user_name,
            "email": user.emails[0].value if user.emails else None
        }
    except Exception as e:
        return {"status": "unhealthy", "error": str(e)[:100]}

async def check_system_tables(ws: WorkspaceClient, warehouse_id: str) -> dict:
    """Verify access to system tables (requires OBO for most users)."""
    try:
        result = ws.statement_execution.execute_statement(
            warehouse_id=warehouse_id,
            statement="SELECT 1 FROM system.lakeflow.job_run_timeline LIMIT 1",
            wait_timeout="30s"
        )
        if result.status.state.value == "SUCCEEDED":
            return {"status": "healthy"}
        else:
            return {"status": "degraded", "state": result.status.state.value}
    except Exception as e:
        error_msg = str(e)
        if "PERMISSION_DENIED" in error_msg or "does not have permission" in error_msg:
            return {"status": "unhealthy", "error": "No system table access - use OBO"}
        else:
            return {"status": "unhealthy", "error": error_msg[:100]}

async def check_cache_tables(ws: WorkspaceClient, warehouse_id: str, catalog: str, schema: str) -> dict:
    """Verify cache tables are accessible."""
    try:
        result = ws.statement_execution.execute_statement(
            warehouse_id=warehouse_id,
            statement=f"SELECT 1 FROM {catalog}.{schema}.job_health_cache LIMIT 1",
            wait_timeout="10s"
        )
        if result.status.state.value == "SUCCEEDED":
            return {"status": "healthy"}
        else:
            return {"status": "not_available", "note": "Cache tables not set up"}
    except Exception as e:
        return {"status": "not_available", "error": str(e)[:50]}

@router.get("/api/health")
async def health_comprehensive(request: Request):
    """
    Comprehensive health check for production monitoring.

    Checks:
    - SQL warehouse connectivity
    - OBO authentication (if enabled)
    - System table access
    - Cache table access (if configured)
    """
    checks = {}
    overall = "healthy"

    # Get configuration
    host = os.getenv("DATABRICKS_HOST")
    warehouse_id = os.getenv("DATABRICKS_WAREHOUSE_ID")
    cache_catalog = os.getenv("CACHE_CATALOG", "job_monitor")
    cache_schema = os.getenv("CACHE_SCHEMA", "cache")

    # Determine auth mode
    user_token = request.headers.get("x-forwarded-access-token")
    if user_token:
        # Use OBO for all checks
        ws = WorkspaceClient(host=host, token=user_token)
        checks["auth_mode"] = "obo"
    else:
        # Fall back to SP auth
        ws = WorkspaceClient()  # Uses DATABRICKS_CLIENT_ID/SECRET
        checks["auth_mode"] = "service_principal"

    # Run checks in parallel for speed
    warehouse_check, obo_check = await asyncio.gather(
        check_sql_warehouse(ws, warehouse_id),
        check_obo_permissions(ws, request),
        return_exceptions=True
    )

    # Process warehouse check
    if isinstance(warehouse_check, Exception):
        checks["sql_warehouse"] = {"status": "error", "error": str(warehouse_check)[:100]}
        overall = "unhealthy"
    else:
        checks["sql_warehouse"] = warehouse_check
        if warehouse_check["status"] != "healthy":
            overall = "degraded" if overall == "healthy" else overall

    # Process OBO check
    if isinstance(obo_check, Exception):
        checks["obo_auth"] = {"status": "error", "error": str(obo_check)[:100]}
    else:
        checks["obo_auth"] = obo_check

    # System tables check (only if warehouse is healthy)
    if checks["sql_warehouse"].get("status") == "healthy":
        system_check = await check_system_tables(ws, warehouse_id)
        checks["system_tables"] = system_check
        if system_check["status"] == "unhealthy":
            overall = "degraded"

    # Cache tables check (optional)
    if checks["sql_warehouse"].get("status") == "healthy":
        cache_check = await check_cache_tables(ws, warehouse_id, cache_catalog, cache_schema)
        checks["cache_tables"] = cache_check
        # Cache is optional, don't degrade overall status

    return {
        "status": overall,
        "checks": checks,
        "version": os.getenv("APP_VERSION", "unknown"),
        "workspace": host,
        "workspace_name": extract_workspace_name(host),
        "timestamp": datetime.utcnow().isoformat(),
    }

def extract_workspace_name(host: str) -> str:
    """Extract friendly workspace name from host URL."""
    if not host:
        return "unknown"
    # e.g., https://e2-demo-field-eng.cloud.databricks.com -> E2 Demo Field Eng
    import re
    match = re.search(r'https?://([^.]+)', host)
    if match:
        name = match.group(1).replace('-', ' ').title()
        return name
    return host
```

## Health Check Response Examples

### Healthy Response
```json
{
  "status": "healthy",
  "checks": {
    "auth_mode": "obo",
    "sql_warehouse": {"status": "healthy", "latency_ms": "< 10000"},
    "obo_auth": {"status": "healthy", "user": "user@company.com"},
    "system_tables": {"status": "healthy"},
    "cache_tables": {"status": "healthy"}
  },
  "version": "1.2.0",
  "workspace": "https://e2-demo-field-eng.cloud.databricks.com",
  "workspace_name": "E2 Demo Field Eng",
  "timestamp": "2026-02-27T10:30:00Z"
}
```

### Degraded Response (Common Issues)
```json
{
  "status": "degraded",
  "checks": {
    "auth_mode": "service_principal",
    "sql_warehouse": {"status": "healthy"},
    "obo_auth": {"status": "not_configured", "note": "OBO not enabled or local dev"},
    "system_tables": {"status": "unhealthy", "error": "No system table access - use OBO"},
    "cache_tables": {"status": "not_available"}
  },
  "version": "1.2.0",
  "workspace": "https://demo-west.cloud.databricks.com",
  "timestamp": "2026-02-27T10:30:00Z"
}
```

**Diagnosis**: OBO not enabled. System tables require user permissions.

**Fix**:
```bash
databricks apps update <app-name> --json '{"user_api_scopes": ["sql"]}' -p <profile>
```

### Unhealthy Response
```json
{
  "status": "unhealthy",
  "checks": {
    "sql_warehouse": {"status": "unhealthy", "error": "Warehouse not found"},
    "obo_auth": {"status": "error", "error": "Invalid token"}
  },
  "version": "1.2.0",
  "timestamp": "2026-02-27T10:30:00Z"
}
```

**Diagnosis**: Wrong warehouse ID for this workspace.

## Integration with Monitoring

### Kubernetes Probes

```yaml
# app.yaml or Kubernetes deployment
livenessProbe:
  httpGet:
    path: /api/health
    port: 8000
  initialDelaySeconds: 30
  periodSeconds: 30

readinessProbe:
  httpGet:
    path: /api/health
    port: 8000
  initialDelaySeconds: 10
  periodSeconds: 10
```

### Automated Health Monitoring Script

```bash
#!/bin/bash
# monitor-health.sh - Check health across all deployments

DEPLOYMENTS=(
  "e2|DEFAULT|https://job-monitor-xxx.aws.databricksapps.com"
  "prod|DEMO WEST|https://job-monitor-yyy.aws.databricksapps.com"
  "dev|LPT_FREE|https://job-monitor-zzz.aws.databricksapps.com"
)

for deployment in "${DEPLOYMENTS[@]}"; do
  IFS='|' read -r name profile url <<< "$deployment"

  echo "==> Checking $name ($url)..."

  response=$(curl -sf "$url/api/health" 2>/dev/null)
  if [ $? -ne 0 ]; then
    echo "  UNREACHABLE"
    continue
  fi

  status=$(echo "$response" | jq -r '.status')
  if [ "$status" = "healthy" ]; then
    echo "  HEALTHY"
  elif [ "$status" = "degraded" ]; then
    echo "  DEGRADED - $(echo "$response" | jq -c '.checks')"
  else
    echo "  UNHEALTHY - $(echo "$response" | jq -c '.checks')"
  fi
done
```

## Troubleshooting Common Health Issues

| Health Check | Status | Likely Cause | Fix |
|--------------|--------|--------------|-----|
| sql_warehouse | unhealthy: not found | Wrong warehouse ID | Update `DATABRICKS_WAREHOUSE_ID` in app config |
| sql_warehouse | degraded: stopped | Warehouse auto-stopped | Start warehouse or configure auto-start |
| obo_auth | not_configured | Scopes not applied | Run `databricks apps update --json '{"user_api_scopes": ["sql"]}'` |
| system_tables | unhealthy: permission denied | Using SP auth for system tables | Enable OBO and use `get_ws_prefer_user()` |
| cache_tables | not_available | Cache not set up | Run cache refresh job or grant SELECT on cache schema |

## Best Practices

1. **Always check OBO first** - Most permission issues stem from OBO not being enabled
2. **Use parallel checks** - Health endpoint should respond in < 5 seconds
3. **Don't fail on optional features** - Cache tables missing shouldn't make app unhealthy
4. **Include version** - Essential for debugging "works in dev, fails in prod"
5. **Include workspace name** - Quickly identify which deployment has issues
6. **Log health check results** - Track degradation over time
