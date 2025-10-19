#!/usr/bin/env bash
# ~/.bashrc
# Bash configuration for interactive non-login shells
# Executed for: new terminal tabs, subshells, etc.

# ============================================
# Early Exit for Non-Interactive Shells
# ============================================

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

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

# Append to the Bash history file, rather than overwriting it
shopt -s histappend

# Check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS
shopt -s checkwinsize

# Autocorrect typos in path names when using `cd`
shopt -s cdspell

# Enable Bash 4+ features (if available)
if [ "${BASH_VERSINFO[0]}" -ge 4 ]; then
    # ** recursive globbing
    shopt -s globstar

    # Autocorrect directory names during word completion
    shopt -s dirspell

    # Save multi-line commands as one history entry
    shopt -s cmdhist
fi

# ============================================
# History Configuration
# ============================================

# History size (set here for redundancy, also set in ~/.bash/exports)
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoreboth:erasedups
export HISTIGNORE="ls:ll:cd:pwd:exit:clear:history"
export HISTTIMEFORMAT="%F %T "

# ============================================
# Less Configuration
# ============================================

# Make less more friendly for non-text input files
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# ============================================
# Chroot Identification
# ============================================

# Set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# ============================================
# dircolors Configuration
# ============================================

# Enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    # Use custom dircolors if available
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
fi

# ============================================
# Optional: Welcome Message
# ============================================

# Uncomment to show a welcome message when opening a new terminal
# echo "Welcome to $(hostname)!"
# echo "Type 'tools' for a list of available terminal enhancement tools."
