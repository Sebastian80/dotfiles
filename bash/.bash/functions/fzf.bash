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
#   fkill           - Find and kill process interactively
#   fgb             - Git branch switcher with preview
#   fgl             - Git log browser with commit preview
#   fssh            - SSH host picker from ~/.ssh/config
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

# Kill process interactively
# Usage: fkill [signal]
# Example: fkill       # Default SIGTERM
#          fkill -9    # Force kill with SIGKILL
fkill() {
    local signal="${1:--TERM}"
    local pids

    pids=$(ps -eo pid,user,comm,args --no-headers | \
        fzf -m --height=50% \
            --header="Select process(es) to kill [$signal] (Tab to multi-select)" \
            --preview='ps -p {1} -o pid,ppid,user,%cpu,%mem,start,command 2>/dev/null || echo "Process info unavailable"' \
            --preview-window=down:3:wrap | \
        awk '{print $1}')

    if [ -n "$pids" ]; then
        echo "$pids" | xargs kill "$signal" 2>/dev/null
        echo "Sent $signal to PID(s): $pids"
    fi
}

# Git branch switcher with preview
# Usage: fgb
# Shows log preview of selected branch
fgb() {
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        echo "Not in a git repository"
        return 1
    fi

    local branch
    branch=$(git branch --all | grep -v HEAD | \
        sed 's/^[* ]*//' | \
        fzf --height=50% \
            --header="Select branch (Enter to checkout)" \
            --preview='git log --oneline --graph --color=always {} | head -30' \
            --preview-window=right:50% | \
        sed 's|remotes/origin/||')

    if [ -n "$branch" ]; then
        git checkout "$branch"
    fi
}

# Git log browser with commit preview
# Usage: fgl [path]
# Enter to view full commit, Ctrl-Y to copy hash
fgl() {
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        echo "Not in a git repository"
        return 1
    fi

    local log_format="%C(yellow)%h%C(reset) %C(blue)%ad%C(reset) %C(green)%an%C(reset) %s"
    local commit

    commit=$(git log --date=short --format="$log_format" --color=always "$@" | \
        fzf --ansi --no-sort --height=60% \
            --header='Enter: view commit | Ctrl-Y: copy hash' \
            --preview='git show --color=always {1}' \
            --preview-window=right:60% \
            --bind='ctrl-y:execute-silent(echo -n {1} | xclip -selection clipboard)+abort' | \
        awk '{print $1}')

    if [ -n "$commit" ]; then
        git show "$commit"
    fi
}

# SSH host picker from config
# Usage: fssh
# Parses ~/.ssh/config for Host entries
fssh() {
    local host

    if [ ! -f ~/.ssh/config ]; then
        echo "No ~/.ssh/config found"
        return 1
    fi

    host=$(grep -E "^Host\s+" ~/.ssh/config | \
        grep -v '[*?]' | \
        awk '{print $2}' | \
        fzf --height=40% \
            --header='Select SSH host' \
            --preview='grep -A10 "^Host {}" ~/.ssh/config | head -10' \
            --preview-window=right:40%)

    if [ -n "$host" ]; then
        echo "Connecting to $host..."
        ssh "$host"
    fi
}
