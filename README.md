# Sebastian's Dotfiles

Modern, modular dotfiles managed with GNU Stow. XDG Base Directory compliant.

## Features

- **Modular Bash Configuration**: Split into 8 focused files (path, exports, prompt, aliases, functions, tools, completion, local)
- **XDG Compliant**: Modern tools configured in `~/.config/`
- **GNU Stow**: Simple, transparent symlink management
- **Modern Tooling**: ghostty, oh-my-posh, yazi, micro, bat, eza, fzf, ripgrep
- **Catppuccin Theme**: Consistent theming across applications

## Structure

```
dotfiles/
├── bash/           # Bash shell configuration
│   ├── .bashrc
│   ├── .bash_profile
│   ├── .profile
│   └── .bash/      # Modular configs
├── git/            # Git configuration
├── ghostty/        # Ghostty terminal
├── oh-my-posh/     # Prompt engine
├── yazi/           # File manager
├── micro/          # Text editor
├── htop/           # System monitor
└── README.md       # This file
```

## Prerequisites

- **Operating System**: Ubuntu/Debian Linux
- **GNU Stow**: `sudo apt install stow`
- **Git**: `sudo apt install git`

## Installation

### Fresh Installation

```bash
# Clone repository
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles

# Install GNU Stow
sudo apt update && sudo apt install -y stow

# Backup existing configs (important!)
mkdir -p ~/dotfiles-backup-$(date +%Y%m%d)
cp ~/.bashrc ~/dotfiles-backup-$(date +%Y%m%d)/ 2>/dev/null || true
cp ~/.bash_profile ~/dotfiles-backup-$(date +%Y%m%d)/ 2>/dev/null || true
cp -r ~/.config/ghostty ~/dotfiles-backup-$(date +%Y%m%d)/ 2>/dev/null || true

# Deploy all packages
cd ~/dotfiles
stow */

# Reload shell
source ~/.bashrc
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

# Install all tools
stow yazi micro htop
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

## Tools Included

### Terminal
- **ghostty**: Modern GPU-accelerated terminal
- **oh-my-posh**: Cross-platform prompt engine
- **Catppuccin Frappe**: Color theme

### Shell Tools
- **bat**: cat with syntax highlighting
- **eza**: Modern ls replacement
- **fzf**: Fuzzy finder
- **ripgrep**: Fast text search
- **yazi**: Terminal file manager

### Editors
- **micro**: Modern terminal text editor
- **vim**: Classic editor (with configs)

### System
- **htop**: Interactive process viewer

## Deployment to New Machine

```bash
# 1. Install prerequisites
sudo apt update
sudo apt install -y git stow

# 2. Clone dotfiles
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles

# 3. Review what will be linked
cd ~/dotfiles
stow --no -v */  # Dry run

# 4. Deploy
stow */

# 5. Install tools (optional)
sudo apt install -y bat fd-find ripgrep fzf

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
