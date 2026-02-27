#!/bin/bash

# Claude Code Configuration Setup Script
# This script automates the installation of dependencies for Claude Code
# Run: chmod +x setup.sh && ./setup.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect architecture and OS
ARCH=$(uname -m)
OS=$(uname -s)

if [ "$OS" = "Darwin" ]; then
    # macOS
    if [ "$ARCH" = "arm64" ]; then
        HOMEBREW_PREFIX="/opt/homebrew"
        GCLOUD_ARCH="darwin-arm"
    else
        HOMEBREW_PREFIX="/usr/local"
        GCLOUD_ARCH="darwin-x86_64"
    fi
else
    # Linux
    HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
        GCLOUD_ARCH="linux-arm"
    else
        GCLOUD_ARCH="linux-x86_64"
    fi
fi

print_header "Claude Code Configuration Setup"
echo "This script will install and configure dependencies for Claude Code."
echo "Architecture detected: $ARCH"
echo ""

# ============================================================================
# STEP 1: Install Homebrew
# ============================================================================
print_header "Step 1: Homebrew Package Manager"

if command_exists brew; then
    print_success "Homebrew is already installed"
    brew --version | head -1
else
    print_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for this session
    if [ -f "$HOMEBREW_PREFIX/bin/brew" ]; then
        eval "$($HOMEBREW_PREFIX/bin/brew shellenv)"
        print_success "Homebrew installed successfully"
    else
        print_error "Homebrew installation failed"
        exit 1
    fi
fi

# Ensure Homebrew is in PATH
if ! command_exists brew; then
    print_info "Adding Homebrew to PATH..."
    eval "$($HOMEBREW_PREFIX/bin/brew shellenv)"

    # Add to shell profile
    if [ -f ~/.zprofile ]; then
        if ! grep -q "brew shellenv" ~/.zprofile; then
            echo 'eval "$('$HOMEBREW_PREFIX'/bin/brew shellenv)"' >> ~/.zprofile
        fi
    fi
fi

# ============================================================================
# STEP 2: Install Node.js
# ============================================================================
print_header "Step 2: Node.js"

if command_exists node; then
    print_success "Node.js is already installed"
    node --version
else
    print_info "Installing Node.js via Homebrew..."
    brew install node
    print_success "Node.js installed"
    node --version
fi

# ============================================================================
# STEP 3: Install Python 3
# ============================================================================
print_header "Step 3: Python 3"

if command_exists python3; then
    print_success "Python 3 is already installed"
    python3 --version
else
    print_info "Installing Python 3 via Homebrew..."
    brew install python@3.13
    print_success "Python 3 installed"
    python3 --version
fi

# ============================================================================
# STEP 4: Install Git
# ============================================================================
print_header "Step 4: Git"

if command_exists git; then
    print_success "Git is already installed"
    git --version
else
    print_info "Installing Git via Homebrew..."
    brew install git
    print_success "Git installed"
    git --version
fi

# ============================================================================
# STEP 5: Install Salesforce CLI
# ============================================================================
print_header "Step 5: Salesforce CLI"

if command_exists sf; then
    print_success "Salesforce CLI is already installed"
    sf --version | head -1
else
    print_info "Installing Salesforce CLI via Homebrew..."
    brew install sf
    print_success "Salesforce CLI installed"
    sf --version | head -1
fi

# ============================================================================
# STEP 6: Install Claude Code CLI
# ============================================================================
print_header "Step 6: Claude Code CLI"

if command_exists claude; then
    print_success "Claude Code CLI is already installed"
    claude --version 2>/dev/null || echo "Version check unavailable"
else
    print_info "Installing Claude Code CLI via Homebrew Cask..."
    brew install --cask claude-code
    print_success "Claude Code CLI installed"
fi

# ============================================================================
# STEP 7: Install Google Cloud SDK
# ============================================================================
print_header "Step 7: Google Cloud SDK"

if command_exists gcloud; then
    print_success "Google Cloud SDK is already installed"
    gcloud --version | head -1
