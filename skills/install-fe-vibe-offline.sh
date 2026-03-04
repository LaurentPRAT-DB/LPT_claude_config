#!/bin/bash
#
# FE Vibe Offline Installer
# Complete installation of FE Vibe skills for Claude Code
# Includes: plugins, gcloud CLI, Google authentication, and verification
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/LaurentPRAT-DB/LPT_claude_config/main/skills/install-fe-vibe-offline.sh | bash
#
#   # With custom GCP quota project (for Google tools):
#   curl -fsSL https://raw.githubusercontent.com/LaurentPRAT-DB/LPT_claude_config/main/skills/install-fe-vibe-offline.sh | bash -s -- --gcp-project YOUR_PROJECT_ID
#

set -e

# Default values
DEFAULT_GCP_PROJECT="gcp-sandbox-field-eng"
GCP_PROJECT="$DEFAULT_GCP_PROJECT"
SKIP_GOOGLE_AUTH=false

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --gcp-project)
            GCP_PROJECT="$2"
            shift 2
            ;;
        --skip-google-auth)
            SKIP_GOOGLE_AUTH=true
            shift
            ;;
        --help|-h)
            echo "FE Vibe Offline Installer"
            echo ""
            echo "Usage:"
            echo "  ./install-fe-vibe-offline.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --gcp-project PROJECT_ID   GCP quota project for Google tools"
            echo "                             Default: gcp-sandbox-field-eng"
            echo "  --skip-google-auth         Skip Google authentication step"
            echo "  --help, -h                 Show this help"
            echo ""
            echo "Examples:"
            echo "  # Full install with Google auth"
            echo "  curl -fsSL https://raw.githubusercontent.com/LaurentPRAT-DB/LPT_claude_config/main/skills/install-fe-vibe-offline.sh | bash"
            echo ""
            echo "  # Install with custom GCP project"
            echo "  curl -fsSL https://raw.githubusercontent.com/LaurentPRAT-DB/LPT_claude_config/main/skills/install-fe-vibe-offline.sh | bash -s -- --gcp-project my-gcp-project"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage"
            exit 1
            ;;
    esac
done

