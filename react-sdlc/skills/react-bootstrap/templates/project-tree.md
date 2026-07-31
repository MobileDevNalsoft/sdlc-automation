<!-- vendored bulletproof-react docs concept on 2026-07-30, source: https://github.com/alan2207/bulletproof-react, license: MIT -->
<!-- Folder-layout CONCEPT only (feature-folder isolation: api/components/types
     per feature, shared cross-cutting code at src root). No package.json,
     tooling config, or code from that repo is copied — only the folder-shape
     idea, cited here for provenance. -->

# Project tree — both profiles

The three-layer split (`app/` > `features/` > `shared/`) is not a convention
here, it is **machine-enforced** by `boundaries/dependencies` in
`eslint.config.js`:

- `app/` may import anything — it is the composition root.
- `features/<x>/` may import its OWN subtree, `shared/`, and `styles/`.
  It may **not** import another feature, and may **not** import `app/`.
- `shared/` may import only `shared/` and `styles/`.

Verify the rule still fires after touching the resolver, the aliases, or the
elements patterns — see react-bootstrap/SKILL.md trap 2 for the two-case check.

## Greenfield

```
<new-project>/
├── public/
│   ├── config.js                   # window.__ENV__ dev defaults (no secrets)
│   └── config.local.example.js     # copy to config.local.js (gitignored)
├── src/
│   ├── main.tsx                    # single entrypoint; wires the token port
│   ├── app/                        # composition root — may import anything
│   │   ├── App.tsx
│   │   ├── AppLayout.tsx
│   │   ├── providers.tsx           # ErrorBoundary > Query > I18n > Suspense
│   │   ├── query-client.ts         # cache policy + compounding-retry fix
│   │   └── router/
│   │       ├── router.tsx          # the one aggregator; every route lazy
│   │       ├── RequireAuth.tsx     # redirects BEFORE mount
│   │       └── RouteErrorBoundary.tsx
│   ├── features/                   # ships 3 placeholders (SKILL.md trap 8);
│   │   │                           # react-slice replaces each one
│   │   ├── products/components/ProductsPage.tsx   # placeholder: index route
│   │   ├── auth/components/LoginPage.tsx          # placeholder: wired to useSignIn
│   │   ├── errors/components/NotFoundPage.tsx     # placeholder: catch-all route
│   │   └── <feature>/              # written by react-slice, one at a time
│   │       ├── api/
│   │       │   ├── <feature>.api.ts           # extends BaseApiService
│   │       │   ├── <feature>.queries.ts       # keys + useQuery/useMutation
│   │       │   └── <feature>.transformers.ts  # wire <-> domain, ONE place
│   │       ├── components/
│   │       └── types/
│   │           └── <feature>-dto.types.ts     # wire shape, exact field names
│   ├── shared/                     # bottom layer — imports neither app nor features
│   │   ├── api/
│   │   │   ├── http-client.ts      # the one axios instance, ordered chain
│   │   │   ├── auth-interceptor.ts # single-flight 401 refresh (tested)
│   │   │   ├── retry-interceptor.ts# idempotent methods only
│   │   │   ├── api-error.ts        # AppError union + ApiError carrier
│   │   │   └── base-api.service.ts # what every feature api extends
│   │   ├── config/env.ts           # typed runtime config, parsed once
│   │   ├── navigation/routes.ts    # path constants — in shared/, NOT app/
│   │   ├── storage/                # interfaces + one impl + test double
│   │   ├── store/                  # zustand slices, per-field selectors
│   │   ├── ui/                     # cn, Button, Spinner, ErrorView
│   │   └── i18n/                   # i18n.ts, i18next.d.ts, locales/
│   └── styles/tokens.css           # THE only file defining a raw color
├── index.html                      # loads config.js before the bundle
├── vite.config.ts                  # base path via BASE_PATH at build time
├── vitest.setup.ts                 # seeds window.__ENV__ before any import
├── tsconfig.json                   # no baseUrl; erasableSyntaxOnly on
├── eslint.config.js                # boundary rule + TS resolver (mandatory)
├── Dockerfile                      # BASE_PATH ARG + credential proxy
├── docker-nginx.conf
├── docker-entrypoint.d/50-inject-api-auth.sh
└── package.json                    # see templates/package.deps.verified.json
```

## Adopt-in-place — read the target repo before assuming this shape

Confirm the target's actual structure first; the tree above is what a
react-bootstrap pass produces, not a claim about any existing project.

Adopt in this order, so each step is independently reviewable:

1. `tsconfig.json` + `eslint.config.js` (+ the `overrides` block — without it
   `npm install` fails on ESLint 10; see SKILL.md trap 1).
2. `shared/config/env.ts` + `public/config.js`.
3. `shared/api/**` — the largest win, and what react-slice depends on.
4. `shared/store/**`, `shared/storage/**`.
5. `app/**` routing and providers.
6. `styles/tokens.css` + `shared/ui/**` — usually the most invasive, because
   it touches existing markup. Leave it last.

The boundary rule will report violations against pre-existing code the moment
it is switched on. Set it to `warn` first, measure the count, and fix by
directory rather than failing the adoption pass on day one.
