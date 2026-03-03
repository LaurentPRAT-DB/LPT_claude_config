# FE Vibe Setup Guide

Instructions for installing and configuring FE Vibe plugins for Claude Code.

## Prerequisites

- **Databricks employee** with GitHub EMU (Enterprise Managed User) account
- macOS with [Homebrew](https://brew.sh) installed
- Claude Code installed (`brew install --cask claude-code`)

## Quick Installation

### Option 1: With GitHub EMU Access (recommended)

```bash
brew install gh && gh auth login --web --hostname github.com --git-protocol ssh --skip-ssh-key && gh release download latest --repo databricks-field-eng/vibe --pattern 'install_vibe.sh' -O - | zsh
```

**Important:** When prompted, select your **Databricks EMU GitHub account** (not personal).

### Option 2: Without GitHub EMU Access (offline install)

```bash
curl -fsSL https://raw.githubusercontent.com/LaurentPRAT-DB/LPT_claude_config/main/skills/install-fe-vibe-offline.sh | bash
```

This installs from a snapshot in this repo. No EMU access required, but won't receive automatic updates.

#### Custom GCP Project (for Google tools)

By default, Google tools use `gcp-sandbox-field-eng` as the quota project. If you don't have access to this project, specify your own:

```bash
curl -fsSL https://raw.githubusercontent.com/LaurentPRAT-DB/LPT_claude_config/main/skills/install-fe-vibe-offline.sh | bash -s -- --gcp-project YOUR_PROJECT_ID
```

Your GCP project needs these APIs enabled:
- Google Drive API
- Google Docs API
- Google Sheets API
- Google Slides API
- Gmail API
- Google Calendar API

After installation, restart Claude Code to load the plugins.

## Verify Installation

```bash
# Check GitHub access
gh repo view databricks-field-eng/vibe

# Check vibe CLI
vibe --help

# Check installed plugins
claude plugin list
```

## Updating Vibe

Run periodically to get new features and fixes:

```bash
vibe update && vibe sync
```

## Plugin Catalog

| Plugin | Purpose |
|--------|---------|
| **fe-databricks-tools** | Workspace management, querying, app development, Lakebase |
| **fe-salesforce-tools** | UCO management, Salesforce CRM operations |
| **fe-google-tools** | Gmail, Docs, Sheets, Slides, Calendar, Drive |
| **fe-internal-tools** | Logfood analytics, AWS auth, Genie Rooms |
| **fe-jira-tools** | JIRA ticket management |
| **fe-workflows** | POC docs, troubleshooting, RCA, support escalations |
| **fe-file-expenses** | Emburse/ChromeRiver expense filing |
| **fe-specialized-agents** | CLI executor, Mermaid diagrams, web testing |
| **fe-vibe-setup** | Environment setup and validation |

## Key Skills

### Databricks
- `/databricks-authentication` - Authenticate with Databricks
- `/databricks-query` - Execute SQL queries
- `/databricks-apps` - Build and deploy Databricks Apps
- `/databricks-lakebase` - Manage Lakebase PostgreSQL databases

### Salesforce
- `/salesforce-authentication` - Authenticate with Salesforce
- `/salesforce-actions` - Read/update UCOs, accounts, opportunities
- `/uco-updates` - Weekly UCO status updates

### Google Workspace
- `/google-auth` - Authenticate with Google APIs
- `/gmail` - Search, read, send emails
- `/google-docs` - Create and edit Google Docs
- `/google-sheets-creator` - Create formatted spreadsheets
- `/google-calendar` - Manage calendar events

### Internal
- `/logfood-querier` - Query internal consumption data
- `/genie-rooms` - Query any Genie Room by ID

## MCP Servers

Vibe configures these MCP servers:

| Server | Purpose |
|--------|---------|
| `chrome-devtools` | Browser automation and testing |
| `glean` | Internal knowledge base search |
| `slack` | Slack integration |

## Post-Installation Authentication

After installing vibe, authenticate with each service:

```bash
# Databricks
/databricks-authentication

# Google Workspace
/google-auth

# Salesforce
sf org login web

# AWS (for internal tools)
/aws-authentication
```

## Permissions

Vibe auto-configures permissions in `~/.claude/settings.json`. Key permissions include:

- All Bash commands
- Read/Edit/Write in `~/code/**`
- Read access to `~/**`
- All vibe skills and MCP tools

## File Locations

| Path | Contents |
|------|----------|
| `~/.vibe/marketplace/` | Vibe installation and plugins |
| `~/.claude/plugins/cache/fe-vibe/` | Cached plugin files |
| `~/.claude/settings.json` | Claude Code settings (permissions merged here) |

## Troubleshooting

### "Permission denied" on GitHub
```bash
# Re-authenticate with EMU account
gh auth login --web --hostname github.com --git-protocol ssh --skip-ssh-key
```

### Plugins not loading
```bash
# Restart Claude Code or run:
vibe sync
```

### Skills not found
```bash
# Update vibe
vibe update && vibe sync
```

## Resources

- **Vibe Repo:** `databricks-field-eng/vibe` (private)
- **Plugin Docs:** See `~/.vibe/marketplace/README.md` after installation

---

**Last Updated:** 2026-03-03
