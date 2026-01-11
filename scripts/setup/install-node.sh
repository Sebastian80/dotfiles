#!/bin/bash
# Node.js Installation Script
# Installs Node.js versions via fnm and global npm packages

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Node versions to install
NODE_DEFAULT="20"
NODE_VERSIONS=("20" "22")

# Global npm packages
NPM_GLOBALS=(
    "@anthropic-ai/claude-code"
)

echo ""
step "Starting Node.js setup..."
echo ""

# Check if fnm is available
if ! command -v fnm &> /dev/null; then
    error "fnm is not installed. Install it first via: brew install fnm"
    exit 1
fi

info "fnm found: $(fnm --version)"

# Step 1: Install Node versions
step "Installing Node.js versions..."
for version in "${NODE_VERSIONS[@]}"; do
    if fnm list | grep -q "v${version}"; then
        info "Node ${version} already installed"
    else
        info "Installing Node ${version}..."
        fnm install "$version"
    fi
done
info "All Node versions installed"

# Step 2: Set default version
step "Setting default Node version to ${NODE_DEFAULT}..."
fnm default "$NODE_DEFAULT"
fnm use "$NODE_DEFAULT"
info "Default Node: $(node --version)"

# Step 3: Install global npm packages
step "Installing global npm packages..."
for package in "${NPM_GLOBALS[@]}"; do
    package_name=$(echo "$package" | cut -d'@' -f1-2)
    if npm list -g "$package_name" &> /dev/null; then
        info "$package_name already installed"
    else
        info "Installing $package_name..."
        npm install -g "$package"
    fi
done
info "All npm globals installed"

# Step 4: Verify installation
step "Verifying installation..."
echo ""
info "Node versions:"
fnm list
echo ""
info "Global npm packages:"
npm list -g --depth=0
echo ""

step "Node.js setup complete!"
echo ""
