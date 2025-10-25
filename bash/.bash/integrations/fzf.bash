#!/usr/bin/env bash
# ~/.bash/integrations/fzf.bash
# fzf fuzzy finder integration
#
# Purpose:
#   Initialize fzf keybindings and completion:
#   - Ctrl+R: Search command history
#   - Ctrl+T: Find files
#   - Alt+C: Change directory
#
# Architecture:
#   - Exports configured in: ~/.bash/exports/fzf.bash
#   - Functions defined in: ~/.bash/functions/fzf.bash
#   - This file loads: official Homebrew keybindings + completion

if command -v fzf &>/dev/null; then
    # Determine fzf installation path
    if command -v brew &>/dev/null; then
        FZF_BASE="$(brew --prefix)/opt/fzf"
    fi

    # Load fzf keybindings (Ctrl+R, Ctrl+T, Alt+C)
    if [ -n "$FZF_BASE" ] && [ -f "$FZF_BASE/shell/key-bindings.bash" ]; then
        source "$FZF_BASE/shell/key-bindings.bash"
    fi

    # Load fzf completion (triggers fzf on **<TAB>)
    if [ -n "$FZF_BASE" ] && [ -f "$FZF_BASE/shell/completion.bash" ]; then
        source "$FZF_BASE/shell/completion.bash"
    fi

    unset FZF_BASE
fi
