#!/usr/bin/env bash
# ~/.bash/completions/bitwarden.bash
# Bash completion for Bitwarden CLI (bw)
#
# Purpose:
#   Tab completion for the enhanced 'bw' function with shortcuts.
#   Supports both custom shortcuts and official bw commands.
#
# Completions:
#   bw <TAB>       - Show all shortcuts + official commands
#   bw list <TAB>  - Show item types (items, folders, etc.)
#   bw --<TAB>     - Show common options (--pretty, --raw, etc.)

if declare -f bw &>/dev/null; then
    _bw_completion() {
        local cur prev commands shortcuts item_types
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"

        # Shortcut commands (handled by our bw function)
        shortcuts="get g copy c search find f list ls l unlock u lock sync status s help h"

        # Official bw commands (pass-through to original CLI)
        commands="login logout generate encode config update completion create edit delete restore move confirm share import export send receive"

        # Item types for list/get commands
        item_types="items folders collections organizations org-collections org-members"

        case "${prev}" in
            bw)
                # Complete with both shortcuts and official commands
                COMPREPLY=($(compgen -W "${shortcuts} ${commands}" -- "${cur}"))
                return 0
                ;;
            list|get|ls|l)
                COMPREPLY=($(compgen -W "${item_types}" -- "${cur}"))
                return 0
                ;;
            --session)
                # Don't complete session tokens
                return 0
                ;;
            *)
                # Complete with common options
                if [[ ${cur} == -* ]]; then
                    COMPREPLY=($(compgen -W "--pretty --raw --response --session --help" -- "${cur}"))
                fi
                return 0
                ;;
        esac
    }

    complete -F _bw_completion bw
fi
