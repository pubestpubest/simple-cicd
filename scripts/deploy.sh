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

echo "🧹 Stopping old screen session..."
screen -S web -X quit || true

echo "🚀 Starting new screen session..."
screen -dmS web bash -c "cd $APP_DIR && pnpm run start >> $APP_DIR/log.txt 2>&1"

echo "✅ Deployment successful!"
curl -H "Content-Type: application/json" \
     -X POST \
     -d '{"content":"✅ Deployment complete on VM!"}' \
     $DISCORD_WEBHOOK
