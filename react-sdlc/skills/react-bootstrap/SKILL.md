---
name: react-bootstrap
description: Use when scaffolding a brand-new React + Vite + TypeScript project (greenfield) or bringing an existing one up to a defensible baseline (adopt-in-place) — emits a version-pinned dependency set proven to install and build together, plus a vendored src/ structure (composition root, axios client with single-flight 401 refresh and idempotent-only retry, an ApiError union, react-router 8 with a pre-mount auth guard, typed runtime config, storage behind interfaces, Zustand slices, Tailwind v4 design tokens, shared UI primitives, i18n, Vitest setup), an ESLint 10 flat config whose feature-boundary rule is PROVEN to fire, tsconfig, and a containerized deploy with a credential-proxy pattern. Use once per project/profile, before react-slice does any vertical-slice work.
---

# react-bootstrap

**Verb: scaffold.**

## Before anything else: what "verified" means for this skill

This matters because the sibling `flutter-sdlc:flutter-bootstrap` is explicit
that its `templates/` tree was **never compiled as a set**. This skill is in a
better position and says so precisely, because overclaiming here would be the
exact dishonesty that preamble exists to prevent.

**Pass 1 (2026-07-30).** Research and prose only. It produced correct guidance
about state management, routing and folder architecture, and shipped config +
Docker templates — but **no application code**, and the guidance was never run.

**Pass 2 (2026-07-31, this revision).** A real Vite project was scaffolded in a
scratch directory from these exact templates and driven end to end on **Node
v24.14.1 / npm 11.11.0, Windows 11**. Three classes of claim came out of it:

1. **Verified by execution.** The full dependency set installs together (389
   packages, zero peer conflicts). `npx tsc --noEmit` exits 0. `npx eslint .`
   exits 0. `npx vite build` exits 0 and splits each route into its own chunk.
   `npx vitest run` passes **8/8 across 2 files**. This covers the scaffold,
   **the `react-slice` templates** (dropped in as a real feature and compiled
   and linted clean), and **the `forms/` templates**. Six *real* failures were
   hit and fixed along the way — recorded below as numbered traps, not smoothed
   away.
2. **Verified by fetching a live source.** Every version number and peer range
   in the table below came from the npm registry on 2026-07-31, not memory.
3. **NOT verified.** The Docker/nginx credential-proxy templates carry their
   own `ASSUMPTION:` markers and are gated by `react-ship`'s STOP CONDITIONS —
   **no container was built or run in this pass.** i18n is wired and compiles,
   but no second locale was added, so "adding a locale needs no code change" is
   a design property, not a tested one. No browser ever rendered the app: the
   build succeeds and components are unit-tested, but nothing here is a claim
   about how it looks or behaves on a real screen.

**The `forms/` templates did not compile before this pass, and that is worth
stating plainly rather than quietly fixing.** Shipped in pass 1 and never
exercised, they failed `tsc` with a genuine zod-4 input/output mismatch (see
trap 7). Anyone who had copied them would have hit it immediately. They are now
compiled, linted, and covered by three runtime tests asserting that validation
actually blocks submit, rejects a malformed email, trims input, and resolves
defaults.

**The gap this pass closed.** Pass 1 documented state management, routing and
folder architecture in prose while shipping no code for any of them, and
`react-slice`'s `*.api.ts` template imported
`shared/api/base-api.service` — **a file nothing emitted.** A project
scaffolded by this skill and then sliced did not compile. That file now exists
and is proven.

## The toolchain this revision was verified against

| Component | Version | How known |
|---|---|---|
| Node | **v24.14.1** | `node --version`, 2026-07-31 |
| npm | **11.11.0** | `npm --version`, 2026-07-31 |
| OS | Windows 11 | the boundary-rule proof below is Windows-specific evidence |

**Node floor for the scaffold: `>=22.22.0`.** Not a preference —
`react-router@8.3.0` declares `engines.node >=22.22.0` (fetched 2026-07-31).
Put it in `package.json` `engines` so a teammate on an older Node gets a clear
error rather than a runtime failure.

## Procedure

The executable step list. Every section below this one is reference material
for a step here — if you are following the skill, follow these.

1. **Greenfield:** `npm create vite@latest <app> -- --template react-ts`.
   **Adopt-in-place:** skip to step 2 against the existing repo.
2. **Install the dependency set** from `templates/package.deps.verified.json`
   — greenfield takes the pins as-is; adopt-in-place follows the procedure in
   "Two profiles" instead of copying those numbers.
   **The `overrides` block is not optional: without it `npm install` fails**
   on ESLint 10 (trap 1).
