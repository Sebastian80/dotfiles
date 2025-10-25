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
# 1. path          - PATH modifications (loaded first so tools are available)
# 2. exports/*     - Environment variables (modular)
# 3. prompt        - Prompt configuration (oh-my-posh)
# 4. aliases       - Command aliases
# 5. functions/*   - Bash functions (modular)
# 6. integrations/* - Terminal enhancement tool integrations (modular)
# 7. keybindings   - Custom keybindings
# 8. completion.old + completions/* - Bash completion (modular)
# 9. local         - Machine-specific settings (git-ignored)

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

# Load all integration modules (alphabetical order)
for file in ~/.bash/integrations/*.bash; do
    [ -r "$file" ] && source "$file"
done

# Load keybindings
[ -r ~/.bash/keybindings.bash ] && [ -f ~/.bash/keybindings.bash ] && source ~/.bash/keybindings.bash

# Load completion (legacy + new modular)
[ -r ~/.bash/completion.old ] && [ -f ~/.bash/completion.old ] && source ~/.bash/completion.old
for file in ~/.bash/completions/*.bash; do
    [ -r "$file" ] && source "$file"
done

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
