#!/bin/bash
# UV Tools Installation Script
# Installs Python CLI tools via uv tool

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
# UV Tools Manifest
# ============================================
# Format: "package|command1:desc,command2:desc,..."

UV_TOOLS=(
    "claude-code-tools|tmux-cli:Terminal multiplexer CLI control,aichat:Claude Code session management,env-safe:Safe .env inspection (no secret exposure),gdoc2md:Google Docs to Markdown,md2gdoc:Markdown to Google Docs,vault:Encrypted .env backup/sync"
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
echo ""

# Install UV tools
step "Installing UV tools..."
echo ""

for entry in "${UV_TOOLS[@]}"; do
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
    if uv tool list 2>/dev/null | grep -q "^${package}"; then
        info "$package already installed"
    else
        info "Installing $package..."
        uv tool install "$package"
    fi
    echo ""
done

# Verify installation
step "Verifying installation..."
echo ""
uv tool list
echo ""

step "UV tools setup complete!"
echo ""
