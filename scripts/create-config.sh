#!/bin/bash
source ~/scripts/env.sh

mkdir -p ~/configs
cat > ~/configs/cloudflared.yml <<EOF
tunnel: ${TUNNEL_NAME}
credentials-file: ${APP_DIR}/.cloudflared/${TUNNEL_ID}.json

ingress:
  - hostname: ${DEPLOY_DOMAIN}
    service: http://localhost:4000
  - hostname: hooks.${DEPLOY_DOMAIN}
    service: http://localhost:9000
  - service: http_status:404
EOF

echo "✅ cloudflared config generated at ~/configs/cloudflared.yml"
