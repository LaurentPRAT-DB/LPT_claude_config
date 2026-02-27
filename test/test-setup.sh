#!/bin/bash

# Test script for Claude Code setup
# Usage: ./test-setup.sh [build|run|shell|clean]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="claude-setup-test"

case "${1:-build-and-run}" in
    build)
        echo "Building test container..."
        docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
        echo "Build complete!"
        ;;

    run)
        echo "Running setup script in container..."
        docker run --rm -it "$IMAGE_NAME"
        ;;

    shell)
        echo "Opening shell in container (for manual testing)..."
        docker run --rm -it "$IMAGE_NAME" /bin/bash
        ;;

    build-and-run)
        echo "Building and running test container..."
        docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
        echo ""
        echo "=== Running setup script ==="
        docker run --rm -it "$IMAGE_NAME"
        ;;

    clean)
        echo "Removing test image..."
        docker rmi "$IMAGE_NAME" 2>/dev/null || true
        echo "Cleaned up!"
        ;;

    *)
        echo "Usage: $0 [build|run|shell|build-and-run|clean]"
        echo ""
        echo "  build         - Build the Docker image"
        echo "  run           - Run the setup script in container"
        echo "  shell         - Open a shell for manual testing"
        echo "  build-and-run - Build and run (default)"
        echo "  clean         - Remove the Docker image"
        exit 1
        ;;
esac
