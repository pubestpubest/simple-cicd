#!/bin/bash
set -e

# Dynamically find and source env.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

echo "🔧 Creating systemd service files..."

# Create temporary directory for service files
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Generate web.service
cat > "$TEMP_DIR/web.service" <<EOF
[Unit]
Description=Web Application Service
After=network.target

[Service]
# Your app directory
WorkingDirectory=${APP_DIR}

# Start command
ExecStart=/usr/bin/pnpm start

# Restart on crash or exit
Restart=always
RestartSec=5

# Ensure it runs under your user
User=${USER}
Group=${USER}

# Logs handled by systemd (journalctl) and file
StandardOutput=append:${APP_DIR}/log.txt
StandardError=append:${APP_DIR}/log.txt

[Install]
WantedBy=multi-user.target
EOF

# Generate webhook.service
cat > "$TEMP_DIR/webhook.service" <<EOF
[Unit]
Description=Webhook Listener Service
After=network.target

[Service]
User=${USER}
Group=${USER}
WorkingDirectory=${HOME}
ExecStart=/usr/bin/webhook \\
    -hooks ${HOME}/configs/hooks.yml \\
    -port 9000 \\
    -verbose

Restart=always
RestartSec=3

# environment (if needed)
Environment=PATH=/usr/local/bin:/usr/bin:/bin

[Install]
WantedBy=multi-user.target
EOF

echo "📋 Generated service files:"
echo "  - web.service"
echo "  - webhook.service"

# Copy service files to systemd directory
echo "📦 Installing service files to /etc/systemd/system/..."
sudo cp "$TEMP_DIR/web.service" /etc/systemd/system/
sudo cp "$TEMP_DIR/webhook.service" /etc/systemd/system/

# Reload systemd daemon
echo "🔄 Reloading systemd daemon..."
sudo systemctl daemon-reload

# Enable services
echo "✅ Enabling services..."
sudo systemctl enable web.service
sudo systemctl enable webhook.service

echo ""
echo "✅ Service files created and enabled!"
echo ""
echo "To start the services, run:"
echo "  sudo systemctl start web"
echo "  sudo systemctl start webhook"
echo ""
echo "To check service status:"
echo "  sudo systemctl status web"
echo "  sudo systemctl status webhook"
echo ""
echo "To view logs:"
echo "  journalctl -u web -f"
echo "  journalctl -u webhook -f"

