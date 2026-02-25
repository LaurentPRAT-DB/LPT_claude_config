# Databricks Notebook Fix Skill

You are an expert at fixing Databricks notebooks with proper versioning and deployment workflow.

## Your Task

When the user asks you to fix a Databricks notebook, follow this complete workflow:

## Step 1: Identify and Analyze the Issue

1. Read the notebook file to understand the problem
2. Use Grep to search for problematic patterns:
   - SQL parameter markers: `\$[0-9]` or `\$` in SQL queries
   - Decimal type issues: `pd.Timedelta.*days=` or multiplication with Decimals
   - Invalid API calls: `dbutils.jobs.list` or other invalid methods
   - Field name errors: Check against system table schemas

## Step 2: Fix the Code

Apply targeted fixes based on the issue type:

### SQL Parameter Markers
```python
# Before
CONCAT('$', FORMAT_NUMBER(amount, 2))
-- Comment with $3,000

# After
CONCAT('USD ', FORMAT_NUMBER(amount, 2))
-- Comment with USD 3,000
```

### Decimal Type Conversion
```python
# Before
range=[0, contract_value * 1.1]
pd.Timedelta(days=days_to_burndown)
burndown_pct = (max_cumulative / contract_value * 100)

# After
range=[0, float(contract_value) * 1.1]
pd.Timedelta(days=float(days_to_burndown))
burndown_pct = (float(max_cumulative) / float(contract_value) * 100)
```

### Invalid API Calls
```python
# Before
dbutils.jobs.list()

# After
from databricks.sdk import WorkspaceClient
w = WorkspaceClient()
list(w.jobs.list())
```

### System Table Field Names
```python
# Before
u.cloud_provider  # Wrong
lp.pricing.default_price_per_unit  # Wrong

# After
u.cloud  # Correct
lp.pricing.default  # Correct
```

## Step 3: Update Version Numbers

**CRITICAL:** Always update BOTH locations:

1. **Markdown header:**
```python
# MAGIC **Version:** X.Y.Z (Build: YYYY-MM-DD-NNN)
```

2. **Python constants:**
```python
VERSION = "X.Y.Z"
BUILD = "YYYY-MM-DD-NNN"
```

**Version Increment Rules:**
- **Patch (X.Y.Z+1):** Bug fixes, type conversions, field name corrections
- **Minor (X.Y+1.0):** New features, new visualizations, new queries
- **Major (X+1.0.0):** Breaking changes, major refactors

**Build Number Rules:**
- Format: `YYYY-MM-DD-NNN`
- Same day as previous build: increment NNN (012 → 013)
- New day: reset to 001

## Step 4: Git Operations

Create a properly formatted commit:

```bash
git add <notebook_file>

git commit -m "$(cat <<'EOF'
<Short summary - imperative mood - under 50 chars>

- <Specific change 1>
- <Specific change 2>
- <Specific change 3>
- Fixes: <Error message or issue description>
- Version bumped to X.Y.Z (Build: YYYY-MM-DD-NNN)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
EOF
)"

git push
```

**Commit Message Requirements:**
- First line: Imperative mood, under 50 characters
- Body: Bullet points describing changes
- Include: "Fixes:" line with error message
- Always mention: "Version bumped to..."
- Always include: Co-Authored-By line

## Step 5: Deploy to Databricks

```bash
databricks bundle deploy
```

Verify deployment success.

## Step 6: Summary and Verification

Provide the user with:
1. Summary of changes made
2. New version number
3. Location in workspace
4. Verification steps:
   - Run affected cell to confirm fix
   - Check version number displays correctly
   - Verify no new errors

## Common Issues Reference

### SQL Parameter Markers
**Error:** `SQL query contains $ parameter. Migrate to the parameter marker syntax, :param:`
**Cause:** Databricks interprets `$` followed by number as parameter marker
**Fix:** Replace all `$` with `USD ` in CONCAT and SQL comments

### Decimal Type Errors
**Error:** `TypeError: unsupported operand type(s) for *: 'decimal.Decimal'`
**Cause:** Spark DataFrames return Decimal type, plotly/pandas require float
**Fix:** Wrap in `float()` before arithmetic or passing to plotly/pandas

### Field Not Found
**Error:** `[UNRESOLVED_COLUMN]` or `[FIELD_NOT_FOUND]`
**Cause:** Wrong field name or incorrect nested field path
**Fix:** Check system.billing.usage and system.billing.list_prices schemas
- Use `u.cloud` not `u.cloud_provider`
- Use `lp.pricing.default` not `lp.pricing.default_price_per_unit`

### Invalid API
**Error:** `AttributeError: module has no attribute`
**Cause:** Using non-existent dbutils methods
**Fix:** Use WorkspaceClient from databricks.sdk

## Files to Check

When fixing notebooks, be aware of related files:
- `notebooks/account_monitor_notebook.py` - Main analytics notebook
- `notebooks/post_deployment_validation.py` - Validation tests
- `notebooks/lakeview_dashboard_queries.sql` - Dashboard queries
- `sql/*.sql` - SQL scripts for jobs

## Verification Checklist

After deploying, confirm:
- [ ] Code fix applied correctly
- [ ] Version updated in both locations
- [ ] Commit message properly formatted
- [ ] Changes pushed to remote
- [ ] Bundle deployed successfully
- [ ] User informed of new version

## Output Format

Always provide:
1. **Issue identified:** Clear description
2. **Root cause:** Why the error occurred
3. **Fix applied:** Code changes made
4. **Version:** Old version → New version
5. **Deployed:** Confirmation with location
6. **Next steps:** How user can verify

## Example Output

```
Fixed the Decimal type conversion error in Cell 9.

**Issue:** Plotly's y-axis range calculation failed because contract_value is Decimal type from Spark DataFrame.

**Root Cause:** Plotly requires int/float, not Decimal objects.

**Fix Applied:**
- Converted contract_value to float in y-axis range
- Converted commitment to float when extracting from DataFrame
- Converted all Decimal values in percentage calculations

**Deployed:**
- Version: 1.5.2 → 1.5.3 (Build: 2026-01-29-013)
- Location: /Workspace/Users/{user}/account_monitor/files/notebooks/account_monitor_notebook.py
- Git: Committed and pushed to GitHub

Cell 9 should now render the Contract Burndown Chart without errors.
```

## Important Notes

- **Always** increment version on every fix
- **Always** update version in two places
- **Always** include version bump in commit message
- **Never** skip git push before deployment
- **Never** use placeholder values in commits
- **Always** verify deployment completed successfully

## Automation Available

If a script exists at `scripts/notebook_fix.sh`, you can use it:
```bash
./scripts/notebook_fix.sh <notebook_file> "<commit_message>"
```

This automates steps 3-5 (versioning, git, deployment).

---

**End of Skill**

When invoked, execute this complete workflow without asking the user for confirmation at each step, unless there's ambiguity about what needs to be fixed.
