# Claude Code Custom Skills

Custom skills for Laurent Prat's development workflows.

## FE Vibe Setup

**New team member?** See [FE-VIBE-SETUP.md](FE-VIBE-SETUP.md) for installation instructions.

Quick install:
```bash
brew install gh && gh auth login --web --hostname github.com --git-protocol ssh --skip-ssh-key && gh release download latest --repo databricks-field-eng/vibe --pattern 'install_vibe.sh' -O - | zsh
```

## Available Skills

### 🔧 databricks-notebook-fix

**File:** `databricks-notebook-fix.md`

**Purpose:** Complete workflow for fixing Databricks notebooks with proper versioning, git operations, and deployment.

**When to Use:**
- Fixing errors in Databricks notebooks
- Applying code corrections with proper versioning
- Deploying notebook changes to workspace

**What It Does:**
1. Identifies and analyzes the issue
2. Applies targeted fixes
3. Updates version numbers (both locations)
4. Creates properly formatted git commit
5. Pushes to remote
6. Deploys to Databricks workspace
7. Provides summary and verification steps

**Invocation:**
```
Fix the [description of issue] in [notebook file]
```

**Example:**
```
Fix the SQL parameter error in notebooks/account_monitor_notebook.py
```

**Handles These Issues:**
- SQL parameter markers (`$` in queries)
- Decimal type conversion errors
- Invalid API calls (e.g., `dbutils.jobs.list()`)
- System table field name errors
- Missing imports

---

### 📋 notebook-fix-deploy

**File:** `notebook-fix-deploy.md`

**Purpose:** Comprehensive reference guide for the complete notebook fix and deployment workflow with detailed checklists and troubleshooting.

**When to Use:**
- Need detailed step-by-step guidance for notebook fixes
- Want comprehensive troubleshooting reference
- Learning the complete workflow process
- Need deployment verification procedures

**What It Provides:**
1. Detailed 7-step workflow with examples
2. Version numbering rules and best practices
3. Git commit message templates
4. Deployment verification procedures
5. Complete troubleshooting guide
6. Comprehensive checklist

**Invocation:**
```
Use the notebook-fix-deploy workflow to fix [issue]
```

**Example:**
```
Use the notebook-fix-deploy workflow to fix the Decimal error in Cell 9
```

**Key Features:**
- Complete workflow checklist
- Detailed troubleshooting section
- Version increment rules
- Deployment verification steps
- Common mistakes and how to avoid them

**Note:** This is the comprehensive reference version based on `SKILL_NOTEBOOK_FIX_WORKFLOW.md`. For quick fixes, use `databricks-notebook-fix` instead.

## How to Use Skills

### Option 1: Reference the Skill
Simply describe what you need, and if it matches a skill pattern, reference:
```
I need to fix the Decimal error in Cell 9 of account_monitor_notebook.py
```

### Option 2: Direct Request
Ask directly for the skill workflow:
```
Use the databricks-notebook-fix workflow to fix [issue]
```

### Option 3: Manual Steps
For learning or customization, follow the steps in the skill file manually.

## Skill Benefits

✅ **Consistency:** Same process every time
✅ **Completeness:** Never miss a step
✅ **Quality:** Proper versioning and commit messages
✅ **Speed:** No need to remember all steps
✅ **Documentation:** Self-documenting workflow

## Adding New Skills

To add a new custom skill:

1. Create a new `.md` file in this directory
2. Follow the format of existing skills
3. Include:
   - Clear purpose statement
   - Step-by-step workflow
   - Code examples
   - Common issues
   - Expected output format
4. Update this README with the new skill

## Skill Format Template

```markdown
# [Skill Name]

You are an expert at [skill purpose].

## Your Task

When the user asks you to [trigger phrase], follow this workflow:

## Step 1: [First Step]
[Details...]

## Step 2: [Second Step]
[Details...]

## Common Issues Reference
[List of common issues...]

## Output Format
[How to present results...]

## Important Notes
[Critical reminders...]

---

**End of Skill**
```

## Related Resources

- **Project Skills:** See project-specific documentation in project repos
- **Databricks Workflow:** `databricks_conso_reports/docs/SKILL_NOTEBOOK_FIX_WORKFLOW.md`
- **Quick Reference:** `databricks_conso_reports/NOTEBOOK_FIX_QUICKREF.md`

## Version History

| Date | Skill | Version | Changes |
|------|-------|---------|---------|
| 2026-01-29 | notebook-fix-deploy | 1.0.0 | Added comprehensive reference guide with detailed troubleshooting |
| 2026-01-29 | databricks-notebook-fix | 1.0.0 | Initial creation |

---

**Location:** `~/.claude/skills/`
**Last Updated:** 2026-01-29
