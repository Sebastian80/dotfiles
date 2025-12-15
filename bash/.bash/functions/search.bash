#!/usr/bin/env bash
# ~/.bash/functions/search.bash
# Search and find operations
#
# Purpose:
#   Fast file and content searching with automatic fallbacks.
#   Uses modern tools (fd, ripgrep) when available, traditional tools otherwise.
#
# Functions:
#   ff       - Find files by name
#   search   - Search file contents
#   largest  - Show largest files/directories

# Find files by name
# Uses fd/fdfind if available (faster), otherwise falls back to find
# Usage: ff <pattern>
# Examples:
#   ff '*.js'              # Find all JavaScript files
#   ff README              # Find files named README
#   ff -e pdf -e doc       # Find PDFs and DOCs (fd syntax)
ff() {
    if command -v fd &>/dev/null; then
        fd "$@"
    elif command -v fdfind &>/dev/null; then
        fdfind "$@"
    else
        # Use $* to join arguments into single pattern (avoids word splitting issues)
        find . -iname "*$**" 2>/dev/null
    fi
}

# Search file contents
# Uses ripgrep (rg) if available (faster), otherwise falls back to grep
# Usage: search <pattern> [path]
# Examples:
#   search "TODO"          # Search for TODO in current directory
#   search "function.*foo" # Regex search
#   search "API_KEY" src/  # Search in specific directory
search() {
    if command -v rg &>/dev/null; then
        rg "$@"
    else
        grep -r "$@" .
    fi
}

# Show largest files/directories
# Displays disk usage sorted by size
# Usage: largest [directory] [count]
# Examples:
#   largest               # Show 20 largest in current directory
#   largest /var/log 10   # Show 10 largest in /var/log
#   largest ~ 50          # Show 50 largest in home directory
largest() {
    du -ah "${1:-.}" 2>/dev/null | sort -rh | head -n "${2:-20}"
}
