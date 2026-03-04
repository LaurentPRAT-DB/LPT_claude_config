#!/bin/bash
#
# Build and run the FE Vibe install connectivity test
#
# Usage:
#   ./run-test.sh                    # Basic connectivity test
#   ./run-test.sh --with-auth        # Test with Google authentication
#   ./run-test.sh --shell            # Open shell in container
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_NAME="fe-vibe-test"

# Parse arguments
WITH_AUTH=false
OPEN_SHELL=false
GCP_PROJECT="${GCP_PROJECT:-gcp-sandbox-field-eng}"

while [[ $# -gt 0 ]]; do
    case $1 in
        --with-auth)
            WITH_AUTH=true
            shift
            ;;
        --shell)
            OPEN_SHELL=true
            shift
            ;;
        --gcp-project)
            GCP_PROJECT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: ./run-test.sh [--with-auth] [--shell] [--gcp-project PROJECT]"
            exit 1
            ;;
    esac
done

echo "================================================"
echo "  FE Vibe Install Test Container"
echo "================================================"
echo ""

# Build image
echo "Building test container..."
docker build -t "$IMAGE_NAME" "$SCRIPT_DIR" --quiet
echo "✓ Container built"
echo ""

# Prepare docker run command
DOCKER_ARGS=(
    "--rm"
    "--network" "host"
    "-e" "GCP_PROJECT=$GCP_PROJECT"
)

# Add authentication if requested
if [[ "$WITH_AUTH" == "true" ]]; then
    echo "Getting Google access token..."
    if command -v gcloud &> /dev/null; then
        TOKEN=$(gcloud auth application-default print-access-token 2>/dev/null || echo "")
        if [[ -n "$TOKEN" ]]; then
            DOCKER_ARGS+=("-e" "GOOGLE_TOKEN=$TOKEN")
            echo "✓ Token obtained"
        else
            echo "⚠ Could not get token. Run: gcloud auth application-default login"
        fi
    else
        echo "⚠ gcloud not installed. Skipping authentication test."
    fi
    echo ""
fi

# Run container
if [[ "$OPEN_SHELL" == "true" ]]; then
    echo "Opening shell in container..."
    echo "Run '/test/test-install.sh' to execute tests"
    echo ""
    docker run -it "${DOCKER_ARGS[@]}" "$IMAGE_NAME" /bin/bash
else
    echo "Running connectivity tests..."
    echo ""
    docker run "${DOCKER_ARGS[@]}" "$IMAGE_NAME"
fi
