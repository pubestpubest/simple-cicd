# Workflow Examples

Two reference GitHub Actions workflows for the deployment pipeline in this repo. Copy one into your application repository under `.github/workflows/` and adapt it.

## Which one to use

| File | Use when |
|------|----------|
| [`push.single-image.yaml`](push.single-image.yaml) | Your repo builds **one** Docker image (one service). Pairs with `configs.example/docker-compose.yml`. |
| [`push.multi-image.yaml`](push.multi-image.yaml) | Your repo is a monorepo that builds **multiple** images (e.g. backend + frontend, each in its own folder). Pairs with `configs.example/docker-compose.multi-container.yml`. |

Both workflows do the same thing end-to-end:

1. **Lint / compile check** — fail fast before building.
2. **Build & push** Docker image(s) to DockerHub with `latest` + commit-SHA tags and registry-based build cache.
3. **Discord notification** when an image is pushed.
4. **HMAC-signed webhook** to the VM, which verifies the signature and runs `scripts/deploy.sh`.

The multi-image variant adds:

- **`dorny/paths-filter`** to detect which service folders changed, so only the affected services rebuild.
- **`concurrency`** group cancels older in-flight runs for the same branch so only the newest commit deploys.
- A single **`trigger-deployment`** job that fires once after all builds, even if only one service was rebuilt.

## Required GitHub repository secrets

### Single image

| Secret | Description |
|--------|-------------|
| `DOCKERHUB_USERNAME` | DockerHub username |
| `DOCKERHUB_TOKEN` | DockerHub access token (Account Settings → Security) |
| `DOCKERHUB_REPO` | Image repo name (e.g. `my-app`) |
| `DISCORD_WEBHOOK_URL` | Discord channel webhook |
| `WEBHOOK_URL` | Full URL of the VM's webhook listener (e.g. `https://hooks.example.com`) |
| `WEBHOOK_SECRET` | Shared secret — must match `WEBHOOK_SECRET` in `scripts/env.sh` on the VM |

### Multi image

Same as above, but replace `DOCKERHUB_REPO` with one secret per service:

| Secret | Description |
|--------|-------------|
| `DOCKERHUB_REPO_BACKEND` | Backend image repo name (e.g. `my-app-backend`) |
| `DOCKERHUB_REPO_FRONTEND` | Frontend image repo name (e.g. `my-app-frontend`) |

Add more (`DOCKERHUB_REPO_WORKER`, ...) as you add services.

## Adapting to your project

- **Folder layout** — the multi-image example assumes `backend/` and `frontend/` at the repo root. Rename to match your tree, then update `paths:`, `paths-filter`, `working-directory`, and the build `context` accordingly.
- **Lint commands** — the examples show Go (`go vet` + `go build`) and Node/pnpm (`tsc --noEmit`). Swap in whatever your stack uses (`ruff`, `cargo check`, `mvn verify`, ...).
- **Adding a service** to the multi-image workflow: copy a `lint-*` job, add a filter under `detect-changes`, copy a `build-*` job, and add its name to `trigger-deployment.needs` and the `if:` condition.
- **Dockerfile target** — `target: production` in the frontend job is for multi-stage Dockerfiles. Remove it if your Dockerfile is single-stage.

## How this fits the VM side

The VM's `deploy.sh` runs `docker compose pull && docker compose up -d` — it doesn't know or care how many images were rebuilt. As long as `docker-compose.yml` on the VM references the same image names you're pushing here, the new tags will be pulled on the next webhook trigger.
