# Claude Code Configuration Setup Guide

This guide helps you replicate the Claude Code configuration from Laurent Prat on a new Mac.

## Quick Start

```bash
# Clone and run the setup script
git clone https://github.com/LaurentPRAT-DB/LPT_claude_config.git ~/.claude
cd ~/.claude
chmod +x setup.sh
./setup.sh
```

## Dependencies Overview

| Tool | Purpose | Installation Method |
|------|---------|---------------------|
| Homebrew | Package manager for macOS | Shell script |
| Node.js | Required for npx and MCP servers | Homebrew |
| Salesforce CLI (sf) | Salesforce data operations | Homebrew |
| Google Cloud SDK | Google Workspace API access | Manual download |
| Claude Code CLI | The main Claude CLI tool | Homebrew Cask |
| Python 3 | MCP servers and scripting | Homebrew |
| Git | Version control | Xcode CLT / Homebrew |

## Manual Installation Steps

### 1. Install Homebrew (if not installed)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

After installation, follow the instructions to add Homebrew to your PATH:
```bash
# For Apple Silicon Macs (M1/M2/M3)
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### 2. Install Core Dependencies

```bash
# Node.js (required for npx commands and MCP servers)
brew install node

# Python 3 (for MCP servers)
brew install python@3.13

# Git (if not already installed via Xcode)
brew install git

# Salesforce CLI
brew install sf

# Claude Code CLI
brew install --cask claude-code
```

### 3. Install Google Cloud SDK

Download from: https://cloud.google.com/sdk/docs/install

**For macOS (Apple Silicon):**
```bash
# Download and extract
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-darwin-arm.tar.gz
tar -xvf google-cloud-cli-darwin-arm.tar.gz

# Move to home directory
mv google-cloud-sdk ~/

# Run installer
~/google-cloud-sdk/install.sh

# Initialize (follow prompts)
~/google-cloud-sdk/bin/gcloud init
```

**For macOS (Intel):**
```bash
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-darwin-x86_64.tar.gz
tar -xvf google-cloud-cli-darwin-x86_64.tar.gz
mv google-cloud-sdk ~/
~/google-cloud-sdk/install.sh
~/google-cloud-sdk/bin/gcloud init
```

### 4. Clone the Configuration Repository

```bash
# Backup existing config if present
[ -d ~/.claude ] && mv ~/.claude ~/.claude.backup.$(date +%Y%m%d)

# Clone the repository
git clone https://github.com/LaurentPRAT-DB/LPT_claude_config.git ~/.claude
```

### 5. Create Configuration Files from Templates

```bash
cd ~/.claude

# Create settings.json from template
cp settings.json.template settings.json

# Create mcp.json from template
cp mcp.json.template mcp.json
```

### 6. Edit Configuration Files

#### settings.json
Edit `~/.claude/settings.json` and replace these placeholders:

| Placeholder | Description | How to Get |
|-------------|-------------|------------|
| `YOUR_WORKSPACE` | Databricks workspace URL prefix (e.g., `e2-demo-field-eng`) | From your Databricks workspace URL |
| `YOUR_DATABRICKS_PAT_TOKEN` | Databricks Personal Access Token | Databricks UI → Settings → Developer → Access Tokens |
| `YOUR_CONTEXT7_API_KEY` | Context7 MCP API key | https://context7.com |

Example env section:
```json
"env": {
  "ANTHROPIC_MODEL": "databricks-claude-opus-4-5",
  "ANTHROPIC_BASE_URL": "https://e2-demo-field-eng.cloud.databricks.com/serving-endpoints/anthropic",
  "ANTHROPIC_AUTH_TOKEN": "dapi123abc...",
  "ANTHROPIC_CUSTOM_HEADERS": "x-databricks-use-coding-agent-mode: true"
}
```

#### mcp.json
Edit `~/.claude/mcp.json` and update:
- Path references from `/Users/laurent.prat/` to your home directory
- Any API keys or tokens for MCP servers

### 7. Install FE Vibe Plugins (Databricks Internal)

> **Note**: This requires access to Databricks GitHub EMU (databricks-field-eng organization).

```bash
# Clone the vibe installer (requires Databricks GitHub access)
git clone https://github.com/databricks-field-eng/vibe.git ~/Documents/vibe

# Run the vibe installer
cd ~/Documents/vibe
./install.sh
```

If you don't have access to the FE Vibe repo, you can still use Claude Code without these plugins. They provide Databricks-specific skills and workflows.

### 8. Set Up Directory Structure

```bash
# Create required directories
mkdir -p ~/.vibe/chrome/profile
mkdir -p ~/mcp/servers
mkdir -p ~/code
```

### 9. Authenticate Services

#### Salesforce CLI
```bash
sf org login web --alias my-org
sf config set target-org=my-org
```

#### Google Cloud
```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

#### Databricks CLI (optional)
```bash
brew tap databricks/tap
brew install databricks
databricks configure
```

## Verification

Run these commands to verify installation:

```bash
# Check all tools are installed
echo "=== Checking Dependencies ===" && \
which brew && brew --version && \
which node && node --version && \
which sf && sf --version | head -1 && \
which gcloud && gcloud --version | head -1 && \
which claude && claude --version && \
which python3 && python3 --version && \
echo "=== All checks passed ==="
```

Start Claude Code:
```bash
claude
```

## Troubleshooting

### "command not found: brew"
Run the Homebrew install script and add to PATH as shown in step 1.

### "sf: command not found"
```bash
brew install sf
```

### Node.js version issues
```bash
brew upgrade node
```

### MCP server errors
Check that all paths in `mcp.json` are correct for your machine:
```bash
# Replace all occurrences of the old username
sed -i '' 's/laurent\.prat/YOUR_USERNAME/g' ~/.claude/mcp.json
```

### Plugin installation fails
FE Vibe plugins require Databricks GitHub EMU access. Contact the FE team for access.

## What's Included

### Skills (40+)
- Databricks: Apps, Jobs, DBSQL, Model Serving, Unity Catalog, Vector Search
- MLflow: Evaluation, Tracing, Metrics
- Spark: Declarative Pipelines, Structured Streaming
- Other: Agent Evaluation, Medium Article Generator, Synthetic Data

### Agents
- Git operations agent
- GSD (Get Shit Done) workflow agents for project management

### Commands
- `/city-news` - Search news for a city
- `/gsd:*` - Project management workflow commands

### Hooks
- GSD status line
- GSD update checker

## Download Links

| Tool | URL |
|------|-----|
| Homebrew | https://brew.sh |
| Node.js | https://nodejs.org (or via Homebrew) |
| Salesforce CLI | https://developer.salesforce.com/tools/salesforcecli |
| Google Cloud SDK | https://cloud.google.com/sdk/docs/install |
| Claude Code | https://claude.ai/download (or `brew install --cask claude-code`) |
| Python | https://www.python.org/downloads/ (or via Homebrew) |

## Support

For issues with:
- Claude Code: https://github.com/anthropics/claude-code/issues
- This configuration: Contact Laurent Prat
