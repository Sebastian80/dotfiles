#!/usr/bin/env bash
# ~/.bash/functions/filesystem.bash
# File and directory operations
#
# Purpose:
#   Convenient functions for working with files and directories.
#   Includes navigation helpers, archive handling, and file preview.
#
# Functions:
#   mkd        - Create directory and cd into it
#   up         - Go up N directories
#   back/fwd   - Directory history navigation (pushd/popd)
#   extract    - Extract various archive formats
#   archive    - Create archives in various formats
#   preview    - Preview file with appropriate tool

# Create directory and cd into it
# Usage: mkd <directory>
# Example: mkd ~/projects/new-project
mkd() {
    mkdir -p "$@" && cd "$_" || return
}

# Go up N directories
# Usage: up [N]
# Example: up 3  # Goes up 3 directories
up() {
    local d=""
    local limit="${1:-1}"
    for ((i=1; i<=limit; i++)); do
        d="../$d"
    done
    cd "$d" || return
}

# Directory history navigation using pushd/popd
# Use 'cd' normally - these let you go back/forward
# Usage: back    - Go to previous directory
#        fwd     - Go forward (after going back)
#        dirs    - Show directory stack
#
# Enhanced cd that automatically pushes to stack
cd() {
    if [ -n "$1" ]; then
        builtin pushd "$1" > /dev/null || return
    else
        builtin pushd ~ > /dev/null || return
    fi
}

# Go back in directory history
back() {
    builtin popd > /dev/null || return
    pwd
}

# Go forward - swap top two entries
fwd() {
    builtin pushd +1 > /dev/null 2>&1 || echo "No forward history"
}

# Show directory stack nicely
dh() {
    dirs -v | head -20
}

# Extract most known archive formats
# Supports: tar.bz2, tar.gz, tar.xz, bz2, rar, gz, tar, tbz2, tgz, zip, Z, 7z
# Usage: extract <archive_file>
# Example: extract myfile.tar.gz
extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1"     ;;
            *.tar.gz)    tar xzf "$1"     ;;
            *.tar.xz)    tar xJf "$1"     ;;
            *.bz2)       bunzip2 "$1"     ;;
            *.rar)       unrar e "$1"     ;;
            *.gz)        gunzip "$1"      ;;
            *.tar)       tar xf "$1"      ;;
            *.tbz2)      tar xjf "$1"     ;;
            *.tgz)       tar xzf "$1"     ;;
            *.zip)       unzip "$1"       ;;
            *.Z)         uncompress "$1"  ;;
            *.7z)        7z x "$1"        ;;
            *)           echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Create archive in various formats
# Supports: tar.gz, tar.bz2, tar.xz, zip, 7z
# Usage: archive <archive_name.ext> <files...>
# Examples:
#   archive backup.tar.gz mydir/
#   archive project.zip file1.txt file2.txt folder/
archive() {
    if [ $# -lt 2 ]; then
        echo "Usage: archive <archive_name.ext> <files...>"
        return 1
    fi

    local archive_name="$1"
    shift

    case "$archive_name" in
        *.tar.gz)  tar czf "$archive_name" "$@" ;;
        *.tar.bz2) tar cjf "$archive_name" "$@" ;;
        *.tar.xz)  tar cJf "$archive_name" "$@" ;;
        *.zip)     zip -r "$archive_name" "$@" ;;
        *.7z)      7z a "$archive_name" "$@" ;;
        *)         echo "Unknown archive format: $archive_name" ;;
    esac
}

# Preview file with appropriate tool
# Auto-detects file type and uses best available tool:
#   - Markdown: glow (if available) or cat
#   - Images: viu or chafa (if available)
#   - JSON: jq (if available) or cat
#   - Other: bat/batcat (if available) or cat
# Usage: preview <file>
# Example: preview README.md
preview() {
    local file="$1"
    if [ -z "$file" ]; then
        echo "Usage: preview <file>"
        return 1
    fi

    case "${file##*.}" in
        md|markdown)
            command -v glow &>/dev/null && glow "$file" || cat "$file"
            ;;
        jpg|jpeg|png|gif|bmp|webp)
            command -v viu &>/dev/null && viu "$file" || \
            command -v chafa &>/dev/null && chafa "$file" || \
            echo "No image viewer available"
            ;;
        json)
            command -v jq &>/dev/null && jq . "$file" || cat "$file"
            ;;
        *)
            if command -v bat &>/dev/null; then
                bat "$file"
            elif command -v batcat &>/dev/null; then
                batcat "$file"
            else
                cat "$file"
            fi
            ;;
    esac
}
