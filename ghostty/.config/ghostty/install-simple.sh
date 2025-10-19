#!/bin/bash

# Simple Installation Script - Most Common Tools
# ==============================================
# Install the essential terminal enhancement tools

echo "Installing essential terminal tools..."
echo ""

# Update first
sudo apt update

# Install tools available in Ubuntu repos
sudo apt install -y \
    bat \
    fzf \
    ranger \
    ripgrep \
    fd-find \
    tree \
    ncdu \
    htop \
    jq \
    chafa

echo ""
echo "✓ Basic tools installed!"
echo ""
echo "Note: bat is installed as 'batcat' on Ubuntu"
echo "Next: Run the full install script for eza, glow, and viu"
echo ""
