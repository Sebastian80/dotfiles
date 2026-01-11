# Sebastian's Dotfiles

Modern, modular dotfiles managed with GNU Stow. XDG Base Directory compliant.

## Features

- **Modular Bash Configuration**: Organized into focused modules (5 top-level files, 7 exports, 10 functions, 3 integrations, 1 completions)
- **XDG Compliant**: Modern tools configured in `~/.config/`
- **GNU Stow**: Simple, transparent symlink management
- **Modern Tooling**: 25 Homebrew packages including modern CLI tools and Bitwarden (see Tools section)
- **Catppuccin Frappé Theme**: Consistent theming across Ghostty, eza, and Yazi

## Structure

```
dotfiles/
├── bash/           # Bash shell configuration
│   ├── .bashrc
│   ├── .bash_profile
│   ├── .profile
│   └── .bash/      # Modular configs
├── bin/            # User utilities (stowed to ~/bin)
│   └── bin/
│       ├── dotfiles-update
│       ├── dotfiles-backup
│       ├── docker-clean
│       └── switch-theme
├── git/            # Git configuration
├── gtk/            # GTK theme configuration
├── ghostty/        # Ghostty terminal
├── oh-my-posh/     # Prompt engine
├── eza/            # Modern ls with Catppuccin Frappé theme
├── fzf/            # Fuzzy finder configuration
├── glow/           # Markdown viewer configuration
├── lazygit/        # Git TUI configuration
├── lazydocker/     # Docker TUI configuration
├── yazi/           # File manager
├── micro/          # Text editor
├── htop/           # System monitor
├── btop/           # Modern system monitor
├── tmux/           # Terminal multiplexer
├── system/         # System-level configurations (requires sudo)
│   ├── .config/
│   │   └── sudoers.d/
│   │       └── homebrew-path
│   └── README.md
├── scripts/        # Installation & maintenance scripts
│   ├── setup/      # bootstrap.sh, install-*.sh
│   ├── maintenance/# verify-installation.sh
│   └── utils/      # Helper scripts
├── Brewfile        # Homebrew package manifest
└── README.md       # This file
```

## Prerequisites