3. **Copy the config files** — `tsconfig.json`, `eslint.config.js`,
   `vite.config.ts`, `vitest.setup.ts`, `index.html`, and merge
   `package.scripts.snippet.json` (including its `engines` floor).
4. **Overlay `templates/` onto `src/`.** Each file's header names its
   destination. `app/`, `shared/`, `styles/` arrive populated; `features/`
   starts empty and is filled one slice at a time by `react-slice`.
5. **Copy `templates/public/config.js`** and add `public/config.local.js` to
   `.gitignore`.
6. **Wire the real refresh endpoint** in `main.tsx` — the shipped
   `wireAuthToHttpClient(() => Promise.resolve(null))` logs the user out on a
   401 instead of recovering. It is honest, not finished.
7. **Prove the boundary rule fires** — the two-case check in trap 2. A boundary
   rule you have not watched fail is not a gate.
8. **Run the four gates**: `tsc --noEmit`, `eslint .`, `vite build`,
   `vitest run`. All four pass on the shipped templates; a failure here is
   something the scaffold introduced into *your* repo, not a template defect.
9. **Establish the 3-tier agent context** — `docs-architect:docs-context`,
   `-Mode Ensure`. Deliberately after step 8: the graphs need code to graph.
   Then `docs-architect:docs-onboarding` for `CODEBASE_ONBOARDING.md`,
   `docs/architecture/react.md`, and the `llmwiki/` files. See "First run"
   below.
10. **Deploy templates** (`Dockerfile`, `docker-nginx.conf`,
    `docker-entrypoint.d/`) — only when a container deploy is actually in
    scope. These remain **container-untested**; `react-ship`'s STOP CONDITIONS
    gate them.

## Two profiles, one skill

- **Greenfield** — pin the exact set in `templates/package.deps.verified.json`.
  That file is a snapshot of what was actually installed and proven together;
  re-verify with `npm view <pkg> version` before trusting it on a new scaffold.
- **Adopt-in-place** — a *procedure*, not a table:
  1. Read the target repo's `package.json` for what is installed today.
  2. Match each dependency's existing **major** unless it carries a security
     floor — don't force an unrelated major cascade onto a repo that asked for
     a lint config.
  3. Tighten `^`/`~` to exact pins once the resolved version installs cleanly.
  4. Raise a floor only where the installed range sits below a disclosed
     advisory — check the advisory database for that exact package.
  5. Record what changed and why wherever this project already records
     dependency decisions.

Don't let a later re-run copy version numbers forward from a previous
project's scaffold. Re-derive them every time.

## The seven traps, every one hit for real in this pass

These are not hypotheticals. Each one was an actual failure or an actual
silent no-op, with the reproduction recorded.

### Trap 1 — `eslint-plugin-jsx-a11y` does not support ESLint 10, and `npm install` fails

Reproduced verbatim:

```
npm error peer eslint@"^3 || ^4 || ^5 || ^6 || ^7 || ^8 || ^9"
npm error   from eslint-plugin-jsx-a11y@6.10.2
```

Its latest release is **6.10.2, published 2024-10-26** — 21 months stale, and
the full version list and dist-tags (checked 2026-07-31) contain **no release
and no prerelease** supporting ESLint 10.

**This made pass 1 internally contradictory:** its `eslint.config.js` imported
jsx-a11y while its SKILL.md said to start new projects on ESLint 10.x.
Following both instructions produced a project that could not install.

The fix is the `overrides` block in `package.deps.verified.json`. **And the
override was proven to actually work, not merely to silence npm:** a fixture
containing an `<img>` with no `alt` and a click handler on a `<div>` produced
three jsx-a11y errors under ESLint 10.

Staying on ESLint 9 is not the escape hatch — **it reaches end-of-life
2026-08-06**, which is six days after this pass.

### Trap 2 — the feature-boundary rule silently reports zero violations (and pass 1's diagnosis was wrong)

Pass 1 declined to enable a boundary rule, warning that such plugins "have been
observed to silently no-op on Windows" due to path normalization. **The caution
was right; the cause was wrong, and the wrong cause would have sent someone
hunting an OS bug that isn't there.**

What actually happens: without a TypeScript-aware import resolver,
`eslint-plugin-boundaries` falls back to the Node resolver, which resolves
`.js`/`.json` but **not `.ts`/`.tsx`**. Every import then classifies as an
*unknown element*, no policy matches, and the rule reports clean. **This
happens on every OS, not just Windows.**

Diagnosed by elimination rather than assumed:

