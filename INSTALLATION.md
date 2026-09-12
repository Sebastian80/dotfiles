# Installation Guide

This guide walks you through completing the dotfiles setup with GNU Stow.

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
stow -n -v bash bin claude git gtk ghostty oh-my-posh tmux yazi micro htop btop eza fzf glow ripgrep herdr pi agents chrome
```

**What to look for**:

- `LINK: .bashrc => dotfiles/bash/.bashrc` ✓ Good
- `WARNING: existing target is ...` ⚠️ Conflict (see below)

### Handling Conflicts

If you see conflicts (existing files), you have two options:

#### Option A: Backup existing files (recommended)

```bash
# Run the bootstrap script (handles backups automatically)
./scripts/setup/bootstrap.sh
```

#### Option B: Manual backup

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
stow bash bin claude git gtk ghostty oh-my-posh tmux yazi micro htop btop eza fzf glow ripgrep herdr pi agents chrome
```

Or install selectively:

```bash
stow bash    # Just bash config
stow git     # Just git config
```

### Claude Code settings (not tracked)

`claude/.claude/settings.json` is gitignored because Claude Code rewrites it
at runtime. On a fresh machine, seed it from the tracked reference before the
first `claude` start:

```bash
cp ~/dotfiles/claude/.claude/settings.reference.json ~/dotfiles/claude/.claude/settings.json
```

When you deliberately change settings (env vars, hooks, permissions,
marketplaces), mirror the change into `settings.reference.json` and commit it.

---

## Step 4: Verify Installation

Check that symlinks were created:

```bash
ls -la ~ | grep '\->'
```

You should see something like:

```text
.bashrc -> dotfiles/bash/.bashrc
.bash_profile -> dotfiles/bash/.bash_profile
.gitconfig -> dotfiles/git/.gitconfig
```

Verify config directories:

```bash
ls -la ~/.config | grep '\->'
```

Expected:

```text
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

- **Sudoers configuration**: Adds Homebrew paths to sudo's secure_path, so Homebrew tools
  (bat, eza, fd, rg, etc.) work with sudo commands

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
# Quote the URL: an unquoted & splits the command and backgrounds the first half.
wget "https://vault.bitwarden.com/download/?app=desktop&platform=linux&variant=deb" -O Bitwarden.deb
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

**Note:** Both `gh` and `glab` read environment variables (GITHUB_TOKEN, GITLAB_TOKEN) that are
auto-loaded from Bitwarden when you run `bw unlock`.

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

## Step 8: The GitHub Remote

This repo already lives at [Sebastian80/dotfiles](https://github.com/Sebastian80/dotfiles), so a
fresh clone has its remote set up and there is nothing to create. Confirm it:

```bash
cd ~/dotfiles
git remote -v
# origin  git@github.com:Sebastian80/dotfiles.git (fetch)
# origin  git@github.com:Sebastian80/dotfiles.git (push)
```

The repository is **public**. Nothing machine-specific or secret belongs in a tracked file: keep
those in `bash/.bash/local.bash` (git-ignored) and the vault. See
[SECRET_MANAGEMENT.md](SECRET_MANAGEMENT.md).

If you ever need to point a clone at a different remote:

```bash
cd ~/dotfiles
git remote set-url origin git@github.com:<owner>/dotfiles.git
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
git clone git@github.com:Sebastian80/dotfiles.git ~/dotfiles

# Run bootstrap
cd ~/dotfiles
./scripts/setup/bootstrap.sh

# Or use make
make install
```

---

## Makefile Commands

```bash
make help           # Show all commands
make install        # Install all dotfiles
make uninstall      # Remove all symlinks
make update         # Git pull + restow
make test           # Dry run (shows what would happen)
make list           # List available packages
make lint           # Lint and spellcheck scripts and docs
make install-system # System config, requires sudo (sudoers)
make install-ai     # Claude Code, Codex/Gemini CLIs, pi + sandbox, herdr integrations
make install-pi     # Just pi and its sandbox extension
make verify-auth    # Verify the authentication setup
make shortcuts      # Restore the desktop keyboard shortcuts from dconf
make dump-shortcuts # Capture the current desktop shortcuts into the repo
make dock           # Point Plank dock launchers at their ~/.local overrides
make status         # Git status
make commit         # Quick commit
make push           # Push to GitHub
make sync           # Pull + push
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
- [ ] Machine-specific files in `.bash/local.bash` (git-ignored)

---

## What's Git-Ignored (Safe from Commits)

The `.gitignore` automatically excludes:

- `*.local` - Machine-specific configs
- `.bash/local.bash` - Your local bash settings
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
   vim ~/.bash/local.bash
   ```

3. **Review and clean up**:

   ```bash
   # Remove the backup bootstrap made, once everything works
   ls -d ~/dotfiles-backup-*
   rm -rf ~/dotfiles-backup-<timestamp>
   ```

4. **Set up GitHub repo** (see Step 8 above)

5. **Install modern CLI tools via Homebrew**:

   ```bash
   cd ~/dotfiles
   brew bundle install --file=~/dotfiles/Brewfile
   ```

6. **Install Node.js and npm globals**:

   ```bash
   ./scripts/setup/install-node.sh
   ```

   Installs Node.js 22 and 24 (default 24) via fnm, plus the base globals (pnpm).
   Claude Code is not included: it uses its own installer and self-updates.

7. **Install AI agent tooling** (optional):

   ```bash
   make install-ai
   ```

   Claude Code (through Anthropic's own installer, skipped when already present), the Codex,
   Gemini and agent-browser CLIs plus repomix, pi with its sandbox extension, and herdr's agent
   integrations. Everything except Claude Code needs Node.js from step 6.

8. **Consider future enhancements**:
   - Add pre-commit hooks for secret scanning
   - Set up GitHub Actions for testing
   - Add more tool configs (nvim, etc.)
   - Create machine-specific branches if needed

---

## Resources

- **GNU Stow Manual**: <https://www.gnu.org/software/stow/manual/>
- **Your README**: `~/dotfiles/README.md`
- **Makefile Help**: `make help`
- **Bootstrap Script**: `./scripts/setup/bootstrap.sh --help`

---

**You're almost done!** Install stow, dry-run, deploy, reload the shell. The dotfiles are then
symlinked from this repo and ready to deploy to any new machine with a single command.

Happy dotfile-ing! 🚀
