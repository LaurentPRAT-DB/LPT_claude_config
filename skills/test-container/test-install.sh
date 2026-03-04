#!/bin/bash
#
# Test script for FE Vibe Offline Installer
# Tests network connectivity and downloads without requiring macOS
#

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO_URL="https://github.com/LaurentPRAT-DB/LPT_claude_config"
REPO_RAW="https://raw.githubusercontent.com/LaurentPRAT-DB/LPT_claude_config/main/skills"
GCP_PROJECT="${GCP_PROJECT:-gcp-sandbox-field-eng}"

FAILURES=0

pass() {
    echo -e "${GREEN}✓${NC} $1"
}

fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILURES++))
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  FE Vibe Install Script - Connectivity Test${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo "Testing from: $(hostname)"
echo "GCP Project: $GCP_PROJECT"
echo ""

# ============================================
# Test 1: GitHub connectivity
# ============================================
echo -e "${BLUE}[Test 1] GitHub Connectivity${NC}"

# Test raw content access
echo "Testing raw.githubusercontent.com..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$REPO_RAW/install-fe-vibe-offline.sh" 2>/dev/null)
if [[ "$HTTP_CODE" == "200" ]]; then
    pass "raw.githubusercontent.com accessible (HTTP $HTTP_CODE)"
else
    fail "raw.githubusercontent.com not accessible (HTTP $HTTP_CODE)"
fi

# Test GitHub API (403 = rate limited, OK for anonymous)
echo "Testing api.github.com..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://api.github.com/repos/LaurentPRAT-DB/LPT_claude_config" 2>/dev/null)
if [[ "$HTTP_CODE" == "200" ]]; then
    pass "GitHub API accessible (HTTP $HTTP_CODE)"
elif [[ "$HTTP_CODE" == "403" ]]; then
    warn "GitHub API rate-limited (HTTP $HTTP_CODE) - OK, installer uses git clone"
else
    fail "GitHub API not accessible (HTTP $HTTP_CODE)"
fi

# Test git clone capability
echo "Testing git clone (sparse checkout)..."
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
if git clone --depth 1 --filter=blob:none --sparse "$REPO_URL" repo 2>/dev/null; then
    cd repo
    if git sparse-checkout set skills/fe-vibe-export 2>/dev/null; then
        PLUGIN_COUNT=$(find skills/fe-vibe-export -type d -maxdepth 1 2>/dev/null | wc -l)
        pass "Git sparse checkout works ($PLUGIN_COUNT directories)"
    else
        fail "Git sparse checkout failed"
    fi
else
    fail "Git clone failed"
fi
cd /test
rm -rf "$TEMP_DIR"

# ============================================
# Test 2: Download installer script
# ============================================
echo ""
echo -e "${BLUE}[Test 2] Installer Script Download${NC}"

SCRIPT_CONTENT=$(curl -fsSL "$REPO_RAW/install-fe-vibe-offline.sh" 2>/dev/null)
if [[ -n "$SCRIPT_CONTENT" ]]; then
    SCRIPT_LINES=$(echo "$SCRIPT_CONTENT" | wc -l)
    pass "Installer script downloaded ($SCRIPT_LINES lines)"

    # Verify script structure
    if echo "$SCRIPT_CONTENT" | grep -q "FE Vibe"; then
        pass "Script header verified"
    else
        fail "Script header missing"
    fi

    if echo "$SCRIPT_CONTENT" | grep -q "gcp-sandbox-field-eng"; then
        pass "Default GCP project found in script"
    else
        warn "Default GCP project not found"
    fi

    if echo "$SCRIPT_CONTENT" | grep -q "\-\-gcp-project"; then
        pass "GCP project flag supported"
    else
        fail "GCP project flag not found"
    fi
else
    fail "Failed to download installer script"
fi

# ============================================
# Test 3: GCP API Connectivity (without auth)
# ============================================
echo ""
echo -e "${BLUE}[Test 3] GCP API Connectivity (unauthenticated)${NC}"

# These tests verify network connectivity to GCP APIs
# They will return 401/403 without auth, but that proves connectivity

declare -A GCP_APIS=(
    ["Drive"]="https://www.googleapis.com/drive/v3/about"
    ["Docs"]="https://docs.googleapis.com/v1/documents/1"
    ["Sheets"]="https://sheets.googleapis.com/v4/spreadsheets/1"
    ["Slides"]="https://slides.googleapis.com/v1/presentations/1"
    ["Gmail"]="https://gmail.googleapis.com/gmail/v1/users/me/profile"
    ["Calendar"]="https://www.googleapis.com/calendar/v3/users/me/calendarList"
    ["OAuth"]="https://oauth2.googleapis.com/tokeninfo"
)

