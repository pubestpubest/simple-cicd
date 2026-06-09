# AI Setup Guide — simple-cicd

> **For AI assistants.** Read this entire file before doing anything. Ask all questions in one go, then proceed only after the user answers.

---

## Your Role

You are helping a developer set up this deployment pipeline on their Ubuntu VM. This repo is a **toolkit**, not an application. You will generate configs and walk the user through commands — you will not write application code.

---

## Step 1 — Ask These Questions First

Ask all questions together in a single message. Do not assume answers.

```
Before I set anything up, I need to understand your project:

1. **Services** — How many Docker services does your app need?
   - (a) One service — just the web app
   - (b) Two services — web app + PostgreSQL database
   - (c) Three services — web app + PostgreSQL + Redis
   - (d) Something else (describe)

2. **Docker image** — Where will the image be pushed?
   - (a) DockerHub  (username/repo-name)
   - (b) GitHub Container Registry  (ghcr.io/...)
   - (c) Other

3. **App port** — What port does your app listen on inside the container?
   (default is 4000 — just say "default" if that's right)

4. **Health check** — Does your app expose a `/health` endpoint?
   - (a) Yes
   - (b) No / not yet

5. **Notifications** — Do you want Discord deployment notifications?
   - (a) Yes — I have a Discord webhook URL
   - (b) No

6. **Domain** — What is your base domain? (e.g., `example.com`)
   The pipeline will expose:
   - `example.com` → your app
   - `hooks.example.com` → webhook listener

7. **Tunnel** — Have you already created a Cloudflared tunnel?
   - (a) Yes — I have a tunnel name and ID
   - (b) No — I need to create one

8. **GitHub repo** — Does the application live in a GitHub repository?
   - (a) Yes
   - (b) No
```

---

## Step 2 — Interpret Answers and Pick the Right Files

Use this table to decide which files to use:

| Services answer | docker-compose template to use |
|---|---|
| (a) one service | `configs.example/docker-compose.yml` |
| (b) web + postgres | `configs.example/docker-compose.multi-container.yml` (remove Redis section) |
| (c) web + postgres + redis | `configs.example/docker-compose.multi-container.yml` (use as-is) |

| GitHub Actions template |
|---|
| One Docker image → `workflows.example/push.single-image.yaml` |
| Multiple images → `workflows.example/push.multi-image.yaml` |

---

## Step 3 — Fill in `scripts/env.sh`

After answers are collected, populate `scripts/env.sh` with the user's values:

```bash
export APP_DIR="${HOME}/app-deploy"         # deployment dir on VM (docker-compose.yml lives here)
export DISCORD_WEBHOOK="..."                # from answer 5 (leave placeholder if no)
export WEBHOOK_SECRET="..."                 # generate with: openssl rand -hex 32
export DEPLOY_DOMAIN="..."                  # from answer 6
export TUNNEL_NAME="..."                    # from answer 7
export TUNNEL_ID="..."                      # from answer 7
export DOCKER_IMAGE="..."                   # from answer 2
export DOCKER_CONTAINER_NAME="web-app"      # adjust if needed
export COMPOSE_PROJECT_NAME="simple-cicd"   # adjust to match app name
```

Tell the user to run:
```bash
nano scripts/env.sh
```

---

## Step 4 — Walk Through Setup in Order

Run through these phases **in order**. Complete each before moving to the next.

### Phase A — VM Prerequisites

```bash
chmod +x scripts/*.sh
./scripts/setup-packages.sh
# ⚠ Log out and back in after this step (Docker group membership)
```

### Phase B — Cloudflared Tunnel

**If user said they have a tunnel (answer 7a):** skip `tunnel create`, just confirm the ID.

**If user needs to create one (answer 7b):**
```bash
cloudflared tunnel login
cloudflared tunnel create TUNNEL_NAME
cloudflared tunnel list   # copy the UUID — this is TUNNEL_ID
```

After `env.sh` is filled in:
```bash
source scripts/env.sh
./scripts/create-config.sh
sudo cloudflared tunnel route dns $TUNNEL_NAME $DEPLOY_DOMAIN
sudo cloudflared tunnel route dns $TUNNEL_NAME hooks.$DEPLOY_DOMAIN
sudo cloudflared service install
sudo systemctl enable --now cloudflared
sudo systemctl status cloudflared
```

