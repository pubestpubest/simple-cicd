#!/bin/bash

# Auto-detect script directory and project root
export SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_ROOT="$(dirname "$SCRIPTS_DIR")"

# Application directory - change this to your actual app directory path
export APP_DIR="${HOME}/APP_DIR"

export DISCORD_WEBHOOK="https://discord.com/api/webhooks/foo/bar"
export WEBHOOK_SECRET="supersecret"
export DEPLOY_DOMAIN="example.com"
export TUNNEL_NAME="TUNNEL_NAME"
export TUNNEL_ID="TUNNEL_LONG_STRING"