for api_name in "Drive" "Docs" "Sheets" "Slides" "Gmail" "Calendar" "OAuth"; do
    url="${GCP_APIS[$api_name]}"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)

    # 401/403 means API is reachable but auth required (expected)
    # 200/400/404 means API is reachable
    if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "400" || "$HTTP_CODE" == "401" || "$HTTP_CODE" == "403" || "$HTTP_CODE" == "404" ]]; then
        pass "$api_name API reachable (HTTP $HTTP_CODE)"
    else
        fail "$api_name API unreachable (HTTP $HTTP_CODE)"
    fi
done

# ============================================
# Test 4: GCP Authenticated Access (if token provided)
# ============================================
echo ""
echo -e "${BLUE}[Test 4] GCP Authenticated Access${NC}"

if [[ -n "$GOOGLE_TOKEN" ]]; then
    echo "Using provided GOOGLE_TOKEN..."

    # Test Drive API with quota project
    RESPONSE=$(curl -s -w "\n%{http_code}" \
        "https://www.googleapis.com/drive/v3/about?fields=user" \
        -H "Authorization: Bearer $GOOGLE_TOKEN" \
        -H "x-goog-user-project: $GCP_PROJECT" 2>/dev/null)

    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | sed '$d')

    if [[ "$HTTP_CODE" == "200" ]]; then
        USER_EMAIL=$(echo "$BODY" | jq -r '.user.emailAddress // "unknown"' 2>/dev/null)
        pass "Authenticated as: $USER_EMAIL"
        pass "GCP project access: $GCP_PROJECT"

        # Test all APIs with auth
        for api_name in "Drive" "Docs" "Sheets" "Gmail" "Calendar"; do
            case $api_name in
                Drive) url="https://www.googleapis.com/drive/v3/about?fields=user" ;;
                Docs) url="https://docs.googleapis.com/v1/documents/1" ;;
                Sheets) url="https://sheets.googleapis.com/v4/spreadsheets/1" ;;
                Gmail) url="https://gmail.googleapis.com/gmail/v1/users/me/profile" ;;
                Calendar) url="https://www.googleapis.com/calendar/v3/users/me/calendarList?maxResults=1" ;;
            esac

            CODE=$(curl -s -o /dev/null -w "%{http_code}" "$url" \
                -H "Authorization: Bearer $GOOGLE_TOKEN" \
                -H "x-goog-user-project: $GCP_PROJECT" 2>/dev/null)

            if [[ "$CODE" == "200" || "$CODE" == "400" || "$CODE" == "404" ]]; then
                pass "$api_name API authenticated access"
            else
                fail "$api_name API access denied (HTTP $CODE)"
            fi
        done
    else
        fail "Authentication failed (HTTP $HTTP_CODE)"
        echo "  Response: $BODY"
    fi
elif [[ -f "/credentials/application_default_credentials.json" ]]; then
    warn "Credentials file found but token generation requires gcloud"
    echo "  Mount token directly with: -e GOOGLE_TOKEN=\$(gcloud auth application-default print-access-token)"
else
    warn "No authentication token provided"
    echo "  To test authenticated access, run with:"
    echo "  docker run --network host -e GOOGLE_TOKEN=\$(gcloud auth application-default print-access-token) <image>"
fi

# ============================================
# Test 5: Homebrew URLs (for reference)
# ============================================
echo ""
echo -e "${BLUE}[Test 5] External Dependencies${NC}"

# Test Homebrew (macOS would need this)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" 2>/dev/null)
if [[ "$HTTP_CODE" == "200" ]]; then
    pass "Homebrew installer accessible"
else
    warn "Homebrew installer not accessible (HTTP $HTTP_CODE) - OK for Linux"
fi

# Test Google Cloud SDK download page
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://cloud.google.com/sdk/docs/install" 2>/dev/null)
if [[ "$HTTP_CODE" == "200" ]]; then
    pass "Google Cloud SDK docs accessible"
else
    fail "Google Cloud SDK docs not accessible (HTTP $HTTP_CODE)"
fi

# ============================================
# Summary
# ============================================
echo ""
echo -e "${BLUE}================================================${NC}"
if [[ $FAILURES -eq 0 ]]; then
    echo -e "${GREEN}  All connectivity tests passed!${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
    echo "The install script should work from this network."
    echo ""
    echo "To run the actual installation on macOS:"
    echo "  curl -fsSL $REPO_RAW/install-fe-vibe-offline.sh | bash"
else
    echo -e "${RED}  $FAILURES test(s) failed${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
    echo "Some connectivity issues detected."
    echo "Check VPN connection and firewall settings."
fi
echo ""

exit $FAILURES
