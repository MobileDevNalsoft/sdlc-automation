#!/bin/sh
# 50-inject-api-auth.sh — react-bootstrap template
#
# ASSUMPTION (STOP CONDITION, restated at its point of use): this script is
# only ever run if the chosen base image actually executes executable *.sh
# files under /docker-entrypoint.d/ before starting nginx, the way the
# standard docker-library/nginx image's entrypoint documents. Confirm against
# your specific image before relying on it — if it does NOT run,
# /etc/nginx/conf.d/api-auth.conf stays as the empty placeholder the
# Dockerfile touched, the /api/ location has no auth header, and every
# proxied backend call will fail auth.
#
# Numbered "50-" so it runs after the base image's own numbered entrypoint
# scripts (commonly in the 10-30 range) and before nginx actually starts
# serving.
set -eu

CONF_FILE="/etc/nginx/conf.d/api-auth.conf"

# Preferred path: Docker secrets (docker run --secret / compose `secrets:` /
# swarm). Each secret is mounted as a file at /run/secrets/<name> containing
# ONLY the value — no shell quoting, no surrounding whitespace expected.
if [ -f "/run/secrets/api_username" ] && [ -f "/run/secrets/api_password" ]; then
    API_USER="$(cat /run/secrets/api_username)"
    API_PASS="$(cat /run/secrets/api_password)"
else
    # Fallback: plain environment variables (docker run -e API_USERNAME=...).
    # Documented as the less-safe path deliberately — env vars are visible via
    # `docker inspect` and `/proc/<pid>/environ` to anything with host/container
    # access, which a Docker secret is not. Prefer secrets in any real
    # deployment; this fallback exists so local `docker run` testing doesn't
    # require standing up a secrets store.
    API_USER="${API_USERNAME:-}"
    API_PASS="${API_PASSWORD:-}"
fi

if [ -z "$API_USER" ] || [ -z "$API_PASS" ]; then
    echo "[50-inject-api-auth] WARNING: no API credential found (checked /run/secrets/api_username+api_password, then \$API_USERNAME+\$API_PASSWORD). Writing an empty auth conf — /api/ proxy calls will be unauthenticated." >&2
    : > "$CONF_FILE"
    exit 0
fi

# Basic auth = base64("user:pass"). printf avoids echo's inconsistent
# trailing-newline/backslash-escape behavior across shells. Swap this for
# whatever auth scheme your real backend actually uses (bearer token, signed
# header, etc.) — Basic auth is illustrative here, not prescriptive.
B64_CREDENTIAL="$(printf '%s:%s' "$API_USER" "$API_PASS" | base64 | tr -d '\n')"

# Write ONLY a proxy_set_header directive — this file is `include`d inside an
# existing `location /api/ { ... }` block in docker-nginx.conf, so it must
# contain directives, not a location/server block of its own.
{
    echo "# generated at container start by docker-entrypoint.d/50-inject-api-auth.sh — do not edit by hand"
    echo "proxy_set_header Authorization \"Basic ${B64_CREDENTIAL}\";"
} > "$CONF_FILE"

echo "[50-inject-api-auth] Wrote ${CONF_FILE} for API user '${API_USER}' (password redacted)."
