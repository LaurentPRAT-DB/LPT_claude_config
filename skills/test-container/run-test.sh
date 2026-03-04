#!/bin/bash
#
# Build and run the FE Vibe installation simulation in a container
# Simulates a colleague's fresh laptop environment
#
# Usage:
#   ./run-test.sh                    # Full installation simulation
#   ./run-test.sh --shell            # Open shell in container for debugging
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_NAME="fe-vibe-colleague-sim"

# Parse arguments
OPEN_SHELL=false
GCP_PROJECT="${GCP_PROJECT:-gcp-sandbox-field-eng}"

while [[ $# -gt 0 ]]; do
    case $1 in
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
            echo "Usage: ./run-test.sh [--shell] [--gcp-project PROJECT]"
            exit 1
            ;;
    esac
done

echo "================================================"
echo "  FE Vibe Installation Simulation"
echo "  (Colleague's Fresh Laptop)"
echo "================================================"
echo ""

# Check if Docker is running
if ! docker info &>/dev/null; then
    echo "Error: Docker is not running."
    echo "Please start Docker Desktop and try again."
    exit 1
fi

# Build image
echo "Building simulation container..."
docker build -t "$IMAGE_NAME" "$SCRIPT_DIR" --quiet
echo "✓ Container built"
echo ""

# Prepare docker run command
DOCKER_ARGS=(
    "--rm"
    "--network" "host"
    "-e" "GCP_PROJECT=$GCP_PROJECT"
)

# Run container
if [[ "$OPEN_SHELL" == "true" ]]; then
    echo "Opening shell in container..."
    echo "Run './test-full-install.sh' to execute tests"
    echo ""
    docker run -it "${DOCKER_ARGS[@]}" "$IMAGE_NAME" /bin/bash
else
    echo "Running full installation simulation..."
    echo ""
    docker run "${DOCKER_ARGS[@]}" "$IMAGE_NAME"
fi
