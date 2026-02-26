---
name: databricks-app-apx
description: "Build full-stack Databricks applications using APX framework (FastAPI + React)."
---

# Databricks APX Application

Build full-stack Databricks applications using APX framework (FastAPI + React).

## Trigger Conditions

**Invoke when user requests**:
- "Databricks app" or "Databricks application"
- "Build me an app that does X" (where X is a Databricks use case)
- Full-stack app for Databricks without specifying framework
- Mentions APX framework

**Do NOT invoke if user specifies**: Streamlit, Dash, Node.js, Shiny, Gradio, Flask, or other frameworks.

## Step 0: Gather Project Requirements

**Before initializing, ask the user:**

1. **Project Name**: "What would you like to name this app?" (e.g., `cluster-manager`, `data-explorer`)
   - Use kebab-case for directory/bundle name
   - Use snake_case for Python package name

2. **Target Workspace**: "Which Databricks workspace will this deploy to?"
   - Need the workspace URL for `app.yaml` DATABRICKS_HOST

3. **Core Features**: Confirm understanding of the app's purpose
   - What data/resources will it manage?
   - What actions should users be able to take?

## Prerequisites Check

Option A)
Repository configured for use with APX.
1.. Verify APX MCP available: `mcp-cli tools | grep apx`
2. Verify shadcn MCP available: `mcp-cli tools | grep shadcn`
3. Confirm APX project (check `pyproject.toml`)

Option B)
Install APX
1. Verify uv available or prompt for install. On Mac, suggest: `brew install uv`.
2. Verify bun available or prompt for install. On Mac, suggest: 
```
brew tap oven-sh/bun
brew install bun
```
3. Verify git available or prompt for install.
4. Run APX setup commands:
```
uvx --from git+https://github.com/databricks-solutions/apx.git apx init
```


## Workflow Overview

Total time: 55-70 minutes

1. **Initialize** (5 min) - Start servers, create todos
2. **Backend** (15-20 min) - Models + routes with mock data
3. **Frontend** (20-25 min) - Components + pages
4. **Test** (5-10 min) - Type check + manual verification
5. **Document** (10 min) - README + code structure guide

## Phase 1: Initialize

```bash
# Start APX development server
mcp-cli call apx/start '{}'
mcp-cli call apx/status '{}'
```

Create TodoWrite with tasks:
- Start servers ✓
- Design models
- Create API routes
- Add UI components
- Create pages
- Test & document

## Phase 2: Backend Development

### Create Pydantic Models

In `src/{app_name}/backend/models.py`:

**Follow 3-model pattern**:
- `EntityIn` - Input validation
- `EntityOut` - Complete output with computed fields
- `EntityListOut` - Performance-optimized summary

**See [backend-patterns.md](backend-patterns.md) for complete code templates.**

### Create API Routes

In `src/{app_name}/backend/router.py`:

**Critical requirements**:
- Always include `response_model` (enables OpenAPI generation)
- Always include `operation_id` (becomes frontend hook name)
- Use naming pattern: `listX`, `getX`, `createX`, `updateX`, `deleteX`
- Initialize 3-4 mock data samples for testing

**See [backend-patterns.md](backend-patterns.md) for complete CRUD templates.**

### Type Check

```bash
mcp-cli call apx/dev_check '{}'
```

Fix any Python type errors reported by basedpyright.

## Phase 3: Frontend Development

**Wait 5-10 seconds** after backend changes for OpenAPI client regeneration.

### Add UI Components

```bash
# Get shadcn add command
mcp-cli call shadcn/get_add_command_for_items '{
  "items": ["@shadcn/button", "@shadcn/card", "@shadcn/table",
            "@shadcn/badge", "@shadcn/select", "@shadcn/skeleton"]
}'
```

Run the command from project root with `--yes` flag.

### Create Pages

**List page**: `src/{app_name}/ui/routes/_sidebar/{entity}.tsx`
- Table view with all entities
- Suspense boundaries with skeleton fallback
- Formatted data (currency, dates, status colors)

**Detail page**: `src/{app_name}/ui/routes/_sidebar/{entity}.$id.tsx`
- Complete entity view with cards
- Update/delete mutations
- Back navigation

**See [frontend-patterns.md](frontend-patterns.md) for complete page templates.**

### Update Navigation

In `src/{app_name}/ui/routes/_sidebar/route.tsx`, add new item to `navItems` array.

## Phase 4: Testing

### Automated Testing with MCP Servers

Use Chrome DevTools MCP for automated UI testing:

```bash
# Type check both backend and frontend
mcp__apx__dev_check

# Navigate browser to app
mcp__chrome-devtools__puppeteer_navigate --url "http://localhost:5173"

# Take screenshot for visual verification
mcp__chrome-devtools__puppeteer_screenshot

# Check for console errors
mcp__chrome-devtools__puppeteer_console_logs

# Test navigation clicks
mcp__chrome-devtools__puppeteer_click --selector "[data-testid='nav-item']"

# Verify data loaded
mcp__chrome-devtools__puppeteer_evaluate --script "document.querySelectorAll('table tbody tr').length"
```

### API Testing

```bash
# Test API endpoints
curl http://localhost:8000/api/{entities} | jq .
curl http://localhost:8000/api/{entities}/{id} | jq .

# Get frontend URL
mcp__apx__get_frontend_url
```

### Test Checklist
- [ ] Type checking passes (`apx dev check`)
- [ ] API endpoints return correct data
- [ ] UI renders without console errors
- [ ] Navigation works (click tests)
- [ ] Data displays correctly (evaluate tests)
- [ ] Loading states work (skeletons)
- [ ] Screenshots captured for visual verification

**See [automated-testing.md](automated-testing.md)** for complete testing patterns with Puppeteer and MCP servers.

