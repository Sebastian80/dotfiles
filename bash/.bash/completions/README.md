# Bash Completions

This directory contains bash completion configurations split into modular files.

## Files

- `bitwarden.bash` - Bitwarden CLI (bw) completion with shortcut support
- Future: Add more modular completions as needed

## Note

Most completions are handled by:
1. Homebrew bash-completion (automatic for installed tools)
2. System bash-completion (/usr/share/bash-completion/)
3. completion.old (legacy, to be migrated)

Only custom completions need separate files here.
