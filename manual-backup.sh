#!/bin/bash
# Manual backup script to move existing configs before stowing

set -e

BACKUP_DIR="$HOME/dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

echo "Creating backup directory: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Backup bash configs
echo "Backing up bash configs..."
mv ~/.bash "$BACKUP_DIR/" 2>/dev/null || true
mv ~/.bashrc "$BACKUP_DIR/" 2>/dev/null || true
mv ~/.bash_profile "$BACKUP_DIR/" 2>/dev/null || true
mv ~/.profile "$BACKUP_DIR/" 2>/dev/null || true

# Backup git configs
echo "Backing up git configs..."
mv ~/.gitconfig "$BACKUP_DIR/" 2>/dev/null || true
mkdir -p "$BACKUP_DIR/.config"
mv ~/.config/git "$BACKUP_DIR/.config/" 2>/dev/null || true

# Backup ghostty
echo "Backing up ghostty..."
mv ~/.config/ghostty "$BACKUP_DIR/.config/" 2>/dev/null || true

# Backup oh-my-posh
echo "Backing up oh-my-posh..."
mv ~/.config/oh-my-posh "$BACKUP_DIR/.config/" 2>/dev/null || true

# Backup yazi
echo "Backing up yazi..."
mv ~/.config/yazi "$BACKUP_DIR/.config/" 2>/dev/null || true

# Backup micro
echo "Backing up micro..."
mv ~/.config/micro "$BACKUP_DIR/.config/" 2>/dev/null || true

# Backup htop
echo "Backing up htop..."
mv ~/.config/htop "$BACKUP_DIR/.config/" 2>/dev/null || true

echo ""
echo "✓ Backup complete: $BACKUP_DIR"
echo ""
echo "Now run: cd ~/dotfiles && make install"
