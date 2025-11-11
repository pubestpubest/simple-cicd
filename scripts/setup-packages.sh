#!/bin/bash
# setup_devops.sh
set -e

echo "🔧 Updating system..."
sudo apt update && sudo apt upgrade -y

echo "📦 Installing required packages..."
sudo apt install -y git curl screen jq webhook unzip

# Install Node.js (LTS) + pnpm
if ! command -v node >/dev/null 2>&1; then
  echo "🌱 Installing Node.js LTS..."
  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
  sudo apt install -y nodejs
fi

if ! command -v pnpm >/dev/null 2>&1; then
  echo "📦 Installing pnpm..."
  sudo npm install -g pnpm
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
