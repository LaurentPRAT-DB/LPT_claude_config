#!/bin/bash
#
# Test connectivity for FE Vibe Offline Installer (runs directly on macOS)
# No Docker required - tests all network endpoints
#
# Usage:
#   ./test-connectivity.sh                    # Basic test
#   ./test-connectivity.sh --with-auth        # Include authenticated GCP tests
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
GCP_PROJECT="${GCP_PROJECT:-gcp-sandbox-field-eng}"
WITH_AUTH=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --with-auth)
            WITH_AUTH=true
            shift
            ;;
        --gcp-project)
            GCP_PROJECT="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

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
echo -e "${BLUE}  FE Vibe Install - Connectivity Test${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
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

# Test plugins package download (HTTP only, no git required)
echo "Testing plugins package download..."
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
if curl -fsSL "$PACKAGE_URL" -o fe-vibe-plugins.tar.gz 2>/dev/null; then
    FILE_SIZE=$(ls -lh fe-vibe-plugins.tar.gz | awk '{print $5}')
    pass "Plugins package downloaded ($FILE_SIZE)"

    # Test extraction
    if tar -xzf fe-vibe-plugins.tar.gz 2>/dev/null; then
        PLUGIN_COUNT=$(find . -maxdepth 1 -type d | wc -l | tr -d ' ')
        pass "Package extracted ($((PLUGIN_COUNT - 1)) plugins)"
    else
        fail "Failed to extract package"
    fi
else
    fail "Failed to download plugins package"
fi
cd ~
rm -rf "$TEMP_DIR"

# ============================================
# Test 2: Download installer script
# ============================================
echo ""
echo -e "${BLUE}[Test 2] Installer Script Download${NC}"

SCRIPT_CONTENT=$(curl -fsSL "$REPO_RAW/install-fe-vibe-offline.sh" 2>/dev/null)
if [[ -n "$SCRIPT_CONTENT" ]]; then
    SCRIPT_LINES=$(echo "$SCRIPT_CONTENT" | wc -l | tr -d ' ')
    pass "Installer script downloaded ($SCRIPT_LINES lines)"

    # Verify script structure
    if echo "$SCRIPT_CONTENT" | grep -q "FE Vibe"; then
        pass "Script header verified"
    else
        fail "Script header missing"
    fi

    if echo "$SCRIPT_CONTENT" | grep -q "gcp-sandbox-field-eng"; then
        pass "Default GCP project found"
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
# Test 3: GCP API Connectivity (unauthenticated)
# ============================================
echo ""
echo -e "${BLUE}[Test 3] GCP API Connectivity (network test)${NC}"

declare -a API_NAMES=("Drive" "Docs" "Sheets" "Slides" "Gmail" "Calendar" "OAuth")
declare -a API_URLS=(
    "https://www.googleapis.com/drive/v3/about"
    "https://docs.googleapis.com/v1/documents/1"
    "https://sheets.googleapis.com/v4/spreadsheets/1"
    "https://slides.googleapis.com/v1/presentations/1"
    "https://gmail.googleapis.com/gmail/v1/users/me/profile"
    "https://www.googleapis.com/calendar/v3/users/me/calendarList"
    "https://oauth2.googleapis.com/tokeninfo"
)

for i in "${!API_NAMES[@]}"; do
    api_name="${API_NAMES[$i]}"
    url="${API_URLS[$i]}"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)

    # 401/403 means API is reachable but auth required (expected)
    if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "400" || "$HTTP_CODE" == "401" || "$HTTP_CODE" == "403" || "$HTTP_CODE" == "404" ]]; then
        pass "$api_name API reachable (HTTP $HTTP_CODE)"
    else
        fail "$api_name API unreachable (HTTP $HTTP_CODE)"
    fi
done

# ============================================
# Test 4: GCP Authenticated Access
# ============================================
echo ""
echo -e "${BLUE}[Test 4] GCP Authenticated Access${NC}"

if [[ "$WITH_AUTH" == "true" ]]; then
    if command -v gcloud &> /dev/null; then
        TOKEN=$(gcloud auth application-default print-access-token 2>/dev/null || echo "")
        if [[ -n "$TOKEN" ]]; then
            # Test Drive API with quota project
            RESPONSE=$(curl -s -w "\n%{http_code}" \
                "https://www.googleapis.com/drive/v3/about?fields=user" \
                -H "Authorization: Bearer $TOKEN" \
                -H "x-goog-user-project: $GCP_PROJECT" 2>/dev/null)

            HTTP_CODE=$(echo "$RESPONSE" | tail -1)
            BODY=$(echo "$RESPONSE" | sed '$d')

            if [[ "$HTTP_CODE" == "200" ]]; then
                USER_EMAIL=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin).get('user',{}).get('emailAddress','unknown'))" 2>/dev/null || echo "unknown")
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
                        -H "Authorization: Bearer $TOKEN" \
                        -H "x-goog-user-project: $GCP_PROJECT" 2>/dev/null)

                    if [[ "$CODE" == "200" || "$CODE" == "400" || "$CODE" == "404" ]]; then
                        pass "$api_name API authenticated"
                    else
                        fail "$api_name API access denied (HTTP $CODE)"
                    fi
                done
            else
                fail "GCP project access failed (HTTP $HTTP_CODE)"
                echo "  Check access to: $GCP_PROJECT"
            fi
        else
            fail "No access token available"
            echo "  Run: gcloud auth application-default login"
        fi
    else
        warn "gcloud not installed - skipping auth tests"
    fi
else
    warn "Auth test skipped (use --with-auth to enable)"
fi

# ============================================
# Test 5: External Dependencies
# ============================================
echo ""
echo -e "${BLUE}[Test 5] External Dependencies${NC}"

# Test Homebrew
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" 2>/dev/null)
if [[ "$HTTP_CODE" == "200" ]]; then
    pass "Homebrew installer accessible"
else
    fail "Homebrew installer not accessible (HTTP $HTTP_CODE)"
fi

# Test Google Cloud SDK (follow redirects)
HTTP_CODE=$(curl -sL -o /dev/null -w "%{http_code}" "https://cloud.google.com/sdk/docs/install" 2>/dev/null)
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
    echo "Your colleague can run:"
    echo "  curl -fsSL $REPO_RAW/install-fe-vibe-offline.sh | bash"
else
    echo -e "${RED}  $FAILURES test(s) failed${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
    echo "Check VPN connection and firewall settings."
fi
echo ""

exit $FAILURES
