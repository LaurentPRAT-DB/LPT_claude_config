#!/bin/bash
#
# Test FE Vibe Installer in a Fresh macOS User Account
# Creates isolated test user, runs installer, verifies, then cleans up
#
# Usage:
#   sudo ./test-fresh-user.sh           # Full test with cleanup
#   sudo ./test-fresh-user.sh --keep    # Keep user after test (for debugging)
#   sudo ./test-fresh-user.sh --cleanup # Only cleanup (if previous run failed)
#   ./test-fresh-user.sh --check-email colleague@databricks.com  # Check GCP access (no sudo)
#

set -e

# Configuration
TEST_USER="fevibe_test"
TEST_UID="599"  # Use a UID unlikely to conflict
TEST_HOME="/Users/$TEST_USER"
INSTALLER_URL="https://raw.githubusercontent.com/LaurentPRAT-DB/LPT_claude_config/main/skills/install-fe-vibe-offline.sh"
GCP_PROJECT="${GCP_PROJECT:-gcp-sandbox-field-eng}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments first (before root check, since --check-email doesn't need root)
KEEP_USER=false
CLEANUP_ONLY=false
CHECK_EMAIL=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --keep)
            KEEP_USER=true
            shift
            ;;
        --cleanup)
            CLEANUP_ONLY=true
            shift
            ;;
        --check-email)
            CHECK_EMAIL="$2"
            shift 2
            ;;
        --gcp-project)
            GCP_PROJECT="$2"
            shift 2
            ;;
        --help|-h)
            echo "Test FE Vibe Installer in Fresh macOS User"
            echo ""
            echo "Usage:"
            echo "  sudo $0 [OPTIONS]              # Full installer test (requires sudo)"
            echo "  $0 --check-email EMAIL         # Check GCP access for email (no sudo)"
            echo ""
            echo "Options:"
            echo "  --keep                Keep test user after completion (for debugging)"
            echo "  --cleanup             Only run cleanup (remove test user)"
            echo "  --check-email EMAIL   Check if EMAIL has GCP project access"
            echo "  --gcp-project PROJECT GCP project to check (default: gcp-sandbox-field-eng)"
            echo "  --help                Show this help"
            echo ""
            echo "Examples:"
            echo "  sudo $0                                    # Run full test"
            echo "  $0 --check-email john.doe@databricks.com   # Check colleague's access"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# ============================================
