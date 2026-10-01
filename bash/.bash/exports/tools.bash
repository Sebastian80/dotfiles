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
    # Note: EZA_ICONS_AUTO is not a valid eza option - icons are controlled via --icons flag
    # Our aliases in aliases.bash already include --icons for icon support
fi

# ripgrep - Configuration file location
# Config file can contain default flags for ripgrep (rg)
export RIPGREP_CONFIG_PATH="$HOME/.config/ripgrep/config"

# Brew's curl, OpenSSL and Python come first in PATH (pulled in as dependencies of composer,
# git, php and others) and ship their own CA bundle, which lacks the mkcert CA, so
# https://*.docker.local failed with "unable to get local issuer". Point brew's OpenSSL at the
# system bundle, which update-ca-certificates keeps current (public roots + mkcert CA).
if [ -r /etc/ssl/certs/ca-certificates.crt ]; then
    export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
fi

# Clickable links inside herdr panes. herdr sets TERM_PROGRAM=herdr in every pane (documented, not
# configurable), which link detection such as Claude Code's does not recognise, so links came out as
# "text (url)". herdr passes OSC 8 hyperlinks through to Ghostty (tested 2026-10-01).
if [ "${TERM_PROGRAM:-}" = herdr ]; then
    export FORCE_HYPERLINK=1
fi
