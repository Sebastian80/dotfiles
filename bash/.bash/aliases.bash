#!/usr/bin/env bash
# ~/.bash/aliases
# Command aliases for all shells
# Loaded by: .bash_profile and .bashrc

# ============================================
# Navigation
# ============================================
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'

# ============================================
# Modern Tool Replacements (with fallbacks)
# ============================================

# eza (modern ls replacement) - check if available
if command -v eza &>/dev/null; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza --icons --long --group-directories-first --git'
    alias la='eza --icons --long --all --group-directories-first --git'
    alias lt='eza --icons --tree --level=2 --group-directories-first'
    alias lt3='eza --icons --tree --level=3 --group-directories-first'
    alias lls='/bin/ls'  # Original ls if needed
else
    # Fallback to standard ls with colors
    alias ls='ls --color=auto'
    alias ll='ls -alF'
    alias la='ls -A'
    alias l='ls -CF'
fi

# bat (cat with syntax highlighting) - check for both 'bat' and 'batcat'
if command -v bat &>/dev/null; then
    alias cat='bat --paging=never'
    alias ccat='/bin/cat'  # Original cat if needed
elif command -v batcat &>/dev/null; then
    alias bat='batcat'
    alias cat='batcat --paging=never'
    alias ccat='/bin/cat'
fi

# ripgrep - use 'rgg' to avoid breaking scripts that depend on 'grep' syntax
if command -v rg &>/dev/null; then
    alias rgg='rg'
    # DON'T override grep - rg has different syntax!
fi

# fd - fast find alternative
if command -v fdfind &>/dev/null; then
    alias fd='fdfind'
    # DON'T override find - fd has different syntax!
fi

# ============================================
# Standard Tool Enhancements
# ============================================

# Enable color support for common commands
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# System information with human-readable output
alias df='df -h'
alias du='du -h'
alias free='free -h'

# ============================================
# Git Shortcuts
# ============================================

alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'
alias glog='git log --oneline --graph --decorate'

# ============================================
# General Shortcuts
# ============================================

alias h='history'
alias j='jobs'
alias c='clear'
alias reload='source ~/.bashrc'
alias bashrc='${EDITOR:-micro} ~/.bashrc'
alias bashprofile='${EDITOR:-micro} ~/.bash_profile'

# ============================================
# Safety Aliases
# ============================================

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias mkdir='mkdir -pv'

# ============================================
# Special Aliases
# ============================================

# Enable aliases to be sudo'ed (the trailing space tells bash to check the next word for aliases)
alias sudo='sudo '

# Get week number
alias week='date +%V'

# Clipboard aliases (if xclip is available)
if command -v xclip &>/dev/null; then
    alias pbcopy='xclip -selection clipboard'
    alias pbpaste='xclip -selection clipboard -o'
fi

# ============================================
# Image Viewers
# ============================================

if command -v chafa &>/dev/null; then
    alias imgcat='chafa'
fi

if command -v viu &>/dev/null; then
    alias imgview='viu'
    alias img='viu'
fi

# ============================================
# Utility Aliases
# ============================================

# Alert for long running commands
# Usage: sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Show open ports
alias ports='netstat -tulanp'

# Get public IP address
alias myip='curl -s https://api.ipify.org && echo'

# Quick edit common files
alias hosts='sudo ${EDITOR:-micro} /etc/hosts'

# ============================================
# Tool-Specific Help
# ============================================

alias tools='terminal-tools-help'
alias help-tools='terminal-tools-help'
