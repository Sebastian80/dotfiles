# Brewfile - Homebrew Package Manifest
# Install all packages: brew bundle install
# Update: brew upgrade

# Modern CLI Tools (Rust-based replacements)
brew "bat"          # cat with syntax highlighting
brew "eza"          # Modern ls replacement
brew "fd"           # Modern find replacement
brew "ripgrep"      # Modern grep replacement (rg)
brew "ast-grep"     # AST-based structural code search (sg)
brew "fzf"          # Fuzzy finder
brew "yazi"         # Terminal file manager
brew "zoxide"       # Smarter cd command

# Git Tools
brew "git-delta"    # Better git diff viewer
brew "difftastic"   # Structural diff tool (alternative to delta)
brew "lazygit"      # Terminal UI for git commands
brew "gh"           # GitHub CLI
brew "glab"         # GitLab CLI
brew "git-filter-repo"  # Rewrite git history (secret/customer-path leaks)

# Password Manager
brew "bitwarden-cli"  # Bitwarden CLI for password management

# Terminal Multiplexer
brew "tmux"         # Terminal multiplexer for session management
brew "herdr"        # Agent multiplexer: persistent panes with Claude/Codex state awareness

# Utilities
brew "jq"           # JSON processor
brew "yq"           # YAML/TOML/XML/CSV processor; the data-tools skill mandates it for structured formats
# gawk claims the `awk` name in Homebrew's bin, so `awk` becomes GNU awk rather than
# Ubuntu's mawk for any shell with brew early on PATH. Installed because mawk 1.3.4
# crashes compiling an interval combined with an alternation (`^ {0,3}(a|b)`, both
# POSIX ERE), which aborts skill-repo-skill's validate-skill.sh with exit 100 on a
# stock Ubuntu box. Every awk call in this repo is plain POSIX, so the swap is safe here.
brew "gawk"         # GNU awk; also becomes `awk` (see note above)
brew "glow"         # Markdown viewer
brew "rich-cli"     # Rich terminal output (JSON, CSV, markdown, syntax)
brew "btop"         # Resource monitor with beautiful TUI
brew "htop"         # Interactive process viewer
brew "micro"        # Modern terminal text editor
brew "lazydocker"   # Terminal UI for docker commands
brew "xclip"        # X11 clipboard utility (required for clipboard ops in terminals)
brew "moor"         # Nice pager for humans (better less)
brew "yt-dlp"       # YouTube downloader; pi-web-access calls it from PATH for video frames, shadows the stale /usr/bin copy
brew "Valkyrie00/homebrew-bbrew/bbrew"  # Terminal UI for managing Homebrew packages

# MCP Tools
brew "f/mcptools/mcp"     # CLI for inspecting and debugging MCP servers

# Development Tools
brew "oven-sh/bun/bun"    # JavaScript runtime, bundler, and package manager
brew "fnm"                # Fast Node.js version manager
brew "uv"                 # Fast Python package manager
brew "composer"           # PHP dependency manager
brew "php@8.4"            # Local PHP for composer and CLI scripts outside Docker
brew "shellcheck"         # Shell script linter
brew "mailpit"            # SMTP sink with web UI for local mail testing
brew "d2"                 # Text-to-diagram language
brew "cloudflared"        # Cloudflare Tunnel client
brew "go"                 # Builds herdr plugins written in Go (herdr-auto-title)
brew "rust"               # Builds herdr plugins written in Rust (herdr-spreader)

# Browser in the terminal (Electron, kitty graphics). Ubuntu 24.04 needs the AppArmor userns
# profile the cask ships; re-run after upgrades, the profile is keyed on the binary path:
#   sudo bash "$(brew --prefix)/Caskroom/terminal-browser/<ver>/terminal-browser/scripts/apparmor.sh"
cask "terminal-browser"

# Prompt & Shell
brew "oh-my-posh"   # Prompt theme engine
brew "bash-completion@2"  # Programmable completion for Bash 4.2+
