#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# ship.sh — Wrapper redirecting to deploy-web.sh
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/deploy-web.sh" "$@"