REPO_RAW="https://raw.githubusercontent.com/LaurentPRAT-DB/LPT_claude_config/main/skills"
PACKAGE_URL="$REPO_RAW/fe-vibe-plugins.tar.gz"
PLUGIN_CACHE="$HOME/.claude/plugins/cache/fe-vibe"
SETTINGS_FILE="$HOME/.claude/settings.json"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  FE Vibe Complete Installer${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo "This installer will:"
echo "  1. Install FE Vibe plugins for Claude Code"
echo "  2. Install Google Cloud CLI (if needed)"
echo "  3. Authenticate with Google (for Google skills)"
echo "  4. Verify GCP project access"
echo ""
echo "GCP Quota Project: $GCP_PROJECT"
echo ""

# Check for macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "${RED}Error: This installer only supports macOS${NC}"
    exit 1
fi

# Check for Homebrew
echo -e "${BLUE}[Step 1/6] Checking Homebrew...${NC}"
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add to path for Apple Silicon
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
fi
echo -e "${GREEN}✓${NC} Homebrew installed"

# Check for Claude Code
echo ""
echo -e "${BLUE}[Step 2/6] Checking Claude Code...${NC}"

# Check if Claude Code is already installed (cask or directory exists)
CLAUDE_INSTALLED=false
if brew list --cask claude-code &>/dev/null 2>&1; then
    CLAUDE_INSTALLED=true
elif [[ -d "/Applications/Claude Code.app" ]] || [[ -d "$HOME/Applications/Claude Code.app" ]]; then
    CLAUDE_INSTALLED=true
fi

if [[ "$CLAUDE_INSTALLED" == "false" ]]; then
    echo "Installing Claude Code..."
    brew install --cask claude-code || {
        echo -e "${YELLOW}⚠${NC} Could not install Claude Code via Homebrew"
        echo "  You may need to install it manually or run with appropriate permissions"
    }
fi

# Always ensure .claude directory exists
mkdir -p "$HOME/.claude"
echo -e "${GREEN}✓${NC} Claude Code ready"

# Check/Install gcloud CLI
echo ""
echo -e "${BLUE}[Step 3/6] Checking Google Cloud CLI...${NC}"

# Check multiple locations for gcloud
GCLOUD_FOUND=false
if command -v gcloud &> /dev/null; then
    GCLOUD_FOUND=true
else
    for path in "/opt/homebrew/bin/gcloud" "/usr/local/bin/gcloud" "$HOME/google-cloud-sdk/bin/gcloud"; do
        if [[ -f "$path" ]]; then
            GCLOUD_FOUND=true
            break
        fi
    done
fi

if [[ "$GCLOUD_FOUND" == "false" ]]; then
    echo "Installing Google Cloud CLI..."
    brew install --cask google-cloud-sdk || {
        echo -e "${YELLOW}⚠${NC} Could not install gcloud via Homebrew"
        echo "  You may need to install it manually: https://cloud.google.com/sdk/docs/install"
    }

    # Source gcloud completion and path
    if [[ -f "$(brew --prefix)/share/google-cloud-sdk/path.bash.inc" ]]; then
        source "$(brew --prefix)/share/google-cloud-sdk/path.bash.inc"
    fi
    if [[ -f "$(brew --prefix)/share/google-cloud-sdk/completion.bash.inc" ]]; then
        source "$(brew --prefix)/share/google-cloud-sdk/completion.bash.inc"
    fi

    # Also try zsh paths
    if [[ -f "$(brew --prefix)/share/google-cloud-sdk/path.zsh.inc" ]]; then
        source "$(brew --prefix)/share/google-cloud-sdk/path.zsh.inc"
    fi
fi

# Find gcloud path
GCLOUD_PATH=$(command -v gcloud 2>/dev/null || echo "")
if [[ -z "$GCLOUD_PATH" ]]; then
    # Try common locations
    for path in "/opt/homebrew/bin/gcloud" "/usr/local/bin/gcloud" "$HOME/google-cloud-sdk/bin/gcloud"; do
        if [[ -f "$path" ]]; then
            GCLOUD_PATH="$path"
            break
        fi
    done
fi

if [[ -n "$GCLOUD_PATH" ]]; then
    GCLOUD_VERSION=$($GCLOUD_PATH --version 2>/dev/null | head -1 || echo "unknown")
    echo -e "${GREEN}✓${NC} Google Cloud CLI installed: $GCLOUD_VERSION"
else
    echo -e "${YELLOW}⚠${NC} gcloud not found in PATH. You may need to restart your terminal."
    echo "  Then run: gcloud auth application-default login"
fi

# Create directories
mkdir -p "$PLUGIN_CACHE"
mkdir -p "$HOME/.claude/settings"

# Download and install plugins
echo ""
echo -e "${BLUE}[Step 4/6] Installing FE Vibe plugins...${NC}"

TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Download plugins package via HTTP (no git required)
echo "Downloading plugins package..."
if curl -fsSL "$PACKAGE_URL" -o fe-vibe-plugins.tar.gz; then
    echo -e "  ${GREEN}✓${NC} Package downloaded"
else
    echo -e "${RED}Error: Failed to download plugins package${NC}"
    echo "  URL: $PACKAGE_URL"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Extract plugins
echo "Extracting plugins..."
tar -xzf fe-vibe-plugins.tar.gz

# Copy plugins to cache
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
    if [[ -d "$plugin" ]]; then
        cp -r "$plugin" "$PLUGIN_CACHE/"
        echo -e "  ${GREEN}✓${NC} $plugin"
    fi
done

# Configure GCP quota project if different from default
if [[ "$GCP_PROJECT" != "$DEFAULT_GCP_PROJECT" ]]; then
    echo ""
    echo "Configuring GCP quota project: $GCP_PROJECT"
    find "$PLUGIN_CACHE" -type f \( -name "*.py" -o -name "*.sh" -o -name "*.md" -o -name "*.yaml" \) -exec \
        sed -i '' "s/$DEFAULT_GCP_PROJECT/$GCP_PROJECT/g" {} \; 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} GCP project configured"
