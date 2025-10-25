#!/usr/bin/env bash
# ~/.bash_profile
# Bash profile for login shells
# Executed for login shells (SSH sessions, macOS Terminal.app, Ghostty, etc.)

# ============================================
# Load .bashrc (Unified Configuration)
# ============================================

# Source .bashrc if it exists and is readable
# This ensures that both login and non-login shells have the same environment
# All configuration is now in .bashrc which uses a modular structure
if [ -r ~/.bashrc ]; then
    source ~/.bashrc
fi

# ============================================
# Login Shell Specific Settings
# ============================================

# Add any login-shell-specific settings here if needed
# Most settings should go in ~/.bashrc for consistency across shell types
