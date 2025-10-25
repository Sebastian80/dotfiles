#!/usr/bin/env bash
# ~/.bash/functions/tools-help.bash
# Terminal tools help and discovery
#
# Purpose:
#   Provide quick reference documentation and installed tools detection
#   for all terminal enhancement tools in the dotfiles environment.
#
# Functions:
#   terminal-tools-help  - Display comprehensive quick reference guide
#   show-tools           - List all installed terminal tools with paths
#
# Usage:
#   terminal-tools-help  - Show all available commands and keybindings
#   show-tools           - Check which tools are installed on this system

# Display comprehensive quick reference for all terminal enhancement tools
terminal-tools-help() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Terminal Enhancement Tools - Quick Reference"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    echo "📁 File Viewing & Preview:"
    echo "  cat <file>         - View file with syntax highlighting (bat)"
    echo "  preview <file>     - Smart preview (auto-detects file type)"
    echo "  bat <file>         - Direct bat usage"
    echo ""

    echo "📂 File Listing:"
    echo "  ls                 - Modern ls with icons (eza)"
    echo "  ll                 - Long listing with git status"
    echo "  la                 - Show all files including hidden"
    echo "  lt                 - Tree view (2 levels)"
    echo "  lt3                - Tree view (3 levels)"
    echo ""

    echo "🗂️  File Management:"
    echo "  Ctrl+O             - Open yazi file manager (keybinding)"
    echo "  y, yy, or fm       - Open yazi (command)"
    echo "  fe [query]         - Find and edit file with fzf"
    echo "  fcd [dir]          - Change directory with fzf"
    echo "  z <dir>            - Jump to directory (zoxide)"
    echo "  zi                 - Interactive directory jump (zoxide)"
    echo ""

    echo "🔍 Search & Find:"
    echo "  rgg <pattern>      - Fast search with ripgrep"
    echo "  fd <name>          - Fast file find (fd)"
    echo "  ff <name>          - Universal file find (uses fd if available)"
    echo "  search <pattern>   - Universal search (uses rg if available)"
    echo "  fsearch [query]    - Search and preview files with fzf"
    echo "  Ctrl+R             - Search command history with fzf"
    echo "  Ctrl+T             - Find files with fzf"
    echo "  Alt+C              - Change directory with fzf"
    echo ""

    echo "🖼️  Image Viewing:"
    echo "  imgcat <file>      - View image in terminal (chafa)"
    echo "  imgview <file>     - View image in terminal (viu)"
    echo ""

    echo "🛠️  Utilities:"
    echo "  extract <file>     - Extract any archive format"
    echo "  archive <out> <in> - Create archive"
    echo "  mkd <dir>          - Create directory and cd into it"
    echo "  largest [dir]      - Show largest files"
    echo "  backup <file>      - Create timestamped backup"
    echo "  genpass [len]      - Generate random password"
    echo "  weather [loc]      - Show weather forecast"
    echo ""

    echo "💻 System Info:"
    echo "  diskusage          - Show disk usage"
    echo "  memusage           - Show memory usage"
    echo "  cpuusage           - Show CPU usage"
    echo "  localip            - Show local IP address"
    echo "  publicip           - Show public IP address"
    echo ""

    echo "📦 Development:"
    echo "  venv               - Create/activate Python virtual environment"
    echo "  serve [port]       - Start HTTP server (default: 8000)"
    echo "  clone <url>        - Clone repo and cd into it"
    echo ""

    echo "For more information on a specific tool, use: <tool> --help"
    echo "═══════════════════════════════════════════════════════════════"
}

# Detect and list all installed terminal enhancement tools
# Useful for debugging and ensuring all tools are properly installed
show-tools() {
    echo "Installed Terminal Enhancement Tools:"
    echo "======================================"
    echo ""
    echo "File Management & Navigation:"
    for tool in eza bat batcat fd fdfind fzf rg yazi zoxide; do
        if command -v $tool &>/dev/null; then
            echo "  ✓ $tool: $(command -v $tool)"
        else
            echo "  ✗ $tool: not installed"
        fi
    done
    echo ""
    echo "Development & Git:"
    for tool in gh lazygit delta difft jq; do
        if command -v $tool &>/dev/null; then
            echo "  ✓ $tool: $(command -v $tool)"
        else
            echo "  ✗ $tool: not installed"
        fi
    done
    echo ""
    echo "System Monitoring & Editors:"
    for tool in htop btop micro; do
        if command -v $tool &>/dev/null; then
            echo "  ✓ $tool: $(command -v $tool)"
        else
            echo "  ✗ $tool: not installed"
        fi
    done
    echo ""
    echo "Docker & Container Tools:"
    for tool in lazydocker docker; do
        if command -v $tool &>/dev/null; then
            echo "  ✓ $tool: $(command -v $tool)"
        else
            echo "  ✗ $tool: not installed"
        fi
    done
    echo ""
    echo "Documentation & Terminal UI:"
    for tool in glow oh-my-posh chafa viu; do
        if command -v $tool &>/dev/null; then
            echo "  ✓ $tool: $(command -v $tool)"
        else
            echo "  ✗ $tool: not installed"
        fi
    done
    echo ""
    echo "Package Managers & Utilities:"
    for tool in fnm uv nala xclip; do
        if command -v $tool &>/dev/null; then
            echo "  ✓ $tool: $(command -v $tool)"
        else
            echo "  ✗ $tool: not installed"
        fi
    done
}
