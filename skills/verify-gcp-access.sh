#!/bin/bash
#
# Verify GCP Access for Google Claude Skills
# Checks authentication, quota project access, and API availability
#
# Usage:
#   ./verify-gcp-access.sh [PROJECT_ID]
#   Default project: gcp-sandbox-field-eng
#

set -e

# Default project
DEFAULT_PROJECT="gcp-sandbox-field-eng"
PROJECT="${1:-$DEFAULT_PROJECT}"

echo "================================================"
echo "  GCP Access Verification for Google Skills"
echo "================================================"
echo ""
echo "Checking project: $PROJECT"
echo ""

# Track failures
FAILURES=0

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

# 1. Check gcloud installation
echo "1. Checking gcloud CLI..."
if command -v gcloud &> /dev/null; then
    GCLOUD_VERSION=$(gcloud --version 2>/dev/null | head -1)
    pass "gcloud installed: $GCLOUD_VERSION"
else
    fail "gcloud not installed"
    echo ""
    echo "Install with: brew install --cask google-cloud-sdk"
    exit 1
fi

# 2. Check authentication
echo ""
echo "2. Checking authentication..."
if gcloud auth application-default print-access-token &> /dev/null; then
    ACCOUNT=$(gcloud config get-value account 2>/dev/null)
    pass "Authenticated as: $ACCOUNT"
    TOKEN=$(gcloud auth application-default print-access-token 2>/dev/null)
else
    fail "Not authenticated with Application Default Credentials"
    echo ""
    echo "Run: gcloud auth application-default login"
    exit 1
fi

# 3. Check quota project access
echo ""
echo "3. Checking quota project access..."

# Try to access the project
PROJECT_CHECK=$(curl -s -w "%{http_code}" -o /tmp/gcp_project_check.json \
    "https://cloudresourcemanager.googleapis.com/v1/projects/$PROJECT" \
    -H "Authorization: Bearer $TOKEN" \
    -H "x-goog-user-project: $PROJECT" 2>/dev/null)

if [[ "$PROJECT_CHECK" == "200" ]]; then
    pass "Access to project: $PROJECT"
else
    fail "Cannot access project: $PROJECT (HTTP $PROJECT_CHECK)"
    if [[ -f /tmp/gcp_project_check.json ]]; then
        ERROR=$(cat /tmp/gcp_project_check.json | grep -o '"message":"[^"]*"' | head -1 || echo "")
        if [[ -n "$ERROR" ]]; then
            echo "   Error: $ERROR"
        fi
    fi
fi

# 4. Check required APIs
echo ""
echo "4. Checking API access..."

declare -A APIS=(
    ["Google Drive"]="https://www.googleapis.com/drive/v3/about?fields=user"
    ["Google Docs"]="https://docs.googleapis.com/v1/documents/1"
    ["Google Sheets"]="https://sheets.googleapis.com/v4/spreadsheets/1"
    ["Google Slides"]="https://slides.googleapis.com/v1/presentations/1"
    ["Gmail"]="https://gmail.googleapis.com/gmail/v1/users/me/profile"
    ["Google Calendar"]="https://www.googleapis.com/calendar/v3/users/me/calendarList?maxResults=1"
)

for api_name in "Google Drive" "Google Docs" "Google Sheets" "Google Slides" "Gmail" "Google Calendar"; do
    url="${APIS[$api_name]}"

    RESPONSE=$(curl -s -w "\n%{http_code}" \
        "$url" \
        -H "Authorization: Bearer $TOKEN" \
        -H "x-goog-user-project: $PROJECT" 2>/dev/null)

    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | sed '$d')

    # 200 = success, 404 = API works but resource not found (expected), 400 = API works but bad request
    if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "404" || "$HTTP_CODE" == "400" ]]; then
        pass "$api_name API"
    elif [[ "$HTTP_CODE" == "403" ]]; then
        # Check if it's a permission issue or API not enabled
        if echo "$BODY" | grep -q "API has not been used"; then
            fail "$api_name API - Not enabled in project"
        elif echo "$BODY" | grep -q "does not have"; then
            fail "$api_name API - Permission denied"
        else
            fail "$api_name API - Access forbidden (HTTP 403)"
        fi
    elif [[ "$HTTP_CODE" == "401" ]]; then
        fail "$api_name API - Authentication failed"
    else
        fail "$api_name API - HTTP $HTTP_CODE"
    fi
done

# 5. Check token scopes
echo ""
echo "5. Checking token scopes..."

TOKEN_INFO=$(curl -s "https://oauth2.googleapis.com/tokeninfo?access_token=$TOKEN" 2>/dev/null)

REQUIRED_SCOPES=(
    "https://www.googleapis.com/auth/drive"
    "https://www.googleapis.com/auth/documents"
    "https://www.googleapis.com/auth/spreadsheets"
    "https://www.googleapis.com/auth/presentations"
    "https://www.googleapis.com/auth/gmail"
    "https://www.googleapis.com/auth/calendar"
)

SCOPE_NAMES=(
    "Drive"
    "Docs"
    "Sheets"
    "Slides"
    "Gmail"
    "Calendar"
)

CURRENT_SCOPES=$(echo "$TOKEN_INFO" | grep -o '"scope":"[^"]*"' | sed 's/"scope":"//;s/"$//' || echo "")

for i in "${!REQUIRED_SCOPES[@]}"; do
    scope="${REQUIRED_SCOPES[$i]}"
    name="${SCOPE_NAMES[$i]}"

    # Check for exact match or broader scope
    if echo "$CURRENT_SCOPES" | grep -q "$scope\|googleapis.com/auth/cloud-platform"; then
        pass "$name scope"
    else
        # Gmail has multiple possible scopes
        if [[ "$name" == "Gmail" ]] && echo "$CURRENT_SCOPES" | grep -q "gmail"; then
            pass "$name scope"
        else
            warn "$name scope - May need to re-authenticate"
        fi
    fi
done

# Summary
echo ""
echo "================================================"
if [[ $FAILURES -eq 0 ]]; then
    echo -e "${GREEN}  All checks passed!${NC}"
    echo "================================================"
    echo ""
    echo "Your GCP access is configured correctly."
    echo "You can use all Google skills:"
    echo "  /gmail, /google-docs, /google-sheets-creator,"
    echo "  /google-slides-creator, /google-calendar"
else
    echo -e "${RED}  $FAILURES check(s) failed${NC}"
    echo "================================================"
    echo ""
    echo "To fix issues:"
    echo ""
    if ! gcloud auth application-default print-access-token &> /dev/null; then
        echo "1. Authenticate:"
        echo "   gcloud auth application-default login \\"
        echo "     --scopes=https://www.googleapis.com/auth/drive,https://www.googleapis.com/auth/documents,https://www.googleapis.com/auth/spreadsheets,https://www.googleapis.com/auth/presentations,https://www.googleapis.com/auth/gmail.modify,https://www.googleapis.com/auth/calendar"
    fi
    echo ""
    echo "2. If APIs are not enabled, enable them in GCP Console:"
    echo "   https://console.cloud.google.com/apis/library?project=$PROJECT"
    echo ""
    echo "3. If permission denied, request access to project: $PROJECT"
fi
echo ""

# Cleanup
rm -f /tmp/gcp_project_check.json

exit $FAILURES
