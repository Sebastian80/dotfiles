#!/bin/bash
# Node.js Installation Script
# Installs Node.js versions via fnm and global npm packages
#
# Usage:
#   install-node.sh         Install the Node versions and the base npm globals
#   install-node.sh --ai    Install only the AI agent CLIs (Node must exist)
#   install-node.sh -h      This help

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
NODE_DEFAULT="24"
NODE_VERSIONS=("22" "24")

# ============================================
# NPM Global Packages Manifest
# ============================================
# Format: "package|command1:desc,command2:desc,..."

# Base tools, useful without any AI agent.
NPM_GLOBALS=(
    "pnpm|pnpm:Fast, disk-efficient package manager"
)

# AI agent tooling, installed with --ai (bootstrap and `make install-ai` ask first).
# Claude Code is NOT installed via npm: it uses its native installer and self-updates, so it has
# its own script (install-claude.sh). pi is not here either: install-pi.sh also provisions its
# sandbox extension. Both run from `make install-ai` alongside this manifest.
NPM_AI_GLOBALS=(
    "@openai/codex|codex:OpenAI Codex CLI (also the codex MCP server for Claude Code)"
    "@google/gemini-cli|gemini:Google Gemini CLI"
    "agent-browser|agent-browser:Browser automation CLI for AI agents"
    "repomix|repomix:Pack a repository into a single AI-friendly file"
)

MODE="base"
case "${1:-}" in
    -h | --help)
        sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    --ai) MODE="ai" ;;
    "") ;;
    *)
        error "Unknown option: $1 (see --help)"
        exit 1
        ;;
esac

echo ""
step "Starting Node.js setup..."
echo ""

# Check if fnm is available
if ! command -v fnm &> /dev/null; then
    error "fnm is not installed. Install it first via: brew install fnm"
    exit 1
fi

info "fnm found: $(fnm --version)"

# Load fnm into this shell. `fnm use` refuses to run without it, and npm would otherwise resolve to
# Homebrew's Node, putting the global CLIs outside fnm's default version.
eval "$(fnm env --shell bash)"

# Install the packages of one manifest, showing what each provides.
install_globals() {
    local entry package commands item cmd_name cmd_desc
    for entry in "$@"; do
        package="${entry%%|*}"
        commands="${entry#*|}"

        echo -e "${GREEN}Package:${NC} $package"
        echo -e "${GREEN}Provides:${NC}"

        IFS=',' read -ra CMD_LIST <<< "$commands"
        for item in "${CMD_LIST[@]}"; do
            cmd_name="${item%%:*}"
            cmd_desc="${item#*:}"
            cmd "$cmd_name" "$cmd_desc"
        done
        echo ""

        if npm list -g "$package" &> /dev/null; then
            info "$package already installed"
        else
            info "Installing $package..."
            npm install -g "$package"
        fi
        echo ""
    done
}

if [[ "$MODE" == "ai" ]]; then
    if ! command -v node &> /dev/null; then
        error "No Node version active. Run install-node.sh without --ai first."
        exit 1
    fi
    step "Installing AI agent CLIs (Node $(node --version))..."
    echo ""
    install_globals "${NPM_AI_GLOBALS[@]}"
    info "Global npm packages:"
    npm list -g --depth=0
    echo ""
    step "AI agent CLIs complete!"
    echo ""
    exit 0
fi

# Step 1: Install Node versions
step "Installing Node.js versions..."
for version in "${NODE_VERSIONS[@]}"; do
    if fnm list | grep -qE "v${version}\."; then
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
install_globals "${NPM_GLOBALS[@]}"

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
info "AI agent tooling (Codex, Gemini, pi, herdr integrations) is a separate step:"
cmd "make install-ai" "install the AI agent tooling"
echo ""
