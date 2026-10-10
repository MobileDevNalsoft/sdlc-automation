---
name: react-ship
description: Use to build, tag, push, and deploy a production Docker image for React 19 (Vite) and Next.js web applications, executing zero-downtime candidate health checks and recording previous-SHA metadata for instant rollback. Runs cross-platform via deploy-web.ps1 (Windows) or deploy-web.sh (Linux/CI). Use after react-verify passes quality gates.
---

# react-ship

**Verb: release.**

## Deployment Architecture

```
Workstation / CI
[typecheck + lint + test + build]
        │
        ▼
[docker build --build-arg APP_BASE_PATH] (Multi-stage unprivileged)
        │
        ▼
[docker push to registry: <image>:<git-sha> and :latest]
        │
        ▼ SSH to Target Host
┌─────────────────────────────────────────────────────────┐
│ Target VM / Host                                        │
│                                                         │
│ 1. docker pull <image>:<git-sha>                        │
│ 2. Run candidate container on CANDIDATE_PORT (8088)     │
│ 3. Smoke check loopback: curl /healthz                  │
│    ├── FAIL ──> Abort. Remove candidate. Keep live run. │
│    └── PASS ──> Swap traffic:                           │
│                 Record previous image to previous_image │
│                 Stop previous container on HOST_PORT    │
│                 Start new container on HOST_PORT (8080) │
│                 Remove candidate                        │
└─────────────────────────────────────────────────────────┘
```

## Security Invariants

1. **Zero build secrets**: Frontend build bundles (`dist/`) never contain backend API credentials.
2. **Reverse proxy secret injection**: Nginx proxies same-origin `${APP_BASE_PATH}api/*` to upstream backend, injecting server-side authorization headers securely inside the private container network.
3. **Runtime configuration (`public/config.js`)**: Non-sensitive values (`API_BASE_URL`, `ENVIRONMENT`, `APP_VERSION`, `REQUEST_TIMEOUT_MS`, `FEATURE_FLAGS_JSON`) are generated at container boot by `entrypoint.sh` using `envsubst`.
4. **Cache segregation**:
   - `index.html` and `config.js`: `Cache-Control: no-store` (guarantees instant deployment visibility).
   - Hashed static assets (`assets/*`): `Cache-Control: public, max-age=31536000, immutable`.
5. **Unprivileged execution**: Runs as non-root UID (`nginx` on port 8080 or `nextjs` on port 3000).

## Supported Runtimes

| Stack | Build Target | Runner Base Image | Template |
|---|---|---|---|
| **React 19 + Vite** | SPA static assets (`dist/`) | `nginxinc/nginx-unprivileged:alpine3.22` | `templates/Dockerfile.vite` |
| **Next.js Standalone** | Node standalone server (`.next/standalone`) | `node:22-alpine` (user `nextjs`) | `templates/Dockerfile.nextjs` |
| **Next.js Static Export** | SPA static assets (`out/`) | `nginxinc/nginx-unprivileged:alpine3.22` | `templates/Dockerfile.vite` |

## Quick Start

### 1. Scaffold Configuration

Copy the configuration template to the project root:
```bash
cp templates/.deploy.env.example .deploy.env
```

Set the required target host parameters in `.deploy.env`:
- `DOCKER_USER`: Registry username or organisation.
- `IMAGE_NAME`: Application image repository name.
- `VM_USER`: SSH user on target host.
- `VM_HOST`: Target server hostname or IP.
- `VM_KEY_PATH`: Path to SSH private key.
- `CONTAINER_NAME`: Docker container name on host.
- `HOST_PORT`: Production listening port (e.g., 8080).
- `CANDIDATE_PORT`: Candidate verification port (e.g., 8088).
- `APP_BASE_PATH`: URL mount prefix (`/` or `/subpath/`).

### 2. Execute Deployment

**Windows (PowerShell):**
```powershell
.\scripts\deploy-web.ps1
```

**Linux / macOS / CI Runner:**
```bash
./scripts/deploy-web.sh
```

**Optional Flags:**
- `-SkipLocalGates` / `SKIP_LOCAL_GATES=true`: Skip workstation checks when running in pre-validated CI pipelines.
- `-AllowDirtyDeploy` / `ALLOW_DIRTY_DEPLOY=true`: Allow deployment with uncommitted tracked changes.

## Rollback Protocol

When a newly deployed release exhibits an operational defect:

```bash
# Read previous image recorded during last deployment:
PREV_IMAGE=$(cat /etc/<CONTAINER_NAME>/previous_image)

# Revert production container to previous image:
docker rm -f <CONTAINER_NAME>
docker run -d --name <CONTAINER_NAME> \
  --restart unless-stopped \
  -p <HOST_PORT>:8080 \
  --env-file /etc/<CONTAINER_NAME>/env \
  "$PREV_IMAGE"
```
