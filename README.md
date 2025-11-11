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
| Component | Purpose | Reference |
|------------|----------|------------|
| **Cloudflared** | Secure tunnel to Cloudflare network | [Cloudflared Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/) |
| **GitHub Actions** | CI/CD automation for deploy and notify | [GitHub Actions Docs](https://docs.github.com/en/actions) |
| **Discord Webhook** | Send notifications to Discord channel | [Discord Webhook Docs](https://discord.com/developers/docs/resources/webhook) |
| **Webhook** | Lightweight webhook listener for automation | [adnanh/webhook](https://github.com/adnanh/webhook) |
| **Git** | Version control | [Git SCM](https://git-scm.com/) |
| **Node.js / Docker / etc.** | (Optional) Your app runtime environment | [Node.js](https://nodejs.org/) / [Docker](https://www.docker.com/) |

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

| Variable | Description | Example |
|-----------|--------------|----------|
| `DEPLOY_DOMAIN` | Main domain connected to Cloudflare | `myapp.example.com` |
| `SUB_DOMAIN` | Subdomain for webhooks (optional) | `hook.myapp.example.com` |
| `DISCORD_WEBHOOK_URL` | Discord notification endpoint | `https://discord.com/api/webhooks/...` |
| `WEBHOOK_SECRET` | Secret for verifying GitHub webhooks | `supersecrettoken` |
| `TUNNEL_NAME` | Name of your Cloudflared tunnel | `myapp-tunnel` |
| `TUNNEL_ID` | ID of your Cloudflared tunnel | `masldk22-s13d-4dws-adw-2xxxvvafc4e` |

---

## 🪄 Steps

### 0. Clone your repo
```bash
git clone https://github.com/<username>/<repo>.git
```


### 1. Clone this repo
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
	•	Update your system
	•	Install git, curl, screen, jq, webhook, and unzip
	•	Install Node.js (LTS) and pnpm if missing (change the runtime if needed)
	•	Install Cloudflared from the official Cloudflare repository

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

export APP_DIR="~/APP_DIR"                        # Path to your app
export DISCORD_WEBHOOK="https://discord.com/api/webhooks/foo/bar"  # Discord notifications
export WEBHOOK_SECRET="supersecret"              # Secret for GitHub webhook verification
export DEPLOY_DOMAIN="example.com"               # Your main domain
export TUNNEL_NAME="TUNNEL_NAME"                # Cloudflared tunnel name
export TUNNEL_ID="TUNNEL_LONG_STRING"           # Cloudflared tunnel ID
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
You can add or remove additional ingress entries (subdomains) as needed by editing cloudflared.yml. For example, you could add api.example.com pointing to another port.
After running both scripts, your VM has all configuration files ready for Cloudflared and the webhook listener.

### 7. Configure DNS Routes and Start Cloudflared
```bash
# Route main domain
cloudflared tunnel route dns $TUNNEL_NAME $DEPLOY_DOMAIN

# Route subdomain (for webhook listener or other services)
cloudflared tunnel route dns $TUNNEL_NAME hooks.$DEPLOY_DOMAIN

sudo cloudflared --config ~/configs/cloudflared.yml service install
```

### 8. Run the Webhook Listener
•	Webhook behavior:
- Listens on the port defined in your hook config (default 9000)
- Verifies GitHub payloads using $WEBHOOK_SECRET
- Executes deploy.sh on a valid push to main
•	Run in the background using screen:
```bash
screen -S webhook
webhook -hooks ~/configs/hooks.yml -verbose
# Press Ctrl+A then D to detach
```

To re-attach
```bash
screen -ls
screen -r webhook
```
💡 Tip: deploy.sh logs the app output to `$APP_DIR/log.txt` and sends a Discord notification when the deployment completes. You can view logs anytime with: `tail -f $APP_DIR/log.txt`

### 9. Setup GitHub Actions Workflow
1. Copy push.yaml to your project
```bash
mkdir -p .github/workflows
cp push.yaml .github/workflows/push.yaml
```
2. Add required repository secrets in GitHub:

| Secret Name           | Description                                                  |
|----------------------|--------------------------------------------------------------|
| DISCORD_WEBHOOK_URL   | Discord webhook URL for notifications                        |
| WEBHOOK_URL           | Full URL of your VM’s webhook listener, e.g., https://hooks.example.com |
| WEBHOOK_SECRET        | Secret used to verify GitHub payloads (X-Hub-Signature-256) |

---
