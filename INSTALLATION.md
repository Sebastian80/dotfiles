# Installation Guide

This guide walks you through completing the dotfiles setup with GNU Stow.

## Current Status

✅ **Completed**:
- Dotfiles repository created at `~/dotfiles`
- All configs copied and organized in stow-compatible structure
- Git repository initialized
- Comprehensive .gitignore for security
- README.md with full documentation
- scripts/setup/bootstrap.sh for automated installation
- Makefile for easy management
- GNU Stow installed (`stow 2.3.1`)
- Homebrew installed with all modern CLI tools
- All dotfiles deployed and symlinked
- Docker Engine installed
- System-level configurations (sudoers for Homebrew PATH)

This guide serves as reference documentation for the installation process and troubleshooting.

---

## Step 1: Install GNU Stow

```bash
sudo apt update && sudo apt install -y stow
```

Verify installation:
```bash
stow --version
```

Expected output: `stow (GNU Stow) version 2.3.1`

---

## Step 2: Test Deployment (Dry Run)

**IMPORTANT**: This step shows what stow will do WITHOUT making changes.

```bash
cd ~/dotfiles
make test
```

Or manually:
```bash
cd ~/dotfiles
stow -n -v bash bin git gtk ghostty oh-my-posh yazi micro htop btop eza fzf glow lazygit lazydocker
```

**What to look for**:
- `LINK: .bashrc => dotfiles/bash/.bashrc` ✓ Good
- `WARNING: existing target is ...` ⚠️ Conflict (see below)

### Handling Conflicts

If you see conflicts (existing files), you have two options:

**Option A: Backup existing files** (Recommended)
```bash
# Run the bootstrap script (handles backups automatically)
./scripts/setup/bootstrap.sh
```

**Option B: Manual backup**
```bash
mkdir -p ~/dotfiles-backup-$(date +%Y%m%d)
mv ~/.bashrc ~/dotfiles-backup-$(date +%Y%m%d)/
mv ~/.bash_profile ~/dotfiles-backup-$(date +%Y%m%d)/
mv ~/.gitconfig ~/dotfiles-backup-$(date +%Y%m%d)/
# ... backup other conflicting files
```

---

## Step 3: Deploy Dotfiles

### Using the Bootstrap Script (Easiest)

```bash
cd ~/dotfiles
./scripts/setup/bootstrap.sh
```

The script will:
- Check for GNU Stow
- Detect conflicts
- Offer to backup existing files
- Install all packages
- Verify installation
- Offer to reload shell

### Using Make (Recommended After Bootstrap)

```bash
cd ~/dotfiles
make install
```

### Manual Stow (Advanced)

Install all packages:
```bash
cd ~/dotfiles
stow bash git gtk ghostty oh-my-posh yazi micro htop btop
```

Or install selectively:
```bash
stow bash    # Just bash config
stow git     # Just git config
```

---

## Step 4: Verify Installation

Check that symlinks were created:

```bash
ls -la ~ | grep '\->'
```

You should see something like:
```
.bashrc -> dotfiles/bash/.bashrc
.bash_profile -> dotfiles/bash/.bash_profile
.gitconfig -> dotfiles/git/.gitconfig
```

Verify config directories:
```bash
ls -la ~/.config | grep '\->'
```

Expected:
```
ghostty -> ../dotfiles/ghostty/.config/ghostty
oh-my-posh -> ../dotfiles/oh-my-posh/.config/oh-my-posh
yazi -> ../dotfiles/yazi/.config/yazi
...
```

---

## Step 5: Install System Configurations

Some configurations require root access and cannot be symlinked with stow.

```bash
cd ~/dotfiles
make install-system
```

This installs:
- **Sudoers configuration**: Adds Homebrew paths to sudo's secure_path, allowing Homebrew tools (bat, eza, fd, rg, etc.) to work with sudo commands

**What happens:**
1. Copies `system/.config/sudoers.d/homebrew-path` to `/etc/sudoers.d/`
2. Sets correct permissions (0440)
3. Validates configuration with `visudo -c`

**Security note:** This is safe and standard practice for Homebrew-based systems. It only affects PATH, not authentication.

---

## Step 6: Reload Shell

```bash
source ~/.bashrc
```

Or restart your terminal.

---

## Step 7: Configure Authentication (Optional but Recommended)

