#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ship.sh — react-ship template: generic build/push/deploy/smoke-check
# sequence for a react-bootstrap-scaffolded project's Docker image.
#
# Every project-specific value (registry/image name, deploy host, SSH key,
# ports, base path, smoke-check URL) is supplied by the adopting project via
# environment variables — see the "Configuration" section below. Nothing here
# is hardcoded to any specific project's infrastructure.
#
# STOP CONDITIONS gate: this script refuses to run at all until a human sets
# REACT_SHIP_STOP_CONDITIONS_CONFIRMED=yes, and that must not happen until
# every condition in react-ship/SKILL.md has actually been checked once
# against a real build of THIS project's chosen base images. See that file for
# what each condition means and how to confirm it.
#
# USAGE (run from the project root):
#   REACT_SHIP_STOP_CONDITIONS_CONFIRMED=yes \
#   SHIP_IMAGE=myregistry/my-app \
#   SHIP_CONTAINER_NAME=my-app \
#   SHIP_DEPLOY_HOST=deploy@example.com \
#   SHIP_SSH_KEY=~/.ssh/deploy_key \
#   SHIP_HOST_PORT=8080 \
#   SHIP_CONTAINER_PORT=8080 \
#   SHIP_BASE_PATH=/ \
#   SHIP_SMOKE_URL=https://example.com/ \
#   ./scripts/ship.sh
# ─────────────────────────────────────────────────────────────────────────────
set -e

# ── STOP CONDITIONS gate ─────────────────────────────────────────────────────
if [ "$REACT_SHIP_STOP_CONDITIONS_CONFIRMED" != "yes" ]; then
  cat <<'EOF'
REFUSING TO RUN.

