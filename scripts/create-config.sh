#!/bin/bash

# Dynamically find and source env.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

echo "🔧 Setting up cloudflared configuration..."

# Check if credentials exist
if [ ! -f "${HOME}/.cloudflared/cert.pem" ]; then
  echo "❌ Error: cert.pem not found at ${HOME}/.cloudflared/"
  echo "Please run 'cloudflared tunnel login' first."
  exit 1
fi

if [ ! -f "${HOME}/.cloudflared/${TUNNEL_ID}.json" ]; then
  echo "❌ Error: Tunnel credentials not found at ${HOME}/.cloudflared/${TUNNEL_ID}.json"
  echo "Please verify your TUNNEL_ID in env.sh matches your tunnel credentials file."
  exit 1
fi

# Copy cloudflared credentials to /etc/cloudflared/
sudo mkdir -p /etc/cloudflared
sudo cp "${HOME}/.cloudflared/cert.pem" /etc/cloudflared/
sudo cp "${HOME}/.cloudflared/${TUNNEL_ID}.json" /etc/cloudflared/

# Set proper permissions for cloudflared credentials
sudo chmod 600 /etc/cloudflared/cert.pem
sudo chmod 600 /etc/cloudflared/${TUNNEL_ID}.json

# Create config in the standard cloudflared location
sudo tee /etc/cloudflared/config.yml > /dev/null <<EOF
tunnel: ${TUNNEL_NAME}
credentials-file: /etc/cloudflared/${TUNNEL_ID}.json
origincert: /etc/cloudflared/cert.pem

ingress:
  - hostname: ${DEPLOY_DOMAIN}
    service: http://localhost:4000
  - hostname: hooks.${DEPLOY_DOMAIN}
    service: http://localhost:9000
  - service: http_status:404
EOF

# Set permissions for config file
sudo chmod 644 /etc/cloudflared/config.yml

echo "✅ Cloudflared config and credentials copied to /etc/cloudflared/"
echo "📋 Config file: /etc/cloudflared/config.yml"
