#!/bin/bash
# UV Tools Installation Script
# Installs Python CLI tools via uv tool

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

# UV tools to install
UV_TOOLS=(
    "claude-code-tools"  # Provides: tmux-cli, aichat, env-safe, gdoc2md, md2gdoc, vault
)

echo ""
step "Starting UV tools setup..."
echo ""

# Check if uv is available
if ! command -v uv &> /dev/null; then
    error "uv is not installed. Install it first via: brew install uv"
    exit 1
fi

info "uv found: $(uv --version)"

# Install UV tools
step "Installing UV tools..."
for tool in "${UV_TOOLS[@]}"; do
    if uv tool list | grep -q "^${tool}"; then
        info "$tool already installed"
    else
        info "Installing $tool..."
        uv tool install "$tool"
    fi
done

# Verify installation
step "Verifying installation..."
echo ""
info "Installed UV tools:"
uv tool list
echo ""

# Show provided commands
info "Commands provided by claude-code-tools:"
echo "  - tmux-cli    : Terminal multiplexer CLI control"
echo "  - aichat      : AI chat interface"
echo "  - env-safe    : Environment variable safety"
echo "  - gdoc2md     : Google Docs to Markdown"
echo "  - md2gdoc     : Markdown to Google Docs"
echo "  - vault       : Secret management"
echo ""

step "UV tools setup complete!"
echo ""
