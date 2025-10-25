#!/usr/bin/env bash
# ~/.bash/completions/dynamic.bash
# Dynamic completion generators for tools that don't provide static completion files
#
# Purpose:
#   Lazy-load completions for tools that provide completion generators via
#   subcommands (e.g., 'docker completion bash', 'npm completion').
#   This follows bash-completion v2's lazy-loading pattern for fast shell startup.
#
# Architecture:
#   Instead of running expensive `eval "$(tool completion bash)"` at shell startup,
#   we register minimal stub completions that generate the real completion on first use.
#
# Supported Tools:
#   - docker  : docker completion bash
#   - git     : git's built-in completion (via Homebrew git formula)
#   - lazygit : currently no completion available

# ============================================
# Docker Completion (Lazy Loading)
# ============================================

if command -v docker &>/dev/null && ! complete -p docker &>/dev/null; then
    # Register a stub completion that will load the real one on first TAB
    _docker_lazy_load() {
        # Remove this stub
        complete -r docker 2>/dev/null
        unset -f _docker_lazy_load

        # Generate and eval the real completion
        if eval "$(docker completion bash 2>/dev/null)"; then
            # Now call the real completion function for the current command line
            if declare -F _docker &>/dev/null || declare -F __start_docker &>/dev/null; then
                _init_completion || return
                # Let bash-completion handle the actual completion
                return 124  # Tell bash to retry completion with new function
            fi
        fi
    }

    # Register the lazy loader
    complete -F _docker_lazy_load docker
fi

# ============================================
# Git Completion
# ============================================

# Git completion is provided by the system's bash-completion package
# at /usr/share/bash-completion/completions/git and will be automatically
# lazy-loaded by bash-completion framework. No manual setup needed.

# For 'g' alias (git shortcut), we need lazy-loading wrapper
if alias g &>/dev/null 2>&1; then
    _g_lazy_load() {
        # Remove this stub
        complete -r g 2>/dev/null
        unset -f _g_lazy_load

        # Trigger git completion loading (it's lazy-loaded by bash-completion)
        # We do this by attempting to complete 'git' which loads its completion
        _comp_load git 2>/dev/null || _completion_loader git 2>/dev/null || true

        # Now check if git completion function exists and map it to 'g'
        if declare -F __git_wrap__git_main &>/dev/null; then
            complete -o bashdefault -o default -o nospace -F __git_wrap__git_main g
        elif declare -F _git &>/dev/null; then
            complete -o bashdefault -o default -o nospace -F _git g
        fi

        # Retry completion with the newly loaded function
        return 124
    }

    complete -F _g_lazy_load g
fi

# ============================================
# NPM Completion (Lazy Loading)
# ============================================

# Note: npm completion is typically provided as a static file by Homebrew's node formula
# at /home/linuxbrew/.linuxbrew/etc/bash_completion.d/npm, so bash-completion
# should auto-discover it. This is here as a fallback.

if command -v npm &>/dev/null && ! complete -p npm &>/dev/null; then
    _npm_lazy_load() {
        complete -r npm 2>/dev/null
        unset -f _npm_lazy_load

        if eval "$(npm completion 2>/dev/null)"; then
            if declare -F _npm_completion &>/dev/null; then
                _init_completion || return
                return 124  # Tell bash to retry completion with new function
            fi
        fi
    }
    complete -F _npm_lazy_load npm
fi

# ============================================
# Summary of Completion Coverage
# ============================================

# ✓ Auto-discovered by bash-completion's lazy loader (from bash_completion.d/):
#   - gh        : Homebrew's gh formula provides completion file
#   - bat       : Homebrew's bat formula provides completion file
#   - brew      : Homebrew provides its own completion
#   - eza       : Homebrew's eza formula provides completion file
#   - npm       : Homebrew's node formula provides npm completion file
#   - git       : System bash-completion package (/usr/share/bash-completion/completions/git)
#
# ✓ Dynamically generated (by this file):
#   - docker    : Lazy-loaded via 'docker completion bash'
#   - g (alias) : Lazy-loaded wrapper that maps to git completion
#
# ✓ Init-based completion (handled in ~/.bash/integrations/):
#   - zoxide    : eval "$(zoxide init bash)" provides 'z' and 'zi' completion
#   - fzf       : Sources shell/completion.bash for **<TAB> trigger completion
#
# ✗ No completion available:
#   - lazygit   : No official bash completion (TUI tool, less critical)
#   - yazi      : No official bash completion (TUI tool, less critical)
#   - fd        : No official bash completion (simple CLI, less critical)
#   - rg        : No official bash completion (simple CLI, less critical)
