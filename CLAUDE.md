# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a simple DevOps pipeline setup repository for deploying applications on Ubuntu VMs using:
- **Cloudflared tunnels** for secure HTTPS exposure without public IPs or Nginx
- **GitHub Actions** for automated CI/CD
- **Webhook listeners** for deployment triggers
- **Systemd services** for application lifecycle management
- **Discord webhooks** for deployment notifications

This is NOT an application repository - it's a deployment automation toolkit designed to be cloned alongside your actual application code.

## Architecture

### Components

1. **Cloudflared Tunnel**
   - Runs as a systemd service (`cloudflared.service`)
   - Config at `/etc/cloudflared/config.yml`
   - Routes traffic from Cloudflare domains to local ports (e.g., port 4000 for app, port 9000 for webhooks)
   - Credentials stored in `/etc/cloudflared/` (copied from `~/.cloudflared/`)

2. **Web Service** (`web.service`)
   - Systemd service that runs the user's application (in `$APP_DIR`)
   - Executes `docker compose up -d` to start containers
   - Pulls latest image from DockerHub via `--pull always` flag
   - Logs to both journalctl and Docker logs (`docker compose logs`)
   - Requires Docker daemon running (`After=docker.service`)

3. **Webhook Service** (`webhook.service`)
   - Systemd service listening on port 9000
   - Uses [adnanh/webhook](https://github.com/adnanh/webhook)
   - Verifies GitHub webhook signatures (HMAC SHA256)
   - Triggers `deploy.sh` on valid payloads from main branch

4. **GitHub Actions Workflow** (`push.yaml`)
   - Triggers on push to main (ignoring .md files)
   - Builds Docker image from application Dockerfile
   - Tags with `latest` and commit SHA
   - Pushes to DockerHub registry
   - Sends Discord notification
   - Triggers webhook on remote VM with signed payload

### Configuration Files

All configuration is driven by `scripts/env.sh`:

```bash
APP_DIR                 # Deployment directory containing docker-compose.yml (NOT source code)
DISCORD_WEBHOOK         # Discord webhook URL for notifications
WEBHOOK_SECRET          # Shared secret for GitHub webhook verification
DEPLOY_DOMAIN           # Main domain (e.g., example.com)
TUNNEL_NAME             # Cloudflared tunnel name
TUNNEL_ID               # Cloudflared tunnel ID (UUID)
DOCKER_IMAGE            # DockerHub image (e.g., username/app-name)
DOCKER_CONTAINER_NAME   # Container name (e.g., web-app)
COMPOSE_PROJECT_NAME    # Docker Compose project name
```

Scripts dynamically source `env.sh` to generate configs:
- `create-config.sh` → `/etc/cloudflared/config.yml`
- `create-hook-config.sh` → `~/configs/hooks.yml`
- `create-service-files.sh` → `/etc/systemd/system/{web,webhook}.service`

### Deployment Flow

1. Developer pushes to main branch
2. GitHub Actions workflow builds and pushes to DockerHub:
   - Builds Docker image from application Dockerfile
   - Tags with `latest` and commit SHA
   - Pushes to DockerHub registry
   - Sends Discord notification
   - Generates HMAC-signed payload
   - Sends POST to `https://hooks.$DEPLOY_DOMAIN`
3. Cloudflared routes traffic to webhook listener (port 9000)
4. Webhook verifies signature and triggers `deploy.sh`
5. `deploy.sh`:
   - Changes to `$APP_DIR` (which contains only `docker-compose.yml`, not source code)
   - Pulls latest Docker image from DockerHub (`docker compose pull`)
   - Restarts web service via `sudo -n systemctl restart web`
   - Systemd service runs `docker compose up -d --pull always`
   - Sends success notification to Discord

**Important**: Passwordless sudo must be configured for the web service:
```bash
echo "$USER ALL=(ALL) NOPASSWD: /bin/systemctl * web" | sudo tee /etc/sudoers.d/deploy
```

## Common Commands

### Initial Setup (on Ubuntu VM)

```bash
# 1. Make scripts executable
chmod +x scripts/*.sh

# 2. Install dependencies (git, curl, jq, webhook, Docker, cloudflared)
./scripts/setup-packages.sh
# Note: Log out and back in after installation for Docker group membership

# 3. Setup cloudflared tunnel
cloudflared tunnel login
cloudflared tunnel create TUNNEL_NAME
cloudflared tunnel list  # Get TUNNEL_ID

# 4. Configure environment
nano scripts/env.sh  # Set APP_DIR, domains, secrets, tunnel info
source scripts/env.sh

# 5. Generate all configs
./scripts/create-config.sh
./scripts/create-hook-config.sh
./scripts/create-service-files.sh

# 6. Setup DNS and start cloudflared
sudo cloudflared tunnel route dns $TUNNEL_NAME $DEPLOY_DOMAIN
sudo cloudflared tunnel route dns $TUNNEL_NAME hooks.$DEPLOY_DOMAIN
sudo cloudflared service install
sudo systemctl status cloudflared

# 7. Start services
sudo systemctl start web
sudo systemctl start webhook
```

### Service Management

```bash
# Check service status
sudo systemctl status web
sudo systemctl status webhook
sudo systemctl status cloudflared

# View logs
journalctl -u web -f
journalctl -u webhook -f

# Or view Docker container logs directly
cd $APP_DIR
docker compose logs -f            # Follow live logs
docker compose logs --tail=100    # Last 100 lines

# Restart services
sudo systemctl restart web
sudo systemctl restart webhook

# Enable/disable auto-start
sudo systemctl enable web
sudo systemctl disable web
```

### Manual Deployment

```bash
# Run deployment script directly
./scripts/deploy.sh
```

### Docker Management

```bash
# View running containers
cd $APP_DIR
docker compose ps

# View container logs
docker compose logs -f
docker compose logs --tail=100

# Pull latest image manually
docker compose pull

# Restart containers
docker compose restart

# Stop and remove containers
docker compose down

# Check container health
docker inspect --format='{{.State.Health.Status}}' web-app

# Access container shell
docker compose exec web sh

# View resource usage
docker stats web-app
```

### Docker Cleanup

```bash
# Remove stopped containers
docker container prune -f

# Remove unused images (frees disk space)
docker image prune -a -f

# Remove unused volumes
docker volume prune -f

# Full cleanup (use with caution!)
docker system prune -a --volumes -f
```

### Updating Configuration

```bash
# After editing env.sh, regenerate configs
source scripts/env.sh
./scripts/create-config.sh           # Regenerate cloudflared config
./scripts/create-hook-config.sh      # Regenerate webhook config
./scripts/create-service-files.sh    # Regenerate systemd services

# Reload systemd after service file changes
sudo systemctl daemon-reload
sudo systemctl restart web
```

## GitHub Actions Setup

1. Copy `push.yaml` to your application repository:
   ```bash
   mkdir -p .github/workflows
   cp push.yaml .github/workflows/push.yaml
   ```

2. Add repository secrets:
   - `DOCKERHUB_USERNAME` - Your DockerHub username
   - `DOCKERHUB_TOKEN` - DockerHub access token (from DockerHub → Account Settings → Security)
   - `DOCKERHUB_REPO` - Repository name (e.g., "my-app")
   - `DISCORD_WEBHOOK_URL` - Discord webhook for notifications
   - `WEBHOOK_URL` - Full URL (e.g., `https://hooks.example.com`)
   - `WEBHOOK_SECRET` - Must match `WEBHOOK_SECRET` in `scripts/env.sh`

## Key Assumptions

- Application has a Dockerfile that exposes port 4000
- Application implements a `/health` endpoint for health checks
- Docker image is pushed to DockerHub by GitHub Actions
- docker-compose.yml exists in $APP_DIR and references the DockerHub image
- Application runs on port 4000 by default
- Webhook listener runs on port 9000
- User has passwordless sudo configured for `systemctl * web`
- User is member of docker group on the VM
- Docker daemon is running and enabled on boot
- User has DockerHub account and repository set up
- GitHub Actions has DockerHub credentials in secrets
- Git repository has a `main` branch
- Application directory (`$APP_DIR`) exists and contains only `docker-compose.yml` and `.env.docker` (NOT the source code)
- Application source code is built into Docker image by GitHub Actions, not deployed directly to server

## Modifying for Different Runtimes

This repository is now configured for Docker-based deployment. If you need to use a different runtime (e.g., Python, Go binary, etc.), you would need to:

1. Create a Dockerfile for your application
2. Push the image to a container registry (DockerHub, GitHub Container Registry, etc.)
3. Update the `docker-compose.yml` to reference your image
4. Ensure the GitHub Actions workflow builds and pushes your image

The deployment flow will remain the same - GitHub Actions builds and pushes the image, then triggers the webhook to pull and restart containers on the VM.

## Security Notes

- Webhook signatures are verified using HMAC SHA256
- Secrets must be kept in sync between GitHub secrets and `scripts/env.sh`
- Cloudflared credentials are copied to `/etc/cloudflared/` (root-owned)
- Sudoers rule allows only systemctl commands for the web service
