# Automated Testing with MCP Servers

This guide covers automated UI testing for Databricks APX apps using the Chrome DevTools MCP server and Puppeteer.

## Overview

Leverage available MCP servers for comprehensive automated testing:
- **Chrome DevTools MCP** - Browser automation, screenshots, console monitoring
- **APX MCP** - Dev server status, type checking, log monitoring

## Prerequisites

Ensure MCP servers are configured in `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["chrome-devtools-mcp@latest", "--userDataDir=~/.vibe/chrome/profile"]
    }
  }
}
```

## Testing Workflow

### Phase 1: Start Dev Servers

```bash
# Start APX development server
mcp__apx__start

# Verify servers are running
mcp__apx__status
```

### Phase 2: Launch Browser for Testing

Use Chrome DevTools MCP to open the app:

```bash
# Navigate to app URL
mcp__chrome-devtools__puppeteer_navigate --url "http://localhost:5173"

# Take initial screenshot
mcp__chrome-devtools__puppeteer_screenshot
```

### Phase 3: Automated UI Tests

#### Test Navigation

```bash
# Click on navigation items
mcp__chrome-devtools__puppeteer_click --selector "[data-testid='nav-dashboard']"
mcp__chrome-devtools__puppeteer_screenshot

# Verify page loaded
mcp__chrome-devtools__puppeteer_evaluate --script "document.querySelector('h1')?.textContent"
```

#### Test Data Display

```bash
# Wait for data to load
mcp__chrome-devtools__puppeteer_evaluate --script "document.querySelectorAll('table tbody tr').length"

# Check for loading states
mcp__chrome-devtools__puppeteer_evaluate --script "document.querySelector('.skeleton') !== null"
```

#### Test Interactive Elements

```bash
# Click buttons
mcp__chrome-devtools__puppeteer_click --selector "button[data-action='refresh']"

# Fill forms
mcp__chrome-devtools__puppeteer_fill --selector "input[name='search']" --value "test query"

# Submit forms
mcp__chrome-devtools__puppeteer_click --selector "button[type='submit']"
```

#### Check Console Errors

```bash
# Get console logs (errors will be highlighted)
mcp__chrome-devtools__puppeteer_console_logs

# Evaluate for errors in app state
mcp__chrome-devtools__puppeteer_evaluate --script "window.__APP_ERRORS__ || []"
```

### Phase 4: Visual Regression Testing

```bash
# Take screenshots at key states
mcp__chrome-devtools__puppeteer_screenshot --name "dashboard-loaded"
mcp__chrome-devtools__puppeteer_screenshot --name "detail-view"
mcp__chrome-devtools__puppeteer_screenshot --name "error-state"
```

### Phase 5: API Response Verification

```bash
# Test API endpoints directly
curl http://localhost:8000/api/health | jq .
curl http://localhost:8000/api/entities | jq '.[] | {id, name, status}'

# Verify OpenAPI schema
curl http://localhost:8000/openapi.json | jq '.paths | keys'
```

## Test Checklist

### Functional Tests
- [ ] All navigation links work
- [ ] Data loads and displays correctly
- [ ] Forms submit successfully
- [ ] Error states display properly
- [ ] Loading skeletons appear during fetches

### Visual Tests
- [ ] Layout renders correctly
- [ ] Dark mode works (if applicable)
- [ ] Responsive design at different widths
- [ ] No visual regressions from screenshots

### Performance Tests
- [ ] Initial page load < 3s
- [ ] API responses < 500ms
- [ ] No memory leaks in console
- [ ] No excessive re-renders

### Console Checks
- [ ] No JavaScript errors
- [ ] No failed network requests
- [ ] No React warnings
- [ ] No TypeScript runtime errors

## Automated Test Script

Create a test script that runs all checks:

```bash
#!/bin/bash
# scripts/test-ui.sh

set -e

echo "==> Starting UI tests..."

# 1. Check dev servers
echo "==> Checking dev servers..."
curl -s http://localhost:8000/api/health > /dev/null || { echo "Backend not running"; exit 1; }
curl -s http://localhost:5173 > /dev/null || { echo "Frontend not running"; exit 1; }

# 2. Run type checks
echo "==> Running type checks..."
mcp__apx__dev_check

# 3. Test API endpoints
echo "==> Testing API endpoints..."
curl -s http://localhost:8000/api/health | jq -e '.status == "ok"' > /dev/null

# 4. Browser tests via MCP (if available)
echo "==> Running browser tests..."
# These would be invoked via Claude with Chrome DevTools MCP

echo "==> All tests passed!"
```

## Testing Deployed Apps

For testing apps deployed to Databricks:

### 1. Navigate to Deployed App

```bash
# Get app URL
APP_URL=$(databricks apps get <app-name> -p <profile> | jq -r '.url')

# Open in browser via MCP
mcp__chrome-devtools__puppeteer_navigate --url "$APP_URL"
```

### 2. Handle OAuth Login

```bash
# Screenshot the login page
mcp__chrome-devtools__puppeteer_screenshot --name "oauth-login"

# After manual login, continue testing
mcp__chrome-devtools__puppeteer_screenshot --name "authenticated-dashboard"
```

### 3. Check Deployed Logs

```bash
# Via APX MCP
mcp__apx__check_deployed_logs --app_name "<app-name>" --profile "<profile>"

# Or via CLI
databricks apps logs <app-name> -p <profile> | tail -50
```

## Integration with Deploy Script

Add testing to your deploy script:

```bash
#!/bin/bash
# scripts/deploy.sh

set -e

TARGET="${1:-e2}"

echo "==> Rebuilding frontend..."
cd job_monitor/ui && npm run build && cd ../..

echo "==> Running pre-deploy tests..."
# Type check
cd job_monitor/ui && npm run typecheck && cd ../..

echo "==> Deploying..."
databricks bundle deploy -t "$TARGET"
databricks bundle run <app-name> -t "$TARGET"

echo "==> Running post-deploy smoke tests..."
APP_URL=$(databricks apps get <app-name> -p <profile> | jq -r '.url')
curl -s "$APP_URL/api/health" | jq -e '.status == "ok"'

echo "==> Deployment and tests complete!"
```

## Common Test Patterns

### Wait for Element

```bash
mcp__chrome-devtools__puppeteer_evaluate --script "
  new Promise(resolve => {
    const check = () => {
      if (document.querySelector('.data-loaded')) resolve(true);
      else setTimeout(check, 100);
    };
    check();
  })
"
```

### Check Table Row Count

```bash
mcp__chrome-devtools__puppeteer_evaluate --script "
  document.querySelectorAll('table tbody tr').length
"
```

### Verify No Console Errors

```bash
mcp__chrome-devtools__puppeteer_evaluate --script "
  window.__consoleErrors?.length === 0
"
```

### Test Dark Mode Toggle

```bash
# Click dark mode toggle
mcp__chrome-devtools__puppeteer_click --selector "[data-testid='theme-toggle']"

# Verify class applied
mcp__chrome-devtools__puppeteer_evaluate --script "
  document.documentElement.classList.contains('dark')
"

# Screenshot dark mode
mcp__chrome-devtools__puppeteer_screenshot --name "dark-mode"
```

## Troubleshooting

### Browser Not Responding
- Restart Chrome DevTools MCP server
- Check if browser window is visible
- Verify no modal dialogs blocking

### Tests Timing Out
- Increase wait times for slow networks
- Check if API is responding
- Verify no auth issues

### Screenshots Not Capturing
- Ensure page is fully loaded
- Wait for animations to complete
- Check viewport size settings
