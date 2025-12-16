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
# 1. path            - PATH modifications (loaded first so tools are available)
# 2. exports/*       - Environment variables (modular)
# 3. prompt          - Prompt configuration (oh-my-posh)
# 4. aliases         - Command aliases
# 5. functions/*     - Bash functions (modular)
# 6. bash-completion - Framework (loaded before integrations for proper support)
# 7. completions/*   - Custom completion scripts (modular)
# 8. integrations/*  - Terminal enhancement tool integrations (modular)
# 9. keybindings     - Custom keybindings
# 10. local          - Machine-specific settings (git-ignored)

# Load PATH first
[ -r ~/.bash/path.bash ] && [ -f ~/.bash/path.bash ] && source ~/.bash/path.bash

# Load all export modules (alphabetical order)
for file in ~/.bash/exports/*.bash; do
    [ -r "$file" ] && source "$file"
done

# Load prompt
[ -r ~/.bash/prompt.bash ] && [ -f ~/.bash/prompt.bash ] && source ~/.bash/prompt.bash

# Load aliases
[ -r ~/.bash/aliases.bash ] && [ -f ~/.bash/aliases.bash ] && source ~/.bash/aliases.bash

# Load all function modules (alphabetical order)
for file in ~/.bash/functions/*.bash; do
    [ -r "$file" ] && source "$file"
done

# Load bash-completion framework via Homebrew's official loader
# This properly sets BASH_COMPLETION_COMPAT_DIR and enables lazy loading
# Loaded before integrations so tools can utilize bash-completion utilities
# Requires bash-completion@2 formula: brew install bash-completion@2
# PERFORMANCE: Use cached HOMEBREW_PREFIX from path.bash (avoids ~150ms brew --prefix call)
if [[ -n "$HOMEBREW_PREFIX" && -r "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh" ]]; then
    source "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh"
fi

# Load custom completion scripts (modular)
# These can now use bash-completion framework utilities like _init_completion
for file in ~/.bash/completions/*.bash; do
    [ -r "$file" ] && source "$file"
done

# Load all integration modules (alphabetical order)
# Integrations like zoxide and fzf can now utilize bash-completion if needed
for file in ~/.bash/integrations/*.bash; do
    [ -r "$file" ] && source "$file"
done

# Load keybindings
[ -r ~/.bash/keybindings.bash ] && [ -f ~/.bash/keybindings.bash ] && source ~/.bash/keybindings.bash

# Load machine-specific config last
[ -r ~/.bash/local.bash ] && [ -f ~/.bash/local.bash ] && source ~/.bash/local.bash

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

# Enable Bash 4+ features
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

# History settings are configured in ~/.bash/exports

# ============================================
# Chroot Identification
# ============================================

# Set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# ============================================
# Optional: Welcome Message
# ============================================

# Uncomment to show a welcome message when opening a new terminal
# echo "Welcome to $(hostname)!"
# echo "Type 'tools' for a list of available terminal enhancement tools."
