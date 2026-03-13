# generate-user-guide

Generate comprehensive user guide documentation for applications with screenshots.

## Trigger
- User asks to create/update user guide documentation
- User asks to document application pages/widgets
- User wants to create contextual help documentation

## Process

### Phase 1: Preparation
1. Review existing documentation (README.md, docs/)
2. Identify all pages/routes in the application
3. List all major components/widgets
4. Create progress tracking document in memory
5. Create screenshots directory

### Phase 2: Application Exploration
1. Start the application (dev server or deployed URL)
2. Use Chrome MCP tools to take screenshots
3. Visit each page systematically
4. Wait for data to fully load before capturing
5. Document each state: loading, empty, error, populated

### Phase 3: Documentation Per Page
For each page, document:
1. **Introduction** - Purpose and target users
2. **Navigation** - How to access the page
3. **Widgets** - For each widget:
   - Widget name and location
   - Purpose/functionality
   - States (loading, error, empty, populated)
   - Data source (API endpoint)
   - Update frequency (cache settings)
   - User interactions
4. **Common Workflows** - Step-by-step scenarios
5. **Screenshots** - Annotated images

### Phase 4: Cross-Cutting Concerns
Document:
- Global filters and how they affect pages
- Navigation patterns
- Error handling
- Performance considerations

### Phase 5: Output Generation
1. Write main USER_GUIDE.md with all sections
2. Include table of contents with anchor links
3. Reference screenshots with relative paths
4. Add mermaid diagrams for workflows

## Screenshot Conventions
- Save to `docs/screenshots/`
- Naming: `{page}.png` for main screenshots
- Naming: `{page}-annotated.png` for annotated versions
- Naming: `empty-state-{page}.png` for empty states
- Naming: `loading-state-{page}.png` for loading states

## Chrome MCP Screenshot Workflow

### Basic Screenshot
```
1. navigate_page(url) - Navigate to application
2. wait_for(["Expected Text"]) - Wait for data to load
3. resize_page(1400, 900) - Set consistent dimensions
4. take_screenshot(filePath, format="png")
```

### Waiting for Lazy-Loaded Data
Some data loads asynchronously from APIs. Wait for specific indicators:
- Wait for "Load More" buttons to appear
- Wait for table row counts
- Wait for specific data values (not just UI elements)
- Use multiple wait_for attempts with increasing timeouts

**Common issue**: Sparkline/recent-runs data may show empty circles if:
- Data hasn't loaded yet from system tables
- Job has no historical run data
- System table latency (5-15 minutes)

### Creating Annotated Screenshots
1. Create temp HTML file with screenshot + CSS overlays:
```html
<div class="container" style="position: relative;">
  <img src="screenshot.png" />
  <div class="callout" style="position: absolute; top: 100px; left: 200px;">1</div>
</div>
<div class="legend">
  <span class="num">1</span> Description of element
</div>
```
2. Navigate Chrome to `file:///path/to/annotated.html`
3. Take fullPage screenshot: `take_screenshot(fullPage=true)`
4. Delete temp HTML file after capture

## Output Structure
```
docs/
├── USER_GUIDE.md              # Main guide (700+ lines)
└── screenshots/
    ├── dashboard.png          # Main page screenshots
    ├── running-jobs.png
    ├── job-health.png
    ├── alerts.png
    ├── historical.png
    ├── dashboard-annotated.png    # Annotated versions with callouts
    ├── running-jobs-annotated.png
    ├── job-health-annotated.png
    ├── alerts-annotated.png
    ├── empty-state-*.png      # Empty/filtered state screenshots
    └── loading-state-*.png    # Loading state screenshots
```

## USER_GUIDE.md Structure
1. Table of Contents with anchor links
2. Introduction (purpose, audience, benefits)
3. Getting Started (navigation, layout)
4. Per-page sections with:
   - Screenshot with collapsible annotated version
   - Widget descriptions
   - Data sources and update frequencies
5. Cross-cutting (filters, presets, performance)
6. Troubleshooting
7. Visual Reference appendix

## Dependencies
- Chrome MCP server for screenshots (`chrome-devtools` tools)
- Running/deployed application instance
- Read access to source code for API details
