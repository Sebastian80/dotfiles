#!/usr/bin/env bash
# ~/.bash/integrations/zoxide.bash
# zoxide smart cd integration
#
# Purpose:
#   Initialize zoxide - a smarter cd command that learns your habits.
#
# Usage after init:
#   z <directory>  - Jump to frequently used directory
#   zi             - Interactive directory selection
#
# Examples:
#   z projects     - Jump to ~/projects (if frequently used)
#   z doc          - Jump to ~/Documents
#   zi             - Show menu of directories

if command -v zoxide &>/dev/null; then
    eval "$(zoxide init bash)"
fi
