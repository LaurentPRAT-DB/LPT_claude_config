# Databricks Deployment Patterns for APX Apps

**Critical patterns learned from production APX deployments. Consult before deploying.**

## Project Structure (Deployed)

```
{app-name}/
├── databricks.yml          # DABS config
├── app.yaml                # App runtime config
├── {app_name}/             # Python package (underscore, NOT src/)
│   ├── __init__.py
│   ├── _metadata.py
│   ├── __dist__/           # Built frontend (CRITICAL: NOT in .gitignore!)
│   │   ├── index.html
│   │   └── assets/
│   ├── backend/
│   │   ├── app.py          # FastAPI app
│   │   ├── core.py         # Dependencies, static serving
│   │   ├── models.py       # Pydantic models
│   │   └── routers/        # API endpoints
│   └── ui/
│       ├── routes/         # TanStack Router pages
│       └── components/     # React components
```

## Pre-Deployment Checklist

### 1. Build Frontend (CRITICAL!)

**TSX changes are NOT automatically built for deployment!**

```bash
# Navigate to UI directory
cd {app-name}/{app_name}/ui

# Build frontend - outputs to ../__dist__/
npm run build

# Go back to project root
cd ../..
```

### 2. Verify .gitignore

**CRITICAL**: `__dist__/` must NOT be in `.gitignore`:

```bash
# Check if __dist__ is ignored (should return nothing)
grep -n "__dist__" .gitignore

# If found, remove the line!
```

### 3. Add Version Number for Validation

Add visible version in sidebar to confirm deployments worked:

```tsx
// In _sidebar.tsx footer
<span className="text-xs text-muted-foreground">v1.0.0</span>
```

Bump after each deployment to visually verify updates are live.

## app.yaml Configuration

### DATABRICKS_HOST is Required

The app URL (e.g., `my-app-xxx.aws.databricksapps.com`) is NOT the workspace URL.
`WorkspaceClient.config.host` may be empty in Databricks Apps context.

```yaml
command:
  - uvicorn
  - {app_name}.backend.app:app
  - --host
  - 0.0.0.0
  - --port
  - "8000"

env:
  - name: DATABRICKS_HOST
    value: "https://your-workspace.cloud.databricks.com"  # REQUIRED!
  - name: MY_APP_SETTING
    value: "value"

# OAuth scopes for user token (OBO)
user_api_scopes:
  - compute.clusters:read
  - compute.clusters:manage
```

### Authentication Strategy

**Problem**: OBO (On-Behalf-Of) tokens lack cluster/compute scopes by default.

**Solution**: Use Service Principal auth for management APIs:

```python
# In core.py - Service Principal client (app.state)
def get_ws(request: Request) -> WorkspaceClient:
    return request.app.state.workspace_client  # Uses SP credentials

# User client for user-specific operations
def get_user_ws(
    request: Request,
    token: Annotated[str | None, Header(alias="X-Forwarded-Access-Token")] = None,
) -> WorkspaceClient:
    if token:
        return WorkspaceClient(token=token, auth_type="pat")
    return request.app.state.workspace_client  # Fallback to SP
```

**Service Principal Setup**:
```bash
# Get app's service principal ID
databricks apps get {app-name} | jq '.service_principal_id'

# Add SP to admins group for full access
databricks groups patch {admins-group-id} --json '{
  "Operations": [{"op": "add", "path": "members", "value": [{"value": "{sp-id}"}]}],
  "schemas": ["urn:ietf:params:scim:api:messages:2.0:PatchOp"]
}'
```

## databricks.yml Configuration

```yaml
bundle:
  name: {app-name}

variables:
  app_name:
    description: Name of the Databricks App
    default: {app-name}

targets:
  dev:
    mode: development
    default: true
    workspace:
      root_path: /Users/${workspace.current_user.userName}/.bundle/${bundle.name}/dev

  prod:
    mode: production
    workspace:
      root_path: /Shared/.bundle/${bundle.name}/prod

resources:
  apps:
    {app_name}:  # Use underscores
      name: ${var.app_name}
      description: "Your app description"
      source_code_path: .
      permissions:
        - user_name: ${workspace.current_user.userName}
          level: CAN_MANAGE
```

## Deployment Commands

```bash
# Full deployment workflow
cd {app-name}/{app_name}/ui
npm run build              # 1. Build frontend
cd ../..
databricks bundle deploy -t dev  # 2. Deploy bundle

# App lifecycle
databricks apps stop {app-name}
databricks apps start {app-name}
databricks apps get {app-name}   # Check status and URL

# View logs for debugging
databricks apps logs {app-name}
```

