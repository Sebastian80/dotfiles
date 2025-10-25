#!/usr/bin/env bash
# ~/.bash/keybindings.bash
# Custom bash keybindings
#
# Purpose:
#   Centralized configuration for all custom keyboard shortcuts.
#   Only active in interactive shells.
#
# Keybindings:
#   Ctrl+O  - Open yazi file manager
#
# Note:
#   fzf keybindings (Ctrl+R, Ctrl+T, Alt+C) are loaded separately
#   via ~/.bash/integrations/fzf.bash from Homebrew's official scripts

# Only set keybindings in interactive shells
if [[ $- == *i* ]]; then
    # Ctrl+O: Open yazi file manager
    # Uses the y() function from ~/.bash/functions/yazi.bash
    # which changes to the last directory on exit
    if command -v yazi &>/dev/null; then
        bind -x '"\C-o": y' 2>/dev/null
    fi
fi
