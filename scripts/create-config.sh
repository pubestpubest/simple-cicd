#!/bin/bash

# Dynamically find and source env.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

mkdir -p "${HOME}/configs"
cat > "${HOME}/configs/cloudflared.yml" <<EOF
tunnel: ${TUNNEL_NAME}
credentials-file: ${APP_DIR}/.cloudflared/${TUNNEL_ID}.json

ingress:
  - hostname: ${DEPLOY_DOMAIN}
    service: http://localhost:4000
  - hostname: hooks.${DEPLOY_DOMAIN}
    service: http://localhost:9000
  - service: http_status:404
EOF

echo "✅ cloudflared config generated at ${HOME}/configs/cloudflared.yml"
