#!/usr/bin/env bash
# ~/.bash/functions/misc.bash
# Miscellaneous utility functions
#
# Purpose:
#   Various helper functions that don't fit in other categories.
#
# Functions:
#   weather - Get weather forecast
#   eza     - Wrapper to fix eza stdin regression bug

# Weather forecast
# Gets weather information from wttr.in
# Usage: weather [location]
# Examples:
#   weather           # Weather for current location (based on IP)
#   weather Berlin    # Weather for Berlin
#   weather "New York" # Weather for New York
weather() {
    local location="${1:-}"
    curl -s "wttr.in/${location}?format=3"
}

# eza wrapper to fix stdin regression bug (v0.23.0+)
# Issue: https://github.com/eza-community/eza/issues/1568
# Problem: When stdin is available (pipes, command substitution), eza reads it
#          and may produce no output if stdin is empty.
# Solution: Force explicit path when stdin is not a TTY or when no arguments provided.
# Usage: Same as regular eza command
eza() {
    # If stdin is a TTY or arguments were provided, use eza normally
    if [[ -t 0 ]] || [[ $# -gt 0 ]]; then
        command eza "$@"
    else
        # Non-TTY stdin with no args: force current directory
        command eza . "$@"
    fi
}
