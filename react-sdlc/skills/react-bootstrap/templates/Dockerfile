# ─────────────────────────────────────────────────────────────────────────────
# Multi-stage Dockerfile — react-bootstrap template
#
# Generic two-stage build for a Vite-built SPA served by nginx, parameterized
# by a BASE_PATH build ARG (see react-bootstrap/SKILL.md's "BASE_PATH" section)
# and wired for the credential-proxy pattern described in that same file's
# "The security fix this profile exists to ship" section: no backend
# credential is ever inlined into the browser bundle. nginx injects it
# server-side on the /api/ proxy_pass, sourced from a Docker secret at
# container start (see docker-entrypoint.d/50-inject-api-auth.sh and
# docker-nginx.conf in this same templates/ directory).
#
# STOP CONDITIONS — see react-ship/SKILL.md. This Dockerfile is written
# against container/build behaviors that must be confirmed against a real
# build/run before relying on them in a pipeline. Each is marked at the exact
# line it depends on. react-ship refuses to run `docker build`/`docker run`
# against this Dockerfile until a human has confirmed all of them at least
# once for the base images actually chosen below.
# ─────────────────────────────────────────────────────────────────────────────

# ════════════════════════════════════════════════════════════
# Stage 1 — Build
# ════════════════════════════════════════════════════════════
# ASSUMPTION: pin an exact Node major/minor your project actually targets —
# "<node-major>" below is a placeholder. Verify the current Active LTS line
# (nodejs.org/en/about/previous-releases) before pinning; do not copy a number
# from an old project without checking.
FROM node:<node-major>-alpine AS builder

WORKDIR /app

# BASE_PATH controls both the Vite `base` used at build time and the nginx
# document-root subfolder the built assets are copied into (runner stage).
# Default is the domain root. Override at build time:
#   docker build --build-arg BASE_PATH=/some-app/ -t <image> .
ARG BASE_PATH=/

# ── Install dependencies ───────────────────────────────────
# Copy ONLY package files first so Docker's layer cache reuses node_modules
# when source changes but dependencies don't.
COPY package.json package-lock.json ./

RUN --mount=type=cache,target=/root/.npm \
    npm ci --prefer-offline

# ── Copy source and build ─────────────────────────────────
COPY . .

# ASSUMPTION: `npm run build -- --base=X` is assumed to forward `--base=X`
# through npm's script runner to the underlying `vite build` invocation as a
# CLI flag that overrides vite.config.ts's `base` setting. npm's documented
# `--` arg-forwarding behavior and Vite's documented `--base` CLI flag are
# each individually true, but confirm them TOGETHER against this project's
# actual vite.config.ts and package.json `"build"` script by running the
# command before relying on it in a pipeline (react-ship STOP CONDITION — see
# that skill's SKILL.md). If it does not forward correctly, fall back to a
# generated (not hand-mutated) vite.config.ts per environment instead of one
# parameterized Dockerfile.
RUN npm run build -- --base=${BASE_PATH}
# Vite output lands in /app/dist


# ════════════════════════════════════════════════════════════
# Stage 2 — Serve with nginx (unprivileged, runs as non-root)
# ════════════════════════════════════════════════════════════
# ASSUMPTION: pin an exact, currently-pullable tag for your chosen
# unprivileged nginx image (or equivalent) — "<current-tag>" below is a
# placeholder. Confirm with `docker pull <image>:<tag>` before relying on it;
# tags on minimal/rolling base images are periodically retired.
FROM nginxinc/nginx-unprivileged:<current-tag> AS runner

# ARG does NOT cross the FROM boundary — must be re-declared in this stage to
# be visible to the COPY --from=builder destination path below.
ARG BASE_PATH=/

# Custom nginx.conf: SPA fallback, cache headers, gzip, security headers, and
# the /api/ auth-proxy location added by this template (see docker-nginx.conf
# in this same templates/ directory).
COPY docker-nginx.conf /etc/nginx/nginx.conf

# Pre-create the include file the entrypoint script overwrites at container
# start (docker-entrypoint.d/50-inject-api-auth.sh). nginx's `include`
# directive fails config-test (and therefore fails to start) if the target
# file does not exist, so a placeholder must exist at image-build time, owned
# by the same user the entrypoint runs as so it can overwrite it.
RUN mkdir -p /etc/nginx/conf.d \
    && touch /etc/nginx/conf.d/api-auth.conf \
    && chown -R nginx:nginx /etc/nginx/conf.d

# ASSUMPTION (STOP CONDITION): the chown above is assumed sufficient for the
# nginx user (UID 101 by nginx-unprivileged's own convention) to write
# /etc/nginx/conf.d/api-auth.conf at container start. Confirm by actually
# running the entrypoint as that UID against this exact directory before
# relying on it.

# ASSUMPTION (STOP CONDITION): the chosen base image is assumed to execute
# every executable *.sh file under /docker-entrypoint.d/ on container start,
# the same as the standard nginx image's documented entrypoint behavior.
# Confirm against THIS image's actual docker-entrypoint.sh before relying on
# it — not every nginx-based image implements this convention.
COPY docker-entrypoint.d/50-inject-api-auth.sh /docker-entrypoint.d/50-inject-api-auth.sh

# COPY --from=builder with ARG in the DESTINATION path.
# ASSUMPTION (STOP CONDITION): Docker is assumed to expand ${BASE_PATH} inside
# a COPY *destination* path the same way it expands ARGs in a source path or a
# RUN command — this is documented Dockerfile behavior but a less commonly
# exercised case than ARG-in-source. Confirm by actually building this
# Dockerfile before relying on it. If it does NOT expand, fall back to a fixed
# destination with one Dockerfile variant per subpath instead of one
# parameterized Dockerfile.
COPY --chown=nginx:nginx --from=builder /app/dist /usr/share/nginx/html${BASE_PATH}

USER nginx

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
