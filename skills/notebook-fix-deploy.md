# Skill: Notebook Fix and Deployment Workflow

**Author:** laurent.prat
**Version:** 1.0.0
**Created:** 2026-01-29
**Purpose:** Standard workflow for fixing Databricks notebooks with proper versioning and deployment

---

## When to Use This Skill

Use this skill when you need to:
- Fix bugs or errors in Databricks notebooks
- Update notebook code with proper versioning
- Deploy notebook changes to Databricks workspace
- Follow a complete fix-to-deployment workflow

Invoke with: `/notebook-fix-deploy` or when asked to "fix notebook and deploy"

---

## Prerequisites Check

Before starting, verify:
- [ ] Git repository initialized and connected to remote
- [ ] Databricks Asset Bundle configured (databricks.yml exists)
- [ ] Databricks CLI authenticated with profile
- [ ] Access to Databricks workspace

---

## Workflow Steps

### 1. IDENTIFY THE ISSUE

**Actions:**
1. Review error messages from notebook execution
2. Check user reports or validation test results
3. Locate the affected file using glob/grep
4. Read the file to understand the context

**Example patterns to look for:**
```
- SQL parameter markers: $ in queries
- Type conversion errors: Decimal to float
- Invalid API calls: wrong method names
- Undefined variables: scope issues
```

---

### 2. ANALYZE ROOT CAUSE

**Actions:**
1. Use grep to search for problematic patterns
2. Read relevant code sections
3. Review related documentation
4. Identify the exact line(s) causing the issue

**Common Issues:**
- `\$[0-9]` - SQL parameter markers in queries
- `decimal.Decimal` - Type conversion errors
- `dbutils.jobs.list()` - Invalid API calls
- Variable scope issues

---

### 3. FIX THE ISSUE

**Actions:**
1. Use Edit tool with exact string replacements
2. Make minimal, targeted changes
3. Fix one issue at a time for clarity
4. Preserve existing logic and structure

**Example fixes:**
```python
# SQL parameter markers
CONCAT('$', FORMAT_NUMBER(...)) → CONCAT('USD ', FORMAT_NUMBER(...))

# Decimal type conversion
range=[0, contract_value * 1.1] → range=[0, float(contract_value) * 1.1]

# Invalid API call
dbutils.jobs.list() → WorkspaceClient().jobs.list()
```

---

### 4. UPDATE VERSION NUMBERS ⚠️ CRITICAL

**Every fix MUST increment the version!**

**Version Format:**
- Major.Minor.Patch (e.g., 1.5.3)
- Build: YYYY-MM-DD-NNN (e.g., 2026-01-29-013)

**What to Increment:**
- **Patch**: Bug fixes, minor corrections (e.g., 1.5.2 → 1.5.3)
- **Minor**: New features, significant changes (e.g., 1.5.0 → 1.6.0)
- **Major**: Breaking changes, major refactors (e.g., 1.5.0 → 2.0.0)

**Files to Update (2 places in notebook):**
1. Markdown header: `# MAGIC **Version:** X.Y.Z (Build: YYYY-MM-DD-NNN)`
2. Python constants: `VERSION = "X.Y.Z"\nBUILD = "YYYY-MM-DD-NNN"`

**Verification:**
```bash
grep "Version:" notebooks/*.py
grep "VERSION = " notebooks/*.py
```

---

### 5. GIT OPERATIONS

**Standard Commit Flow:**

```bash
# Stage the changed file
git add notebooks/<notebook_name>.py

# Create descriptive commit message
git commit -m "$(cat <<'EOF'
[Short summary line - imperative mood, 50 chars max]

- [Change 1]
- [Change 2]
- [Change 3]
- Fixes: [Error message or issue description]
- Version bumped to [X.Y.Z] (Build: [YYYY-MM-DD-NNN])

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
EOF
)"

# Push to remote
git push
```

**Commit Message Best Practices:**
- Use imperative mood ("Fix" not "Fixed")
- Be specific about what changed
- Include the error message being fixed
- Always mention version bump
- Keep first line under 50 characters

---