Set REACT_SHIP_STOP_CONDITIONS_CONFIRMED=yes only after a human has actually
confirmed ALL FIVE of the following against a real build/run of this
project's Dockerfile (react-bootstrap/templates/Dockerfile) — see
react-ship/SKILL.md for how to check each one:

  1. Does your chosen nginx (or equivalent) base image actually execute
     /docker-entrypoint.d/*.sh scripts on container start?
  2. Does `npm run build -- --base=<path>` actually forward the --base flag
     through npm to vite on THIS project's package.json?
  3. Does a Dockerfile ARG actually expand inside a COPY *destination* path
     (not just a source path) for your Docker version?
  4. Is your pinned base-image tag still current and pullable?
  5. Does the entrypoint's write into a --chown'd directory succeed when
     running as that image's actual non-root UID?

None of these should be assumed true by default. This script will not guess
at the answer by running it "just once to see" in a shared/prod context —
confirm locally first (`docker build` + `docker run` on your own machine,
inspect the running container), THEN set the env var and re-run.
EOF
  exit 1
fi

# ── Configuration — every value below is supplied by the adopting project ──
: "${SHIP_IMAGE:?Set SHIP_IMAGE, e.g. myregistry/my-app}"
: "${SHIP_CONTAINER_NAME:?Set SHIP_CONTAINER_NAME}"
: "${SHIP_DEPLOY_HOST:?Set SHIP_DEPLOY_HOST, e.g. user@host}"
: "${SHIP_SSH_KEY:?Set SHIP_SSH_KEY, path to the deploy key}"
: "${SHIP_HOST_PORT:?Set SHIP_HOST_PORT}"
SHIP_CONTAINER_PORT="${SHIP_CONTAINER_PORT:-8080}"
SHIP_BASE_PATH="${SHIP_BASE_PATH:-/}"
SHIP_SMOKE_URL="${SHIP_SMOKE_URL:-}"

GIT_SHA="$(git rev-parse --short HEAD)"
ROLLBACK_FILE=".react-ship-previous-sha-${SHIP_CONTAINER_NAME}"

# ── Step 1/4 — Build ─────────────────────────────────────────────────────
echo "Building ${SHIP_IMAGE}:${GIT_SHA} (and :latest) with BASE_PATH=${SHIP_BASE_PATH}"
docker build \
  --build-arg BASE_PATH="$SHIP_BASE_PATH" \
  -t "$SHIP_IMAGE:$GIT_SHA" \
  -t "$SHIP_IMAGE:latest" \
  .

# ── Step 2/4 — Push ──────────────────────────────────────────────────────
docker push "$SHIP_IMAGE:$GIT_SHA"
docker push "$SHIP_IMAGE:latest"

# ── Step 3/4 — Deploy (record previous SHA before replacing the container) ──
ssh -i "$SHIP_SSH_KEY" "$SHIP_DEPLOY_HOST" << EOF
  set -e
  echo "Pulling ${SHIP_IMAGE}:${GIT_SHA}..."
  docker pull "$SHIP_IMAGE:$GIT_SHA"

  echo "Recording currently-running SHA (if any) for rollback..."
  docker inspect --format '{{ index .Config.Labels "deployed-sha" }}' "$SHIP_CONTAINER_NAME" 2>/dev/null > /tmp/${SHIP_CONTAINER_NAME}-previous-sha.txt || echo "none" > /tmp/${SHIP_CONTAINER_NAME}-previous-sha.txt

  echo "Stopping old container (if running)..."
  docker stop "$SHIP_CONTAINER_NAME" 2>/dev/null || true
  docker rm   "$SHIP_CONTAINER_NAME" 2>/dev/null || true

  echo "Starting new container..."
  docker run -d \
    --name "$SHIP_CONTAINER_NAME" \
    --restart unless-stopped \
    -p ${SHIP_HOST_PORT}:${SHIP_CONTAINER_PORT} \
    --label "deployed-sha=${GIT_SHA}" \
    "$SHIP_IMAGE:$GIT_SHA"

  echo "Container status:"
  docker ps --filter "name=${SHIP_CONTAINER_NAME}" --format "  Name: {{.Names}}  |  Status: {{.Status}}  |  Ports: {{.Ports}}"
EOF

# Pull the previous-SHA record back to the local machine so a rollback command
# has something concrete to reference without another SSH round-trip.
scp -i "$SHIP_SSH_KEY" "$SHIP_DEPLOY_HOST:/tmp/${SHIP_CONTAINER_NAME}-previous-sha.txt" "$ROLLBACK_FILE" 2>/dev/null || echo "none" > "$ROLLBACK_FILE"
echo "Previous SHA recorded in ${ROLLBACK_FILE}: $(cat "$ROLLBACK_FILE")"
echo "Rollback command: docker run -d --name $SHIP_CONTAINER_NAME --restart unless-stopped -p ${SHIP_HOST_PORT}:${SHIP_CONTAINER_PORT} --label deployed-sha=<previous-sha> $SHIP_IMAGE:<previous-sha>"

# ── Step 4/4 — Post-deploy smoke check (optional — only if SHIP_SMOKE_URL set) ──
if [ -n "$SHIP_SMOKE_URL" ]; then
  echo ""
  echo "Smoke checking ${SHIP_SMOKE_URL}..."
  sleep 3   # give the entrypoint a moment to finish its docker-entrypoint.d pass
  HTTP_CODE="$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$SHIP_SMOKE_URL" || echo "000")"
  if [ "$HTTP_CODE" = "200" ]; then
    echo "Smoke check PASSED (HTTP $HTTP_CODE) — $SHIP_SMOKE_URL"
  else
    echo "Smoke check FAILED (HTTP $HTTP_CODE) — $SHIP_SMOKE_URL"
    echo "  Container is running but did not return 200. Consider rolling back"
    echo "  using the command printed above before treating this deploy as done."
    exit 1
  fi
else
  echo "SHIP_SMOKE_URL not set — skipping post-deploy smoke check. Set it to enable this safety net."
fi

echo ""
echo "Deployed: ${SHIP_IMAGE}:${GIT_SHA} to ${SHIP_CONTAINER_NAME}@${SHIP_DEPLOY_HOST}"
