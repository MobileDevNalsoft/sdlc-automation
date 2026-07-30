---
name: react-bootstrap
description: Use when scaffolding a brand-new React + Vite + TypeScript project (greenfield) or bringing an existing React + Vite + TypeScript project up to a defensible baseline (adopt-in-place) — emits a version-pinned dependency set, eslint.config.js, tsconfig.json, npm scripts, a containerized deploy setup with a credential-proxy pattern, runtime config via a public/config.js window global, generalized state-management/routing/folder-architecture guidance, and a react-hook-form+zod form template. Use once per project/profile, before react-slice does any vertical-slice work.
---

# react-bootstrap

**Verb: scaffold.**

## Two profiles, one skill

Every template in this skill serves both profiles; the difference between them is dependency **versions** and how those versions get chosen, not file shape.

- **Greenfield** — no existing code to reconcile against. Pin the current stable major/minor of each dependency (see the version table below; verify at scaffold time — see "Keeping the version table honest").
- **Adopt-in-place** — bringing an existing repo up to this baseline. This is a *procedure*, not a table of one project's version numbers:
  1. Read the target repo's `package.json` to see what's actually installed today.
  2. For each dependency, match the existing **major** version unless it carries a known security floor (see below) — don't force an unrelated major-version cascade (e.g. a new router major that itself requires a newer framework major, a newer build-tool major, and a newer runtime, all at once) onto a repo that only asked for a lint config.
  3. Tighten `^`/`~` ranges to exact pins once you've confirmed the currently-resolved version installs cleanly.
  4. Raise a dependency's **floor** only where the installed range is below a version with a disclosed security advisory — check the advisory database for the exact package, not from memory.
  5. Record what you changed and why wherever this project already records dependency-upgrade decisions (changelog, PR description, ADR).

This procedure is the adopt-in-place "profile" — it produces different numbers on every project it runs against, which is the point. Don't let a later re-run of this skill quietly copy forward version numbers from a previous project's scaffold pass; re-derive them from the target repo and the current registry every time.

## Keeping the version table honest

Dependency versions age out quickly — a frozen table in a skill file goes stale the day it's written. Treat every number below as **verified via web research on 2026-07-30** and re-verify before trusting it on a new scaffold:

```
npm view <package> version          # latest published version
npm view <package> versions --json  # full history, for checking a specific line (e.g. 6.x vs 7.x)
npm view <package> peerDependencies  # what it actually requires
```

