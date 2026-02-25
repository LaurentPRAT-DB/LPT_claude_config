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
