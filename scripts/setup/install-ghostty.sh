#!/bin/bash
# Install Ghostty Terminal Emulator on Ubuntu/Debian
# https://ghostty.org/

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC}  $1"; }
error() { echo -e "${RED}✗${NC} $1"; }
step() { echo -e "${BLUE}→${NC} $1"; }

# Cleanup trap - ensure temp directories are removed on exit
TEMP_DIR=""
cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

echo ""
echo "════════════════════════════════════════════════════"
echo "  Ghostty Terminal Emulator Installation"
echo "════════════════════════════════════════════════════"
echo ""

# This script targets Ubuntu/Debian family only.
if ! grep -qiE "ubuntu|debian" /etc/os-release 2>/dev/null; then
    error "This script supports only Ubuntu/Debian-family distros"
    exit 1
fi

# Check if already installed
if command -v ghostty &> /dev/null; then
    CURRENT_VERSION=$(ghostty --version 2>&1 | head -1 || echo "unknown")
    info "Ghostty is already installed: $CURRENT_VERSION"
    echo ""
    read -p "Reinstall/upgrade? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Skipping Ghostty installation"
        exit 0
    fi
fi

# Choose installation method
echo -e "${CYAN}Available installation methods:${NC}"
echo ""
echo "  1. Ubuntu .deb package (community-maintained, recommended)"
echo "  2. Snap (official, auto-updates)"
echo ""
read -p "Choose installation method (1/2): " -n 1 -r
echo ""
echo ""

case "$REPLY" in
    1)
        step "Installing Ghostty via Ubuntu .deb package..."
        echo ""
        info "Downloading latest .deb from community repository..."

        TEMP_DIR=$(mktemp -d)
        cd "$TEMP_DIR"

        LATEST_URL=$(curl -s https://api.github.com/repos/mkasberg/ghostty-ubuntu/releases/latest \
            | grep "browser_download_url.*\.deb" \
            | cut -d '"' -f 4 \
            | head -1)

        if [ -z "$LATEST_URL" ]; then
            error "Could not find .deb package"
            exit 1
        fi

        info "Downloading: $(basename "$LATEST_URL")"
        curl -L -o ghostty.deb "$LATEST_URL"

        step "Installing package..."
        sudo apt install -y ./ghostty.deb

        cd - > /dev/null
        rm -rf "$TEMP_DIR"
        TEMP_DIR=""
        ;;
    2)
        step "Installing Ghostty via Snap..."

        if ! command -v snap &> /dev/null; then
            error "Snap is not installed"
            echo ""
            warn "Install snapd first:"
            echo "  sudo apt update && sudo apt install snapd"
            exit 1
        fi

        sudo snap install ghostty --classic
        ;;
    *)
        error "Invalid selection"
        exit 1
        ;;
esac

# Verify installation
echo ""
step "Verifying installation..."
if command -v ghostty &> /dev/null; then
    INSTALLED_VERSION=$(ghostty --version 2>&1 | head -1 || echo "installed")
    info "✓ Ghostty successfully installed: $INSTALLED_VERSION"
    echo ""
    info "Ghostty config is set up at: ~/.config/ghostty"
    info "Launch with: ghostty"
else
    error "Installation verification failed"
    exit 1
fi

echo ""
echo "════════════════════════════════════════════════════"
echo "  ✨ Ghostty Installation Complete!"
echo "════════════════════════════════════════════════════"
echo ""