| Slot | Greenfield (verified 2026-07-30) | Adopt-in-place | Notes |
|---|---|---|---|
| react / react-dom | 19.2.8 | match installed major; tighten range | Verified via npm registry / react.dev. |
| vite | 8.1.3 | match installed major; raise only to close a disclosed CVE | Verified via vite.dev/releases. |
| typescript | 6.0.x line — **not** the newest 7.0.2 | same reasoning applies | See "Why not the newest TypeScript" below. |
| router | `react-router` (not `-dom`), current 7.x line, if the target's React major is 18; `react-router` 8.x only if React major is >=19 | branch on the *target repo's* installed React major | react-router 8 requires React >=19.2.7, Node >=22.22, and Vite 7+ (Framework Mode), and ships ESM-only — verified via its own changelog/migration docs. Don't install v8 against a React 18 project; that combination is unsupported, not merely untested. |
| server state | `@tanstack/react-query`, current 5.x | same | Ships very frequent patch releases (near-weekly at verification time) — pin whatever 5.x patch `npm view` returns at scaffold time rather than hand-copying a number from this file. |
| client state | `zustand`, current 5.x | same, unless the installed major is 4.x and nothing forces an upgrade | v5 is the current major as of this pass; verify the exact patch at scaffold time. |
| http client | native `fetch` **or** `axios` — see "HTTP client choice" below | keep whatever the target repo already uses | A choice point, not a version pin. |
| styling | Tailwind CSS v4.x (Oxide engine, CSS-first config) | match installed major; v4's config format is a real breaking change from v3, so don't force that rewrite onto a repo that's stable on v3 without a scoped migration task | v4 has been GA and the de facto default for new projects since 2025; current patch (4.3) verified via web search this pass. |
| lint | ESLint 10.x + `typescript-eslint` 8.65.0+ | see note | ESLint 9.x reaches end-of-life 2026-08-06 (verified via eslint.org's own release/migration posts) — start new projects on 10.x. `typescript-eslint` 8.65.0 is confirmed to support ESLint 10's flat-config-only world. |
| format | Prettier (current major) + `eslint-config-prettier` | same | Not wired into react-verify's gate — formatting isn't a defect class worth blocking a merge over. |
| test | Vitest current 4.x (4.1.10 verified) + `@testing-library/react` | same | A 5.0 beta exists (5.0.0-beta.6 at verification time) — don't pin a beta for anything that gates a merge. |
| forms | `react-hook-form` + `zod` (+ `@hookform/resolvers`) | same, once adopted | See `templates/forms/`. |

### Why not the newest TypeScript

TypeScript 7.0 shipped with its compiler rewritten onto a Go-based codebase for roughly a 10x speed-up, but it shipped **without** the stable programmatic compiler API that type-aware tooling depends on. As of this pass, `typescript-eslint`'s own peer-dependency range explicitly excludes it (requires TypeScript `<6.1.0`), because its type-aware rules are built directly against that API and the fix depends on TypeScript 7.1 shipping a new one — not on typescript-eslint's side. Some teams work around this by running TypeScript 7 for `tsc` itself while pinning a side-by-side TypeScript 6.0 install purely for ESLint's type-aware rules; that's a real option but adds a second compiler version to reason about. Until 7.1 ships and the ecosystem catches up, the pragmatic "best in market today" choice for a project that also wants working lint tooling is the TypeScript 6.0.x line, not the objectively-newest 7.0.2 — newest is not always best-in-market when the surrounding tool ecosystem hasn't caught up. Re-check this before a new scaffold; this gap is expected to close.

### HTTP client choice

Native `fetch` and `axios` both integrate fine with TanStack Query — the query/mutation layer doesn't care which one does the actual request. `fetch` costs zero bundle size and is sufficient for most REST/JSON needs (with a small wrapper for JSON parsing, error normalization, and base-URL handling). `axios` adds interceptors, more convenient error shapes, and wider legacy-environment support, at a real (if small) bundle cost. If the target repo already uses one of them, keep using that one — introducing a second HTTP client into an existing codebase costs more than either library's individual trade-offs are worth.

## Principles for what NOT to include (verify before reintroducing any of these)

These are classes of decision that go stale or backfire in ways worth naming, not a list of banned package names:

- **Config auto-sync scripts.** A script that regenerates part of your lint/build config by scanning the filesystem (e.g. a `readdirSync()`-driven config generator) can silently *remove* a gate command the next time it runs, with no diff a reviewer would notice as "a check disappeared." Prefer an explicit, hand-edited config file over a generated one for anything that gates a merge.
- **Glob-based import-boundary plugins, unverified.** Tools like `eslint-plugin-boundaries` or an `import/no-restricted-paths`-style rule are worth adopting (see "Folder architecture" below), but some of these plugins' glob-matching runs after the OS's own path normalization on Windows, which can silently turn a boundary rule into a no-op that reports zero violations regardless of real violations present. If you adopt one, prove it fires by deliberately breaking a boundary in a throwaway commit and confirming the rule catches it, on every OS your team actually develops on — don't trust it as a gate until you've watched it fail on a bad import.
- **Type-aware linting by default.** Full type-aware ESLint rules typically roughly double lint run time versus syntax-only rules, because they load the TypeScript program/checker. Worth it for specific high-value rules (e.g. `no-floating-promises`); not worth enabling wholesale as a default until you've measured the cost against your own codebase's size.
- **Blanket file-naming lint rules on an adopted codebase.** A rule like enforced kebab-case on every filename can produce hundreds of violations on day one of adopting it into an existing repo, for zero defect-catching value — it's a style preference, not a correctness gate. Apply naming conventions to new files going forward; don't retroactively fail an adoption pass over pre-existing filenames.
- **Chasing every framework rewrite immediately.** When a tool ships a rewritten config format or engine (a CSS-first config rewrite, a new bundler core, etc.), confirm there's a working, tested migration path for *your* project's actual usage before adopting it — "the docs say it's a drop-in" and "it's a drop-in for this project's specific plugin/config combination" are different claims.
- **Auditing for dead parallel implementations during bootstrap.** Before or during scaffolding, check for: a second, unused framework/runtime scaffold left over from an earlier prototype (e.g. an edge-runtime adapter whose imports are unused but still present in the module graph); build-tool plugins imported but never wired into the active config; `package.json` scripts that reference a deploy target nobody uses anymore. Flag these for a human decision (is that old target still in scope, or purely historical?) rather than deleting them unilaterally — that's a scope call, not a mechanical cleanup this skill should make on its own.

## Folder architecture: feature-based, with enforced import boundaries

Organize by feature (vertical slice), not by technical layer:

```
src/
├── app/                 # composition root: providers, router, top-level layout
├── features/
│   └── <feature>/
│       ├── api/         # DTO types, transformers, query/mutation hooks
│       ├── components/  # presentation components for this feature only
│       └── types/
├── shared/               # cross-cutting: design-system primitives, generic hooks,
│                         #   the HTTP client base class, common types
└── main.tsx
```

**Why this shape, not a technical-layer split** (`components/`, `hooks/`, `services/` at the top level): a feature-based tree keeps everything one change touches in one place. Concretely, that buys you:
- **Blast radius** — a change to how tags work stays inside `features/products/`; a reviewer doesn't have to reason about the whole app to review it.
- **Deletability** — removing a feature is deleting one directory, not hunting for its files scattered across `components/`, `hooks/`, and `services/`.
- **Parallel work** — two people working on two features rarely touch the same file, because there's no shared `components/` or `hooks/` grab-bag they're both editing.

**Enforce the boundary, don't just document it.** The rule: a feature may import from its own subtree and from `shared/`; a feature must never import another feature's internals directly (`features/products/*` reaching into `features/orders/api/*`). If two features need to share something, promote it to `shared/` — that's the whole mechanism, no per-feature exceptions. Encode this with an ESLint rule (`eslint-plugin-boundaries`, or an `import/no-restricted-paths`-equivalent) once you've verified it actually fires (see the caveat above) — until then, it's a code-review checklist item, not a silently-trusted gate.

`app/` sits above `features/` and does the composition: mounts the router, wraps the app in providers (query client, state store, theme), owns top-level layout. `app/` may import from any feature's public surface (typically each feature's `index.ts` barrel); features never import from `app/`.

