#!/usr/bin/env bash
# ~/.bash/integrations/zoxide.bash
# zoxide smart cd integration
#
# Purpose:
#   Initialize zoxide - a smarter cd command that learns your habits.
#
# Usage after init:
#   z <directory>  - Jump to frequently used directory
#   zi             - Interactive directory selection
#
# Examples:
#   z projects     - Jump to ~/projects (if frequently used)
#   z doc          - Jump to ~/Documents
#   zi             - Show menu of directories

if command -v zoxide &>/dev/null; then
    eval "$(zoxide init bash)"

    # Override default completion with frecency-based completion
    # Default only shows local directories; this shows zoxide's database
    _zoxide_frecency_complete() {
        local cur="${COMP_WORDS[COMP_CWORD]}"
        local IFS=$'\n'

        # Query zoxide database, filter by current input, show top 20
        COMPREPLY=($(
            zoxide query --list 2>/dev/null | \
            grep -i "${cur}" | \
            head -20 | \
            sed "s|^$HOME|~|"
        ))

        # Fall back to regular directory completion if no matches
        if [[ ${#COMPREPLY[@]} -eq 0 ]]; then
            COMPREPLY=($(compgen -d -- "$cur"))
        fi
    }

    complete -o filenames -o nospace -F _zoxide_frecency_complete z
fi
