#!/usr/bin/env bash
# ~/.bash/functions/fzf.bash
# fzf utility functions
#
# Purpose:
#   Provide convenient fzf-based functions for file navigation and editing.
#
# Functions:
#   fe [query]      - Find and edit file with fzf
#   fcd [path]      - Find and cd into directory with fzf
#   fsearch [query] - Search files with preview
#
# Dependencies:
#   - fzf (fuzzy finder)
#   - fd/fdfind (optional, faster than find)
#   - preview function (for fsearch)
#
# Note:
#   Core fzf keybindings (Ctrl+R, Ctrl+T, Alt+C) are loaded via
#   ~/.bash/integrations/fzf.bash

# Find and edit file
# Usage: fe [query]
# Opens selected file in $EDITOR (defaults to micro)
fe() {
    local file
    file=$(fzf --query="$1" --select-1 --exit-0)
    [ -n "$file" ] && ${EDITOR:-micro} "$file"
}

# Find and cd into directory
# Usage: fcd [starting_path]
# Uses fd/fdfind if available, otherwise falls back to find
fcd() {
    local dir
    if command -v fd &>/dev/null; then
        dir=$(fd --type d "${1:-.}" | fzf +m)
    elif command -v fdfind &>/dev/null; then
        dir=$(fdfind --type d "${1:-.}" | fzf +m)
    else
        dir=$(find "${1:-.}" -type d 2>/dev/null | fzf +m)
    fi
    [ -n "$dir" ] && cd "$dir" || return
}

# Quick file search and preview
# Usage: fsearch [query]
# Searches files with live preview using preview function
fsearch() {
    if command -v fzf &>/dev/null; then
        local file
        file=$(fzf --query="$1" --preview 'preview {}')
        [ -n "$file" ] && preview "$file"
    else
        echo "fzf not installed"
    fi
}
