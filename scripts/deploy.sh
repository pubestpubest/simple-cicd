#!/bin/bash
set -e

# Dynamically find and source env.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

echo "📥 Pulling latest code..."
cd $APP_DIR
git fetch origin main
git reset --hard origin/main

echo "📦 Installing dependencies via pnpm..."
pnpm install --frozen-lockfile

echo "🚀 Restarting systemd service..."
sudo -n systemctl restart web

echo "⏳ Waiting for service to stabilize..."
sleep 3

sudo -n systemctl is-active --quiet web \
  && echo "✅ Service is running." \
  || { echo "❌ Service failed to start."; exit 1; }

echo "✅ Deployment successful!"
curl -H "Content-Type: application/json" \
     -X POST \
     -d '{"content":"✅ Deployment complete on VM!"}' \
     $DISCORD_WEBHOOK


