#!/bin/bash

# Dynamically find and source env.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

# Ensure output directory exists
mkdir -p "${HOME}/configs"

# Generate webhook hook config
cat > "${HOME}/configs/hooks.yml" <<EOF
- id: deploy-myapp
  execute-command: ${SCRIPTS_DIR}/deploy.sh
  command-working-directory: ${HOME}
  response-message: "Deployment triggered!"
  trigger-rule:
    and:
      - match:
          type: payload-hash-sha256
          secret: ${WEBHOOK_SECRET}
          parameter:
            source: header
            name: X-Hub-Signature-256
      - match:
          type: value
          value: "refs/heads/main"
          parameter:
            source: payload
            name: ref
EOF

echo "✅ Webhook config generated at ${HOME}/configs/hooks.yml"
