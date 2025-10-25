#!/usr/bin/env bash
# ~/.bash/exports/xdg.bash
# XDG Base Directory Specification
#
# Purpose:
#   Define standard locations for config files, data, cache, and state.
#   Helps keep your home directory organized by preventing dot-file clutter.
#
# Specification: https://specifications.freedesktop.org/basedir-spec/latest/
#
# Variables:
#   XDG_CONFIG_HOME - User-specific configuration files (~/.config)
#   XDG_DATA_HOME   - User-specific data files (~/.local/share)
#   XDG_CACHE_HOME  - User-specific cache files (~/.cache)
#   XDG_STATE_HOME  - User-specific state data (~/.local/state)

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
