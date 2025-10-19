#!/bin/bash

# Oh My Posh Theme Switcher
# Usage: ./switch-theme.sh [theme-name]
# Example: ./switch-theme.sh catppuccin

if [ -z "$1" ]; then
    echo "Oh My Posh Theme Switcher"
    echo "========================="
    echo ""
    echo "Usage: $0 <theme-name>"
    echo ""
    echo "Popular themes:"
    echo "  - catppuccin"
    echo "  - powerlevel10k_rainbow"
    echo "  - tokyo"
    echo "  - dracula"
    echo "  - bubbles"
    echo "  - spaceship"
    echo "  - agnoster"
    echo "  - sorin"
    echo "  - paradox"
    echo "  - atomic"
    echo ""
    echo "Browse all themes at: https://ohmyposh.dev/docs/themes"
    echo ""
    echo "Current theme in ~/.bashrc:"
    grep "oh-my-posh init bash" ~/.bashrc | tail -1
    exit 0
fi

THEME=$1
THEME_FILE="$HOME/.config/oh-my-posh/themes/${THEME}.omp.json"
BASHRC="$HOME/.bashrc"

# Download theme if it doesn't exist
if [ ! -f "$THEME_FILE" ]; then
    echo "Downloading ${THEME} theme..."
    mkdir -p "$HOME/.config/oh-my-posh/themes"

    # Try to download from Oh My Posh GitHub
    THEME_URL="https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/${THEME}.omp.json"

    if curl -fsSL "$THEME_URL" -o "$THEME_FILE" 2>/dev/null; then
        echo "✓ Downloaded ${THEME}.omp.json"
    else
        echo "✗ Failed to download theme '${THEME}'"
        echo "  Make sure the theme name is correct."
        echo "  Visit https://ohmyposh.dev/docs/themes to see available themes."
        exit 1
    fi
fi

# Backup bashrc
cp "$BASHRC" "$BASHRC.backup-$(date +%Y%m%d-%H%M%S)"

# Replace the oh-my-posh init line
sed -i "s|eval \"\$(oh-my-posh init bash --config .*)\"|eval \"\$(oh-my-posh init bash --config ~/.config/oh-my-posh/themes/${THEME}.omp.json)\"|g" "$BASHRC"

echo ""
echo "✓ Theme switched to: ${THEME}"
echo "✓ Backup created: $BASHRC.backup-$(date +%Y%m%d-%H%M%S)"
echo ""
echo "To apply the changes, run:"
echo "  source ~/.bashrc"
echo ""
echo "Or open a new terminal window."
