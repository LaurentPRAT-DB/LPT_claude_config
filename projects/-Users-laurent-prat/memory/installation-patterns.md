# Installation Patterns - Claude Code & Related Tools

## Homebrew Formula vs Cask

**Important distinction:**
- **Formulas** = CLI tools, installed with `brew install <name>`
- **Casks** = GUI apps or larger packages, installed with `brew install --cask <name>`

| Tool | Type | Correct Command |
|------|------|-----------------|
| Salesforce CLI | Formula | `brew install sf` |
| Google Cloud CLI | Cask | `brew install --cask gcloud-cli` |
| Claude Code | Cask | `brew install --cask claude-code` |
| GitHub CLI | Formula | `brew install gh` |

**Note:** `google-cloud-sdk` is the OLD name - use `gcloud-cli` instead.

## FE Vibe Plugins Installation

### Access Requirements
- **Databricks employees only** - requires GitHub EMU (Enterprise Managed User) account
- Requires access to private repo: `databricks-field-eng/vibe`

### Correct Installation Command
```bash
brew install gh && gh auth login --web --hostname github.com --git-protocol ssh --skip-ssh-key && gh release download latest --repo databricks-field-eng/vibe --pattern 'install_vibe.sh' -O - | zsh
```

### What It Installs
- fe-databricks-tools (Databricks integration)
- fe-salesforce-tools (UCO management)
- fe-google-tools (Docs, Sheets, Gmail, Calendar)
- fe-jira-tools (JIRA integration)
- fe-internal-tools (Logfood, AWS auth)
- fe-workflows (POC docs, troubleshooting)
- fe-specialized-agents (CLI executor, diagrams)
- fe-file-expenses (Emburse/expense filing)
- fe-vibe-setup (Environment configuration)

### Updating Vibe
```bash
vibe update && vibe sync
```

### WRONG Command (does NOT work)
```
/install-plugin fe-vibe  # This is INCORRECT
```

### Plugin Location After Install
- Marketplace: `/Users/laurent.prat/.vibe/marketplace`
- Cached plugins: `~/.claude/plugins/cache/fe-vibe/`

## Claude Code Installation Options

### Option 1: Homebrew (Recommended)
```bash
brew install --cask claude-code
```

### Option 2: npm
```bash
npm install -g @anthropic-ai/claude-code
```

## Post-Installation Authentication

### Salesforce
```bash
sf org login web
# Opens browser for Okta authentication
```

### Google Cloud
```bash
gcloud auth login
gcloud auth application-default login
# Required quota project: gcp-sandbox-field-eng
```

### GitHub (for vibe access)
```bash
gh auth login --web --hostname github.com --git-protocol ssh --skip-ssh-key
# Must use Databricks EMU account
```

## Finding Salesforce User ID

In Salesforce UI:
1. Click profile icon (top right)
2. Settings
3. My Personal Information
4. Advanced User Details
5. User ID starts with `005...`

Or via CLI:
```bash
sf data query --query "SELECT Id, Name, Email FROM User WHERE Email = 'your.email@databricks.com'" --json
```

## Syncing Skills from ai-dev-kit Repository

**Source:** https://github.com/databricks-solutions/ai-dev-kit

### Update Workflow
```bash
# 1. Clone repo
gh repo clone databricks-solutions/ai-dev-kit /tmp/ai-dev-kit -- --depth 1

# 2. Find MISSING skills
AI_DEV_KIT="/tmp/ai-dev-kit/databricks-skills"
GLOBAL_SKILLS="$HOME/.claude/skills"

for skill in $(ls $AI_DEV_KIT); do
  if [[ -d "$AI_DEV_KIT/$skill" ]] && [[ ! -d "$GLOBAL_SKILLS/$skill" ]]; then
    echo "Missing: $skill"
  fi
done

# 3. Compare CONFLICTING skills (line count comparison)
for skill in $(ls $AI_DEV_KIT); do
  if [[ -d "$AI_DEV_KIT/$skill" ]] && [[ -d "$GLOBAL_SKILLS/$skill" ]]; then
    ai_lines=$(find "$AI_DEV_KIT/$skill" -name "*.md" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}')
    global_lines=$(find "$GLOBAL_SKILLS/$skill" -name "*.md" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}')
    echo "$skill: ai-dev-kit=$ai_lines, global=$global_lines"
  fi
done

# 4. Install missing skills
cp -r "$AI_DEV_KIT/<skill-name>" "$GLOBAL_SKILLS/"

# 5. Cleanup
rm -rf /tmp/ai-dev-kit
```

### Naming Differences (ai-dev-kit → global)
| ai-dev-kit name | Global name |
|-----------------|-------------|
| databricks-lakebase-autoscale | lakebase-autoscale |
| databricks-lakebase-provisioned | lakebase-provisioned |
| databricks-mlflow-evaluation | mlflow-evaluation |
| databricks-spark-declarative-pipelines | spark-declarative-pipelines |
| databricks-spark-structured-streaming | spark-structured-streaming |
| databricks-synthetic-data-gen | synthetic-data-generation |
| databricks-unstructured-pdf-generation | unstructured-pdf-generation |

### Decision Rules
1. **Missing skills** → Install from ai-dev-kit
2. **Identical line counts** → Keep current (no change needed)
3. **ai-dev-kit has more lines** → Update from ai-dev-kit (newer/more complete)
4. **Global has more lines** → Keep current (may have custom additions)
