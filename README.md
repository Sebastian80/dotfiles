# Sebastian's Dotfiles

Modern, modular dotfiles managed with GNU Stow. XDG Base Directory compliant.

## Features

- **Modular Bash Configuration**: Split into 8 focused files (path, exports, prompt, aliases, functions, tools, completion, local)
- **XDG Compliant**: Modern tools configured in `~/.config/`
- **GNU Stow**: Simple, transparent symlink management
- **Modern Tooling**: 21 modern CLI tools via Homebrew (see Tools section)
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
├── yazi/           # File manager
├── micro/          # Text editor
├── htop/           # System monitor
├── btop/           # Modern system monitor
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
stow bash bin git gtk ghostty oh-my-posh yazi micro htop btop

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

The bash configuration is split into focused files:

| File | Purpose |
|------|---------|
| `path` | PATH modifications and binary locations |
| `exports` | Environment variables (EDITOR, LOCALE, etc.) |
| `prompt` | oh-my-posh initialization and prompt setup |
| `aliases` | Command aliases |
| `functions` | Custom bash functions |
| `tools` | Terminal tool integration (bat, eza, fzf, ripgrep, yazi) |
| `completion` | Bash completion configuration |
| `local` | Machine-specific settings (git-ignored) |

These are sourced in order by `.bashrc`.

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
- SSH key management (Ed25519 best practices)
- Development secrets with `pass` (GPG-based password manager)
- API token storage (GitHub, GitLab, Jira, etc.)
- Separating company vs personal credentials
- Backup and recovery procedures

## Tools Included

All CLI tools are installed via **Homebrew** (see `Brewfile` for complete list).

**📦 For complete package inventory:** See **[PACKAGES.md](PACKAGES.md)** for detailed list of all 139+ packages organized by installation method (Homebrew, APT, Snap, Flatpak, shell scripts, etc.).

**🔧 For script organization:** See **[SCRIPTS.md](SCRIPTS.md)** for complete guide to user utilities (`~/bin`) and installation/maintenance scripts (`scripts/`).

### Terminal
- **ghostty** - Modern GPU-accelerated terminal (via apt)
- **oh-my-posh** - Cross-platform prompt engine with custom themes

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

### Utilities
- **jq** - Command-line JSON processor
- **glow** - Render markdown in the terminal
- **lazydocker** - Terminal UI for Docker management

### Development Tools
- **fnm** - Fast Node.js version manager
- **uv** - Fast Python package installer and resolver
- **Docker Engine** - Container platform (via apt)

### Optional Tools (Bash integration included)
The bash configuration includes integration code for these tools if you install them:
- **direnv** - Directory-specific environment variables
- **asdf** - Multi-language version manager
- **chafa** - Terminal image viewer

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
stow -n -v bash git gtk ghostty oh-my-posh yazi micro htop btop

# 4. Deploy packages
stow bash git gtk ghostty oh-my-posh yazi micro htop btop

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