fi

# Merge permissions into settings.json
echo ""
echo "Configuring permissions..."

# Create settings.json if it doesn't exist
if [[ ! -f "$SETTINGS_FILE" ]]; then
    echo '{"permissions":{"allow":[],"deny":[]},"enabledPlugins":{}}' > "$SETTINGS_FILE"
fi

# Use Python to merge permissions
python3 << PYTHON_SCRIPT
import json
import os

settings_file = os.path.expanduser("$SETTINGS_FILE")

try:
    with open(settings_file, 'r') as f:
        settings = json.load(f)
except:
    settings = {}

if 'permissions' not in settings:
    settings['permissions'] = {}
if 'allow' not in settings['permissions']:
    settings['permissions']['allow'] = []
if 'deny' not in settings['permissions']:
    settings['permissions']['deny'] = []
if 'enabledPlugins' not in settings:
    settings['enabledPlugins'] = {}

vibe_permissions = [
    "Bash", "Skill",
    "Read(~/code/**)", "Edit(~/code/**)", "Write(~/code/**)",
    "Read(//tmp/**)", "Edit(//tmp/**)", "Write(//tmp/**)",
    "Read(~/.vibe/**)", "Edit(~/.vibe/**)", "Write(~/.vibe/**)",
    "Read(~/.claude/**)", "Read(~/**)",
    "Skill(aws-authentication)", "Skill(configure-vibe)",
    "Skill(databricks-authentication)", "Skill(databricks-demo)",
    "Skill(databricks-query)", "Skill(databricks-resource-deployment)",
    "Skill(databricks-warehouse-selector)", "Skill(databricks-fe-vm-workspace-deployment)",
    "Skill(databricks-oneenv-workspace-deployment)", "Skill(databricks-apps)",
    "Skill(databricks-lakebase)", "Skill(databricks-lakeview-dashboard)",
    "Skill(gmail)", "Skill(google-auth)", "Skill(google-calendar)",
    "Skill(google-docs)", "Skill(google-sheets-creator)", "Skill(google-slides-creator)",
    "Skill(logfood-querier)", "Skill(genie-rooms)", "Skill(uco-consumption-analysis)",
    "Skill(salesforce-actions)", "Skill(salesforce-authentication)",
    "Skill(jira-actions)", "Skill(emburse-expenses)", "Skill(file-expenses)",
    "Skill(databricks-sizing)", "Skill(poc-doc)", "Skill(product-question-research)",
    "Skill(security-questionnaire)", "Skill(uco-updates)", "Skill(support-escalation)",
    "Skill(performance-tuning)", "Skill(databricks-troubleshooting)", "Skill(draft-rca)",
    "Skill(validate-mcp-access)", "Skill(fe-snowflake)", "Skill(vibe-update)",
    "Skill(fe-poc-postmortem)", "Skill(fe-todo-list)", "Skill(fe-answer-customer-questions)",
    "Skill(fe-account-transition)", "Skill(fe-databricks-feature-tester)",
]

existing = set(settings['permissions']['allow'])
for perm in vibe_permissions:
    if perm not in existing:
        settings['permissions']['allow'].append(perm)

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

print("  \033[0;32m✓\033[0m Permissions configured")
print("  \033[0;32m✓\033[0m Plugins enabled")
PYTHON_SCRIPT

# Cleanup temp directory
cd /
rm -rf "$TEMP_DIR"

# Google Authentication
echo ""
echo -e "${BLUE}[Step 5/6] Google Authentication...${NC}"

if [[ "$SKIP_GOOGLE_AUTH" == "true" ]]; then
    echo -e "${YELLOW}⚠${NC} Skipping Google authentication (--skip-google-auth)"
elif [[ -z "$GCLOUD_PATH" ]]; then
    echo -e "${YELLOW}⚠${NC} gcloud not found. Skipping authentication."
    echo "  After restarting terminal, run: gcloud auth application-default login"