- **Operating System**: Ubuntu/Debian Linux
- **GNU Stow**: `sudo apt install stow`
- **Git**: `sudo apt install git`
- **Homebrew**: See [Installation](#installation) section for setup

## Installation

### Automated Installation (Recommended)

```bash
# Clone repository
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles

# Run bootstrap script (installs stow, Homebrew, and deploys dotfiles)
cd ~/dotfiles
./scripts/setup/bootstrap.sh

# The script will:
# - Check and install GNU Stow if needed
# - Optionally install Homebrew
# - Check for conflicts and offer backup/adopt options
# - Install all dotfiles packages (including ~/bin utilities)
# - Verify symlinks

# Install system configurations (requires sudo)
make install-system
```

### Manual Installation

```bash
# Clone repository
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles

# Install prerequisites
sudo apt update && sudo apt install -y git stow

# Install Homebrew (for modern CLI tools)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Backup existing configs (important!)
mkdir -p ~/dotfiles-backup-$(date +%Y%m%d)
cp ~/.bashrc ~/dotfiles-backup-$(date +%Y%m%d)/ 2>/dev/null || true
cp ~/.bash_profile ~/dotfiles-backup-$(date +%Y%m%d)/ 2>/dev/null || true
cp -r ~/.config/ghostty ~/dotfiles-backup-$(date +%Y%m%d)/ 2>/dev/null || true

# Deploy all packages (includes bin/ for user utilities)
cd ~/dotfiles
stow bash bin git gtk ghostty oh-my-posh tmux yazi micro htop btop eza fzf glow lazygit lazydocker

# Install Homebrew packages
brew bundle install --file=~/dotfiles/Brewfile

# Reload shell
source ~/.bashrc

# Now you have access to user utilities:
# - dotfiles-update, dotfiles-backup, docker-clean, switch-theme
```

### Selective Installation

Install only specific packages:

```bash
cd ~/dotfiles

# Install just bash configs
stow bash

# Install just git config
stow git

# Install terminal configs
stow ghostty oh-my-posh

# Install file managers and editors
stow yazi micro

# Install system monitors
stow htop btop

# Install GTK theming
stow gtk
```

## Management

### Adding New Configs

```bash
cd ~/dotfiles

# Add a new tool (example: nvim)
mkdir -p nvim/.config/nvim
cp -r ~/.config/nvim/* nvim/.config/nvim/

# Stow it
stow nvim

# Commit
git add nvim/
git commit -m "feat(nvim): add neovim configuration"
git push
```

### Updating Existing Configs

Configs are **symlinked**, so you can edit them in place:

```bash
# Edit directly (changes appear in ~/dotfiles automatically)
vim ~/.bashrc

# Or edit in the repo
vim ~/dotfiles/bash/.bashrc

# Commit changes
cd ~/dotfiles
git add bash/.bashrc
git commit -m "feat(bash): update prompt configuration"
git push
```

### Removing Configs

```bash
cd ~/dotfiles

# Unstow a package (removes symlinks)
stow -D bash

# Remove from repository
rm -rf bash/
git commit -m "remove bash config"
```

### Restowing (After Updates)

```bash
cd ~/dotfiles

# Pull latest changes
git pull

# Restow all packages
stow --restow */

# Or restow specific package
stow --restow bash
```

## Modular Bash Configuration

The bash configuration is organized into focused modules loaded by `.bashrc`:

### Top-Level Files (5)
| File | Purpose |
|------|---------|
| `path.bash` | PATH modifications and binary locations |
| `aliases.bash` | Command aliases |
| `prompt.bash` | oh-my-posh initialization and prompt setup |
| `keybindings.bash` | Custom keybindings (Ctrl+O for yazi) |
| `local.bash` | Machine-specific settings (git-ignored) |

### Modular Directories
| Directory | Files | Purpose |
|-----------|-------|---------|
| `exports/` | 7 modules | Environment variables split by concern (core, history, colors, tools, XDG, fzf, bitwarden) |
| `functions/` | 10 modules | Custom bash functions organized by category (bitwarden, dev, filesystem, fzf, git, misc, search, system, tools-help, yazi) |
| `integrations/` | 3 modules | Tool initializations (fzf keybindings, yazi, zoxide) |
| `completions/` | 4 modules | Custom completions (bitwarden, composer, dynamic lazy-loading, ripgrep) |

**Loading Order**: path → exports/* → prompt → aliases → functions/* → bash-completion → completions/* → integrations/* → keybindings → local

## Machine-Specific Configuration

Create a `local` file in any package for machine-specific overrides:

```bash
# bash/.bash/local (this file is git-ignored)
export WORK_ENV=true
export CUSTOM_PATH="/opt/work/bin"
```

Pattern: `*.local`, `*_local`, `local.*` files are automatically ignored by git.

## Security

**Never commit secrets!** The `.gitignore` is configured to exclude:

- SSH private keys
- API tokens and credentials
- `.env` files
- Password databases
- Cloud provider credentials
- Any file matching `*secret*`, `*token*`, `*credential*`

Use the `.local` suffix pattern for sensitive configs:

```bash
# Committed (safe)
.bashrc

# Git-ignored (secrets)
.bashrc.local
```

### Comprehensive Security Guide

See **[SECRET_MANAGEMENT.md](SECRET_MANAGEMENT.md)** for detailed guidelines on:
- Bitwarden integrated setup (Desktop + Browser + CLI + SSH Agent)
- Biometric unlock configuration (fingerprint authentication)
- SSH key management with Bitwarden SSH agent
- Development token automation (GITHUB_TOKEN, GITLAB_TOKEN, etc.)
- Session management in tmpfs (RAM-only, auto-cleared)
- API token storage and best practices
- Backup and recovery procedures

## Authentication & Secret Management

This dotfiles setup uses **Bitwarden** as a unified authentication solution for all development workflows:

### What It Provides
- **CLI tools:** GitHub CLI (`gh`), GitLab CLI (`glab`), Composer
- **SSH keys:** Managed via Bitwarden SSH Agent
- **Development tokens:** GITHUB_TOKEN, GITLAB_TOKEN, COMPOSER_AUTH
- **One unlock per session:** Biometric (fingerprint) unlock once, use everywhere

### Quick Start

1. **Install Bitwarden desktop app** (.deb, not Flatpak)
2. **Enable SSH Agent** in Bitwarden settings
3. **Unlock once:**
   ```bash
   bw unlock
   ```
4. **All tokens auto-load** and persist across all terminals

### Key Features

- 🔐 Biometric unlock (fingerprint) for all authentication
- 💾 Tokens stored in tmpfs (RAM-only, auto-cleared on logout)
- 🔄 One unlock per session, shared across all terminals
- 🔑 SSH keys never touch disk unencrypted
- 🌐 gh CLI configured with `git_protocol: ssh`
- 🏢 glab CLI configured for self-hosted GitLab (git.netresearch.de)
- 📦 Composer auth via COMPOSER_AUTH JSON (GitHub + GitLab self-hosted)

### Daily Workflow

```bash
# Morning: Unlock once (fingerprint or master password)
bw unlock

# All terminals now have access to:
# - GITHUB_TOKEN (for gh CLI and Composer)
# - GITLAB_TOKEN (for glab CLI and Composer)
# - COMPOSER_AUTH (for private packages)
# - SSH keys (for git operations)

# Work normally - no re-authentication needed
gh pr list
glab mr list
composer install
git push
```

### Architecture

| Operation | Method | Authentication |
|-----------|--------|----------------|
| Git clone/push | SSH | Bitwarden SSH Agent |
| gh CLI (API) | HTTPS | GITHUB_TOKEN |
| glab CLI (API) | HTTPS | GITLAB_TOKEN |
| Composer (GitHub) | HTTPS | COMPOSER_AUTH |
| Composer (GitLab) | HTTPS | COMPOSER_AUTH |

**For complete setup and troubleshooting:** See [SECRET_MANAGEMENT.md](SECRET_MANAGEMENT.md)

## Tools Included

All CLI tools are installed via **Homebrew** (see `Brewfile` for complete list of 25 packages).

**🔧 For script organization:** See **[SCRIPTS.md](SCRIPTS.md)** for complete guide to user utilities (`~/bin`) and installation/maintenance scripts (`scripts/`).

### Terminal
- **ghostty** - Modern GPU-accelerated terminal (via apt)
- **oh-my-posh** - Cross-platform prompt engine with custom themes
- **tmux** - Terminal multiplexer for session management

### Modern CLI Tools (Rust-based)
- **bat** - `cat` with syntax highlighting and Git integration
- **eza** - Modern `ls` replacement with icons and Git status
- **fd** - Fast and user-friendly `find` replacement
- **ripgrep** (rg) - Extremely fast `grep` alternative
- **fzf** - Fuzzy finder for files, history, and commands
- **yazi** - Terminal file manager with preview support
- **zoxide** - Smarter `cd` command that learns your habits

### Git Tools
- **git-delta** - Better `git diff` viewer with syntax highlighting
- **difftastic** - Structural diff tool that understands syntax
- **lazygit** - Terminal UI for git commands
- **gh** - GitHub CLI for working with issues, PRs, repos

### Editors
- **micro** - Modern, intuitive terminal text editor (mouse support!)

### System Monitoring
- **htop** - Interactive process viewer
- **btop** - Beautiful resource monitor with modern TUI

### Password Manager
- **bitwarden-cli** - Bitwarden CLI for password management and secrets

### Utilities
- **jq** - Command-line JSON processor
- **glow** - Render markdown in the terminal
- **lazydocker** - Terminal UI for Docker management
- **xclip** - X11 clipboard utility

### Development Tools
- **fnm** - Fast Node.js version manager
- **uv** - Fast Python package installer and resolver
- **bash-completion@2** - Programmable completion for Bash 4.2+
- **Docker Engine** - Container platform (via apt)

## Deployment to New Machine

```bash
# 1. Install prerequisites
sudo apt update
sudo apt install -y git stow

# 2. Clone dotfiles
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles

# 3. Run automated setup (recommended)
cd ~/dotfiles
./bootstrap.sh

# OR Manual deployment:

# 3. Review what will be linked (dry run)
cd ~/dotfiles
stow -n -v bash bin git gtk ghostty oh-my-posh yazi micro htop btop eza fzf glow lazygit lazydocker

# 4. Deploy packages
stow bash bin git gtk ghostty oh-my-posh tmux yazi micro htop btop eza fzf glow lazygit lazydocker

# 5. Install Homebrew and tools
brew bundle install --file=~/dotfiles/Brewfile

# 6. Reload shell
exec bash
```

## Troubleshooting

### Stow Conflicts

If stow reports conflicts:

```bash
# See what conflicts
stow -n -v bash

# Option 1: Move conflicting files
mv ~/.bashrc ~/.bashrc.old

# Option 2: Adopt existing files into repo
stow --adopt bash
git diff  # Review changes
git restore .  # If you want to keep repo version
```

### Broken Symlinks

```bash
# Find broken symlinks
find ~ -maxdepth 1 -xtype l

# Remove broken symlinks
find ~ -maxdepth 1 -xtype l -delete
```

### Unstow Everything

```bash
cd ~/dotfiles
stow -D */
```

## XDG Base Directory

This setup follows the XDG Base Directory Specification:

- **Config**: `~/.config/` - User configuration files
- **Data**: `~/.local/share/` - User data files
- **Cache**: `~/.cache/` - Non-essential cache data
- **State**: `~/.local/state/` - State data (logs, history)

## Resources

- [GNU Stow Manual](https://www.gnu.org/software/stow/manual/stow.html)
- [XDG Base Directory](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)
- [Catppuccin Theme](https://github.com/catppuccin/catppuccin)

## License

MIT License - Feel free to use and modify

## Author

Sebastian - 2025

---

**Note**: Remember to replace `yourusername` with your actual GitHub username in the clone URLs above.