# Check Email Mode (no sudo required)
# ============================================
if [[ -n "$CHECK_EMAIL" ]]; then
    # Disable exit on error for this section (some commands may fail gracefully)
    set +e

    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}  GCP Access Check for: $CHECK_EMAIL${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
    echo "GCP Project: $GCP_PROJECT"
    echo ""

    # Check if we have gcloud and are authenticated
    if ! command -v gcloud &> /dev/null; then
        echo -e "${RED}Error: gcloud not found. Install it first.${NC}"
        exit 1
    fi

    TOKEN=$(gcloud auth application-default print-access-token 2>/dev/null || echo "")
    if [[ -z "$TOKEN" ]]; then
        echo -e "${RED}Error: Not authenticated. Run: gcloud auth application-default login${NC}"
        exit 1
    fi

    CURRENT_USER=$(gcloud config get-value account 2>/dev/null || echo "unknown")
    echo "Checking as: $CURRENT_USER"
    echo ""

    echo -e "${BLUE}[Step 1/3] Checking project IAM policy...${NC}"

    # Get IAM policy for the project
    IAM_POLICY=$(gcloud projects get-iam-policy "$GCP_PROJECT" --format=json 2>/dev/null || echo "")

    if [[ -z "$IAM_POLICY" ]]; then
        echo -e "${RED}✗ Cannot read IAM policy for $GCP_PROJECT${NC}"
        echo "  You may not have permission to view IAM policies."
        echo ""
        echo "Alternative: Ask your colleague to run this command themselves:"
        echo "  curl -fsSL https://raw.githubusercontent.com/LaurentPRAT-DB/LPT_claude_config/main/skills/verify-gcp-access.sh | bash"
        exit 1
    fi

    # Check if email is in the policy (direct binding)
    DIRECT_ACCESS=false
    if echo "$IAM_POLICY" | grep -q "$CHECK_EMAIL"; then
        DIRECT_ACCESS=true
        echo -e "${GREEN}✓${NC} Direct IAM binding found for $CHECK_EMAIL"

        # Show which roles
        ROLES=$(echo "$IAM_POLICY" | python3 -c "
import json, sys
policy = json.load(sys.stdin)
email = '$CHECK_EMAIL'
roles = []
for binding in policy.get('bindings', []):
    for member in binding.get('members', []):
        if email in member:
            roles.append(binding.get('role', 'unknown'))
print(', '.join(roles) if roles else 'none')
" 2>/dev/null || echo "unknown")
        echo "  Roles: $ROLES"
    else
        echo -e "${YELLOW}⚠${NC} No direct IAM binding for $CHECK_EMAIL"
    fi

    echo ""
    echo -e "${BLUE}[Step 2/3] Checking group memberships...${NC}"

    # Check for group bindings that might include the user
    GROUPS=$(echo "$IAM_POLICY" | python3 -c "
import json, sys
policy = json.load(sys.stdin)
groups = set()
for binding in policy.get('bindings', []):
    for member in binding.get('members', []):
        if member.startswith('group:'):
            groups.add(member.replace('group:', ''))
for g in sorted(groups):
    print(g)
" 2>/dev/null || echo "")

    if [[ -n "$GROUPS" ]]; then
        echo "Project has access via these groups:"
        # Use here-string to avoid subshell issues with pipe
        while IFS= read -r group; do
            [[ -n "$group" ]] && echo "  - $group"
        done <<< "$GROUPS"
        echo ""
        echo -e "${YELLOW}Note:${NC} Check if $CHECK_EMAIL is a member of any of these groups."
        echo "  (Databricks employees typically have inherited access via organization)"
    else
        echo "No group bindings found."
    fi

    echo ""
    echo -e "${BLUE}[Step 3/3] Checking domain-wide access...${NC}"

    # Check for domain bindings
    DOMAIN_ACCESS=$(echo "$IAM_POLICY" | grep -o 'domain:[^"]*' | head -1 || echo "")
    if [[ -n "$DOMAIN_ACCESS" ]]; then
        DOMAIN=$(echo "$DOMAIN_ACCESS" | cut -d: -f2)
        EMAIL_DOMAIN=$(echo "$CHECK_EMAIL" | cut -d@ -f2)

        if [[ "$EMAIL_DOMAIN" == "$DOMAIN" ]]; then
            echo -e "${GREEN}✓${NC} Domain-wide access: $DOMAIN"
            echo "  $CHECK_EMAIL matches the domain and should have access."
        else
            echo -e "${YELLOW}⚠${NC} Domain binding exists for: $DOMAIN"
            echo "  $CHECK_EMAIL is from $EMAIL_DOMAIN (different domain)"
        fi
    else
        echo "No domain-wide bindings found."
    fi

    # Check organization-level inheritance
    echo ""
    echo -e "${BLUE}Organization-level access:${NC}"
    EMAIL_DOMAIN=$(echo "$CHECK_EMAIL" | cut -d@ -f2)
    if [[ "$EMAIL_DOMAIN" == "databricks.com" ]]; then
        echo -e "${GREEN}✓${NC} $CHECK_EMAIL is a @databricks.com account"
        echo "  Databricks employees typically have inherited access from the organization."
        echo "  They should be able to use the Google skills."
    else
        echo -e "${YELLOW}⚠${NC} $CHECK_EMAIL is not a @databricks.com account"
        echo "  They may need explicit access to the project."
    fi

    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}  Recommendation${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""

    if [[ "$DIRECT_ACCESS" == "true" ]] || [[ "$EMAIL_DOMAIN" == "databricks.com" ]]; then
        echo -e "${GREEN}$CHECK_EMAIL should have access to $GCP_PROJECT${NC}"
        echo ""
        echo "They can verify by running:"
        echo "  curl -fsSL https://raw.githubusercontent.com/LaurentPRAT-DB/LPT_claude_config/main/skills/verify-gcp-access.sh | bash"
    else
        echo -e "${YELLOW}$CHECK_EMAIL may not have access to $GCP_PROJECT${NC}"
        echo ""
        echo "Options:"
        echo "  1. Use a different GCP project they have access to:"
        echo "     curl -fsSL .../install-fe-vibe-offline.sh | bash -s -- --gcp-project THEIR_PROJECT"
        echo ""
        echo "  2. Request access to $GCP_PROJECT"
        echo ""
        echo "  3. Have them verify their own access:"
        echo "     curl -fsSL https://raw.githubusercontent.com/LaurentPRAT-DB/LPT_claude_config/main/skills/verify-gcp-access.sh | bash"
    fi
    echo ""
    exit 0
fi

# ============================================
# Full Test Mode (requires root)
# ============================================

# Check root for full test
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Error: Full test must be run as root (sudo)${NC}"
    echo "Usage: sudo $0 [--keep|--cleanup]"
    echo ""
    echo "For GCP access check (no sudo): $0 --check-email EMAIL"
    exit 1
fi

# Cleanup function
cleanup_user() {
    echo ""
    echo -e "${BLUE}Cleaning up test user...${NC}"

    # Kill any processes owned by test user
    pkill -u "$TEST_USER" 2>/dev/null || true
    sleep 1

    # Remove user from Directory Services
    if dscl . -read "/Users/$TEST_USER" &>/dev/null; then
        dscl . -delete "/Users/$TEST_USER"
        echo -e "  ${GREEN}✓${NC} User removed from Directory Services"
    else
        echo -e "  ${YELLOW}⚠${NC} User not found in Directory Services"
    fi

    # Remove home directory
    if [[ -d "$TEST_HOME" ]]; then
        rm -rf "$TEST_HOME"
        echo -e "  ${GREEN}✓${NC} Home directory removed"
    else
        echo -e "  ${YELLOW}⚠${NC} Home directory not found"
    fi

    # Remove from admin group if added
    dseditgroup -o edit -d "$TEST_USER" -t user admin 2>/dev/null || true

    echo -e "${GREEN}Cleanup complete${NC}"
}

# If cleanup only, just clean and exit
if [[ "$CLEANUP_ONLY" == "true" ]]; then
    cleanup_user
    exit 0
fi

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  FE Vibe Installer - Fresh User Test${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo "Test user: $TEST_USER"
echo "Home: $TEST_HOME"
echo ""

# Check if test user already exists
if dscl . -read "/Users/$TEST_USER" &>/dev/null; then
    echo -e "${YELLOW}Warning: Test user already exists. Cleaning up first...${NC}"
    cleanup_user
fi

# ============================================
# Step 1: Create test user
# ============================================
echo -e "${BLUE}[Step 1/5] Creating test user...${NC}"

# Create user
dscl . -create "/Users/$TEST_USER"
dscl . -create "/Users/$TEST_USER" UserShell /bin/zsh
dscl . -create "/Users/$TEST_USER" RealName "FE Vibe Test User"
dscl . -create "/Users/$TEST_USER" UniqueID "$TEST_UID"
dscl . -create "/Users/$TEST_USER" PrimaryGroupID 20  # staff group
dscl . -create "/Users/$TEST_USER" NFSHomeDirectory "$TEST_HOME"

# Create home directory
mkdir -p "$TEST_HOME"
chown -R "$TEST_USER:staff" "$TEST_HOME"

# Set a random password (user won't need to login interactively)
RANDOM_PASS=$(openssl rand -base64 12)
dscl . -passwd "/Users/$TEST_USER" "$RANDOM_PASS"

echo -e "  ${GREEN}✓${NC} Test user created"

# ============================================
# Step 2: Run installer as test user
# ============================================
echo ""
echo -e "${BLUE}[Step 2/5] Running installer as test user...${NC}"
echo "  (with --skip-google-auth since browser auth not possible)"
echo ""

# Create installer script for the test user
cat > "$TEST_HOME/run_installer.sh" << 'INSTALLER_SCRIPT'
#!/bin/bash
set -e

# Set HOME explicitly
export HOME="$1"
cd "$HOME"

# Run the installer with skip-google-auth
curl -fsSL "$2" | bash -s -- --skip-google-auth

# Exit with installer's exit code
exit $?
INSTALLER_SCRIPT

chmod +x "$TEST_HOME/run_installer.sh"
chown "$TEST_USER:staff" "$TEST_HOME/run_installer.sh"

# Run as test user
if sudo -u "$TEST_USER" "$TEST_HOME/run_installer.sh" "$TEST_HOME" "$INSTALLER_URL"; then
    echo ""
    echo -e "  ${GREEN}✓${NC} Installer completed successfully"
    INSTALL_SUCCESS=true
else
    echo ""
    echo -e "  ${RED}✗${NC} Installer failed"
    INSTALL_SUCCESS=false
fi

# ============================================
# Step 3: Verify installation
# ============================================
echo ""
echo -e "${BLUE}[Step 3/5] Verifying installation...${NC}"

VERIFY_FAILURES=0

# Check Claude directory
if [[ -d "$TEST_HOME/.claude" ]]; then
    echo -e "  ${GREEN}✓${NC} ~/.claude directory exists"
else
    echo -e "  ${RED}✗${NC} ~/.claude directory missing"
    ((VERIFY_FAILURES++))
fi

# Check plugins cache
PLUGIN_DIR="$TEST_HOME/.claude/plugins/cache/fe-vibe"
if [[ -d "$PLUGIN_DIR" ]]; then
    PLUGIN_COUNT=$(find "$PLUGIN_DIR" -maxdepth 1 -type d | wc -l | tr -d ' ')
    PLUGIN_COUNT=$((PLUGIN_COUNT - 1))  # Subtract 1 for the directory itself
    echo -e "  ${GREEN}✓${NC} Plugins cache exists ($PLUGIN_COUNT plugins)"
else
    echo -e "  ${RED}✗${NC} Plugins cache missing"
    ((VERIFY_FAILURES++))
fi

# Check each expected plugin
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
echo "  Checking plugins:"
for plugin in "${PLUGINS[@]}"; do
    if [[ -d "$PLUGIN_DIR/$plugin" ]]; then
        echo -e "    ${GREEN}✓${NC} $plugin"
    else
        echo -e "    ${RED}✗${NC} $plugin (MISSING)"
        ((VERIFY_FAILURES++))
    fi
done

# Check settings.json
SETTINGS_FILE="$TEST_HOME/.claude/settings.json"
if [[ -f "$SETTINGS_FILE" ]]; then
    echo ""
    echo -e "  ${GREEN}✓${NC} settings.json exists"

    # Check if plugins are enabled
    ENABLED_COUNT=$(python3 -c "import json; s=json.load(open('$SETTINGS_FILE')); print(len(s.get('enabledPlugins', {})))" 2>/dev/null || echo "0")
    echo -e "  ${GREEN}✓${NC} $ENABLED_COUNT plugins enabled in settings"

    # Check permissions
    PERM_COUNT=$(python3 -c "import json; s=json.load(open('$SETTINGS_FILE')); print(len(s.get('permissions', {}).get('allow', [])))" 2>/dev/null || echo "0")
    echo -e "  ${GREEN}✓${NC} $PERM_COUNT permissions configured"
else
    echo -e "  ${RED}✗${NC} settings.json missing"
    ((VERIFY_FAILURES++))
fi

# ============================================
# Step 4: Check dependencies
# ============================================
echo ""
echo -e "${BLUE}[Step 4/5] Checking installed dependencies...${NC}"

# Check Homebrew (should be installed system-wide or in test user's path)
if sudo -u "$TEST_USER" bash -c 'command -v brew' &>/dev/null; then
    BREW_VERSION=$(sudo -u "$TEST_USER" bash -c 'brew --version 2>/dev/null | head -1' || echo "unknown")
    echo -e "  ${GREEN}✓${NC} Homebrew: $BREW_VERSION"
else
    echo -e "  ${YELLOW}⚠${NC} Homebrew not in test user's PATH (may be system-wide)"
fi

# Check gcloud
if sudo -u "$TEST_USER" bash -c 'command -v gcloud' &>/dev/null; then
    GCLOUD_VERSION=$(sudo -u "$TEST_USER" bash -c 'gcloud --version 2>/dev/null | head -1' || echo "unknown")
    echo -e "  ${GREEN}✓${NC} gcloud: $GCLOUD_VERSION"
else
    # Check common paths
    for path in "/opt/homebrew/bin/gcloud" "/usr/local/bin/gcloud"; do
        if [[ -f "$path" ]]; then
            echo -e "  ${GREEN}✓${NC} gcloud found at: $path"
            break
        fi
    done
fi

# ============================================
# Step 5: Summary and cleanup
# ============================================
echo ""
echo -e "${BLUE}[Step 5/5] Summary${NC}"
echo ""

if [[ "$INSTALL_SUCCESS" == "true" ]] && [[ $VERIFY_FAILURES -eq 0 ]]; then
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}  All tests passed!${NC}"
    echo -e "${GREEN}================================================${NC}"
    TEST_RESULT=0
else
    echo -e "${RED}================================================${NC}"
    if [[ "$INSTALL_SUCCESS" != "true" ]]; then
        echo -e "${RED}  Installer failed${NC}"
    fi
    if [[ $VERIFY_FAILURES -gt 0 ]]; then
        echo -e "${RED}  $VERIFY_FAILURES verification(s) failed${NC}"
    fi
    echo -e "${RED}================================================${NC}"
    TEST_RESULT=1
fi

echo ""
echo "Test user home: $TEST_HOME"
echo ""

# Cleanup unless --keep was specified
if [[ "$KEEP_USER" == "true" ]]; then
    echo -e "${YELLOW}Keeping test user for debugging.${NC}"
    echo "To cleanup later: sudo $0 --cleanup"
    echo ""
    echo "To inspect as test user:"
    echo "  sudo -u $TEST_USER -i"
    echo "  ls -la ~/.claude/"
else
    cleanup_user
fi

exit $TEST_RESULT
