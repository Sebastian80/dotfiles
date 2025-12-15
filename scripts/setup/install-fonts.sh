#!/bin/bash
# Nerd Font Installation Script
# Downloads and installs Nerd Fonts for oh-my-posh and terminal icons

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Cleanup trap - ensure temp directories are removed on exit
temp_dir=""
cleanup() {
    if [[ -n "$temp_dir" && -d "$temp_dir" ]]; then
        rm -rf "$temp_dir"
    fi
}
trap cleanup EXIT

# Font installation directory
FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"

# Nerd Fonts version
NERD_FONTS_VERSION="v3.2.1"

# List of fonts to install (add/remove as needed)
FONTS=(
    "JetBrainsMono"
    "FiraCode"
    "Meslo"
)

step "Installing Nerd Fonts..."
echo ""

for font in "${FONTS[@]}"; do
    info "Installing $font Nerd Font..."

    # Download URL
    url="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONTS_VERSION}/${font}.zip"

    # Create temp directory (uses global var for cleanup trap)
    temp_dir=$(mktemp -d) || {
        warn "Failed to create temp directory"
        continue
    }

    # Download font
    if curl -fLo "$temp_dir/${font}.zip" "$url"; then
        # Extract to fonts directory
        unzip -o -q "$temp_dir/${font}.zip" -d "$FONT_DIR" -x "*.txt" -x "*.md"
        info "✓ $font installed successfully"
    else
        warn "✗ Failed to download $font"
    fi

    # Cleanup (trap will also catch this on unexpected exit)
    rm -rf "$temp_dir"
    temp_dir=""
done

echo ""
step "Refreshing font cache..."
fc-cache -f "$FONT_DIR"

echo ""
info "Font installation complete!"
echo ""
echo "Installed fonts:"
fc-list : family | grep -i "nerd" | sort -u | head -10
echo ""
echo "To use these fonts:"
echo "  1. Set your terminal font to 'JetBrainsMono Nerd Font' or 'FiraCode Nerd Font'"
echo "  2. Restart your terminal application"
echo "  3. oh-my-posh icons should now display correctly"
echo ""
