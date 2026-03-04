#!/bin/bash
#
# Simulates FE Vibe installation on a colleague's fresh laptop
# Tests everything except macOS-specific parts (Homebrew, Claude Code app)
#

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO_RAW="https://raw.githubusercontent.com/LaurentPRAT-DB/LPT_claude_config/main/skills"
PACKAGE_URL="$REPO_RAW/fe-vibe-plugins.tar.gz"
INSTALLER_URL="$REPO_RAW/install-fe-vibe-offline.sh"
GCP_PROJECT="${GCP_PROJECT:-gcp-sandbox-field-eng}"

FAILURES=0

pass() {
    echo -e "${GREEN}✓${NC} $1"
}

fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILURES++)) || true
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  FE Vibe Installation Simulation${NC}"
echo -e "${BLUE}  (Colleague's Fresh Laptop)${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo "User: $(whoami)"
echo "Home: $HOME"
echo "GCP Project: $GCP_PROJECT"
echo ""

# ============================================
# Step 1: Test Network Connectivity
# ============================================
echo -e "${BLUE}[Step 1/5] Testing network connectivity...${NC}"

# Test GitHub raw content
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$INSTALLER_URL" 2>/dev/null)
if [[ "$HTTP_CODE" == "200" ]]; then
    pass "GitHub raw content accessible"
else
    fail "GitHub not accessible (HTTP $HTTP_CODE)"
fi

# Test GCP APIs (will return 401/403 without auth, but proves connectivity)
for api in "drive" "docs" "sheets" "gmail"; do
    case $api in
        drive) url="https://www.googleapis.com/drive/v3/about" ;;
        docs) url="https://docs.googleapis.com/v1/documents/1" ;;
        sheets) url="https://sheets.googleapis.com/v4/spreadsheets/1" ;;
        gmail) url="https://gmail.googleapis.com/gmail/v1/users/me/profile" ;;
    esac

    CODE=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
    if [[ "$CODE" == "401" || "$CODE" == "403" || "$CODE" == "400" ]]; then
        pass "$api API reachable (HTTP $CODE - auth required)"
    else
        fail "$api API unreachable (HTTP $CODE)"
    fi
done

# ============================================
# Step 2: Download Installer Script
# ============================================
echo ""
echo -e "${BLUE}[Step 2/5] Downloading installer script...${NC}"

SCRIPT_CONTENT=$(curl -fsSL "$INSTALLER_URL" 2>/dev/null)
if [[ -n "$SCRIPT_CONTENT" ]]; then
    SCRIPT_LINES=$(echo "$SCRIPT_CONTENT" | wc -l)
    pass "Installer downloaded ($SCRIPT_LINES lines)"

    # Verify key components
    if echo "$SCRIPT_CONTENT" | grep -q "FE Vibe"; then
        pass "Script header verified"
    else
        fail "Script header missing"
    fi

    if echo "$SCRIPT_CONTENT" | grep -q "fe-vibe-plugins.tar.gz"; then
        pass "Uses HTTP package download (no git required)"
    else
        fail "HTTP package download not found"
    fi
else
    fail "Failed to download installer"
fi

# ============================================
# Step 3: Download and Extract Plugins Package
# ============================================
echo ""
echo -e "${BLUE}[Step 3/5] Downloading plugins package...${NC}"

mkdir -p "$HOME/.claude/plugins/cache/fe-vibe"
cd "$HOME"

if curl -fsSL "$PACKAGE_URL" -o fe-vibe-plugins.tar.gz 2>/dev/null; then
    FILE_SIZE=$(ls -lh fe-vibe-plugins.tar.gz | awk '{print $5}')
    pass "Package downloaded ($FILE_SIZE)"

    # Extract
    if tar -xzf fe-vibe-plugins.tar.gz 2>/dev/null; then
        pass "Package extracted"

        # Move to plugin cache
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

        echo ""
        echo "Checking plugins:"
        for plugin in "${PLUGINS[@]}"; do
            if [[ -d "$plugin" ]]; then
                cp -r "$plugin" "$HOME/.claude/plugins/cache/fe-vibe/"
                pass "  $plugin"
            else
                fail "  $plugin (MISSING)"
            fi
        done
    else
        fail "Failed to extract package"
    fi

    rm -f fe-vibe-plugins.tar.gz