## Databricks SDK Gotchas

### Always Use getattr for Optional Attributes

Some attributes may not exist on all SDK objects:

```python
# WRONG - may raise AttributeError
last_activity = cluster.last_activity_time
disk_spec = cluster.disk_spec

# CORRECT - use getattr with default
last_activity = getattr(cluster, 'last_activity_time', None)
disk_spec = getattr(cluster, 'disk_spec', None)
```

### Pagination for Large Workspaces

```python
# Don't fetch all at once - use limits
clusters = []
for i, cluster in enumerate(ws.clusters.list()):
    clusters.append(cluster)
    if i + 1 >= limit:
        break
```

### SQL Warehouse Selection

Prefer serverless warehouses (start instantly vs minutes for classic):

```python
def _is_serverless(wh) -> bool:
    if getattr(wh, 'enable_serverless_compute', False):
        return True
    wh_type = getattr(wh, 'warehouse_type', None)
    if wh_type and str(wh_type.value).upper() == "PRO":
        return True
    return False
```

## Workspace URL Patterns

**IMPORTANT**: Use hash-based routing for Databricks workspace links:

```python
# CORRECT - hash-based routing
f"{host}/#setting/clusters/{cluster_id}/configuration"
f"{host}/#setting/clusters/{cluster_id}/driverLogs"
f"{host}/#setting/clusters/{cluster_id}/sparkUi"

# WRONG - will redirect incorrectly!
f"{host}/compute/clusters/{cluster_id}"
```

## Job Clusters are Ephemeral

Job clusters (`cluster_type = "JOB"`) are deleted after job completion.
API calls to get job cluster details will return 404.

```tsx
// Hide links for job clusters in UI
{cluster.clusterType !== "JOB" && (
  <a href={workspaceUrl}>View in Workspace</a>
)}
```

## Pydantic Model Gotchas

### Inheritance - Don't Duplicate Fields

```python
# PARENT
class ClusterSummary(BaseModel):
    policy_id: str | None = None  # Defined here

# CHILD - DON'T duplicate!
class ClusterDetail(ClusterSummary):
    # policy_id inherited - DON'T add again!
    terminated_time: datetime | None = None
```

**Error if duplicated**: `got multiple values for keyword argument 'policy_id'`

### model_dump() + Explicit Fields = Error

```python
# BAD - policy_id set twice
return ClusterDetail(
    **summary.model_dump(),  # Includes policy_id
    policy_id=cluster.policy_id,  # DUPLICATE ERROR!
)

# GOOD - let dump handle inherited fields
return ClusterDetail(
    **summary.model_dump(),  # Already includes policy_id
    terminated_time=cluster.terminated_time,
)
```

## TanStack Router Patterns

### Navigation in Dropdown Menus

```tsx
// BAD - Link wrapping doesn't work
<Link to="/path"><DropdownMenuItem>Click</DropdownMenuItem></Link>

// GOOD - Programmatic navigation
const navigate = useNavigate();
<DropdownMenuItem onClick={() => navigate({ to: "/path" })}>
  Click
</DropdownMenuItem>
```

### URL Search Parameters

```tsx
// Route definition with validateSearch
export const Route = createFileRoute("/_sidebar/entities/")({
  component: EntitiesPage,
  validateSearch: (search: Record<string, unknown>) => ({
    filter: (search.filter as string) || undefined,
  }),
});

// Access in component
const { filter } = Route.useSearch();

// Navigate with search params
navigate({ to: "/entities", search: { filter: "active" } });
```

## Better Error Messages

Include actual error details for debugging:

```python
except Exception as e:
    error_type = type(e).__name__
    error_msg = str(e)
    logger.error(f"Failed: [{error_type}] {error_msg}")
    raise HTTPException(
        status_code=404,
        detail=f"Resource not found. Error: {error_msg}"  # Include actual error!
    )
```

## Static File Serving (core.py)

SPA routing requires catch-all route AFTER API routes:

```python
if dist_dir.exists():
    # Serve static assets
    app.mount("/assets", StaticFiles(directory=dist_dir / "assets"))

    # Catch-all for SPA routing
    @app.get("/{full_path:path}")
    async def serve_spa(full_path: str):
        if full_path.startswith("api/"):
            return JSONResponse({"detail": "Not Found"}, status_code=404)
        return FileResponse(dist_dir / "index.html")
```