## State management

**Split server state from client state — don't duplicate one into the other.**

- **Server state** (anything that lives in a database/API and can go stale — a product list, a customer record) belongs to a query/cache library (TanStack Query, SWR, RTK Query — pick one; this skill assumes TanStack Query per the version table above). It owns fetching, caching, background refetch, and invalidation. Never copy a server-fetched value into a client store "for convenience" — that's a second source of truth that will drift from the first.
- **Client state** (anything that's purely about the UI and has no server-side origin — a modal's open/closed flag, a multi-step form's current step, a sidebar's collapsed state) belongs to a lightweight client store (Zustand, or component-local `useState`/`useReducer` for state that doesn't need to be shared). Don't route ephemeral UI state through the query cache just because a query client is already in the tree.

**Store-slice organization.** Split a client store by concern, not into one monolithic global store: `useAuthStore`, `useUIStore`, `useThemeStore`, etc., each independently testable and independently persistable. A feature that needs client state generally owns its own slice inside `features/<feature>/` rather than adding fields to a shared store.

**Selector conventions.** Always subscribe to the narrowest slice a component needs:

```ts
// Bad — re-renders on ANY store change, and returns a fresh object every
// render, which defeats reference-equality checks even if you *did* narrow it:
const { user, theme } = useAppStore((s) => ({ user: s.user, theme: s.theme }));

// Good — each hook call subscribes to exactly the field it needs:
const user = useAppStore((s) => s.user);
const theme = useAppStore((s) => s.theme);
```

A selector that returns a freshly-constructed object or array literal (`(s) => ({ ...s.foo })`, `(s) => s.items.filter(...)`) produces a new reference on every call, which defeats the store's reference-equality check and causes a re-render on every state change regardless of whether the selected data actually changed — a common source of "why does this component re-render on every keystroke somewhere else in the app" bugs. If you need a derived/computed value, memoize it (a stable selector factory, or a library's built-in shallow-equality helper) rather than recomputing a new literal inline.

**Persistence/hydration.** Persist only client state that genuinely belongs on the client (user preferences, draft form content, UI layout choices) via the store library's persistence middleware (e.g. Zustand's `persist`). Never persist server state into `localStorage` yourself — that's the query library's job (TanStack Query has its own persister mechanism if offline caching is a real requirement) and hand-rolling it reintroduces the stale-cache problem the query library exists to solve.

