#!/bin/bash
# setup_devops.sh
set -e

echo "🔧 Updating system..."
sudo apt update && sudo apt upgrade -y

echo "📦 Installing required packages..."
sudo apt install -y git curl jq webhook unzip

# Install Docker Engine
if ! command -v docker >/dev/null 2>&1; then
  echo "🐳 Installing Docker Engine..."

  # Add Docker's official GPG key
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl gnupg
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  # Add Docker repository
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  # Install Docker packages
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # Add current user to docker group
  sudo usermod -aG docker $USER
  echo "✅ Docker installed. Please log out and back in for group changes to take effect."
fi

# Verify Docker Compose
if docker compose version >/dev/null 2>&1; then
  echo "✅ Docker Compose is available"
else
  echo "❌ Docker Compose plugin not available"
  exit 1
fi

# Install Cloudflared if missing
if ! command -v cloudflared >/dev/null 2>&1; then
  echo "☁️ Installing Cloudflared..."
  	# Add cloudflare gpg key
	sudo mkdir -p --mode=0755 /usr/share/keyrings
	curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null

	# Add this repo to your apt repositories
	# Stable
	echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' | sudo tee /etc/apt/sources.list.d/cloudflared.list
	# Nightly
	echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://next.pkg.cloudflare.com/cloudflared any main' | sudo tee /etc/apt/sources.list.d/cloudflared.list

	# install cloudflared
	sudo apt-get update && sudo apt-get install cloudflared
fi

echo "✅ Base setup complete."
