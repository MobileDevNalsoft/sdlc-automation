#!/usr/bin/env bash
# =============================================================================
# Automated production web deployment script for React (Vite) and Next.js apps.
# Performs pre-flight gates, builds immutable Docker images, pushes to registry,
# and executes zero-downtime candidate swap on remote VM via SSH.
# =============================================================================
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOY_ENV_FILE="${DEPLOY_ENV_FILE:-${PROJECT_ROOT}/.deploy.env}"

die() {
  printf '%s\n' "[deploy-web] ERROR: $1" >&2
  exit 1
}

on_error() {
  local exit_code=$?
  printf '%s\n' "[deploy-web] failed at line $1 (exit ${exit_code})" >&2
  exit "${exit_code}"
}
trap 'on_error $LINENO' ERR

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command is unavailable: $1"
}

require_value() {
  local value_name="$1"
  [[ -n "${!value_name:-}" ]] || die "${value_name} must be set in ${DEPLOY_ENV_FILE}"
}

[[ -f "${DEPLOY_ENV_FILE}" ]] || die "deployment config not found: ${DEPLOY_ENV_FILE} (copy .deploy.env.example)"

# shellcheck disable=SC1090
source "${DEPLOY_ENV_FILE}"

for cmd in docker git npm ssh curl; do
  require_command "${cmd}"
done

for val in DOCKER_USER IMAGE_NAME VM_USER VM_HOST VM_KEY_PATH CONTAINER_NAME HOST_PORT CANDIDATE_PORT APP_BASE_PATH; do
  require_value "${val}"
done

[[ -f "${VM_KEY_PATH}" ]] || die "VM_KEY_PATH does not point to a readable private key"

if [[ "${ALLOW_DIRTY_DEPLOY:-false}" != "true" ]] && { ! git diff --quiet || ! git diff --cached --quiet; }; then
  die "tracked worktree is dirty; commit/stash it or set ALLOW_DIRTY_DEPLOY=true deliberately"
fi

GIT_SHA="$(git rev-parse --verify HEAD)"
IMAGE_TAG="${IMAGE_TAG:-${GIT_SHA:0:12}}"
IMAGE_REF="${DOCKER_USER}/${IMAGE_NAME}:${IMAGE_TAG}"
LATEST_REF="${DOCKER_USER}/${IMAGE_NAME}:latest"

if [[ "${SKIP_LOCAL_GATES:-false}" != "true" ]]; then
  printf '%s\n' "[deploy-web] Running local quality gates..."
  npm run typecheck
  npm run lint
  npm run test -- --maxWorkers=2
  npm run build
fi

printf '%s\n' "[deploy-web] Building Docker image: ${IMAGE_REF}"
docker build --build-arg APP_BASE_PATH="${APP_BASE_PATH}" -t "${IMAGE_REF}" -t "${LATEST_REF}" .

printf '%s\n' "[deploy-web] Pushing Docker image to registry..."
docker push "${IMAGE_REF}"
docker push "${LATEST_REF}"

printf '%s\n' "[deploy-web] Executing zero-downtime candidate deployment on ${VM_HOST}..."
REMOTE_ENV_DIR="/etc/${CONTAINER_NAME}"

ssh -i "${VM_KEY_PATH}" -o StrictHostKeyChecking=accept-new "${VM_USER}@${VM_HOST}" "bash -s" <<REMOTE_EOF
set -e
docker pull "${IMAGE_REF}"

docker rm -f "${CONTAINER_NAME}-candidate" 2>/dev/null || true

echo "[remote] Starting candidate container on port ${CANDIDATE_PORT}..."
docker run -d --name "${CONTAINER_NAME}-candidate" \
  -p "127.0.0.1:${CANDIDATE_PORT}:8080" \
  --env-file "${REMOTE_ENV_DIR}/env" \
  "${IMAGE_REF}"

echo "[remote] Verifying candidate healthcheck on loopback..."
sleep 3
if ! curl --fail --silent "http://127.0.0.1:${CANDIDATE_PORT}/healthz"; then
  echo "[remote] Candidate healthcheck FAILED. Aborting swap."
  docker rm -f "${CONTAINER_NAME}-candidate"
  exit 1
fi
echo "[remote] Candidate healthy."

PREV_IMAGE=\$(docker inspect -f '{{.Config.Image}}' "${CONTAINER_NAME}" 2>/dev/null || echo "none")
echo "\$PREV_IMAGE" > "${REMOTE_ENV_DIR}/previous_image"

echo "[remote] Swapping production traffic to ${IMAGE_REF} on port ${HOST_PORT}..."
docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
docker rm -f "${CONTAINER_NAME}-candidate" 2>/dev/null || true

docker run -d --name "${CONTAINER_NAME}" \
  --restart unless-stopped \
  -p "${HOST_PORT}:8080" \
  --env-file "${REMOTE_ENV_DIR}/env" \
  "${IMAGE_REF}"

echo "[remote] Deployment SUCCESS. Previous image: \$PREV_IMAGE"
REMOTE_EOF

printf '%s\n' "[deploy-web] Release complete: ${IMAGE_REF} is active on ${VM_HOST}:${HOST_PORT}"