## Routing

- **Route-tree organization.** Define the route table in one place (`app/routes.tsx` or equivalent), composed from each feature's own route fragment where the feature is large enough to warrant one. Don't scatter `<Route>` declarations across arbitrary components.
- **Code-splitting at route boundaries.** Lazy-load each route's component (`React.lazy` + `Suspense`, or the router's own built-in lazy-loading if it has one) so a user's initial bundle doesn't include every route in the app. Route boundaries are the natural code-split points — they're already where a full page transition happens, so a loading state is expected there.
- **Route guards / protected routes.** Implement auth-gated routes as a wrapper component or a router-level loader check that redirects before the protected component ever mounts, not as a `useEffect` inside the protected component that redirects *after* it renders — the latter causes a visible flash of protected content before the redirect fires.
- **Loader/data-fetching boundaries.** If your router supports data loaders (route-level data fetching that runs before the route renders), use them for data the route can't render without; use component-level TanStack Query hooks for everything else (data that can render progressively, or that's fetched in response to user interaction after the route is already showing). Don't force every fetch through a loader just because the capability exists.
- **Error boundaries per route.** Wrap each route (or a logical group of routes) in its own error boundary so a thrown error in one route's tree doesn't blank the entire app — the router's own nested-route error-boundary mechanism, if it has one, is usually the right place for this rather than a single top-level boundary.

## Templates in this skill

| File | Purpose |
|---|---|
| `templates/eslint.config.js` | Flat config, ESLint 10-compatible. Two load-bearing trap comments inline (see below). |
| `templates/tsconfig.json` | Baseline strict config; the strict-flag ladder lives here as commented-out entries owned by react-verify. |
| `templates/package.scripts.snippet.json` | Adds `dev`/`build`/`preview`/`typecheck`/`lint` scripts. |
| `templates/Dockerfile` | Two-stage build with a `BASE_PATH` ARG and the credential-proxy pattern wired in. Every behavior it depends on but that hasn't been confirmed against a real container is marked inline with an `ASSUMPTION:` tied to a numbered react-ship STOP CONDITION. |
| `templates/docker-nginx.conf` | SPA fallback, cache headers, gzip, security headers, plus a generic `/api/` proxy location that injects an auth header server-side. |
| `templates/docker-entrypoint.d/50-inject-api-auth.sh` | Reads an API credential from a Docker secret (or env var fallback) at container start and writes the header nginx includes. |
| `templates/public/config.js` + `templates/public/config.local.example.js` | Runtime `window.__ENV__` pattern with committed dev defaults and a gitignored local override. |
| `templates/forms/schema.ts`, `useEntityForm.ts`, `EntityForm.tsx` | react-hook-form + zod, worked example against a generic `<Entity>` (a "Customer" contact form, standing in for any entity). |
| `templates/router-migration-example.tsx` | The mechanical import-source change the router-version branching above requires when it applies. |
| `templates/project-tree.md` | Full tree for both profiles; vendors bulletproof-react's folder-layout **concept only** (see its header for provenance). |

## The two ESLint traps (encoded as literal comments in the template — read them there, not just here)

1. `@eslint/js`'s `latest` dist-tag tracks whatever ESLint major is current — if this package is ever bumped via a bare `^` range or an unrelated `npm install @eslint/js@latest`, it can jump a major and change rule defaults or fail to load. Hand-pin the exact patch you tested against.
2. `@tanstack/eslint-plugin-query`'s flat-config export (`configs['flat/recommended']`) is an **array**, not a single config object — it must be spread with `...`, not nested as one entry, or rules silently drop out with no hard error.

## The security fix this profile exists to ship: never send a credential to the browser

