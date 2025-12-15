#!/bin/bash
# Install Ghostty Terminal Emulator on Linux
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

# Detect distribution
# SECURITY: Parse os-release instead of sourcing (prevents code injection)
if [ -f /etc/os-release ]; then
    DISTRO=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
    DISTRO_VERSION=$(grep '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
else
    DISTRO="unknown"
    DISTRO_VERSION=""
fi

info "Detected distribution: $DISTRO"
echo ""

# Show installation options
echo -e "${CYAN}Available installation methods:${NC}"
echo ""

case "$DISTRO" in
    ubuntu|debian|linuxmint|pop)
        echo "  1. Snap (recommended - official, auto-updates)"
        echo "  2. Ubuntu .deb package (community-maintained)"
        echo "  3. Build from source (requires Zig compiler)"
        ;;
    fedora|rhel|centos)
        echo "  1. Fedora COPR (community repository)"
        echo "  2. Build from source (requires Zig compiler)"
        ;;
    arch|manjaro)
        echo "  1. Official Arch package (pacman)"
        echo "  2. AUR development version (ghostty-git)"
        ;;
    *)
        echo "  1. Snap (universal Linux package)"
        echo "  2. Build from source (requires Zig compiler)"
        ;;
esac

echo ""
read -p "Choose installation method (1/2/3): " -n 1 -r
echo ""
echo ""

INSTALL_METHOD=$REPLY

# Method 1: Distribution-specific packages
if [[ $INSTALL_METHOD == "1" ]]; then
    case "$DISTRO" in
        ubuntu|debian|linuxmint|pop)
            step "Installing Ghostty via Snap..."

            # Check if snap is available
            if ! command -v snap &> /dev/null; then
                error "Snap is not installed"
                echo ""
                warn "Install snapd first:"
                echo "  sudo apt update && sudo apt install snapd"
                exit 1
            fi

            sudo snap install ghostty --classic

            if command -v ghostty &> /dev/null; then
                info "✓ Ghostty installed successfully via Snap"
                INSTALLED_VERSION=$(ghostty --version 2>&1 | head -1 || echo "installed")
                info "Version: $INSTALLED_VERSION"
            else
                error "Installation failed"
                exit 1
            fi
            ;;

        fedora|rhel|centos)
            step "Installing Ghostty via COPR..."

            sudo dnf copr enable scottames/ghostty -y
            sudo dnf install ghostty -y

            if command -v ghostty &> /dev/null; then
                info "✓ Ghostty installed successfully via COPR"
            else
                error "Installation failed"
                exit 1
            fi
            ;;

        arch|manjaro)
            step "Installing Ghostty via pacman..."

            sudo pacman -S ghostty --noconfirm

            if command -v ghostty &> /dev/null; then
                info "✓ Ghostty installed successfully"
            else
                error "Installation failed"
                exit 1
            fi
            ;;

        *)
            step "Installing Ghostty via Snap..."

            if ! command -v snap &> /dev/null; then
                error "Snap is not available on this system"
                echo ""
                warn "Please choose method 2 to build from source"
                exit 1
            fi

            sudo snap install ghostty --classic

            if command -v ghostty &> /dev/null; then
                info "✓ Ghostty installed successfully via Snap"
            else
                error "Installation failed"
                exit 1
            fi
            ;;
    esac

