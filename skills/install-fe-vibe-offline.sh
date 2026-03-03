#!/bin/bash
#
# FE Vibe Offline Installer
# Install FE Vibe skills without GitHub EMU access
# Uses exported plugins from LaurentPRAT-DB/LPT_claude_config
#
# Usage: curl -fsSL https://raw.githubusercontent.com/LaurentPRAT-DB/LPT_claude_config/main/skills/install-fe-vibe-offline.sh | bash
#

set -e

REPO_URL="https://github.com/LaurentPRAT-DB/LPT_claude_config"
REPO_RAW="https://raw.githubusercontent.com/LaurentPRAT-DB/LPT_claude_config/main/skills"
PLUGIN_CACHE="$HOME/.claude/plugins/cache/fe-vibe"
SETTINGS_FILE="$HOME/.claude/settings.json"

echo "================================================"
echo "  FE Vibe Offline Installer"
echo "================================================"
echo ""
echo "Installing from: $REPO_URL"
echo "(No GitHub EMU access required)"
echo ""

# Check for macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "Error: This installer only supports macOS"
    exit 1
fi

# Check for Claude Code
if [[ ! -d "$HOME/.claude" ]]; then
    echo "Error: Claude Code not installed"
    echo "Install with: brew install --cask claude-code"
    exit 1
fi
echo "✓ Claude Code detected"

# Create directories
mkdir -p "$PLUGIN_CACHE"
mkdir -p "$HOME/.claude/settings"

# Download and extract plugins
echo ""
echo "Downloading FE Vibe plugins..."

TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Clone just the skills directory (sparse checkout)
git clone --depth 1 --filter=blob:none --sparse "$REPO_URL" repo 2>/dev/null
cd repo
git sparse-checkout set skills/fe-vibe-export 2>/dev/null

# Copy plugins to cache
echo "Installing plugins..."
PLUGINS=(
    "fe-databricks-tools"
    "fe-salesforce-tools"
    "fe-google-tools"
    "fe-internal-tools"
    "fe-jira-tools"
    "fe-file-expenses"
    "fe-workflows"
    "fe-specialized-agents"
    "fe-vibe-setup"
    "fe-mcp-servers"
)

for plugin in "${PLUGINS[@]}"; do
    if [[ -d "skills/fe-vibe-export/$plugin" ]]; then
        cp -r "skills/fe-vibe-export/$plugin" "$PLUGIN_CACHE/"
        echo "  ✓ $plugin"
    fi
done

# Merge permissions into settings.json
echo ""
echo "Configuring permissions..."

# Create settings.json if it doesn't exist
if [[ ! -f "$SETTINGS_FILE" ]]; then
    echo '{"permissions":{"allow":[],"deny":[]},"enabledPlugins":{}}' > "$SETTINGS_FILE"
fi

# Read permissions from exported yaml
PERMISSIONS_FILE="skills/fe-vibe-export/permissions.yaml"

# Use Python to merge permissions (more reliable than jq for this)
python3 << PYTHON_SCRIPT
import json
import os

settings_file = os.path.expanduser("$SETTINGS_FILE")

# Read existing settings
try:
    with open(settings_file, 'r') as f:
        settings = json.load(f)
except:
    settings = {}

# Ensure structure exists
if 'permissions' not in settings:
    settings['permissions'] = {}
if 'allow' not in settings['permissions']:
    settings['permissions']['allow'] = []
if 'deny' not in settings['permissions']:
    settings['permissions']['deny'] = []
if 'enabledPlugins' not in settings:
    settings['enabledPlugins'] = {}

# Add FE Vibe permissions
vibe_permissions = [
    "Bash",
    "Skill",
    "Read(~/code/**)",
    "Edit(~/code/**)",
    "Write(~/code/**)",
    "Read(//tmp/**)",
    "Edit(//tmp/**)",
    "Write(//tmp/**)",
    "Read(~/.vibe/**)",
    "Edit(~/.vibe/**)",
    "Write(~/.vibe/**)",
    "Read(~/.claude/**)",
    "Read(~/**)",
    "Skill(aws-authentication)",
    "Skill(configure-vibe)",
    "Skill(databricks-authentication)",
    "Skill(databricks-demo)",
    "Skill(databricks-query)",
    "Skill(databricks-resource-deployment)",
    "Skill(databricks-warehouse-selector)",
    "Skill(databricks-fe-vm-workspace-deployment)",
    "Skill(databricks-oneenv-workspace-deployment)",
    "Skill(databricks-apps)",
    "Skill(databricks-lakebase)",
    "Skill(databricks-lakeview-dashboard)",
    "Skill(gmail)",
    "Skill(google-auth)",
    "Skill(google-calendar)",
    "Skill(google-docs)",
    "Skill(google-sheets-creator)",
    "Skill(google-slides-creator)",
    "Skill(logfood-querier)",
    "Skill(genie-rooms)",
    "Skill(uco-consumption-analysis)",
    "Skill(salesforce-actions)",
    "Skill(salesforce-authentication)",
    "Skill(jira-actions)",
    "Skill(emburse-expenses)",
    "Skill(file-expenses)",
    "Skill(databricks-sizing)",
    "Skill(poc-doc)",
    "Skill(product-question-research)",
    "Skill(security-questionnaire)",
    "Skill(uco-updates)",
    "Skill(support-escalation)",
    "Skill(performance-tuning)",
    "Skill(databricks-troubleshooting)",
    "Skill(draft-rca)",
    "Skill(validate-mcp-access)",
    "Skill(fe-snowflake)",
    "Skill(vibe-update)",
    "Skill(fe-poc-postmortem)",
    "Skill(fe-todo-list)",
    "Skill(fe-answer-customer-questions)",
    "Skill(fe-account-transition)",
    "Skill(fe-databricks-feature-tester)",
]

# Merge permissions (avoid duplicates)
existing = set(settings['permissions']['allow'])
for perm in vibe_permissions:
    if perm not in existing:
        settings['permissions']['allow'].append(perm)

# Enable plugins
plugins_to_enable = [
    "fe-databricks-tools@fe-vibe",
    "fe-salesforce-tools@fe-vibe",
    "fe-google-tools@fe-vibe",
    "fe-specialized-agents@fe-vibe",
    "fe-internal-tools@fe-vibe",
    "fe-vibe-setup@fe-vibe",
    "fe-mcp-servers@fe-vibe",
    "fe-jira-tools@fe-vibe",
    "fe-file-expenses@fe-vibe",
    "fe-workflows@fe-vibe",
]

for plugin in plugins_to_enable:
    settings['enabledPlugins'][plugin] = True

# Write settings
with open(settings_file, 'w') as f:
    json.dump(settings, f, indent=2)

print("  ✓ Permissions configured")
print("  ✓ Plugins enabled")
PYTHON_SCRIPT

# Cleanup
cd /
rm -rf "$TEMP_DIR"

echo ""
echo "================================================"
echo "  Installation Complete!"
echo "================================================"
echo ""
echo "Installed plugins:"
for plugin in "${PLUGINS[@]}"; do
    echo "  - $plugin"
done
echo ""
echo "Next steps:"
echo "  1. Restart Claude Code to load plugins"
echo "  2. Run authentication skills as needed:"
echo "     /databricks-authentication"
echo "     /google-auth"
echo "     /salesforce-authentication"
echo ""
echo "Note: This is an offline install from a snapshot."
echo "To get updates, ask Laurent for a new export or"
echo "get GitHub EMU access for the official installer."
echo ""
