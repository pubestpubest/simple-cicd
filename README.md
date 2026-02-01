# 🚀 Simple DevOps Setup (Cloudflared + GitHub Actions + Discord Webhooks)

## 🧩 Overview

This project demonstrates a minimal yet functional DevOps pipeline built on a **fresh Ubuntu VM**, using:

- **Cloudflared Tunnel** for secure HTTPS exposure (no need for Nginx or public IPs)
- **GitHub Actions** for automated deployment on every push
- **GitHub Webhooks** for custom triggers (optional)
- **Discord Webhooks** for deployment notifications

It’s a practical foundation for small projects or internal apps where simplicity and automation matter more than heavy infrastructure.

---

## 📦 Packages / References

| Component                   | Purpose                                     | Reference                                                                                      |
| --------------------------- | ------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| **Cloudflared**             | Secure tunnel to Cloudflare network         | [Cloudflared Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/) |
| **GitHub Actions**          | CI/CD automation for deploy and notify      | [GitHub Actions Docs](https://docs.github.com/en/actions)                                      |
| **Discord Webhook**         | Send notifications to Discord channel       | [Discord Webhook Docs](https://discord.com/developers/docs/resources/webhook)                  |
| **Webhook**                 | Lightweight webhook listener for automation | [adnanh/webhook](https://github.com/adnanh/webhook)                                            |
| **Git**                     | Version control                             | [Git SCM](https://git-scm.com/)                                                                |
| **Systemd**                 | Service manager for Linux systems           | [Systemd Documentation](https://www.freedesktop.org/wiki/Software/systemd/)                    |
| **Node.js / Docker / etc.** | (Optional) Your app runtime environment     | [Node.js](https://nodejs.org/) / [Docker](https://www.docker.com/)                             |

---

## ⚙️ Prerequisites

Before setting up:

- Ubuntu VM (clean install)
- A Cloudflare account and a registered **Domain**
- Your app repository hosted on GitHub
- Discord channel webhook URL (optional)
- Basic understanding of GitHub Actions and Linux shell

---

## 🧠 Environment Variables

Edit a `scripts/env.sh` file in your Ubuntu VM.

| Variable              | Description                          | Example                                |
| --------------------- | ------------------------------------ | -------------------------------------- |
| `DEPLOY_DOMAIN`       | Main domain connected to Cloudflare  | `myapp.example.com`                    |
| `SUB_DOMAIN`          | Subdomain for webhooks (optional)    | `hook.myapp.example.com`               |
| `DISCORD_WEBHOOK_URL` | Discord notification endpoint        | `https://discord.com/api/webhooks/...` |
| `WEBHOOK_SECRET`      | Secret for verifying GitHub webhooks | `supersecrettoken`                     |
| `TUNNEL_NAME`         | Name of your Cloudflared tunnel      | `myapp-tunnel`                         |
| `TUNNEL_ID`           | ID of your Cloudflared tunnel        | `masldk22-s13d-4dws-adw-2xxxvvafc4e`   |

---

## 🪄 Steps

### 0. Prepare your application repository (on your local machine)

Your application repository should have:

- A `Dockerfile` that builds your application
- Copy the files from this repo that you need:
  - `push.yaml` → `.github/workflows/push.yaml` (for GitHub Actions)
  - `configs.example/docker-compose.yml` → `docker-compose.yml` (customize for your app)
  - `configs.example/.env.docker` → `.env.docker` (add to .gitignore)

**Important**: With Docker deployment, you do NOT clone your application source code to the production server. The production server only needs the `docker-compose.yml` file to pull and run the pre-built Docker image from DockerHub.

### 1. Clone this repo (on your production server)

```bash
git clone https://github.com/pubestpubest/simple-cicd.git
cd simple-cicd
```

### 2. Make all scripts executable

```bash
chmod +x scripts/*.sh
```

### 3. Install dependencies

```bash
./scripts/setup-packages.sh
```

This will:

- Update your system
- Install git, curl, jq, webhook, and unzip
- Install Docker Engine, containerd, and Docker Compose plugin
- Add user to docker group for passwordless Docker commands
- Install Cloudflared from the official Cloudflare repository

⚠️ **Important:** After installation, you must log out and back in for Docker group membership to take effect.

### 4. Create Cloudflared Tunnel

```bash
cloudflared tunnel login
cloudflared tunnel create TUNNEL_NAME
```

Replace TUNNEL_NAME with a name for your tunnel, e.g., simple-cicd-tunnel.

check your tunnel

```bash
cloudflared tunnel list
```

### 5. Configure Environment Variables

Edit `scripts/env.sh` with your project-specific values:

```bash
nano scripts/env.sh
```

Example content

```bash
#!/bin/bash

export APP_DIR="~/app-deploy"                     # Deployment directory (docker-compose.yml location)
export DISCORD_WEBHOOK="https://discord.com/api/webhooks/foo/bar"  # Discord notifications
export WEBHOOK_SECRET="supersecret"              # Secret for GitHub webhook verification
export DEPLOY_DOMAIN="example.com"               # Your main domain
export TUNNEL_NAME="TUNNEL_NAME"                # Cloudflared tunnel name
export TUNNEL_ID="TUNNEL_LONG_STRING"           # Cloudflared tunnel ID

# Docker configuration
export DOCKER_IMAGE="your-dockerhub-username/your-app-name"
export DOCKER_CONTAINER_NAME="web-app"
export COMPOSE_PROJECT_NAME="simple-cicd"
```

Then load the environment

```bash
source scripts/env.sh
```

### 6. Generate Config Files

```bash
./scripts/create-config.sh
./scripts/create-hook-config.sh
```

The `create-config.sh` script will:

- Copy cloudflared credentials from `~/.cloudflared/` to `/etc/cloudflared/`
- Generate the config file at `/etc/cloudflared/config.yml` with your environment variables
- Set proper permissions (600 for credentials, 644 for config)
- Include the origin certificate path for authentication

You can later add or remove additional ingress entries (subdomains) by editing `/etc/cloudflared/config.yml`. For example, you could add `api.example.com` pointing to another port.

After running both scripts, your VM has all configuration files ready for Cloudflared and the webhook listener.

### 7. Configure DNS Routes and Start Cloudflared

```bash
# Route main domain
cloudflared tunnel route dns $TUNNEL_NAME $DEPLOY_DOMAIN

# Route subdomain (for webhook listener or other services)
cloudflared tunnel route dns $TUNNEL_NAME hooks.$DEPLOY_DOMAIN

# Install and start cloudflared service
sudo cloudflared service install
sudo systemctl status cloudflared
```

**Note**: The config file is located at `/etc/cloudflared/config.yml`, which is the standard location cloudflared expects. The service will start automatically on boot.

**Troubleshooting**: If you see warnings like `Can't read origin cert from /etc/cloudflared/cert.pem` when running DNS route commands, but the DNS records appear in your Cloudflare dashboard and the service is running, this is expected. The warnings occur because the commands check `/etc/cloudflared/` first but can fall back to `~/.cloudflared/`. As long as the service is active and DNS records are created, everything is working correctly.

If you ran `create-config.sh` before permissions were added to the script, manually fix permissions:
```bash
sudo chmod 600 /etc/cloudflared/cert.pem
sudo chmod 600 /etc/cloudflared/$TUNNEL_ID.json
sudo chmod 644 /etc/cloudflared/config.yml
sudo systemctl restart cloudflared
```

### 7.5. Setup Application Docker Configuration

**Important**: With Docker deployment, `$APP_DIR` on the production server is NOT your application source code. It's just a directory containing `docker-compose.yml` that references your pre-built DockerHub image.

1. **Create the app directory and copy docker-compose.yml template:**

   ```bash
   mkdir -p $APP_DIR
   cp configs.example/docker-compose.yml $APP_DIR/
   cp configs.example/.env.docker $APP_DIR/
   ```

2. **Edit docker-compose.yml:**

   - Replace `your-dockerhub-username/your-app-name` with your actual DockerHub image
   - Adjust volume mounts for your app's persistent data
   - Ensure port 4000 is mapped
   - Verify health check endpoint matches your app

3. **Edit .env.docker:**

   - Add your app-specific environment variables
   - Add `.env.docker` to `.gitignore` (never commit secrets!)

4. **Update scripts/env.sh:**

   ```bash
   nano scripts/env.sh
   # Set DOCKER_IMAGE to match your DockerHub repo:
   export DOCKER_IMAGE="yourusername/yourapp"
   ```

5. **Test Docker setup locally:**

   ```bash
   cd $APP_DIR
   docker compose up
   # Test at http://localhost:4000
   # Press Ctrl+C, then:
   docker compose down
   ```

6. **Ensure docker group membership:**
   ```bash
   groups | grep -q docker || echo "⚠️ Please log out and back in"
   ```

### 8. Setup Systemd Services

Generate and install systemd service files for both the web application and webhook listener:

```bash
./scripts/create-service-files.sh
```

This script will:

- Generate `web.service` and `webhook.service` with your environment variables
- Install them to `/etc/systemd/system/`
- Enable both services to start on boot

Start the services:

```bash
sudo systemctl start web
sudo systemctl start webhook
```

Check service status:

```bash
sudo systemctl status web
sudo systemctl status webhook
```

View logs:

```bash
# View logs in real-time
journalctl -u web -f
journalctl -u webhook -f

# Or view Docker container logs directly
cd $APP_DIR
docker compose logs -f            # Follow live logs
docker compose logs --tail=100    # Last 100 lines
```

💡 **Important**: For automatic deployments to work, you need to configure passwordless sudo for systemctl commands. Add this to `/etc/sudoers.d/deploy`:

```bash
echo "$USER ALL=(ALL) NOPASSWD: /bin/systemctl * web" | sudo tee /etc/sudoers.d/deploy
sudo chmod 440 /etc/sudoers.d/deploy
```

This wildcard allows all systemctl commands (restart, start, stop, status, is-active, etc.) for the `web` service without requiring a password.

🔧 **Webhook behavior**:

- Listens on port 9000 (defined in hooks.yml)
- Verifies GitHub payloads using $WEBHOOK_SECRET
- Executes deploy.sh on a valid push to main
- deploy.sh automatically restarts the web service after deployment

### 9. Setup GitHub Actions Workflow

1. Copy push.yaml to your project

```bash
mkdir -p .github/workflows
cp push.yaml .github/workflows/push.yaml
```

2. Add required repository secrets in GitHub:

| Secret Name         | Description                                                       |
| ------------------- | ----------------------------------------------------------------- |
| DOCKERHUB_USERNAME  | Your DockerHub username                                           |
| DOCKERHUB_TOKEN     | DockerHub access token (Settings → Security → New Access Token)   |
| DOCKERHUB_REPO      | Repository name (e.g., "my-app")                                  |
| DISCORD_WEBHOOK_URL | Discord webhook URL for notifications                             |
| WEBHOOK_URL         | Full URL of VM webhook listener (e.g., https://hooks.example.com) |
| WEBHOOK_SECRET      | Secret for webhook signature verification (matches env.sh)        |

#### Creating DockerHub Access Token:

1. Go to [DockerHub](https://hub.docker.com/)
2. Click your profile → Account Settings → Security
3. Click "New Access Token"
4. Name it (e.g., "github-actions")
5. Copy the token immediately (you won't see it again)
6. Add to GitHub repository secrets as `DOCKERHUB_TOKEN`

---

## 🐳 Docker Management

### View Running Containers

```bash
cd $APP_DIR
docker compose ps
```

### View Container Logs

```bash
docker compose logs -f
docker compose logs --tail=100
```

### Pull Latest Image Manually

```bash
docker compose pull
```

### Restart Containers

```bash
docker compose restart
```

### Stop and Remove Containers

```bash
docker compose down
```

### Check Container Health

```bash
docker inspect --format='{{.State.Health.Status}}' web-app
```

### Access Container Shell

```bash
docker compose exec web sh
```

### View Resource Usage

```bash
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

---