# Method 2: Ubuntu .deb or Build from source
elif [[ $INSTALL_METHOD == "2" ]]; then
    case "$DISTRO" in
        ubuntu|debian|linuxmint|pop)
            step "Installing Ghostty via Ubuntu .deb package..."
            echo ""
            info "Downloading latest .deb from community repository..."

            TEMP_DIR=$(mktemp -d)
            cd "$TEMP_DIR"

            # Get latest release
            LATEST_URL=$(curl -s https://api.github.com/repos/mkasberg/ghostty-ubuntu/releases/latest | grep "browser_download_url.*\.deb" | cut -d '"' -f 4 | head -1)

            if [ -z "$LATEST_URL" ]; then
                error "Could not find .deb package"
                rm -rf "$TEMP_DIR"
                exit 1
            fi

            info "Downloading: $(basename "$LATEST_URL")"
            curl -L -o ghostty.deb "$LATEST_URL"

            step "Installing package..."
            sudo apt install -y ./ghostty.deb

            cd - > /dev/null
            rm -rf "$TEMP_DIR"

            if command -v ghostty &> /dev/null; then
                info "✓ Ghostty installed successfully"
            else
                error "Installation failed"
                exit 1
            fi
            ;;

        *)
            # Build from source for other distros
            step "Building Ghostty from source..."
            echo ""

            # Check for required dependencies
            step "Checking build dependencies..."

            MISSING_DEPS=()

            case "$DISTRO" in
                fedora|rhel|centos)
                    DEPS="gtk4-devel gtk4-layer-shell-devel libadwaita-devel gettext"
                    for dep in $DEPS; do
                        if ! rpm -q "$dep" &>/dev/null; then
                            MISSING_DEPS+=("$dep")
                        fi
                    done
                    PKG_MGR="sudo dnf install -y"
                    ;;
                arch|manjaro)
                    DEPS="gtk4 gtk4-layer-shell libadwaita gettext"
                    for dep in $DEPS; do
                        if ! pacman -Q "$dep" &>/dev/null; then
                            MISSING_DEPS+=("$dep")
                        fi
                    done
                    PKG_MGR="sudo pacman -S --noconfirm"
                    ;;
                *)
                    DEPS="libgtk-4-dev libgtk4-layer-shell-dev libadwaita-1-dev gettext libxml2-utils"
                    for dep in $DEPS; do
                        if ! dpkg -l "$dep" &>/dev/null 2>&1; then
                            MISSING_DEPS+=("$dep")
                        fi
                    done
                    PKG_MGR="sudo apt install -y"
                    ;;
            esac

            if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
                warn "Missing dependencies: ${MISSING_DEPS[*]}"
                echo ""
                read -p "Install missing dependencies? (y/n) " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    $PKG_MGR ${MISSING_DEPS[@]}
                else
                    error "Cannot build without dependencies"
                    exit 1
                fi
            fi

            # Check for Zig
            if ! command -v zig &> /dev/null; then
                error "Zig compiler not found"
                echo ""
                warn "Ghostty requires Zig to build. Install from:"
                echo "  https://ziglang.org/download/"
                echo ""
                echo "For Zig 0.14.1 (required for Ghostty 1.2.x):"
                echo "  wget https://ziglang.org/download/0.14.1/zig-linux-x86_64-0.14.1.tar.xz"
                echo "  tar xf zig-linux-x86_64-0.14.1.tar.xz"
                echo "  sudo mv zig-linux-x86_64-0.14.1 /usr/local/zig"
                echo "  export PATH=/usr/local/zig:\$PATH"
                exit 1
            fi

            ZIG_VERSION=$(zig version)
            info "Zig compiler found: $ZIG_VERSION"

            # Download source
            step "Downloading Ghostty source code..."
            TEMP_DIR=$(mktemp -d)
            cd "$TEMP_DIR"

            git clone https://github.com/ghostty-org/ghostty.git
            cd ghostty

            # Build
            step "Building Ghostty (this may take a few minutes)..."
            zig build -Doptimize=ReleaseFast

            # Install
            echo ""
            step "Choose installation location:"
            echo "  1. User-local (~/.local/bin) - no sudo needed"
            echo "  2. System-wide (/usr/local) - requires sudo"
            echo ""
            read -p "Choose (1/2): " -n 1 -r
            echo

            case $REPLY in
                1)
                    step "Installing to ~/.local..."
                    zig build -p "$HOME/.local" -Doptimize=ReleaseFast
                    info "Installed to ~/.local/bin/ghostty"

                    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
                        warn "Add ~/.local/bin to PATH in your .bashrc:"
                        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
                    fi
                    ;;
                2)
                    step "Installing to /usr/local (requires sudo)..."
                    sudo zig build -p /usr/local -Doptimize=ReleaseFast
                    info "Installed to /usr/local/bin/ghostty"
                    ;;
                *)
                    error "Invalid choice"
                    rm -rf "$TEMP_DIR"
                    exit 1
                    ;;
            esac

            cd - > /dev/null
            rm -rf "$TEMP_DIR"

            if command -v ghostty &> /dev/null; then
                info "✓ Ghostty built and installed successfully"
            else
                error "Installation failed"
                exit 1
            fi
            ;;
    esac