| Probe | Result | Conclusion |
|---|---|---|
| Deliberate `features/products` → `features/auth` import, alias form | exit 0 | rule not firing |
| Same, rewritten as a relative import | exit 0 | **not** an alias problem |
| `boundaries/no-unknown-files` | silent | the *importing file* IS classified |
| `boundaries/no-unknown` | **error** | the *import target* is unknown → resolver |

The fix is one settings block, and it is why `eslint-import-resolver-typescript`
is a required devDependency:

```js
'import/resolver': {
  typescript: { alwaysTryTypes: true, project: './tsconfig.json' },
},
```

**Proof it now works, both directions:**

- `features/products` importing `features/auth` → **exit 1**,
  `There is no policy allowing dependencies from elements of type "feature" and
  captured values: featureName="products" to elements of type "feature" and
  captured values: featureName="auth"`.
- A same-feature import → **exit 0**.

**Re-run that two-case check whenever you touch the resolver, the aliases, or
the elements patterns.** A boundary rule you have not watched fail is not a
gate.

### Trap 3 — `captured` vs `capture`: a misspelled selector key silently widens the rule

While fixing trap 2, the rule fired on some violations but **not** on
cross-feature imports. Cause: the selector key is **`captured`**, not
`capture`. An unrecognized key is **silently ignored rather than rejected**, so
the "same feature only" constraint simply vanished while the rule kept running
and kept reporting other violations — it looked perfectly healthy.

```js
// WRONG — silently allows EVERY cross-feature import
captured: { featureName: '{{from.featureName}}' }   // ...if spelled `capture:`
// RIGHT
captured: { featureName: '{{from.captured.featureName}}' }
```

This is why the two-case check in trap 2 is mandatory: a config that is 95%
correct produces a rule that is 0% effective, with no error anywhere.

### Trap 4 — eslint-plugin-boundaries v7 renamed nearly everything

v7 (7.1.0, published 2026-07-20) renamed the rule and its options. The legacy
shape still loads and only emits deprecation warnings, so **a config can look
fine and be entirely legacy** — which is what most tutorials and most generated
configs will hand you.

| v5/v6 | v7 |
|---|---|
| `boundaries/element-types` | `boundaries/dependencies` |
| `boundaries/no-unknown` | `boundaries/no-unknown-dependencies` |
| `rules: [...]` | `policies: [...]` |
| array selectors `['feature', {...}]` | object selectors `{ element: { type: 'feature' } }` |
| `${from.x}` | `{{from.x}}` |

### Trap 5 — TypeScript 6.0 deprecates `baseUrl`, and it is a hard error

```
tsconfig.json(20,5): error TS5101: Option 'baseUrl' is deprecated and will
stop functioning in TypeScript 7.0.
```

`paths` resolves relative to the tsconfig without it. The template omits
`baseUrl` entirely — do not add it back to "fix" an alias.

### Trap 6 — `erasableSyntaxOnly` bans parameter properties

```
src/shared/api/base-api.service.ts(30,25): error TS1294: This syntax is not
allowed when 'erasableSyntaxOnly' is enabled.
```

`constructor(private readonly basePath: string)` emits runtime code, so it is
illegal under the flag. Declare the field longhand. The flag is worth keeping —
it guarantees the TS is type-strippable, which is what Vite's esbuild transform
and Node's native TS support both assume. Enums and namespaces are out for the
same reason.

### Trap 7 — zod `.default()` splits the input type from the output type, and breaks react-hook-form

The `forms/` templates shipped in pass 1 and were never compiled. They fail:

```
Type 'Resolver<{ ...subscribed?: boolean | undefined }, any, { ...subscribed: boolean }>'
  is not assignable to type 'Resolver<{ ...subscribed: boolean }, ...>'.
    Type 'undefined' is not assignable to type 'boolean'.
```

**Cause.** `z.boolean().default(true)` makes the field *optional on the way in*
and *guaranteed on the way out*. A single `z.infer` alias describes only the
output, so `useForm<EntityFormValues>` promises the resolver an input type it
does not accept. Any `.default()`, `.optional()`, `.catch()` or transform does
this — it is not specific to booleans.

**Fix.** Export both types and use react-hook-form's three generics, which
exist for precisely this case:

```ts
export type EntityFormInput  = z.input<typeof schema>;   // what the form holds
export type EntityFormValues = z.output<typeof schema>;  // what submit hands you

useForm<EntityFormInput, unknown, EntityFormValues>({ resolver: zodResolver(schema) })
```

`handleSubmit` then hands the callback the **output** type. Verified against
react-hook-form 7.83.0 + zod 4.4.3 + @hookform/resolvers 5.5.7.

