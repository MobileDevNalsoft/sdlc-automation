#!/bin/sh
# -----------------------------------------------------------------------------
# Production entrypoint for unprivileged web application containers.
# Validates required runtime variables, injects browser-safe config.js,
# renders private reverse-proxy nginx.conf, and tests configuration before boot.
# Never prints secrets sourced from BACKEND_BASIC_PASS to stdout or stderr.
# -----------------------------------------------------------------------------
set -eu

umask 077

fail() {
  printf '%s\n' "[web-entrypoint] $1" >&2
  exit 1
}

require_value() {
  eval "value=\${$1-}"
  [ -n "$value" ] || fail "$1 is required"
}

reject_control_characters() {
  if printf '%s' "$2" | LC_ALL=C grep -q '[[:cntrl:]]'; then
    fail "$1 must not contain control characters"
  fi
}

require_value APP_BASE_PATH
require_value BACKEND_UPSTREAM_ORIGIN
require_value BACKEND_BASE_PATH
require_value BACKEND_BASIC_USER
require_value BACKEND_BASIC_PASS

case "$APP_BASE_PATH" in
  /|/*/) ;;
  *) fail "APP_BASE_PATH must begin and end with '/'" ;;
esac
case "$APP_BASE_PATH" in
  *'//'*) fail "APP_BASE_PATH must not contain an empty segment" ;;
  *[!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789./_-]*) fail "APP_BASE_PATH contains unsupported characters" ;;
  */./*|*/../*) fail "APP_BASE_PATH must not contain traversal segments" ;;
esac

BACKEND_UPSTREAM_ORIGIN=${BACKEND_UPSTREAM_ORIGIN%/}
if ! printf '%s\n' "$BACKEND_UPSTREAM_ORIGIN" | grep -Eq '^https?://[A-Za-z0-9.-]+(:[0-9]+)?$'; then
  fail "BACKEND_UPSTREAM_ORIGIN must be an http(s) origin with an optional port"
fi

BACKEND_BASE_PATH=${BACKEND_BASE_PATH%/}
if ! printf '%s\n' "$BACKEND_BASE_PATH" | grep -Eq '^/([A-Za-z0-9._-]+/)*[A-Za-z0-9._-]*$'; then
  fail "BACKEND_BASE_PATH must be a slash-delimited path"
fi
case "$BACKEND_BASE_PATH" in
  */.|*/..|*/./*|*/../*) fail "BACKEND_BASE_PATH must not contain traversal segments" ;;
esac

: "${ENVIRONMENT:=staging}"
: "${APP_VERSION:=unknown}"
: "${REQUEST_TIMEOUT_MS:=30000}"
: "${FEATURE_FLAGS_JSON:={}}"
: "${MOCK_DOMAINS:=}"

case "$ENVIRONMENT" in
  development|staging|production) ;;
  *) fail "ENVIRONMENT must be development, staging, or production" ;;
esac
case "$REQUEST_TIMEOUT_MS" in
  *[!0-9]*|'') fail "REQUEST_TIMEOUT_MS must be a positive integer" ;;
esac
[ "$REQUEST_TIMEOUT_MS" -gt 0 ] || fail "REQUEST_TIMEOUT_MS must be a positive integer"

reject_control_characters BACKEND_BASIC_USER "$BACKEND_BASIC_USER"
reject_control_characters BACKEND_BASIC_PASS "$BACKEND_BASIC_PASS"

FEATURE_FLAGS_JSON=$(printf '%s' "$FEATURE_FLAGS_JSON" | jq -ce 'if type == "object" then . else error("must be an object") end') \
  || fail "FEATURE_FLAGS_JSON must be a JSON object"

API_BASE_URL="${APP_BASE_PATH}api"
BACKEND_BASIC_AUTH_B64=$(printf '%s' "${BACKEND_BASIC_USER}:${BACKEND_BASIC_PASS}" | base64 | tr -d '\n')
PUBLIC_ROOT="/usr/share/nginx/html${APP_BASE_PATH%/}"

[ -f "${PUBLIC_ROOT}/index.html" ] || fail "built application is missing from ${PUBLIC_ROOT}"

export APP_BASE_PATH BACKEND_UPSTREAM_ORIGIN BACKEND_BASE_PATH BACKEND_BASIC_AUTH_B64
export API_BASE_URL ENVIRONMENT APP_VERSION REQUEST_TIMEOUT_MS FEATURE_FLAGS_JSON MOCK_DOMAINS

# Render browser-safe config.js (no credentials)
envsubst '${API_BASE_URL} ${ENVIRONMENT} ${APP_VERSION} ${REQUEST_TIMEOUT_MS} ${FEATURE_FLAGS_JSON} ${MOCK_DOMAINS}' \
  < /etc/app/config.js.template > "${PUBLIC_ROOT}/config.js"

# Render unprivileged Nginx reverse-proxy configuration
envsubst '${APP_BASE_PATH} ${BACKEND_UPSTREAM_ORIGIN} ${BACKEND_BASE_PATH} ${BACKEND_BASIC_AUTH_B64}' \
  < /etc/app/nginx.conf.template > /tmp/app-nginx.conf

# Strip credentials from memory before spawning process
unset BACKEND_BASIC_USER BACKEND_BASIC_PASS BACKEND_BASIC_AUTH_B64

# Validate Nginx syntax before handing off control
nginx -t -c /tmp/app-nginx.conf
exec "$@"
