#!/usr/bin/env bash
# ~/.bash/exports/tools.bash
# Configuration for modern CLI tools
#
# Purpose:
#   Configure enhanced replacements for traditional Unix tools:
#   - bat: Better 'cat' with syntax highlighting
#   - eza: Modern 'ls' with colors and icons
#   - ripgrep: Faster 'grep' with better defaults
#
# Tools configured:
#   bat/batcat - cat with syntax highlighting
#   eza        - Modern ls replacement
#   ripgrep    - Fast text search tool

# bat - Better cat with syntax highlighting
# Check for both 'bat' (brew) and 'batcat' (apt) names
if command -v bat &>/dev/null; then
    export BAT_THEME="Catppuccin Frappe"       # Color scheme (dark, pastel)
    export BAT_STYLE="numbers,changes,header"  # Show line numbers, git changes, file header
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"  # Use bat for man pages
elif command -v batcat &>/dev/null; then
    export BAT_THEME="Catppuccin Frappe"
    export BAT_STYLE="numbers,changes,header"
    export MANPAGER="sh -c 'col -bx | batcat -l man -p'"
fi

# eza - Modern ls with icons and git integration
if command -v eza &>/dev/null; then
    export EZA_COLORS="da=1;34:gm=1;34"        # Custom colors: directories=blue, git modified=blue
    export EZA_ICONS_AUTO=1                    # Automatically show file icons
fi

# ripgrep - Configuration file location
# Config file can contain default flags for ripgrep (rg)
export RIPGREP_CONFIG_PATH="$HOME/.config/ripgrep/config"
