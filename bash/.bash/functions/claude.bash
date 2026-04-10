#!/usr/bin/env bash
# ~/.bash/functions/claude.bash
# Claude Code terminal cleanup wrapper
#
# Purpose:
#   Work around Claude Code TUI cleanup bug (anthropics/claude-code#39294)
#   where status line content and autocomplete suggestions leak into the
#   terminal after /exit.
#
# Functions:
#   claude - Wrapper that resets terminal state after Claude Code exits

claude() {
    command claude "$@"
    local exit_code=$?
    tput reset 2>/dev/null
    return $exit_code
}