else
    fail "Failed to download package"
fi

# ============================================
# Step 4: Create Settings Configuration
# ============================================
echo ""
echo -e "${BLUE}[Step 4/5] Creating settings configuration...${NC}"

mkdir -p "$HOME/.claude"
SETTINGS_FILE="$HOME/.claude/settings.json"

# Create settings.json with Python (same as installer)
python3 << 'PYTHON_SCRIPT'
import json
import os

settings_file = os.path.expanduser("~/.claude/settings.json")

settings = {
    "permissions": {"allow": [], "deny": []},
    "enabledPlugins": {}
}

vibe_permissions = [
    "Bash", "Skill",
    "Read(~/code/**)", "Edit(~/code/**)", "Write(~/code/**)",
    "Read(//tmp/**)", "Edit(//tmp/**)", "Write(//tmp/**)",
    "Read(~/.vibe/**)", "Edit(~/.vibe/**)", "Write(~/.vibe/**)",
    "Read(~/.claude/**)", "Read(~/**)",
]

settings['permissions']['allow'] = vibe_permissions

plugins_to_enable = [
    "fe-databricks-tools@fe-vibe", "fe-salesforce-tools@fe-vibe",
    "fe-google-tools@fe-vibe", "fe-specialized-agents@fe-vibe",
    "fe-internal-tools@fe-vibe", "fe-vibe-setup@fe-vibe",
    "fe-mcp-servers@fe-vibe", "fe-jira-tools@fe-vibe",
    "fe-file-expenses@fe-vibe", "fe-workflows@fe-vibe",
]

for plugin in plugins_to_enable:
    settings['enabledPlugins'][plugin] = True

with open(settings_file, 'w') as f:
    json.dump(settings, f, indent=2)

print("Settings created successfully")
PYTHON_SCRIPT

if [[ -f "$SETTINGS_FILE" ]]; then
    pass "settings.json created"

    # Verify content
    ENABLED_COUNT=$(python3 -c "import json; s=json.load(open('$SETTINGS_FILE')); print(len(s.get('enabledPlugins', {})))")
    PERM_COUNT=$(python3 -c "import json; s=json.load(open('$SETTINGS_FILE')); print(len(s.get('permissions', {}).get('allow', [])))")

    pass "$ENABLED_COUNT plugins enabled"
    pass "$PERM_COUNT permissions configured"
else
    fail "settings.json not created"
fi

# ============================================
# Step 5: Verify Installation Structure
# ============================================
echo ""
echo -e "${BLUE}[Step 5/5] Verifying installation structure...${NC}"

# Check directory structure
if [[ -d "$HOME/.claude" ]]; then
    pass "~/.claude directory exists"
else
    fail "~/.claude directory missing"
fi

if [[ -d "$HOME/.claude/plugins/cache/fe-vibe" ]]; then
    PLUGIN_COUNT=$(find "$HOME/.claude/plugins/cache/fe-vibe" -maxdepth 1 -type d | wc -l)
    PLUGIN_COUNT=$((PLUGIN_COUNT - 1))
    pass "Plugin cache exists ($PLUGIN_COUNT plugins)"
else
    fail "Plugin cache missing"
fi

if [[ -f "$HOME/.claude/settings.json" ]]; then
    pass "settings.json exists"
else
    fail "settings.json missing"
fi

# ============================================
# Summary
# ============================================
echo ""
echo -e "${BLUE}================================================${NC}"
if [[ $FAILURES -eq 0 ]]; then
    echo -e "${GREEN}  All tests passed!${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
    echo "Installation simulation successful."
    echo ""
    echo "On a real macOS laptop, the installer will also:"
    echo "  - Install Homebrew (if needed)"
    echo "  - Install Claude Code app (if needed)"
    echo "  - Install gcloud CLI (if needed)"
    echo "  - Authenticate with Google"
    echo "  - Verify GCP project access"
    echo ""
    echo "Your colleague can run:"
    echo "  curl -fsSL $INSTALLER_URL | bash"
else
    echo -e "${RED}  $FAILURES test(s) failed${NC}"
    echo -e "${BLUE}================================================${NC}"
fi
echo ""

exit $FAILURES
