#!/bin/bash
set -e

# Dynamically find and source env.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

echo "🐳 Pulling latest Docker image from DockerHub..."
cd $APP_DIR
docker compose pull

echo "🚀 Restarting containers via systemd..."
sudo -n systemctl restart web

echo "⏳ Waiting for container to stabilize..."
sleep 5

# Health check: verify container is running
if docker compose ps | grep -q "Up"; then
  echo "✅ Container is running."
else
  echo "❌ Container failed to start."
  echo "📋 Recent logs:"
  docker compose logs --tail=50
  exit 1
fi

echo "✅ Deployment successful!"
curl -H "Content-Type: application/json" \
     -X POST \
     -d '{"content":"✅ Deployment complete on VM! Image pulled from DockerHub."}' \
     $DISCORD_WEBHOOK


