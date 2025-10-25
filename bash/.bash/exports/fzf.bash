#!/usr/bin/env bash
# ~/.bash/exports/fzf.bash
# fzf environment configuration
#
# Purpose:
#   Configure fzf search commands and preview options for keybindings.
#   These exports control the behavior of Ctrl+R, Ctrl+T, and Alt+C.
#
# Exports:
#   FZF_DEFAULT_OPTS_FILE - Points to main fzf config
#   FZF_DEFAULT_COMMAND   - Default file search command (uses fd/fdfind)
#   FZF_CTRL_T_COMMAND    - Command for Ctrl+T file finder
#   FZF_CTRL_T_OPTS       - Preview options for Ctrl+T
#   FZF_CTRL_R_OPTS       - Preview options for Ctrl+R history
#   FZF_ALT_C_COMMAND     - Command for Alt+C directory navigator
#   FZF_ALT_C_OPTS        - Preview options for Alt+C
#
# Note:
#   Keybindings are loaded separately in ~/.bash/integrations/fzf.bash

# Point to the main config file (shell-agnostic options)
export FZF_DEFAULT_OPTS_FILE="$HOME/.config/fzf/config"

# File searching backend - use fd if available, fallback to find
if command -v fd &>/dev/null; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
elif command -v fdfind &>/dev/null; then
    export FZF_DEFAULT_COMMAND='fdfind --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fdfind --type d --hidden --follow --exclude .git'
fi

# Ctrl+T: File/Directory Finder
# Preview file contents with bat (text files only), directories with eza
# Use 'file' command to detect binary files by checking charset
# -L flag follows symlinks (important for stow-managed dotfiles)
# Checks for charset=binary to exclude true binaries while allowing JSON, XML, YAML, etc.
if command -v bat &>/dev/null && command -v eza &>/dev/null; then
    export FZF_CTRL_T_OPTS="--walker-skip .git,node_modules,target,.venv,__pycache__ --preview 'if [ -d {} ]; then eza --tree --color=always --icons {} | head -200; elif file -bL --mime {} | grep -qv \"charset=binary\"; then bat -n --color=always --line-range :500 {}; else echo \"[Binary file - no preview]\"; fi' --bind 'ctrl-/:change-preview-window(down|hidden|)' --header 'Press CTRL-/ to toggle preview'"
elif command -v bat &>/dev/null; then
    export FZF_CTRL_T_OPTS="--walker-skip .git,node_modules,target,.venv,__pycache__ --preview 'if file -bL --mime {} | grep -qv \"charset=binary\"; then bat -n --color=always --line-range :500 {}; else echo \"[Binary file - no preview]\"; fi' --bind 'ctrl-/:change-preview-window(down|hidden|)'"
fi

# Ctrl+R: History Search
# Simple echo preview for command history (no bat errors!)
export FZF_CTRL_R_OPTS="--preview 'echo {}' --preview-window down:3:hidden:wrap --bind '?:toggle-preview' --exact --header 'Press ? to toggle command preview'"

# Alt+C: Directory Navigator
# Show directory tree with eza
if command -v eza &>/dev/null; then
    export FZF_ALT_C_OPTS="--walker-skip .git,node_modules,target --preview 'eza --tree --color=always --icons {} | head -200'"
fi
