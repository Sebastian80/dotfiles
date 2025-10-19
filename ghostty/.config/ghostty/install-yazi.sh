#!/bin/bash
# Install Yazi - Modern Terminal File Manager
# ============================================

set -e

echo "================================"
echo "Yazi Installation Script"
echo "================================"
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Step 1: Remove ranger
echo -e "${BLUE}Step 1: Removing ranger...${NC}"
sudo apt remove -y ranger
sudo apt autoremove -y
echo -e "${GREEN}✓ Ranger removed${NC}"
echo ""

# Step 2: Get latest yazi version
echo -e "${BLUE}Step 2: Downloading Yazi...${NC}"
YAZI_VERSION=$(curl -s "https://api.github.com/repos/sxyazi/yazi/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')

if [ -z "$YAZI_VERSION" ]; then
    echo -e "${YELLOW}Warning: Could not fetch latest version, using v0.4.2${NC}"
    YAZI_VERSION="0.4.2"
fi

echo "Latest version: v${YAZI_VERSION}"

# Step 3: Download and install
YAZI_URL="https://github.com/sxyazi/yazi/releases/download/v${YAZI_VERSION}/yazi-x86_64-unknown-linux-gnu.tar.gz"

echo "Downloading from: $YAZI_URL"
wget -q --show-progress "$YAZI_URL" -O /tmp/yazi.tar.gz

# Extract and install
sudo tar -xzf /tmp/yazi.tar.gz -C /tmp/
sudo mv /tmp/yazi-x86_64-unknown-linux-gnu/yazi /usr/local/bin/
sudo mv /tmp/yazi-x86_64-unknown-linux-gnu/ya /usr/local/bin/
sudo chmod +x /usr/local/bin/yazi /usr/local/bin/ya

# Cleanup
rm -rf /tmp/yazi.tar.gz /tmp/yazi-x86_64-unknown-linux-gnu/

echo -e "${GREEN}✓ Yazi installed successfully!${NC}"
echo ""

# Step 4: Verify installation
echo -e "${BLUE}Step 3: Verifying installation...${NC}"
yazi --version
echo ""

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "Next steps:"
echo "1. Configuration will be added to ~/.bash_terminal_tools"
echo "2. Use Ctrl+O to open yazi"
echo "3. Use 'y' command to open yazi with directory change on exit"
echo ""