Two related zod-4 notes found while fixing this: `z.string().email()` is
deprecated in favour of the top-level `z.email()` (the old form still
compiles), and validating an email **before** trimming rejects addresses that
arrive from autofill or paste with a trailing space — the template pipes a
trimmed string into `z.email()` for that reason.

## Why TypeScript 6.0.3 and not 7.0.2

TypeScript 7.0 rewrote the compiler onto Go for roughly a 10x speed-up, but
shipped **without** the stable programmatic compiler API that type-aware
tooling depends on. Two independent packages exclude it, both fetched
2026-07-31:

- `typescript-eslint@8.65.0` → `typescript: ">=4.8.4 <6.1.0"`
- `@tanstack/eslint-plugin-query@5.101.4` → `typescript: "^5.4.0 || ^6.0.0"`

Two independent confirmations, not one package lagging. Some teams run TS 7 for
`tsc` and a side-by-side TS 6 purely for ESLint; that works but adds a second
compiler to reason about. **Newest is not best-in-market when the tooling
around it hasn't caught up.** Re-check before a new scaffold — this gap is
expected to close with 7.1.

## Architecture: feature-sliced, with the boundary MACHINE-ENFORCED

```
src/
  main.tsx                     Single entrypoint. React needs only ONE (unlike
                               flutter's three) because the flavor arrives at
                               RUNTIME via window.__ENV__, not at build time.

  app/                         <-- composition root. May import anything.
    App.tsx                    Providers wrapped around the router. Nothing else.
    AppLayout.tsx              Persistent shell: skip link, nav, theme class.
    providers.tsx              ErrorBoundary > QueryClient > I18n > Suspense,
                               in that order, each outside the next for a reason.
    query-client.ts            Cache policy + THE COMPOUNDING-RETRY FIX.
    router/
      router.tsx               The ONE aggregator importing every feature.
      RequireAuth.tsx          Guard that redirects BEFORE mount.
      RouteErrorBoundary.tsx   Per-route, so one failure doesn't blank the app.

  shared/                      <-- bottom layer. May NOT import app/ or features/.
    api/
      http-client.ts           The one axios instance + ORDERED interceptors.
      auth-interceptor.ts      Single-flight 401 refresh. Tested, 5 cases.
      retry-interceptor.ts     Idempotent methods ONLY.
      api-error.ts             AppError union + ApiError carrier + mapper.
      base-api.service.ts      What react-slice extends. (Was missing entirely.)
    config/env.ts              Typed runtime config, parsed once, fails loudly.
    navigation/routes.ts       Path constants. IN shared/, NOT app/ — see below.
    storage/
      key-value-store.ts       interface
      local-storage-store.ts   the one production impl, best-effort by design
      memory-store.ts          test double
      token-store.ts           memory-first, with the honest XSS ranking
      storage-keys.ts          every key string, one file
    store/
      auth-store.ts            session status + the AuthTokenPort wiring
      ui-store.ts              theme/sidebar, persisted
    ui/
      cn.ts, Button.tsx, Spinner.tsx, ErrorView.tsx
    i18n/
      i18n.ts, i18next.d.ts, locales/en.json

  styles/tokens.css            THE only file that defines a raw color.

  features/<feature>/          <-- written by react-slice, one at a time
    api/        {*.api.ts, *.queries.ts, *.transformers.ts}
    components/
    types/      {*-dto.types.ts}
```

**Why feature folders, concretely** — blast radius (a change stays in one
directory), deletability (removing a feature is deleting a directory), and
parallel work (two people rarely touch the same file, because there is no
shared `components/` grab-bag).

### `routes.ts` lives in `shared/`, and the boundary rule is why

It was originally placed in `app/router/routes.ts`. **The boundary rule
immediately caught it** as a real defect:

```
error There is no policy allowing dependencies from elements of type "feature"
and captured values: featureName="errors" to elements of type "app"
```

A feature linking anywhere needs the path constants, so putting them in `app/`
forces every feature to import the layer above it. Moving them to
`shared/navigation/routes.ts` matches flutter-bootstrap, which puts `AppRoutes`
in `core/` for exactly the same reason, and preserves the rule that makes the
whole boundary enforceable:

> **Cross-feature navigation carries no import.** Feature A navigates to
> feature B with a **string from `shared/`**, never a symbol from feature B.

Without that, every navigation would be a boundary violation and the rule would
have to be abandoned or exempted into meaninglessness.

## State management: server state and client state are different things

- **Server state** (anything with a database/API origin that can go stale)
  belongs to TanStack Query. It owns fetching, caching, background refetch and
  invalidation. **Never copy a server-fetched value into a client store "for
  convenience"** — that is a second source of truth that will drift.
