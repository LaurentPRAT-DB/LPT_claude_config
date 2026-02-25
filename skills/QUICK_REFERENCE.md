# Claude Skills Quick Reference Card

**Custom skills available globally across all projects**

---

## 🔧 Databricks Notebook Fix

**Trigger:**
```
Fix [issue] in [notebook_file]
```

**What it does:**
1. ✅ Analyzes and fixes the issue
2. ✅ Updates version numbers
3. ✅ Creates git commit
4. ✅ Pushes to remote
5. ✅ Deploys to Databricks

**Common fixes:**
- SQL parameter markers: `$` → `USD `
- Decimal types: `value` → `float(value)`
- API calls: `dbutils.x` → `WorkspaceClient().x`

---

## 📋 Notebook Fix & Deploy (Comprehensive)

**Trigger:**
```
Use the notebook-fix-deploy workflow for [issue]
```

**What it provides:**
1. ✅ Complete 7-step workflow guide
2. ✅ Detailed troubleshooting reference
3. ✅ Version numbering rules
4. ✅ Deployment verification procedures
5. ✅ Comprehensive checklist

**Use when:**
- Need detailed guidance
- Learning the workflow
- Troubleshooting deployment issues
- Want complete verification steps

---

## 📋 Quick Commands

### Invoke a Skill
```
Use the databricks-notebook-fix workflow for [notebook]
```

### Check Available Skills
```
What skills are available?
```

### Get Skill Details
```
Show me details about databricks-notebook-fix skill
```

---

## 🗂️ Skill Locations

**Global Skills:** `~/.claude/skills/`
**Project Skills:** `[project]/docs/SKILL_*.md`

---

## 💡 Tips

- Skills work across all projects
- No need to repeat context
- Each skill is self-contained
- Skills include error handling

---

**Last Updated:** 2026-01-29
