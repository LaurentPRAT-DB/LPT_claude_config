#!/bin/bash
#
# FE Vibe Installer
# One-command installation for Databricks Field Engineering Claude Code plugins
#
# Usage: curl -fsSL https://raw.githubusercontent.com/LaurentPRAT-DB/LPT_claude_config/main/skills/install-fe-vibe.sh | bash
#    or: ./install-fe-vibe.sh
#

set -e

REPO="databricks-field-eng/vibe"

echo "================================================"
echo "  FE Vibe Installer"
echo "================================================"
echo ""

# Check for macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "Error: This installer only supports macOS"
    exit 1
fi

# Check/install Homebrew
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add to path for Apple Silicon
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    echo "✓ Homebrew installed"
fi

# Check/install GitHub CLI
if ! command -v gh &> /dev/null; then
    echo "Installing GitHub CLI..."
    brew install gh
else
    echo "✓ GitHub CLI installed"
fi

# Check GitHub authentication
echo ""
echo "Checking GitHub authentication..."
if ! gh auth status &> /dev/null; then
    echo ""
    echo "GitHub authentication required."
    echo "IMPORTANT: Select your Databricks EMU account (not personal GitHub)"
    echo ""
    gh auth login --web --hostname github.com --git-protocol ssh --skip-ssh-key
fi
echo "✓ GitHub authenticated"

# Verify repo access
echo ""
echo "Verifying access to $REPO..."
if ! gh repo view "$REPO" &> /dev/null; then
    echo ""
    echo "Error: Cannot access $REPO"
    echo ""
    echo "This repo requires Databricks GitHub EMU access."
    echo "Make sure you:"
    echo "  1. Have a Databricks EMU GitHub account"
    echo "  2. Are logged in with that account (not personal)"
    echo ""
    echo "To re-authenticate: gh auth login --web --hostname github.com"
    exit 1
fi
echo "✓ Repo access verified"

# Download and run vibe installer
echo ""
echo "Downloading and running vibe installer..."
echo ""
gh release download latest --repo "$REPO" --pattern 'install_vibe.sh' -O - | zsh

echo ""
echo "================================================"
echo "  Installation Complete!"
echo "================================================"
echo ""
echo "Next steps:"
echo "  1. Restart Claude Code to load plugins"
echo "  2. Run authentication skills as needed:"
echo "     /databricks-authentication"
echo "     /google-auth"
echo "     /salesforce-authentication"
echo ""
echo "To update vibe later: vibe update && vibe sync"
echo ""
