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

    # Fix for execution timer bug:
    # _omp_hook sets _omp_start_time='' (empty) at the end, but the check
    # [[ -n "${_omp_start_time+x}" ]] tests if SET, not if HAS VALUE.
    # When no command runs (just Enter), it calculates now - "" = now - 0 = epoch time.
    # Solution: Wrap _omp_hook to unset empty _omp_start_time BEFORE it runs.
    if declare -f _omp_hook &>/dev/null; then
        # Copy original function to new name
        eval "$(declare -f _omp_hook | sed '1s/_omp_hook/_omp_hook_orig/')"
        # Redefine _omp_hook with fix
        _omp_hook() {
            # Clear empty timer to prevent epoch calculation
            [[ -z "$_omp_start_time" ]] && unset _omp_start_time
            _omp_hook_orig
        }
    fi

    # Enable oh-my-posh's built-in OSC 133;C support (marks command execution)
    # This provides FTCS (Final Term Command Set) marks for better terminal integration
    _omp_ftcs_marks=1
fi

# ============================================
# Ghostty Shell Integration
# ============================================
# Load Ghostty integration (adds sudo, ssh wrappers, OSC 7 directory tracking)
# This provides features we lose by disabling shell-integration in Ghostty config
if [[ -f ~/.config/ghostty/integration.bash ]]; then
    source ~/.config/ghostty/integration.bash
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