### 6. DEPLOY TO DATABRICKS ⚠️ MANDATORY STEP

**⚠️ WARNING: This step is MANDATORY and must NOT be skipped!**

Without deployment, changes exist only in GitHub and are NOT visible in the Databricks workspace.

**Deploy using Databricks Asset Bundle:**

```bash
# Deploy to development environment (default)
databricks bundle deploy -t dev

# Or just (dev is default)
databricks bundle deploy

# For production
databricks bundle deploy -t prod

# Verify deployment
databricks bundle validate
```

**What Happens During Deployment:**
1. Files synced to workspace: `/Workspace/Users/{user}/account_monitor/files/`
2. Notebooks uploaded to workspace (visible in UI)
3. Jobs updated with new definitions
4. Deployment state recorded
5. All resources validated

**Expected Output:**
```
Uploading bundle files to /Workspace/Users/...
Deploying resources...
Updating deployment state...
Deployment complete!
```

**Verify Notebooks Are Deployed:**
```bash
databricks workspace list /Workspace/Users/$(databricks current-user me --output json | jq -r .userName)/account_monitor/files/notebooks/
```

**Common Mistake:**
- ❌ Running `git push` and stopping - notebooks NOT updated in workspace
- ✅ Running `git push` AND `databricks bundle deploy` - notebooks updated everywhere

---

### 7. VERIFY AND DOCUMENT

**Actions:**
1. Verify version number updated in both places
2. Check deployment output for errors
3. Verify notebooks appear in workspace
4. Notify user of fix and new version
5. Document recurring issues

---

## Complete Workflow Checklist

Use this checklist for EVERY notebook fix:

- [ ] Issue identified and understood
- [ ] Root cause analyzed
- [ ] Fix applied and tested locally (if possible)
- [ ] Version number incremented (both places)
- [ ] Build number incremented
- [ ] Changes staged with `git add`
- [ ] Descriptive commit message written
- [ ] Commit includes version bump note
- [ ] Changes pushed to remote (`git push`)
- [ ] **⚠️ Bundle deployed to Databricks (`databricks bundle deploy -t dev`) - MANDATORY**
- [ ] **⚠️ Deployment confirmed successful (check output)**
- [ ] **⚠️ Notebooks verified in workspace (list notebooks or open in UI)**
- [ ] User notified of fix and new version
- [ ] Issue documented (if recurring)

**STOP: Do not mark this workflow complete without deploying to Databricks!**

---

## Troubleshooting

### Git push rejected
```bash
git pull --rebase
git push
```

### Merge conflicts
```bash
git status
# Edit conflicted files
git add <resolved-files>
git rebase --continue
git push
```

### Deployment fails
```bash
# Validate bundle configuration
databricks bundle validate

# Check for syntax errors
python -m py_compile notebooks/<notebook_name>.py

# Check profile authentication
databricks auth profiles
```

### Version not updating in workspace
```bash
# Force sync
databricks bundle deploy --force-all

# Verify file timestamp
databricks workspace get /Users/{user}/account_monitor/files/notebooks/<notebook_name>.py
```

---

## Key Principles

1. **Always increment version** - Every fix gets a new version
2. **Descriptive commits** - Future you will thank present you
3. **Test before deploy** - Validate changes when possible
4. **One fix per commit** - Easier to track and revert
5. **Push frequently** - Don't lose work
6. **Validate deployment** - Check workspace after deploy
7. **Document breaking changes** - Update README/CHANGELOG

---

## Skill Invocation

When this skill is invoked, Claude should:

1. **Acknowledge** the workflow and confirm prerequisites
2. **Guide through each step** systematically
3. **Verify version updates** in both locations
4. **Execute git operations** with proper commit messages
5. **Deploy to Databricks** and confirm success
6. **Verify deployment** by checking workspace
7. **Provide summary** with new version number

---

## Related Files

- `databricks.yml` - Asset bundle configuration
- `notebooks/` - All notebook files
- `.git/config` - Git remote configuration
- `~/.databrickscfg` - Databricks CLI profiles

---

**End of Skill**
