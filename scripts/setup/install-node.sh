#!/bin/bash
# Node.js Installation Script
# Installs Node.js versions via fnm and global npm packages

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
step() { echo -e "${BLUE}[STEP]${NC} $1"; }
cmd() { echo -e "  ${CYAN}$1${NC} - $2"; }

# ============================================
# Node.js Versions
# ============================================
NODE_DEFAULT="20"
NODE_VERSIONS=("20" "22")

# ============================================
# NPM Global Packages Manifest
# ============================================
# Format: "package|command1:desc,command2:desc,..."

NPM_GLOBALS=(
    "@anthropic-ai/claude-code|claude:AI coding assistant CLI"
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
echo ""

for entry in "${NPM_GLOBALS[@]}"; do
    # Parse package name and commands
    package="${entry%%|*}"
    commands="${entry#*|}"

    echo -e "${GREEN}Package:${NC} $package"
    echo -e "${GREEN}Provides:${NC}"

    # Parse and display commands
    IFS=',' read -ra CMD_LIST <<< "$commands"
    for item in "${CMD_LIST[@]}"; do
        cmd_name="${item%%:*}"
        cmd_desc="${item#*:}"
        cmd "$cmd_name" "$cmd_desc"
    done
    echo ""

    # Install if not present
    if npm list -g "$package" &> /dev/null; then
        info "$package already installed"
    else
        info "Installing $package..."
        npm install -g "$package"
    fi
    echo ""
done

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