- **Client state** (a modal flag, a wizard step, a sidebar toggle) belongs to
  Zustand, or to `useState` when it doesn't need sharing. **Don't route
  ephemeral UI state through the query cache** just because a client is in the
  tree.

**Slices, not one global store.** `auth-store.ts` and `ui-store.ts` are
separate so a theme change doesn't notify auth subscribers, and each is
independently testable and persistable.

**Selectors must be narrow.** A selector returning a fresh object or array
literal allocates a new reference on every call, defeats the reference-equality
check, and re-renders on every unrelated state change:

```ts
// Bad — new object every call; re-renders on ANY store change
const { user, theme } = useStore((s) => ({ user: s.user, theme: s.theme }));
// Good — one field per hook
const user = useAuthUser();
```

Every store in `templates/shared/store/` exports per-field selector hooks so
call sites get this by default instead of by discipline.

**The access token is deliberately not in store state.** It lives in a
`TokenStore` closure, so no `persist` middleware or devtools panel can
serialize it to disk by accident. That is structural, not a rule to remember.

**Persistence:** persist only genuine client state, via the store's own
middleware, with `partialize` so actions are never serialized. Never
hand-persist server state — that reintroduces the stale-cache problem the query
library exists to solve.

## The API layer

```
component / hook        never sees an AxiosError, ever
  -> *.queries.ts       TanStack Query, { signal } threaded through
    -> *.api.ts         extends BaseApiService
      -> BaseApiService maps every failure to ApiError, then throws
        -> httpClient   ONE axios instance
          -> auth-interceptor   (1) stamp token, single-flight 401 refresh
          -> retry-interceptor  (2) idempotent methods only
```

**Interceptor order is load-bearing.** Axios runs response interceptors in
registration order. Auth is installed first, so a 401 is resolved by a refresh
before retry sees it — and 401 is not in retry's status table, so the two never
contend. Swapping the two lines produces a client that retries an expired-token
request three times before refreshing it once.

**Single-flight refresh is the crown jewel, and it is tested.** Without it, a
page firing six queries on mount against an expired token produces six
concurrent refresh calls; on a backend that rotates refresh tokens, five are
replaying a consumed token, so five fail and the user is logged out by a race
rather than by an auth problem. `auth-interceptor.test.ts` asserts exactly this:
three concurrent 401s produce **one** refresh call and three successful
retries. It also covers the no-infinite-loop case, a throwing refresh
endpoint, and the "don't refresh on a 500" case. **5/5 passing.**

**Retry is idempotent-only, and that is a safety rule.** A POST that timed out
client-side may have committed server-side; replaying it double-charges the
card. GET/HEAD/OPTIONS by default. PUT/DELETE are idempotent *per RFC 9110* but
only if the server implements them that way, so they are opt-in behind a flag —
a DELETE that decrements a counter is a real thing that exists.

**The compounding-retry trap.** axios retries transport failures up to 3 times.
TanStack Query's own default is *also* 3. Left at defaults these multiply — one
failing GET becomes up to **nine** requests, and a flaky endpoint becomes a
self-inflicted load test. `query-client.ts` owns transport retry at exactly one
layer and never retries an error that cannot succeed on a second attempt (404,
403, 422). Mutations are `retry: false`.

**One error type above the client.** `AppError` is a discriminated union
(`network | timeout | canceled | unauthorized | forbidden | notFound |
conflict | validation | rateLimited | server | unknown`); `ApiError extends
Error` carries it on `.detail`. Throwing a bare union object would lose stack
traces and break `instanceof Error` in error boundaries and loggers; a plain
`Error` with only a message would lose the exhaustive `switch`. Carrying the
union on a real Error subclass keeps both. **If a `.tsx` file imports from
`axios`, the mapping is missing — not the component taking a shortcut.**

## Routing

- **One route table**, in `app/router/router.tsx`, composed from features.
- **Every route is lazy.** Verified in the build output: `ProductsPage`,
  `LoginPage`, `DashboardPage` and `NotFoundPage` each land in their own chunk.
- **Guards redirect before mount.** `RequireAuth` returns `<Navigate/>` during
  render. The common `useEffect` version runs *after* the first render, so the
  user sees a frame of protected content — real names, real numbers — before
  the redirect. Screenshots capture it.
- **A third auth state is required.** `status` is `unknown | authenticated |
  anonymous`. Treating `unknown` as anonymous bounces an authenticated user to
  `/login` on every refresh, because a cold reload hasn't restored the session
  yet.
- **Error boundaries per route**, not one at the top. A single top-level
  boundary means any thrown error blanks the entire app, nav and all, and the
  only recovery is a full reload.