This step sets up Bitwarden for unified authentication across GitHub, GitLab, and Composer.

### Install Bitwarden Desktop

**Important:** Use the `.deb` package (not Flatpak) for proper SSH agent integration.

```bash
# Download from https://bitwarden.com/download/
wget https://vault.bitwarden.com/download/?app=desktop&platform=linux&variant=deb -O Bitwarden.deb
sudo dpkg -i Bitwarden.deb
```

### Enable SSH Agent

1. Open Bitwarden desktop app
2. Go to **Settings → Options**
3. Enable "**Enable SSH Agent**" ✓
4. (Optional) Enable "**Unlock with biometrics**" ✓ (for fingerprint unlock)

### Unlock Bitwarden CLI

```bash
# Unlock vault (loads session + development tokens)
bw unlock

# You should see:
# ✅ Bitwarden unlocked successfully!
# 📦 Session stored in tmpfs (auto-cleared on logout)
# 🔑 GITHUB_TOKEN loaded
# 🔑 GITLAB_TOKEN loaded
# 📦 COMPOSER_AUTH loaded (GitHub + GitLab)
# ✅ Development secrets loaded and saved to tmpfs
```

### Verify Tokens Loaded

```bash
# Check environment variables
echo $GITHUB_TOKEN
echo $GITLAB_TOKEN
echo $COMPOSER_AUTH | jq

# Verify SSH agent
ls -la ~/.bitwarden-ssh-agent.sock
ssh-add -l
```

### Configure CLI Tools

#### GitHub CLI (gh)

The gh CLI is pre-configured to use SSH protocol:

```bash
# Verify configuration
gh config get git_protocol
# Should output: ssh

# Check authentication
gh auth status
# Should show: ✓ Logged in to github.com (GITHUB_TOKEN)
```

#### GitLab CLI (glab)

The glab CLI is pre-configured for self-hosted GitLab (git.netresearch.de):

```bash
# Check configuration
cat ~/.config/glab-cli/config.yml | grep host
# Should show: host: git.netresearch.de

# Check authentication
glab auth status
# Should show: ✓ Logged in to git.netresearch.de (GITLAB_TOKEN)
```

**Note:** Both `gh` and `glab` use environment variables (GITHUB_TOKEN, GITLAB_TOKEN) which are auto-loaded from Bitwarden when you run `bw unlock`.

### Test Authentication

```bash
# Test GitHub SSH
ssh -T git@github.com
# Expected: Hi <username>! You've successfully authenticated

# Test GitLab SSH
ssh -T git@git.netresearch.de
# Expected: Welcome to GitLab, @<username>!

# Test gh CLI
gh api user | jq -r .login

# Test glab CLI
glab api user | jq -r .username

# Test Composer
composer diagnose | grep github
# Expected: github.com oauth access: OK
```

### Daily Workflow

After initial setup, you only need to unlock once per session:

```bash
# Morning: Unlock once (fingerprint or master password)
bw unlock

# All terminals now have access to tokens
# Work normally with gh, glab, composer, git
```

**For complete authentication setup and troubleshooting:** See [SECRET_MANAGEMENT.md](SECRET_MANAGEMENT.md)

---

## Step 8: Push to GitHub

### Create GitHub Repository

**Option A: Using GitHub CLI (gh)**
```bash
cd ~/dotfiles

# Create private repo
gh repo create dotfiles --private --source=. --remote=origin

# Push
git push -u origin main
```

**Option B: Using GitHub Web Interface**

1. Go to https://github.com/new
2. Repository name: `dotfiles`
3. Description: "Personal dotfiles managed with GNU Stow"
4. **Private** (recommended for first version)
5. Do NOT initialize with README (we already have one)
6. Click "Create repository"

Then:
```bash
cd ~/dotfiles
git remote add origin https://github.com/YOUR_USERNAME/dotfiles.git
git push -u origin main
```

### Verify Push

```bash
git remote -v
git log --oneline
```

---

## Daily Usage

### Editing Configs

Since configs are **symlinked**, edit them anywhere:

```bash
# Edit in home directory
vim ~/.bashrc

# Or edit in repo
vim ~/dotfiles/bash/.bashrc

# Changes are the same file!
```

### Committing Changes

```bash
cd ~/dotfiles

# Check what changed
git status

# Commit
git add .
git commit -m "feat(bash): add new alias"
git push
```

