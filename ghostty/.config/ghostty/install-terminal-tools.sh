#!/bin/bash

# Terminal Enhancement Tools Installation Script
# ===============================================
# This script installs modern CLI tools for an amazing terminal experience

set -e  # Exit on error

echo "================================"
echo "Terminal Tools Installation"
echo "================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Update package list
echo -e "${BLUE}Updating package list...${NC}"
sudo apt update

echo ""
echo -e "${BLUE}Installing tools from apt...${NC}"
echo ""

# Install available tools from apt
TOOLS=(
    "bat"           # Syntax-highlighted file viewer
    "fzf"           # Fuzzy finder
    "ranger"        # Terminal file manager
    "ripgrep"       # Fast grep alternative
    "fd-find"       # Fast find alternative
    "tldr"          # Simplified man pages
    "tree"          # Directory tree viewer
    "ncdu"          # Disk usage analyzer
    "htop"          # Process viewer
    "jq"            # JSON processor
)

for tool in "${TOOLS[@]}"; do
    echo -e "${YELLOW}Installing $tool...${NC}"
    sudo apt install -y "$tool" 2>&1 | tail -5
done

echo ""
echo -e "${BLUE}Installing eza (modern ls replacement)...${NC}"
# eza requires adding a repository or downloading binary
# Check if eza is available in apt first
if apt-cache show eza >/dev/null 2>&1; then
    sudo apt install -y eza
else
    echo "Installing eza from GitHub releases..."
    EZA_VERSION=$(curl -s "https://api.github.com/repos/eza-community/eza/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    wget -q "https://github.com/eza-community/eza/releases/download/v${EZA_VERSION}/eza_x86_64-unknown-linux-gnu.tar.gz" -O /tmp/eza.tar.gz
    sudo tar -xzf /tmp/eza.tar.gz -C /usr/local/bin/
    sudo chmod +x /usr/local/bin/eza
    rm /tmp/eza.tar.gz
    echo -e "${GREEN}✓ eza installed${NC}"
fi

echo ""
echo -e "${BLUE}Installing glow (markdown viewer)...${NC}"
if apt-cache show glow >/dev/null 2>&1; then
    sudo apt install -y glow
else
    echo "Installing glow from GitHub releases..."
    GLOW_VERSION=$(curl -s "https://api.github.com/repos/charmbracelet/glow/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    wget -q "https://github.com/charmbracelet/glow/releases/download/v${GLOW_VERSION}/glow_${GLOW_VERSION}_linux_amd64.tar.gz" -O /tmp/glow.tar.gz
    sudo tar -xzf /tmp/glow.tar.gz -C /usr/local/bin/ glow
    sudo chmod +x /usr/local/bin/glow
    rm /tmp/glow.tar.gz
    echo -e "${GREEN}✓ glow installed${NC}"
fi

echo ""
echo -e "${BLUE}Installing chafa (image viewer)...${NC}"
sudo apt install -y chafa 2>&1 | tail -5

echo ""
echo -e "${BLUE}Installing viu (image viewer)...${NC}"
if command -v cargo >/dev/null 2>&1; then
    cargo install viu
    echo -e "${GREEN}✓ viu installed via cargo${NC}"
else
    echo -e "${YELLOW}Cargo not found. Installing viu binary from GitHub...${NC}"
    VIU_VERSION=$(curl -s "https://api.github.com/repos/atanunq/viu/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    wget -q "https://github.com/atanunq/viu/releases/download/v${VIU_VERSION}/viu" -O /tmp/viu
    sudo mv /tmp/viu /usr/local/bin/viu
    sudo chmod +x /usr/local/bin/viu
    echo -e "${GREEN}✓ viu installed${NC}"
fi

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# Show installed versions
echo "Installed tools:"
echo "----------------"
command -v batcat >/dev/null 2>&1 && echo "✓ bat (as batcat): $(batcat --version | head -1)"
command -v eza >/dev/null 2>&1 && echo "✓ eza: $(eza --version | head -1)"
command -v fzf >/dev/null 2>&1 && echo "✓ fzf: $(fzf --version)"
command -v ranger >/dev/null 2>&1 && echo "✓ ranger: $(ranger --version | head -1)"
command -v glow >/dev/null 2>&1 && echo "✓ glow: $(glow --version)"
command -v rg >/dev/null 2>&1 && echo "✓ ripgrep: $(rg --version | head -1)"
command -v fd >/dev/null 2>&1 && echo "✓ fd: $(fd --version)"
command -v chafa >/dev/null 2>&1 && echo "✓ chafa: $(chafa --version | head -1)"
command -v viu >/dev/null 2>&1 && echo "✓ viu: installed"

echo ""
echo "Next steps:"
echo "1. Run: source ~/.bashrc (to load new aliases)"
echo "2. Check ~/.config/ghostty/TOOLS_GUIDE.md for usage examples"
echo ""
