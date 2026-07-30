// public/config.local.example.js — react-bootstrap template
//
// Copy this file to public/config.local.js (gitignored — add
// "public/config.local.js" to .gitignore) to override individual keys from
// config.js on your own machine without touching the committed defaults.
// index.html should load config.js first, then this file second with an
// `onerror` fallback so a missing config.local.js is silent, not a 404 in the
// console for every dev who hasn't created one:
//
//   <script src="/config.js"></script>
//   <script src="/config.local.js" onerror="this.remove()"></script>
//
// Only override what you actually need to change — this merges shallowly
// onto whatever config.js already set on window.__ENV__.
Object.assign(window.__ENV__, {
  // Example: point at a personal backend instance during local testing.
  // API_BASE_URL: '/api-personal',
});