The class of problem: a Vite (or any bundler's) `import.meta.env.VITE_*`-style variable is **inlined at build time** into the shipped JS bundle. Any credential read this way — a backend API's basic-auth password, a third-party service key — becomes a plaintext string in a file served to every browser that loads the app, readable via view-source or devtools by anyone with the deployed URL. This is true regardless of variable-naming convention; prefixing it differently or reading it through a different mechanism doesn't change where the bytes end up.

**The fix is NOT a `window.__ENV__` runtime global.** That only relocates the same browser-reachable value to a different property on `window` — still readable from dev tools, still shipped to every browser. Moving a secret from a build-time-inlined constant to a runtime-injected global is a cosmetic change, not a security fix, because the browser is still the thing holding the secret.

**The actual fix**: terminate authentication at a reverse proxy the browser never bypasses. Implemented by `templates/Dockerfile` + `templates/docker-nginx.conf` + `templates/docker-entrypoint.d/50-inject-api-auth.sh`: nginx's `/api/` location adds the credential header itself via `proxy_set_header`, sourced from a Docker secret (or, as a documented-weaker fallback, an environment variable) read once at container start. The browser only ever talks to the container's own origin at a relative path (`/api/...`) and never sees the credential in any form — not in a bundle, not on `window`, not in a response header echoed back to it. Any backend credential currently reachable via `import.meta.env` (or the equivalent in another bundler) should be deleted from the codebase entirely once this is live — from `.env`, from any build-variant script that injects it, and from the API client config that reads it — not left in place "just in case."

This pattern generalizes past "basic auth to one backend": the same shape applies to an API key, a bearer token for a service account, or any other credential a browser-run SPA would otherwise need to hold to call a backend directly.

## `BASE_PATH`: parameterized subpath deployment

If the app is served from a subpath (`https://example.com/some-app/` rather than the domain root), don't hardcode that subpath into `vite.config.ts`'s `base` and then mutate the source file per environment with a find-and-replace script before each build — that's a source-mutating build, and a script that edits a tracked file and reverts it afterward is one interrupted build away from committing the mutated version by accident. Instead, parameterize it: a `BASE_PATH` Docker build ARG (default `/`) passed through to `vite build --base=${BASE_PATH}`, with the built assets copied into the matching subfolder of the image's document root (see `templates/Dockerfile`). One Dockerfile, one build command, any subpath — set at build invocation time, never edited into source.

## Runtime config: `public/config.js`

Committed file with dev defaults (`templates/public/config.js`), loaded via a `<script>` tag before the app bundle, plus a gitignored `public/config.local.js` (template at `templates/public/config.local.example.js`) for a developer's personal overrides. This exists because `window.__ENV__` is normally overwritten by a container entrypoint at startup (regenerating this file from a template at container start), which lets one built image be reused across environments without a rebuild — and that entrypoint never runs under `vite dev`, so the committed defaults are what makes local dev behave the same with or without a container ever touching the file. This pattern is unrelated to, and does not replace, the credential-proxy fix above — no credential belongs in this file, ever; only values that are already safe for the browser to see (a base URL, an environment label, a version string, feature flags).

## Forms: react-hook-form + zod

`templates/forms/schema.ts` defines a zod schema for a generic entity (a "Customer" contact form — name, email, company, notes — standing in for whatever entity the real feature needs). `templates/forms/useEntityForm.ts` wires it through `@hookform/resolvers/zod`. `templates/forms/EntityForm.tsx` is the component. react-slice's job is to rename `useEntityForm`/`EntityForm`/the schema to the slice's real feature name and fields — this skill only ships the wiring pattern, not a feature-specific instance.

## Router pin — branches on the target's React major, not on profile name

If the target's React major is 18: pin the current `react-router` 7.x line, migrating any `from 'react-router-dom'` import to `from 'react-router'` (the API surface is unchanged as of the v7 line — see `templates/router-migration-example.tsx` for the mechanical diff). If the target's React major is >=19: pin `react-router` 8.x directly. Never install react-router 8 against a React 18 project — its own peer requirements (React >=19.2.7, Node >=22.22, Vite 7+, ESM-only) make that an unsupported combination, not just an untested one.

## Cross-references

- `react-sdlc:react-slice` does the vertical-slice work (typed DTO -> transformer -> query/mutation hook -> component) on top of whatever this skill scaffolds. Don't re-derive slice conventions here.
- `react-sdlc:react-verify` owns the gate commands and the strict-flag ladder referenced by `templates/tsconfig.json`'s commented-out block.
- `react-sdlc:react-ship` owns the numbered STOP CONDITIONS this skill's Dockerfile/nginx templates are written against — this skill documents the assumptions at the exact line each one is used; react-ship is where they actually block a deploy until a human confirms them.
- `sdlc-core:walkthrough` is where the human-facing summary of a bootstrap pass gets written — this skill does not write that document itself.