### Phase C — Webhook and Service Files

```bash
source scripts/env.sh
./scripts/create-hook-config.sh
./scripts/create-service-files.sh
sudo systemctl daemon-reload
```

Configure passwordless sudo for the deploy script:
```bash
echo "$USER ALL=(ALL) NOPASSWD: /bin/systemctl * web" | sudo tee /etc/sudoers.d/deploy
```

### Phase D — App Deploy Directory

```bash
mkdir -p $APP_DIR
cd $APP_DIR
```

Copy the right docker-compose template (from Step 2) to `$APP_DIR/docker-compose.yml` and fill in values.

Copy and fill environment files:
```bash
cp ~/simple-cicd/configs.example/.env.example .env
cp ~/simple-cicd/configs.example/.env.docker .env.docker
nano .env
nano .env.docker
```

Test before starting the service:
```bash
docker compose pull
docker compose up
# Ctrl+C when satisfied
```

### Phase E — Start Services

```bash
sudo systemctl start web
sudo systemctl start webhook
sudo systemctl enable web webhook

sudo systemctl status web
sudo systemctl status webhook
```

Verify the webhook endpoint is reachable:
```bash
curl -I https://hooks.$DEPLOY_DOMAIN
# Expect: 200 or 405 (method not allowed is fine — means it's up)
```

### Phase F — GitHub Actions

1. Copy the right workflow file to the application repo:
```bash
mkdir -p .github/workflows
cp ~/simple-cicd/workflows.example/push.single-image.yaml .github/workflows/push.yaml
```

2. Add these secrets in **GitHub → repo → Settings → Secrets → Actions**:

| Secret | Value |
|---|---|
| `DOCKERHUB_USERNAME` | DockerHub username |
| `DOCKERHUB_TOKEN` | DockerHub access token |
| `DOCKERHUB_REPO` | Repo name (e.g. `my-app`) |
| `DISCORD_WEBHOOK_URL` | Discord webhook URL (if enabled) |
| `WEBHOOK_URL` | `https://hooks.DEPLOY_DOMAIN` |
| `WEBHOOK_SECRET` | Same value as in `env.sh` |

3. Update the `lint` job in the workflow to match the user's language/stack.

---

## Step 5 — Smoke Test

After everything is up:

```bash
# On the VM — watch logs during a push
journalctl -u webhook -f &
journalctl -u web -f &

# Push any commit from the app repo, then watch the output
```

Expected sequence:
1. GitHub Actions: lint → build → push image → trigger webhook
2. VM webhook receives POST, verifies signature, runs `deploy.sh`
3. `deploy.sh` pulls image, restarts `web` service
4. App is live at `https://DEPLOY_DOMAIN`

---

## Common Problems

| Symptom | Likely cause | Fix |
|---|---|---|
| `web` service fails to start | `$APP_DIR` missing or no `docker-compose.yml` | Run Phase D again |
| Webhook returns 401 | `WEBHOOK_SECRET` mismatch | Re-check `env.sh` and GitHub secret |
| Cloudflared not routing | DNS records not created | Re-run the `tunnel route dns` commands |
| Docker permission denied | Not in docker group | Log out and back in after `setup-packages.sh` |
| `sudo systemctl` blocked | sudoers not configured | Run the `tee /etc/sudoers.d/deploy` command |
| Health check failing | App not on expected port | Check answer 3 — update `deploy.sh` `APP_PORT` |

---

## Variables Reference

| Variable | Where set | Used by |
|---|---|---|
| `APP_DIR` | `env.sh` | `deploy.sh`, service files |
| `DEPLOY_DOMAIN` | `env.sh` | cloudflared config, DNS routes |
| `TUNNEL_NAME` / `TUNNEL_ID` | `env.sh` | `create-config.sh` |
| `WEBHOOK_SECRET` | `env.sh` + GitHub secret | webhook signature verification |
| `DOCKER_IMAGE` | `env.sh` + `.env` | docker-compose pull |
| `DISCORD_WEBHOOK` | `env.sh` + GitHub secret | deploy notifications |