else
    print_info "Google Cloud SDK needs manual installation."
    echo ""
    echo "Download from: https://cloud.google.com/sdk/docs/install"
    echo ""
    echo "Or run these commands:"
    echo ""
    echo "  # Download"
    echo "  curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-${GCLOUD_ARCH}.tar.gz"
    echo ""
    echo "  # Extract and move"
    echo "  tar -xvf google-cloud-cli-${GCLOUD_ARCH}.tar.gz"
    echo "  mv google-cloud-sdk ~/"
    echo ""
    echo "  # Install"
    echo "  ~/google-cloud-sdk/install.sh"
    echo ""
    echo "  # Initialize"
    echo "  ~/google-cloud-sdk/bin/gcloud init"
    echo ""

    # Check if running interactively
    if [ -t 0 ]; then
        read -p "Would you like to install Google Cloud SDK now? (y/n) " -n 1 -r
        echo
    else
        print_warning "Non-interactive mode - skipping Google Cloud SDK installation"
        REPLY="n"
    fi

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Downloading Google Cloud SDK..."
        cd /tmp
        curl -O "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-${GCLOUD_ARCH}.tar.gz"
        tar -xvf "google-cloud-cli-${GCLOUD_ARCH}.tar.gz"
        mv google-cloud-sdk ~/
        ~/google-cloud-sdk/install.sh --quiet
        print_success "Google Cloud SDK installed"
        print_info "Run 'gcloud init' to configure"
    else
        print_warning "Skipping Google Cloud SDK installation"
    fi
fi

# ============================================================================
# STEP 8: Create Directory Structure
# ============================================================================
print_header "Step 8: Directory Structure"

mkdir -p ~/.vibe/chrome/profile
print_success "Created ~/.vibe/chrome/profile"

mkdir -p ~/mcp/servers
print_success "Created ~/mcp/servers"

mkdir -p ~/code
print_success "Created ~/code"

# ============================================================================
# STEP 9: Create Configuration Files
# ============================================================================
print_header "Step 9: Configuration Files"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Create settings.json from template if not exists
if [ -f settings.json ]; then
    print_warning "settings.json already exists - skipping"
elif [ -f settings.json.template ]; then
    cp settings.json.template settings.json
    print_success "Created settings.json from template"
    print_warning "IMPORTANT: Edit settings.json to add your credentials"
else
    print_error "settings.json.template not found"
fi

# Create mcp.json from template if not exists
if [ -f mcp.json ]; then
    print_warning "mcp.json already exists - skipping"
elif [ -f mcp.json.template ]; then
    cp mcp.json.template mcp.json
    # Replace username in paths
    CURRENT_USER=$(whoami)
    if [ "$(uname)" = "Darwin" ]; then
        sed -i '' "s/laurent\.prat/$CURRENT_USER/g" mcp.json
    else
        sed -i "s/laurent\.prat/$CURRENT_USER/g" mcp.json
    fi
    print_success "Created mcp.json from template (updated paths for $CURRENT_USER)"
else
    print_error "mcp.json.template not found"
fi

# ============================================================================
# STEP 10: FE Vibe Plugins (Optional)
# ============================================================================
print_header "Step 10: FE Vibe Plugins (Optional)"

print_info "FE Vibe plugins require Databricks GitHub EMU access."
echo ""
echo "If you have access to databricks-field-eng organization:"
echo ""
echo "  git clone https://github.com/databricks-field-eng/vibe.git ~/Documents/vibe"
echo "  cd ~/Documents/vibe"
echo "  ./install.sh"
echo ""
print_warning "Skipping automatic plugin installation (requires manual setup)"

# ============================================================================
# SUMMARY
# ============================================================================
print_header "Setup Complete!"

echo ""
echo "Installed tools:"
command_exists brew && echo -e "  ${GREEN}✓${NC} Homebrew $(brew --version | head -1 | awk '{print $2}')"
command_exists node && echo -e "  ${GREEN}✓${NC} Node.js $(node --version)"
command_exists python3 && echo -e "  ${GREEN}✓${NC} Python $(python3 --version | awk '{print $2}')"
command_exists git && echo -e "  ${GREEN}✓${NC} Git $(git --version | awk '{print $3}')"
command_exists sf && echo -e "  ${GREEN}✓${NC} Salesforce CLI $(sf --version | head -1 | awk -F'/' '{print $2}' | awk '{print $1}')"
command_exists claude && echo -e "  ${GREEN}✓${NC} Claude Code CLI"
command_exists gcloud && echo -e "  ${GREEN}✓${NC} Google Cloud SDK $(gcloud --version | head -1 | awk '{print $4}')"

echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "1. Edit ~/.claude/settings.json and replace:"
echo "   - YOUR_WORKSPACE → your Databricks workspace URL prefix"
echo "   - YOUR_DATABRICKS_PAT_TOKEN → your Databricks PAT"
echo "   - YOUR_CONTEXT7_API_KEY → your Context7 API key"
echo ""
echo "2. Authenticate services:"
echo "   - Salesforce: sf org login web"
echo "   - Google: gcloud auth login && gcloud auth application-default login"
echo ""
echo "3. (Optional) Install FE Vibe plugins if you have Databricks GitHub access"
echo ""
echo "4. Start Claude Code:"
echo "   claude"
echo ""

print_success "Setup script completed!"
