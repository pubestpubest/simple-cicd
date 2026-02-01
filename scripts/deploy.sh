#!/bin/bash
set -e  # Exit on any error

# Dynamically find and source env.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

# ----------------------------------------
# Discord notification helper
# ----------------------------------------
notify() {
  local msg="$1"
  if [ -n "$DISCORD_WEBHOOK" ]; then
    curl -s -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\": \"$msg\"}" \
         "$DISCORD_WEBHOOK" > /dev/null || true
  fi
}

# ----------------------------------------
# Error handler
# ----------------------------------------
handle_error() {
  local exit_code=$?
  echo "❌ Deployment failed at $(date)"
  notify "❌ **Deployment failed** at $(date '+%Y-%m-%d %H:%M:%S')\nError code: $exit_code"
  exit $exit_code
}

trap handle_error ERR

# ----------------------------------------
# Deployment start
# ----------------------------------------
echo "🔧 Deployment started at $(date)"
notify "🚀 **Deployment started** at $(date '+%Y-%m-%d %H:%M:%S')"

# ----------------------------------------
# Pre-flight checks
# ----------------------------------------
echo "🔍 Checking Docker daemon status..."
if ! docker info > /dev/null 2>&1; then
  echo "❌ Docker daemon is not running"
  notify "❌ **Docker daemon is not running**"
  exit 1
fi

echo "📂 Changing to app directory: $APP_DIR"
cd "$APP_DIR"

# ----------------------------------------
# Pull latest images
# ----------------------------------------
echo "📥 Pulling latest Docker image from DockerHub..."
notify "📥 Pulling latest Docker images..."

if ! docker compose pull; then
  notify "❌ **Failed to pull Docker images**"
  exit 1
fi

notify "✅ Docker images pulled successfully"

# ----------------------------------------
# Restart containers via systemd
# ----------------------------------------
echo "🚀 Restarting containers via systemd..."
notify "🔄 Restarting containers..."

if ! sudo -n systemctl restart web; then
  notify "❌ **Failed to restart web service**"
  exit 1
fi

notify "✅ Web service restarted"

# ----------------------------------------
# Health check
# ----------------------------------------
echo "⏳ Waiting for containers to stabilize..."
sleep 5

echo "🔍 Checking container status..."
docker compose ps

if docker compose ps | grep -q "Up"; then
  echo "✅ Container is running"
  notify "✅ All containers are running"
else
  echo "❌ Container failed to start"
  echo "📋 Recent logs:"
  docker compose logs --tail=50
  notify "⚠️ **Some containers may have failed to start**"
  exit 1
fi

# ----------------------------------------
# Cleanup unused images
# ----------------------------------------
echo "🧹 Cleaning unused Docker images..."
notify "🧹 Cleaning unused Docker images..."

docker image prune -f || echo "⚠️ Image cleanup failed (non-fatal)"

# ----------------------------------------
# Deployment complete
# ----------------------------------------
echo "✅ Deployment completed successfully at $(date)"
notify "🎉 **Deployment completed successfully** at $(date '+%Y-%m-%d %H:%M:%S')"