Or use Make shortcuts:
```bash
cd ~/dotfiles
make commit   # Interactive commit
make push     # Push to GitHub
make sync     # Pull + push
```

### Adding New Configs

Example: Add neovim config

```bash
cd ~/dotfiles

# Create package directory
mkdir -p nvim/.config/nvim

# Copy existing config
cp -r ~/.config/nvim/* nvim/.config/nvim/

# Stow it
stow nvim

# Commit
git add nvim/
git commit -m "feat(nvim): add neovim configuration"
git push
```

### Deploying to New Machine

```bash
# Clone repo
git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/dotfiles

# Run bootstrap
cd ~/dotfiles
./scripts/setup/bootstrap.sh

# Or use make
make install
```

---

## Makefile Commands

```bash
make help       # Show all commands
make install    # Install all dotfiles
make uninstall  # Remove all symlinks
make update     # Git pull + restow
make test       # Dry run (shows what would happen)
make list       # List available packages
make status     # Git status
make commit     # Quick commit
make push       # Push to GitHub
make sync       # Pull + push
```

---

## Troubleshooting

### "Permission denied" when installing stow
```bash
sudo apt install stow
```

### Stow reports "existing target" conflicts
**Solution 1**: Use bootstrap script
```bash
./scripts/setup/bootstrap.sh  # Offers to backup automatically
```

**Solution 2**: Manually backup and retry
```bash
mv ~/.bashrc ~/.bashrc.backup
stow bash
```

**Solution 3**: Adopt existing files (merges into repo)
```bash
stow --adopt bash
git diff  # Review what changed
```

### Symlinks are broken after moving dotfiles repo
Stow uses absolute paths. If you move the repo, unstow and restow:
```bash
cd ~/dotfiles  # In new location
stow -D bash   # Unstow
stow bash      # Restow with new paths
```

### Want to remove everything and start over
```bash
cd ~/dotfiles
make uninstall  # Remove all symlinks
rm -rf ~/dotfiles  # Delete repo (careful!)
```

---

## Security Checklist

Before pushing to GitHub:

- [ ] Review `.gitignore` - secrets excluded?
- [ ] Check for passwords: `grep -r "password" .`
- [ ] Check for API keys: `grep -r "api_key" .`
- [ ] Check for tokens: `grep -r "token" .`
- [ ] No SSH private keys: `find . -name "id_rsa" -o -name "id_ed25519"`
- [ ] Machine-specific files in `.bash/local` (git-ignored)

---

## What's Git-Ignored (Safe from Commits)

The `.gitignore` automatically excludes:

- `*.local` - Machine-specific configs
- `.bash/local` - Your local bash settings
- `*_secret`, `*_private` - Sensitive files
- `.env`, `.env.*` - Environment files
- SSH private keys
- API tokens and credentials
- Backup files (`*.backup-*`)
- Cache and temporary files

You can freely create files matching these patterns - they won't be committed.

---

## Next Steps

After completing installation:

1. **Test the setup**:
   ```bash
   source ~/.bashrc
   # Check if oh-my-posh prompt loads
   # Check if tools work (yazi, micro, etc.)
   ```

2. **Customize for this machine**:
   ```bash
   # Add machine-specific settings (git-ignored)
   vim ~/.bash/local
   ```

3. **Review and clean up**:
   ```bash
   # Remove old backup if everything works
   rm -rf ~/dotfiles-backup-20251019_134818
   ```

4. **Set up GitHub repo** (see Step 6 above)

5. **Install modern CLI tools via Homebrew**:
   ```bash
   cd ~/dotfiles
   brew bundle install --file=~/dotfiles/Brewfile
   ```

6. **Consider future enhancements**:
   - Add pre-commit hooks for secret scanning
   - Set up GitHub Actions for testing
   - Add more tool configs (nvim, tmux, etc.)
   - Create machine-specific branches if needed

---

## Resources

- **GNU Stow Manual**: https://www.gnu.org/software/stow/manual/
- **Your README**: `~/dotfiles/README.md`
- **Makefile Help**: `make help`
- **Bootstrap Script**: `./scripts/setup/bootstrap.sh --help`

---

**You're almost done!** Just install stow, test, deploy, and push to GitHub. Your dotfiles will then be under version control and ready to deploy to any new machine with a single command.

Happy dotfile-ing! 🚀