# Method 3: Build from source (Ubuntu/Debian specific)
elif [[ $INSTALL_METHOD == "3" ]]; then
    # Same as method 2 for non-Ubuntu distros
    step "Building Ghostty from source..."
    echo ""

    # Check dependencies
    step "Checking build dependencies..."
    DEPS="libgtk-4-dev libgtk4-layer-shell-dev libadwaita-1-dev gettext libxml2-utils"
    MISSING_DEPS=()

    for dep in $DEPS; do
        if ! dpkg -l "$dep" &>/dev/null 2>&1; then
            MISSING_DEPS+=("$dep")
        fi
    done

    if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
        warn "Missing dependencies: ${MISSING_DEPS[*]}"
        echo ""
        read -p "Install missing dependencies? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo apt install -y ${MISSING_DEPS[@]}
        else
            error "Cannot build without dependencies"
            exit 1
        fi
    fi

    # Check for Zig
    if ! command -v zig &> /dev/null; then
        error "Zig compiler not found"
        echo ""
        warn "Ghostty requires Zig to build. Install from:"
        echo "  https://ziglang.org/download/"
        echo ""
        echo "Quick install Zig 0.14.1:"
        echo "  wget https://ziglang.org/download/0.14.1/zig-linux-x86_64-0.14.1.tar.xz"
        echo "  tar xf zig-linux-x86_64-0.14.1.tar.xz"
        echo "  sudo mv zig-linux-x86_64-0.14.1 /usr/local/zig"
        echo "  export PATH=/usr/local/zig:\$PATH"
        exit 1
    fi

    ZIG_VERSION=$(zig version)
    info "Zig compiler found: $ZIG_VERSION"

    # Download and build
    step "Downloading Ghostty source..."
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"

    git clone https://github.com/ghostty-org/ghostty.git
    cd ghostty

    step "Building Ghostty (this may take a few minutes)..."
    zig build -Doptimize=ReleaseFast

    # Install
    echo ""
    echo "Choose installation location:"
    echo "  1. User-local (~/.local/bin) - no sudo needed"
    echo "  2. System-wide (/usr/local) - requires sudo"
    echo ""
    read -p "Choose (1/2): " -n 1 -r
    echo

    case $REPLY in
        1)
            step "Installing to ~/.local..."
            zig build -p "$HOME/.local" -Doptimize=ReleaseFast
            info "Installed to ~/.local/bin/ghostty"

            if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
                warn "Add ~/.local/bin to PATH in your .bashrc:"
                echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
            fi
            ;;
        2)
            step "Installing to /usr/local (requires sudo)..."
            sudo zig build -p /usr/local -Doptimize=ReleaseFast
            info "Installed to /usr/local/bin/ghostty"
            ;;
        *)
            error "Invalid choice"
            rm -rf "$TEMP_DIR"
            exit 1
            ;;
    esac

    cd - > /dev/null
    rm -rf "$TEMP_DIR"

    if command -v ghostty &> /dev/null; then
        info "✓ Ghostty built and installed successfully"
    else
        error "Installation failed"
        exit 1
    fi

else
    error "Invalid selection"
    exit 1
fi

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
