#!/bin/bash
# Load environment variables
source ~/scripts/env.sh

# Ensure output directory exists
mkdir -p ~/configs

# Generate webhook hook config
cat > ~/configs/hooks.yml <<EOF
- id: deploy-myapp
  execute-command: ~/scripts/deploy.sh
  command-working-directory: ~
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

echo "✅ Webhook config generated at ~/configs/hooks.yml"
