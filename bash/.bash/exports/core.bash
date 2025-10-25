#!/usr/bin/env bash
# ~/.bash/exports/core.bash
# Core environment variables - editor, pager, language
#
# Purpose:
#   Essential environment variables that define how you interact with the system.
#   These are used by countless programs and should be set first.
#
# Variables:
#   EDITOR  - Default text editor for command-line operations
#   VISUAL  - Visual editor (often same as EDITOR for consistency)
#   PAGER   - Program used to display long text output
#   LANG    - Primary language/locale setting
#   LC_ALL  - Override all locale settings

# Text editors
export EDITOR=micro              # CLI editor for git commits, crontab, etc.
export VISUAL=micro              # Visual editor (same for consistency)

# Pager for man pages and long output
export PAGER=less                # Use 'less' for scrolling through text

# Language and locale (German)
export LANG=de_DE.UTF-8          # Primary language: German, UTF-8 encoding
export LC_ALL=de_DE.UTF-8        # Force all locale categories to German
