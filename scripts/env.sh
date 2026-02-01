#!/bin/bash

# Auto-detect script directory and project root
export SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT="$(dirname "$SCRIPTS_DIR")"

# Application deployment directory - contains docker-compose.yml (NOT source code)
export APP_DIR="${HOME}/app-deploy"

export DISCORD_WEBHOOK="https://discord.com/api/webhooks/foo/bar"
export WEBHOOK_SECRET="supersecret"
export DEPLOY_DOMAIN="example.com"
export TUNNEL_NAME="TUNNEL_NAME"
export TUNNEL_ID="TUNNEL_LONG_STRING"

# Docker configuration
export DOCKER_IMAGE="your-dockerhub-username/your-app-name"
export DOCKER_CONTAINER_NAME="web-app"
export COMPOSE_PROJECT_NAME="simple-cicd"