**Router pin branches on the target's React major.** React 18 → `react-router`
7.x (migrate `from 'react-router-dom'` to `from 'react-router'`; see
`templates/router-migration-example.tsx`). React >=19 → `react-router` 8.x.
Never install v8 against React 18: `react-router@8.3.0` declares peers
`react >=19.2.7`, `react-dom >=19.2.7`, and `engines.node >=22.22.0` (fetched
2026-07-31) — that combination is unsupported, not merely untested.

## Storage, and the honest limit of "secure" on the web

**The browser has no Keychain.** flutter_secure_storage maps to
Keystore/Keychain on device; there is no web equivalent. Anything reachable
from JavaScript is reachable from injected JavaScript. `token-store.ts` ranks
the options in its own header rather than pretending otherwise:

1. **Best** — refresh token in an `httpOnly; Secure; SameSite` cookie the JS
   never touches, access token **in memory only**. This is the default. An XSS
   can still act as the user while it runs, but cannot read the refresh token
   or persist access past unload.
2. **Weaker** — access token in `sessionStorage`: survives reload, readable by
   any injected script, gone when the tab closes.
3. **Weakest** — anything in `localStorage`: readable by any injected script
   and persists indefinitely, so one XSS is a durable account compromise.

`createPersistentTokenStore` implements (2)/(3) and exists because some
backends genuinely cannot issue cookies. It is **labelled, not hidden**, so
choosing it is a decision someone made rather than drifted into.

`local-storage-store.ts` swallows and reports every failure rather than
throwing, because all three realistic failure modes are environmental: Safari
Private Browsing historically throws on the first `setItem`; blocked site data
makes `localStorage` throw on property *access*; storage can be full from
another app on the same origin. A crashed app is worse than an unsaved sidebar
preference — so **nothing that must not be lost may live there.**

## Design tokens

`styles/tokens.css` is the only file allowed to define a raw color — the direct
parallel of flutter's `app_colors.dart`. Tailwind v4 is CSS-first, so `@theme`
replaces v3's `tailwind.config.js` entirely and each token becomes a real
utility (`--color-surface` → `bg-surface`). Colors are oklch: perceptually
uniform, so a lightness ramp reads evenly rather than bunching in the blues.

**Semantic tokens are what features use.** The brand ramp exists so the
semantic layer can be derived from it; a feature writing `bg-brand-600`
directly, or worse `bg-[#1e293b]`, is the same defect as a Flutter feature
writing a raw `Color` literal. Dark mode re-points **only** the semantic
tokens, which is exactly why that rule matters.

Dark mode is class-based (`.dark` on `<html>`) rather than
`prefers-color-scheme` alone, because otherwise "system" would be the only
option a user could have.

## Testing

- **`happy-dom`, not `jsdom`, is the default environment** — and this is a
  verified constraint, not taste. `jsdom@30.0.1` declares
  `engines.node ^22.22.2 || ^24.15.0 || >=26.0.0`, and Node v24.14.1 produced a
  real `EBADENGINE` warning on every install. happy-dom needs only `>=20` and
  is faster. If you want jsdom, raise your Node floor deliberately.
- `msw` is pinned for feature-level tests. Interceptor unit tests deliberately
  use **no mocking library at all** — axios lets you replace its adapter, so
  the real interceptor chain runs and only the network is faked. That avoids
  `axios-mock-adapter`, whose latest release (2.1.0) is from 2024-10-09.
- Priority order for a new scaffold: the auth interceptor test ships working;
  add a text-scale/zoom test and an a11y assertion early. In the flutter pass,
  the equivalent text-scale test caught a real overflow in already-reviewed
  code and was the highest-yield check in the whole scaffold.

## Templates in this skill

