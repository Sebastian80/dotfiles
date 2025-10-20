#!/bin/bash
# Docker Engine Installation Script for Ubuntu/Debian
# Installs Docker Engine with docker-compose plugin via official Docker repository

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Check if running on Ubuntu/Debian
if ! grep -qiE "ubuntu|debian" /etc/os-release; then
    error "This script is designed for Ubuntu/Debian systems only."
    exit 1
fi

# Check if Docker is already installed
if command -v docker &> /dev/null; then
    warn "Docker is already installed: $(docker --version)"
    read -p "Do you want to reinstall/update Docker? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Exiting. Docker installation skipped."
        exit 0
    fi
fi

echo ""
step "Starting Docker Engine installation..."
echo ""

# Step 1: Remove old Docker packages
step "Removing old Docker packages (if any)..."
sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
info "✓ Old packages removed"

# Step 2: Install prerequisites
step "Installing prerequisites..."
sudo apt-get update
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
info "✓ Prerequisites installed"

# Step 3: Add Docker's official GPG key
step "Adding Docker's GPG key..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
info "✓ GPG key added"

# Step 4: Set up Docker repository
step "Setting up Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
info "✓ Repository added"

# Step 5: Install Docker Engine
step "Installing Docker Engine, containerd, and Docker Compose..."
sudo apt-get update
sudo apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin
info "✓ Docker Engine installed"

# Step 6: Verify Docker installation
step "Verifying Docker installation..."
if sudo docker run hello-world &> /dev/null; then
    info "✓ Docker is working correctly"
else
    error "✗ Docker installation verification failed"
    exit 1
fi

# Step 7: Add current user to docker group
step "Adding user '$USER' to docker group..."
if ! groups | grep -q docker; then
    sudo usermod -aG docker "$USER"
    info "✓ User added to docker group"
    warn "You need to LOG OUT and LOG BACK IN for group changes to take effect!"
else
    info "✓ User already in docker group"
fi

# Step 8: Enable Docker service
step "Enabling Docker service to start on boot..."
sudo systemctl enable docker.service
sudo systemctl enable containerd.service
info "✓ Docker service enabled"

echo ""
step "Installation complete!"
echo ""
info "Docker versions installed:"
docker --version
docker compose version
echo ""
echo "Next steps:"
echo "  1. LOG OUT and LOG BACK IN (required for docker group to take effect)"
echo "  2. Test Docker without sudo: docker run hello-world"
echo "  3. Install lazydocker for terminal UI: brew install lazydocker"
echo ""
warn "IMPORTANT: You must log out and log back in before using Docker without sudo!"
echo ""
