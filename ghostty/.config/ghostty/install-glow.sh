#!/bin/bash
# Install glow - markdown viewer
# Not available in Ubuntu apt repos, so we download from GitHub

echo "Installing glow..."

GLOW_VERSION=$(curl -s "https://api.github.com/repos/charmbracelet/glow/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')

if [ -z "$GLOW_VERSION" ]; then
    echo "Failed to get glow version. Installing from snap instead..."
    sudo snap install glow
else
    echo "Downloading glow v${GLOW_VERSION}..."
    wget -q "https://github.com/charmbracelet/glow/releases/download/v${GLOW_VERSION}/glow_${GLOW_VERSION}_linux_amd64.tar.gz" -O /tmp/glow.tar.gz

    sudo tar -xzf /tmp/glow.tar.gz -C /usr/local/bin/ glow
    sudo chmod +x /usr/local/bin/glow
    rm /tmp/glow.tar.gz

    echo "✓ glow installed successfully!"
    glow --version
fi