| File | Purpose |
|---|---|
| `package.deps.verified.json` | The proven dependency set + the load-bearing `overrides` block. |
| `tsconfig.json` | Strict baseline. No `baseUrl` (trap 5); `erasableSyntaxOnly` on (trap 6). Strict-flag ladder is react-verify's. |
| `eslint.config.js` | ESLint 10 flat config. Boundary rule **proven to fire**; TS resolver block is mandatory (trap 2). |
| `vite.config.ts` | React + Tailwind v4 plugins, `@` alias, vitest config. |
| `vitest.setup.ts` | Seeds `window.__ENV__` before any module parses it. |
| `index.html` | Loads `config.js` before the bundle. |
| `main.tsx` | Entrypoint; wires the token port before first render. |
| `app/**` | Composition root, layout, providers, query client, router, guards. |
| `shared/api/**` | Client, both interceptors, error union, base service, the interceptor test. |
| `shared/config/env.ts` | Typed runtime config; translates the SCREAMING_SNAKE wire shape once. |
| `shared/storage/**`, `shared/store/**`, `shared/ui/**`, `shared/i18n/**`, `shared/navigation/routes.ts` | See the tree above. |
| `styles/tokens.css` | Design tokens. |
| `Dockerfile`, `docker-nginx.conf`, `docker-entrypoint.d/50-inject-api-auth.sh` | Credential proxy. **Not container-tested — see react-ship's STOP CONDITIONS.** |
| `public/config.js`, `public/config.local.example.js` | Runtime config defaults. |
| `forms/**` | react-hook-form + zod wiring, plus `EntityForm.test.tsx`. Compiles, lints, and 3 runtime tests pass. Read schema.ts's input/output note before changing the schema (trap 7). |
| `router-migration-example.tsx` | The `react-router-dom` → `react-router` import change. |
| `project-tree.md` | Full tree, both profiles. |

## The security fix this profile exists to ship: never send a credential to the browser

A bundler's `import.meta.env.VITE_*` value is **inlined at build time** into the
shipped JS. Any credential read that way is a plaintext string in a file served
to every browser, readable via view-source. Naming or prefixing it differently
does not change where the bytes end up.

**The fix is NOT a `window.__ENV__` global.** That relocates the same
browser-reachable value to a different property on `window` — still readable
from devtools, still shipped to every browser. Moving a secret from a
build-time constant to a runtime global is cosmetic.

**The actual fix** is to terminate authentication at a reverse proxy the
browser never bypasses: nginx's `/api/` location adds the credential header
itself via `proxy_set_header`, sourced from a Docker secret (or, documented as
weaker, an env var) read once at container start. The browser only ever talks
to its own origin at a relative path and never sees the credential in any form.
Any credential currently reachable via `import.meta.env` should be **deleted
from the codebase entirely** once this is live — from `.env`, from any build
script that injects it, and from the API client config that reads it.

`env.ts` and `public/config.js` are for values already safe for the browser: a
base URL, an environment label, a version string, feature flags. **No
credential belongs there, ever.**

## `BASE_PATH`: parameterized subpath deployment

If the app is served from a subpath, don't hardcode it into `vite.config.ts`'s
`base` and mutate the file per environment — a script that edits a tracked file
and reverts it is one interrupted build away from committing the mutated
version. Parameterize: a `BASE_PATH` build ARG (default `/`) passed to
`vite build --base=${BASE_PATH}`. The router reads it back via
`import.meta.env.BASE_URL` as its `basename`, so routing and assets stay
consistent with no second source of truth.

## What this skill deliberately does not do

Surveyed and rejected. Reintroducing one of these when planning a feature
reopens a closed decision rather than building on it.

- **No TanStack Router** (1.170.18, actively developed and genuinely strong).
  Out because its typed-route story leans on a generated route tree, and this
  marketplace's standing decision is against codegen routing — the same call
  flutter-sdlc made rejecting `auto_route` while keeping `go_router`. **This is
  a policy rejection, not a quality one**; it is the package to reach for if
  the team later wants fully typed params and accepts the codegen.
- **No native `fetch` as the client.** Settled toward axios by the plugin owner
  this pass, for the reason flutter chose dio: interceptors are what make
  single-flight 401 refresh and idempotent retry expressible at all. fetch
  would need that machinery hand-built around every call site.
- **No `class-variance-authority`** (0.7.1, published 2024-11-26, ~20 months
  stale). `Button.tsx`'s variant map is fifteen lines. Taking a stale
  dependency to avoid fifteen lines is a bad trade. Reach for it if variant
  logic genuinely outgrows a lookup object.
- **No `axios-mock-adapter`** (2.1.0, 2024-10-09) — axios's own adapter seam
  does the job with zero dependencies, and keeps the real interceptor chain in
  the test.
- **No component library (shadcn/ui, Radix, Headless UI) in the default
  scaffold.** `@radix-ui/*` and `@headlessui/react` are both healthy and
  actively published — **not a quality rejection.** A scaffold has no business
  choosing the product's component vocabulary before a single screen exists,
  and the four primitives here (Button, Spinner, ErrorView, EmptyState) are
  what the templates themselves need. Adopt Radix the moment you need a real
  dialog, popover, or combobox — do **not** hand-roll those; focus trapping and
  ARIA semantics are exactly where hand-rolling fails.
- **No `@lingui/react` or `react-intl`** — both healthy; `react-i18next` was
  chosen for the smallest setup and typed keys via `i18next.d.ts`. lingui also
  requires `babel-plugin-macros` and Node >=22.19.
