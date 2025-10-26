#!/bin/bash
# Install Ghostty Terminal Emulator
# https://github.com/ghostty-org/ghostty

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC}  $1"; }
error() { echo -e "${RED}✗${NC} $1"; }
step() { echo -e "${BLUE}→${NC} $1"; }

echo ""
echo "════════════════════════════════════════════════════"
echo "  Ghostty Terminal Emulator Installation"
echo "════════════════════════════════════════════════════"
echo ""

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

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        ARCH_NAME="x86_64"
        ;;
    aarch64|arm64)
        ARCH_NAME="aarch64"
        ;;
    *)
        error "Unsupported architecture: $ARCH"
        error "Ghostty supports x86_64 and aarch64 only"
        exit 1
        ;;
esac

info "Detected architecture: $ARCH_NAME"

# Check for required dependencies
step "Checking dependencies..."

MISSING_DEPS=()
for dep in curl tar gtk+3.0; do
    case "$dep" in
        gtk+3.0)
            if ! pkg-config --exists gtk+-3.0 2>/dev/null; then
                MISSING_DEPS+=("libgtk-3-dev")
            fi
            ;;
        *)
            if ! command -v "$dep" &> /dev/null; then
                MISSING_DEPS+=("$dep")
            fi
            ;;
    esac
done

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    warn "Missing dependencies: ${MISSING_DEPS[*]}"
    echo ""
    read -p "Install missing dependencies with apt? (requires sudo) (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        step "Installing dependencies..."
        sudo apt update
        sudo apt install -y "${MISSING_DEPS[@]}"
        info "Dependencies installed"
    else
        error "Cannot continue without dependencies"
        exit 1
    fi
else
    info "All dependencies satisfied"
fi

# Get latest release
step "Fetching latest Ghostty release..."
LATEST_URL=$(curl -s https://api.github.com/repos/ghostty-org/ghostty/releases/latest | grep "browser_download_url.*linux-$ARCH_NAME.tar.gz" | cut -d '"' -f 4)

if [ -z "$LATEST_URL" ]; then
    error "Could not find release for $ARCH_NAME"
    echo ""
    warn "You may need to build from source:"
    echo "  git clone https://github.com/ghostty-org/ghostty"
    echo "  cd ghostty"
    echo "  zig build -Doptimize=ReleaseFast"
    exit 1
fi

LATEST_VERSION=$(echo "$LATEST_URL" | grep -oP 'v[\d.]+')
info "Latest version: $LATEST_VERSION"

# Download
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

step "Downloading Ghostty $LATEST_VERSION..."
if curl -L -o ghostty.tar.gz "$LATEST_URL"; then
    info "Download complete"
else
    error "Download failed"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Extract
step "Extracting archive..."
tar xzf ghostty.tar.gz
info "Extraction complete"

# Install
echo ""
step "Installation location"
echo "Choose installation location:"
echo "  1. System-wide (/usr/local/bin) - requires sudo, available to all users"
echo "  2. User-local (~/.local/bin) - no sudo needed, only for current user"
echo ""
read -p "Choose (1/2): " -n 1 -r
echo

case $REPLY in
    1)
        INSTALL_DIR="/usr/local"
        step "Installing to $INSTALL_DIR (requires sudo)..."
        sudo cp -r ghostty/bin/* "$INSTALL_DIR/bin/"
        sudo cp -r ghostty/share/* "$INSTALL_DIR/share/" 2>/dev/null || true
        info "Installed to $INSTALL_DIR"
        ;;
    2)
        INSTALL_DIR="$HOME/.local"
        mkdir -p "$INSTALL_DIR/bin" "$INSTALL_DIR/share"
        step "Installing to $INSTALL_DIR..."
        cp -r ghostty/bin/* "$INSTALL_DIR/bin/"
        cp -r ghostty/share/* "$INSTALL_DIR/share/" 2>/dev/null || true
        info "Installed to $INSTALL_DIR"

        # Add to PATH if not already there
        if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
            warn "Add ~/.local/bin to PATH in your .bashrc:"
            echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
        fi
        ;;
    *)
        error "Invalid choice"
        rm -rf "$TEMP_DIR"
        exit 1
        ;;
esac

# Cleanup
cd - > /dev/null
rm -rf "$TEMP_DIR"

# Verify installation
echo ""
step "Verifying installation..."
if command -v ghostty &> /dev/null; then
    INSTALLED_VERSION=$(ghostty --version 2>&1 | head -1 || echo "installed")
    info "✓ Ghostty successfully installed: $INSTALLED_VERSION"
    echo ""
    info "Ghostty config is already set up at: ~/.config/ghostty"
    info "Launch with: ghostty"
else
    error "Installation may have failed - ghostty command not found"
    exit 1
fi

echo ""
echo "════════════════════════════════════════════════════"
echo "  ✨ Ghostty Installation Complete!"
echo "════════════════════════════════════════════════════"
echo ""
