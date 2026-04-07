#!/usr/bin/env bash
# ~/.bash/prompt
# Prompt configuration for oh-my-posh
# Loaded by: .bash_profile and .bashrc

# ============================================
# oh-my-posh - Modern Prompt Engine
# ============================================
if command -v oh-my-posh &>/dev/null; then
    # Initialize oh-my-posh with custom theme
    eval "$(oh-my-posh init bash --config ~/.config/oh-my-posh/themes/netresearch.omp.json)"

    # Ghostty 1.3.x auto-injects shell integration (__ghostty_hook) which handles
    # all OSC 133 FTCS marks (A/B/C/D) for jump_to_prompt, click-to-cursor, etc.
    # Disable oh-my-posh's own 133;C to avoid duplicate marks.
    _omp_ftcs_marks=0
fi

# ============================================
# Fallback Prompt (if oh-my-posh not available)
# ============================================
if ! command -v oh-my-posh &>/dev/null; then
    # Define colors
    if tput setaf 1 &>/dev/null; then
        bold=$(tput bold)
        reset=$(tput sgr0)
        black=$(tput setaf 0)
        red=$(tput setaf 1)
        green=$(tput setaf 2)
        yellow=$(tput setaf 3)
        blue=$(tput setaf 4)
        magenta=$(tput setaf 5)
        cyan=$(tput setaf 6)
        white=$(tput setaf 7)
    else
        bold=''
        reset="\e[0m"
        black="\e[1;30m"
        red="\e[1;31m"
        green="\e[1;32m"
        yellow="\e[1;33m"
        blue="\e[1;34m"
        magenta="\e[1;35m"
        cyan="\e[1;36m"
        white="\e[1;37m"
    fi

    # Git prompt support
    if [ -f /usr/share/git/completion/git-prompt.sh ]; then
        source /usr/share/git/completion/git-prompt.sh
    elif [ -f /usr/lib/git-core/git-sh-prompt ]; then
        source /usr/lib/git-core/git-sh-prompt
    fi

    # Set prompt
    PS1="\[${bold}\]\[${cyan}\]\u@\h\[${reset}\]:\[${blue}\]\w\[${reset}\]"
    PS1+="\$(__git_ps1 ' \[${magenta}\](%s)\[${reset}\]')"
    PS1+=" \[${green}\]\\$\[${reset}\] "

    export PS1
fi