## Deploy Validation Pattern (Inspired by Tresor)

Production deployments should follow a multi-phase validation approach to catch issues before users do.

### Phase 1: Pre-Flight Validation

Run before deploying to catch configuration issues early:

```bash
#!/bin/bash
# deploy-validate.sh - Phase 1: Pre-flight checks
set -e

TARGET="${1:-dev}"
echo "==> Phase 1: Pre-flight validation for $TARGET"

# 1.1 Validate app.yaml syntax
echo "  Checking app.yaml..."
python3 -c "import yaml; yaml.safe_load(open('app.yaml'))" || {
  echo "  ERROR: app.yaml is invalid YAML"
  exit 1
}

# 1.2 Check required environment variables are defined
echo "  Checking required env vars..."
grep -q "DATABRICKS_HOST" app.yaml || {
  echo "  ERROR: DATABRICKS_HOST not set in app.yaml"
  exit 1
}

# 1.3 Verify frontend is built
echo "  Checking frontend build..."
DIST_DIR="${APP_NAME}/__dist__"
if [ ! -d "$DIST_DIR" ] || [ ! -f "$DIST_DIR/index.html" ]; then
  echo "  WARNING: Frontend not built. Building now..."
  cd "${APP_NAME}/ui" && npm run build && cd ../..
fi

# 1.4 Verify __dist__ not in .gitignore
if grep -q "__dist__" .gitignore 2>/dev/null; then
  echo "  ERROR: __dist__ is in .gitignore - deployment will fail!"
  exit 1
fi

# 1.5 Type checking
echo "  Running type checks..."
cd "${APP_NAME}/ui" && npm run typecheck && cd ../..

echo "  Pre-flight validation PASSED"
```

### Phase 2: Configuration Safety Checks

Validate Databricks-specific configuration:

```bash
# 2.1 Verify warehouse ID exists for target workspace
echo "==> Phase 2: Configuration safety"

WAREHOUSE_ID=$(grep -A1 "DATABRICKS_WAREHOUSE_ID" app.yaml | tail -1 | sed 's/.*value: *"\([^"]*\)".*/\1/')
echo "  Checking warehouse $WAREHOUSE_ID..."

databricks warehouses get "$WAREHOUSE_ID" -p "$PROFILE" > /dev/null 2>&1 || {
  echo "  ERROR: Warehouse $WAREHOUSE_ID not found in $TARGET workspace"
  exit 1
}

# 2.2 Verify OBO scopes are configured
echo "  Checking OBO configuration..."
if grep -q "user_api_scopes" app.yaml; then
  echo "  WARNING: user_api_scopes in app.yaml alone won't work!"
  echo "  Remember to run: databricks apps update <name> --json '{\"user_api_scopes\": [\"sql\"]}'"
fi

# 2.3 Check for hardcoded values that should be workspace-specific
echo "  Checking for hardcoded values..."
if grep -q "localhost" app.yaml; then
  echo "  WARNING: Found 'localhost' in app.yaml"
fi

echo "  Configuration safety PASSED"
```

### Phase 3: Deployment Execution

```bash
# 3.1 Deploy the bundle
echo "==> Phase 3: Deployment"
databricks bundle deploy -t "$TARGET" || {
  echo "  ERROR: Bundle deployment failed"
  exit 1
}

# 3.2 Enable OBO (CRITICAL - app.yaml alone doesn't work!)
APP_NAME=$(grep "name:" databricks.yml | head -1 | awk '{print $2}')
echo "  Enabling OBO for $APP_NAME..."
databricks apps update "$APP_NAME" --json '{"user_api_scopes": ["sql"]}' -p "$PROFILE" || {
  echo "  WARNING: Could not enable OBO - may need manual intervention"
}

# 3.3 Wait for app to be ready
echo "  Waiting for app to start..."
for i in {1..30}; do
  STATUS=$(databricks apps get "$APP_NAME" -p "$PROFILE" | jq -r '.status.state')
  if [ "$STATUS" = "RUNNING" ]; then
    break
  fi
  echo "  Status: $STATUS (waiting...)"
  sleep 10
done

echo "  Deployment COMPLETE"
```

### Phase 4: Post-Deployment Validation

Validate the deployed app is working:

```bash
# 4.1 Get app URL
echo "==> Phase 4: Post-deployment validation"
APP_URL=$(databricks apps get "$APP_NAME" -p "$PROFILE" | jq -r '.url')
echo "  App URL: $APP_URL"

# 4.2 Health check
echo "  Running health check..."
HEALTH=$(curl -sf "$APP_URL/api/health" 2>/dev/null) || {
  echo "  ERROR: Health endpoint not responding"
  echo "  Check logs: databricks apps logs $APP_NAME -p $PROFILE"
  exit 1
}

STATUS=$(echo "$HEALTH" | jq -r '.status')
if [ "$STATUS" != "healthy" ]; then
  echo "  WARNING: App status is $STATUS"
  echo "  Health details: $HEALTH"
fi

# 4.3 OBO validation (requires authenticated request)
echo "  Checking OBO authentication..."
OBO_STATUS=$(echo "$HEALTH" | jq -r '.checks.obo_auth.status // "unknown"')
if [ "$OBO_STATUS" = "not_configured" ]; then
  echo "  WARNING: OBO not enabled - system table queries may fail"
fi

# 4.4 Data validation (smoke test)
echo "  Running smoke test..."
curl -sf "$APP_URL/api/me" > /dev/null || {
  echo "  WARNING: /api/me endpoint failed"
}

echo ""
echo "==> Deployment validation COMPLETE"
echo "  App URL: $APP_URL"
echo "  Health:  $STATUS"
echo "  Logs:    $APP_URL/logz"
```

### Complete Deploy Script Example

```bash
#!/bin/bash
# deploy.sh - Full deployment with validation
set -e

TARGET="${1:-dev}"

# Map target to profile
case "$TARGET" in
  e2)   PROFILE="DEFAULT" ;;
  prod) PROFILE="DEMO WEST" ;;
  dev)  PROFILE="LPT_FREE_EDITION" ;;
  *)    PROFILE="DEFAULT" ;;
esac

export TARGET PROFILE APP_NAME="job_monitor"

echo "Deploying to $TARGET using profile $PROFILE"
echo "============================================"

# Phase 1: Pre-flight
./scripts/validate-preflight.sh

# Phase 2: Config safety
./scripts/validate-config.sh

# Phase 3: Deploy
./scripts/deploy-bundle.sh

# Phase 4: Post-deploy validation
./scripts/validate-deployed.sh

echo ""
echo "SUCCESS: Deployment to $TARGET complete!"
```

### Validation Checklist

Use this checklist before and after each deployment:

**Pre-Deployment**
- [ ] Frontend built (`npm run build`)
- [ ] Type checks pass (`npm run typecheck`)
- [ ] `__dist__/` not in `.gitignore`
- [ ] `DATABRICKS_HOST` set in app.yaml
- [ ] Warehouse ID valid for target workspace
- [ ] No hardcoded localhost/dev values

**Post-Deployment**
- [ ] Health endpoint returns 200
- [ ] Health status is "healthy"
- [ ] OBO authentication working (check `gap-auth` header)
- [ ] SQL queries return data (not 500 errors)
- [ ] Version number updated in UI
- [ ] Logs show no errors (`/logz` endpoint)

### Multi-Workspace Deployment Matrix

For apps deployed to multiple workspaces, maintain a deployment matrix:

| Target | Profile | Warehouse ID | Last Deploy | Health |
|--------|---------|--------------|-------------|--------|
| e2 | DEFAULT | 06c1adfd3dbdacde | 2026-02-27 | |
| prod | DEMO WEST | 75fd8278393d07eb | 2026-02-26 | |
| dev | LPT_FREE | 58d41113cb262dce | 2026-02-25 | |

**Monitor all deployments:**
```bash
for target in e2 prod dev; do
  ./deploy.sh $target --validate-only
done
```

---

## Troubleshooting Deployed Apps

| Issue | Solution |
|-------|----------|
| UI not updating | Did you run `npm run build`? Check `__dist__` exists |
| `__dist__` not deploying | Remove from `.gitignore` |
| API returns 404 | Check DATABRICKS_HOST is set in app.yaml |
| Permission denied | Add Service Principal to admins group |
| Cluster API fails | Use SP auth, not OBO for cluster management |
| Workspace links broken | Use hash-based routing (`/#setting/...`) |
| SDK AttributeError | Use `getattr(obj, 'attr', None)` |
| System tables 500 error | OBO not enabled - run `databricks apps update --json '{"user_api_scopes": ["sql"]}'` |
| SQL returns 0 rows | `workspace_id` is BIGINT - don't quote in SQL |
| Health degraded | Check `/api/health` response for specific failing check |
