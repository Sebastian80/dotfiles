#!/usr/bin/env bash
# ~/.bash_profile
# Bash profile for login shells
# Executed for login shells (SSH sessions, macOS Terminal.app, etc.)

# ============================================
# Load Modular Bash Configuration
# ============================================

# Load shell dotfiles in a specific order:
# * path       - PATH modifications (loaded first so other scripts can find tools)
# * exports    - Environment variables
# * prompt     - Prompt configuration (oh-my-posh)
# * aliases    - Command aliases
# * functions  - Bash functions
# * tools      - Terminal enhancement tool integrations
# * completion - Bash completion
# * local      - Machine-specific settings (git-ignored)

for file in ~/.bash/{path,exports,prompt,aliases,functions,tools,completion,local}; do
    if [ -r "$file" ] && [ -f "$file" ]; then
        source "$file"
    fi
done
unset file

# ============================================
# Shell Options
# ============================================

# Case-insensitive globbing (used in pathname expansion)
shopt -s nocaseglob

# Append to the Bash history file, rather than overwriting it
shopt -s histappend

# Autocorrect typos in path names when using `cd`
shopt -s cdspell

# Check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS
shopt -s checkwinsize

# Enable Bash 4+ features (if available)
if [ "${BASH_VERSINFO[0]}" -ge 4 ]; then
    # ** recursive globbing
    shopt -s globstar

    # cd into a directory just by typing its name
    shopt -s autocd

    # Autocorrect directory names during word completion
    shopt -s dirspell

    # Save multi-line commands as one history entry
    shopt -s cmdhist
fi

# ============================================
# Less Configuration
# ============================================

# Make less more friendly for non-text input files
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# ============================================
# dircolors Configuration
# ============================================

# Enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    # Use custom dircolors if available
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
fi

# ============================================
# Load .bashrc (for consistency across shell types)
# ============================================

# Source .bashrc if it exists
# This ensures that both login and non-login shells have the same environment
if [ -r ~/.bashrc ]; then
    source ~/.bashrc
fi
