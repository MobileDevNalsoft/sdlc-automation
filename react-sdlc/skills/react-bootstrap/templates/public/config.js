// public/config.js — react-bootstrap template
//
// Committed dev defaults for window.__ENV__. Loaded via a <script> tag in
// index.html BEFORE the app bundle, so app code can read
// `window.__ENV__.SOMETHING` synchronously at module-eval time if needed.
//
// NEVER put a credential in here. This file (and the window.__ENV__ pattern
// generally) is for values that are ALREADY safe for the browser to see —
// which base URL to call, a human-readable environment label, a build/version
// string, feature flags. Any backend credential is handled server-side by
// nginx's /api/ proxy_pass + injected auth header (see docker-nginx.conf +
// docker-entrypoint.d/50-inject-api-auth.sh in this same templates/
// directory) precisely BECAUSE window.__ENV__ does not solve that problem —
// a global on `window` is exactly as reachable from the browser's dev tools
// as a build-time-inlined literal is. Relocating a credential here would be a
// cosmetic fix, not a real one.
//
// Why this file exists instead of relying on import.meta.env everywhere:
// window.__ENV__ is normally overwritten by a container entrypoint at startup
// (e.g. this file gets regenerated from a template before nginx serves it),
// which lets one built image be reused across environments without a
// rebuild. That entrypoint step never runs under `vite dev` — so this
// committed file supplies the same shape with safe local defaults, meaning
// `npm run dev` behaves identically whether or not a container entrypoint has
// ever touched this file.
window.__ENV__ = {
  // Relative path — resolved by the dev server's own proxy in dev, and by
  // nginx's /api/ location in the built/containerized app. Never an absolute
  // production hostname here.
  API_BASE_URL: '/api',
  ENVIRONMENT: 'development',
  APP_VERSION: 'dev',
};
