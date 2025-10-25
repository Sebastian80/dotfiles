#!/usr/bin/env bash
# ~/.bash/functions/yazi.bash
# yazi terminal file manager shell wrapper
#
# Purpose:
#   Provide shell wrapper function for yazi that changes directory on exit.
#
# Functions:
#   y [args]  - Open yazi and cd to final directory on exit
#
# Usage:
#   y           - Open yazi in current directory
#   y /path     - Open yazi in specific path
#   Press 'q'   - Quit and change to final directory
#   Press 'Q'   - Quit without changing directory
#
# How it works:
#   - Creates temporary file to store final directory
#   - Yazi writes cwd to temp file on exit with 'q'
#   - Wrapper reads temp file and changes directory
#   - Temp file is cleaned up after use
#
# Keybinding:
#   Ctrl+O opens yazi (configured in ~/.bash/keybindings.bash)

if command -v yazi &>/dev/null; then
    # Shell wrapper function - changes directory on exit with 'q'
    # Press 'Q' (capital) to quit without changing directory
    function y() {
        local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
        yazi "$@" --cwd-file="$tmp"
        if IFS= read -r -d '' cwd < "$tmp" 2>/dev/null; then
            [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
        fi
        rm -f -- "$tmp"
    }
fi
