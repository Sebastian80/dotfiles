#!/usr/bin/env bash
# ~/.bash/functions/dev.bash
# Development helper functions
#
# Purpose:
#   Tools for common development tasks like virtual environments,
#   local servers, calculations, and note-taking.
#
# Functions:
#   venv    - Create/activate Python virtual environment
#   serve   - Start HTTP server for current directory
#   calc    - Quick calculator
#   genpass - Generate random password
#   backup  - Create timestamped backup
#   note    - Create/edit timestamped notes

# Create and activate Python virtual environment
# If venv exists, activates it. Otherwise, creates new one.
# Usage: venv
venv() {
    if [ -d "venv" ]; then
        echo "Activating existing venv..."
        source venv/bin/activate
    else
        echo "Creating new venv..."
        python3 -m venv venv
        source venv/bin/activate
        echo "✓ Virtual environment created and activated"
    fi
}

# Start simple HTTP server
# Serves current directory over HTTP for testing
# Usage: serve [port]
# Examples:
#   serve        # Start on default port 8000
#   serve 3000   # Start on port 3000
serve() {
    local port="${1:-8000}"
    if command -v python3 &>/dev/null; then
        echo "Starting HTTP server on port $port..."
        python3 -m http.server "$port"
    elif command -v python &>/dev/null; then
        echo "Starting HTTP server on port $port..."
        python -m SimpleHTTPServer "$port"
    else
        echo "Python not found"
        return 1
    fi
}

# Quick calculator
# Uses bc for arbitrary precision calculations
# Usage: calc <expression>
# Examples:
#   calc "2 + 2"
#   calc "sqrt(2)"
#   calc "scale=4; 22/7"  # Pi approximation with 4 decimal places
calc() {
    echo "$*" | bc -l
}

# Generate random password
# Uses openssl if available, otherwise /dev/urandom
# Usage: genpass [length]
# Examples:
#   genpass      # Generate 16-character password
#   genpass 32   # Generate 32-character password
genpass() {
    local length="${1:-16}"
    if command -v openssl &>/dev/null; then
        openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
    else
        cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w "$length" | head -n 1
    fi
}

# Backup file/directory with timestamp
# Creates a copy with .backup.YYYYMMDD_HHMMSS suffix
# Usage: backup <file_or_directory>
# Example: backup important-file.txt
#   Creates: important-file.txt.backup.20251023_220530
backup() {
    if [ -z "$1" ]; then
        echo "Usage: backup <file_or_directory>"
        return 1
    fi
    local timestamp=$(date +%Y%m%d_%H%M%S)
    cp -r "$1" "${1}.backup.${timestamp}"
    echo "✓ Backup created: ${1}.backup.${timestamp}"
}

# Create timestamped note file
# Opens daily note file in $EDITOR or appends quick note
# Usage:
#   note                  # Open today's note in editor
#   note "Quick thought"  # Append timestamped line to today's note
# Notes location: ~/notes/YYYY-MM-DD.md
note() {
    local notedir="$HOME/notes"
    mkdir -p "$notedir"
    local notefile="$notedir/$(date +%Y-%m-%d).md"

    if [ -n "$1" ]; then
        echo "$(date +%H:%M:%S) - $*" >> "$notefile"
    else
        ${EDITOR:-micro} "$notefile"
    fi
}