## Phase 5: Deployment & Monitoring

### Deploy to Databricks

**CRITICAL**: Build frontend before deploying!

```bash
# 1. Build frontend (REQUIRED!)
cd {app_name}/ui
npm run build
cd ../..

# 2. Deploy via DABs
databricks bundle deploy -t dev

# 3. Restart app to pick up changes
databricks apps stop {app-name}
databricks apps start {app-name}
```

**See [databricks-deployment.md](databricks-deployment.md)** for:
- app.yaml configuration (DATABRICKS_HOST is required!)
- Service Principal authentication setup
- Common deployment gotchas and solutions

### Monitor Application Logs

**Automated log checking with APX MCP:**

The APX MCP server can automatically check deployed application logs. Simply ask:
"Please check the deployed app logs for <app-name>"


The APX MCP will retrieve logs and identify issues automatically, including:
- Deployment status and errors
- Runtime exceptions and stack traces
- Both `[SYSTEM]` (deployment) and `[APP]` (application) logs
- Browser console errors (now included in APX dev logs)

**Manual log checking (reference):**

For direct CLI access:
```bash
databricks apps logs <app-name> --profile <profile-name>
```

**Key patterns to look for:**
- ✅ `Deployment successful` - App deployed correctly
- ✅ `App started successfully` - Application is running
- ❌ `Error:` - Check stack traces for issues

## Phase 6: Documentation

Create two markdown files:

**README.md**:
- Features overview
- Technology stack
- How app was created (AI tools + MCP servers used)
- Application architecture
- Getting started instructions
- API documentation
- Development workflow

**CODE_STRUCTURE.md**:
- Directory structure explanation
- Backend structure (models, routes, patterns)
- Frontend structure (routes, components, hooks)
- Auto-generated files warnings
- Guide for adding new features
- Best practices
- Common patterns
- Troubleshooting guide

## Key Patterns

### Backend
- **3-model pattern**: Separate In, Out, and ListOut models
- **operation_id naming**: `listEntities` → `useListEntities()`
- **Type hints everywhere**: Enable validation and IDE support

### Frontend
- **Suspense hooks**: `useXSuspense(selector())`
- **Suspense boundaries**: Always provide skeleton fallback
- **Formatters**: Currency, dates, status colors
- **Never edit**: `lib/api.ts` or `types/routeTree.gen.ts`

## Success Criteria

- [ ] Type checking passes (`apx dev check` succeeds)
- [ ] API endpoints return correct data (curl verification)
- [ ] Frontend displays and mutates data correctly
- [ ] Loading states work (skeletons display)
- [ ] Documentation complete

## Common Issues

**Deployed app not working**: Ask to check deployed app logs (APX MCP will automatically retrieve and analyze them) or manually use `databricks apps logs <app-name>`
**Python type errors**: Use explicit casting for dict access, check Optional fields
**TypeScript errors**: Wait for OpenAPI regen, verify hook names match operation_ids
**OpenAPI not updating**: Check watcher status with `apx dev status`, restart if needed
**Components not added**: Run shadcn from project root with `--yes` flag

## Phase 7: MCP Server Integration (Optional)

Transform your APX app into a **Databricks Managed MCP Server** to enable AI agents in the Databricks Playground to call your app's functionality.

### Why Add MCP?

- AI agents (Supervisor Agents) can call your API as tools
- Natural language interface to your app's functionality
- Registered in Unity Catalog for governance
- Works with Databricks AI Playground

### Quick Steps

1. **Create MCP Router**: Add `routers/mcp.py` with JSON-RPC 2.0 endpoint
2. **Define Tools**: Map your existing REST endpoints to MCP tools
3. **Register Router**: Add `mcp_router` to `app.py`
4. **Deploy**: Rebuild and deploy the app
5. **Create OAuth Secret**: `databricks api post /api/2.0/accounts/servicePrincipals/<SP_ID>/credentials/secrets`
6. **Create UC Connection**: SQL with `is_mcp_connection 'true'`
7. **Create Supervisor Agent**: Via AI Playground UI

**See [databricks-apx-mcp-server](../databricks-apx-mcp-server/SKILL.md)** for complete implementation guide with templates.

### Example Tool Definition

```python
MCP_TOOLS = [
    {
        "name": "list_items",
        "description": "List all items with status and metrics. Use to get overview or filter by status.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "status": {"type": "string", "enum": ["ACTIVE", "PENDING"]},
                "limit": {"type": "integer", "default": 100}
            }
        }
    }
]
```

---

## Reference Materials

- **[backend-patterns.md](backend-patterns.md)** - Complete backend code templates
- **[frontend-patterns.md](frontend-patterns.md)** - Complete frontend page templates
- **[best-practices.md](best-practices.md)** - Best practices, anti-patterns, debugging
- **[databricks-deployment.md](databricks-deployment.md)** - Databricks-specific deployment patterns, SDK gotchas, auth strategies
- **[automated-testing.md](automated-testing.md)** - Automated UI testing with Chrome DevTools MCP and Puppeteer

Read these files only when actively writing that type of code or debugging issues.

## Related Skills

- **[databricks-app-python](../databricks-app-python/SKILL.md)** - for Streamlit, Dash, Gradio, or Flask apps
- **[databricks-asset-bundles](../databricks-asset-bundles/SKILL.md)** - deploying APX apps via DABs
- **[databricks-python-sdk](../databricks-python-sdk/SKILL.md)** - backend SDK integration
- **[lakebase-provisioned](../lakebase-provisioned/SKILL.md)** - adding persistent PostgreSQL state to apps
- **[databricks-apx-mcp-server](../databricks-apx-mcp-server/SKILL.md)** - transform APX app into managed MCP server for AI Playground