- **No date library in the scaffold.** `date-fns` (4.4.0) and `dayjs` (1.11.21)
  are both fine; add one when a feature needs formatting. `Intl.DateTimeFormat`
  covers a surprising amount and is already there.
- **No `@tanstack/react-table` in the scaffold** (8.21.3, published
  2025-04-14 — 15 months stale, worth knowing before adopting). Add per-feature
  if a real data grid appears.
- **No type-aware linting by default.** Type-aware rules load the full TS
  program and roughly double lint time. Enable specific high-value rules
  (`no-floating-promises`) once measured against your own codebase.
- **No config auto-sync scripts.** A config generator that scans the filesystem
  can silently *remove* a gate command with no diff a reviewer reads as "a
  check disappeared." Hand-edit anything that gates a merge.
- **No blanket file-naming lint rules on an adopted codebase** — hundreds of
  day-one violations for zero defect-catching value. Apply naming conventions
  going forward.
- **No React Compiler in the default scaffold.** `babel-plugin-react-compiler`
  reached 1.0 (2025-10-07), but `eslint-plugin-react-compiler` is still
  `19.1.0-rc.2` from 2025-05-14. Note `eslint-plugin-react-hooks@7.1.1` already
  carries compiler-aware rules, so you get much of the lint value without
  adopting the build step.

## First run: establish the 3-tier agent context

Before or immediately after the overlay, dispatch
**`docs-architect:docs-context`**. It detects and creates the three context
tiers, for a greenfield scaffold *and* for an adopt-in-place pass:

```powershell
./ensure-context.ps1 -Mode Detect    # report only
./ensure-context.ps1 -Mode Ensure    # create what is missing
```

| Tier | Artifact | Who builds it |
|---|---|---|
| 1 AST / blast radius | `.code-review-graph/graph.db` | `code-review-graph build` |
| 2 structural | `graphify-out/graph.json` | `graphify update .` |
| 3 architecture memory | `llmwiki/*.md` | **an agent — there is no llmwiki tool** |

**Why a scaffold ships this rather than leaving it to whoever adopts it
later.** Every task in this pipeline is executed by an agent working through a
context window. Without the graphs, "what breaks if I change this hook" means
opening files until the answer appears — expensive, and on a large project it
silently truncates, so the agent proceeds on a *partial* picture without
knowing it. The graphs turn that into a lookup. Retrofitting them onto a mature
codebase is a chore nobody schedules; establishing them at scaffold time costs
one command.

Two things to know before running it:

- **A tier whose CLI is not installed reports `NOT RUN`, never `PASS`.** The
  script exits non-zero if any tier is unusable, so a missing graph cannot be
  mistaken for a built one.
- **Tier 3 can only be *scaffolded* here.** The script writes placeholder files
  marked `STUB`; `docs-architect:docs-onboarding` is what actually authors
  them. A `STUB` also exits non-zero — a placeholder must not read as
  documentation.

**What to commit** (full reasoning in `docs-context`): commit `llmwiki/` and
`graphify-out/graph.json`; **do not** commit `graphify-out/manifest.json` or
`graphify-out/cache/**` — their keys are absolute machine paths, so they are
useless to a teammate and rewrite on every run, conflicting on every merge.
`.code-review-graph/` writes its own ignore rule. Add to `.gitignore`:

```gitignore
graphify-out/cache/
graphify-out/manifest.json
```

Then dispatch **`docs-architect:docs-onboarding`** to write
`CODEBASE_ONBOARDING.md`, `docs/architecture/react.md`, and the llmwiki files.
On an adopted repo, that document must describe **what the code actually
does**, not what this skill's conventions say it should — those diverge, and
the intended-design version is the one that makes people stop trusting docs.

## Cross-references

- `docs-architect:docs-context` / `docs-architect:docs-onboarding` — first-run
  context and documentation, per the section above.
- `react-sdlc:react-slice` does the vertical-slice work on top of this
  scaffold. Its `*.api.ts` template extends the `BaseApiService` shipped here.
- `react-sdlc:react-verify` owns the gate commands, the strict-flag ladder
  referenced by `tsconfig.json`, and the boundary check.
- `react-sdlc:react-ship` owns the STOP CONDITIONS the Docker/nginx templates
  are written against — those remain **container-untested** in this pass.
- `sdlc-core:ui-ux-web` / `sdlc-core:ui-ux-review` own visual and interaction
  decisions. This skill ships tokens and four primitives, not a design system.
- `sdlc-core:walkthrough` writes the human-facing summary; this skill does not.