else
    # Check if already authenticated
    if $GCLOUD_PATH auth application-default print-access-token &> /dev/null; then
        ACCOUNT=$($GCLOUD_PATH config get-value account 2>/dev/null || echo "unknown")
        echo -e "${GREEN}✓${NC} Already authenticated as: $ACCOUNT"
    else
        echo "Opening browser for Google authentication..."
        echo "Please sign in with your Databricks Google account."
        echo ""

        # Run authentication with required scopes
        $GCLOUD_PATH auth application-default login \
            --scopes=https://www.googleapis.com/auth/drive,https://www.googleapis.com/auth/documents,https://www.googleapis.com/auth/spreadsheets,https://www.googleapis.com/auth/presentations,https://www.googleapis.com/auth/gmail.modify,https://www.googleapis.com/auth/calendar,https://www.googleapis.com/auth/cloud-platform \
            2>/dev/null || {
                echo -e "${YELLOW}⚠${NC} Authentication skipped or failed."
                echo "  You can authenticate later with: gcloud auth application-default login"
            }

        if $GCLOUD_PATH auth application-default print-access-token &> /dev/null; then
            ACCOUNT=$($GCLOUD_PATH config get-value account 2>/dev/null || echo "unknown")
            echo -e "${GREEN}✓${NC} Authenticated as: $ACCOUNT"
        fi
    fi
fi

# Verify GCP Access
echo ""
echo -e "${BLUE}[Step 6/6] Verifying GCP Access...${NC}"

if [[ -z "$GCLOUD_PATH" ]] || ! $GCLOUD_PATH auth application-default print-access-token &> /dev/null; then
    echo -e "${YELLOW}⚠${NC} Cannot verify GCP access (not authenticated)"
else
    TOKEN=$($GCLOUD_PATH auth application-default print-access-token 2>/dev/null)

    # Test Drive API with quota project
    RESPONSE=$(curl -s -w "\n%{http_code}" \
        "https://www.googleapis.com/drive/v3/about?fields=user" \
        -H "Authorization: Bearer $TOKEN" \
        -H "x-goog-user-project: $GCP_PROJECT" 2>/dev/null)

    HTTP_CODE=$(echo "$RESPONSE" | tail -1)

    if [[ "$HTTP_CODE" == "200" ]]; then
        echo -e "${GREEN}✓${NC} GCP project access verified: $GCP_PROJECT"

        # Quick API check
        APIS_OK=true
        for api in "drive" "docs" "sheets" "gmail" "calendar"; do
            case $api in
                drive) url="https://www.googleapis.com/drive/v3/about?fields=user" ;;
                docs) url="https://docs.googleapis.com/v1/documents/1" ;;
                sheets) url="https://sheets.googleapis.com/v4/spreadsheets/1" ;;
                gmail) url="https://gmail.googleapis.com/gmail/v1/users/me/profile" ;;
                calendar) url="https://www.googleapis.com/calendar/v3/users/me/calendarList?maxResults=1" ;;
            esac

            CODE=$(curl -s -o /dev/null -w "%{http_code}" "$url" \
                -H "Authorization: Bearer $TOKEN" \
                -H "x-goog-user-project: $GCP_PROJECT" 2>/dev/null)

            # 200, 400, 404 all indicate API is accessible
            if [[ "$CODE" == "200" || "$CODE" == "400" || "$CODE" == "404" ]]; then
                echo -e "  ${GREEN}✓${NC} $api API"
            else
                echo -e "  ${RED}✗${NC} $api API (HTTP $CODE)"
                APIS_OK=false
            fi
        done
    else
        echo -e "${RED}✗${NC} Cannot access GCP project: $GCP_PROJECT (HTTP $HTTP_CODE)"
        echo ""
        echo "You may need to request access to this project."
        echo "Or use a different project with: --gcp-project YOUR_PROJECT"
    fi
fi

# Final Summary
echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo "Installed plugins:"
for plugin in "${PLUGINS[@]}"; do
    echo "  - $plugin"
done
echo ""
echo "GCP Quota Project: $GCP_PROJECT"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Restart Claude Code to load plugins"
echo "  2. Use skills like: /gmail, /google-docs, /databricks-query"
echo ""
echo "For other authentications (run inside Claude Code):"
echo "  /databricks-authentication"
echo "  /salesforce-authentication"
echo ""
