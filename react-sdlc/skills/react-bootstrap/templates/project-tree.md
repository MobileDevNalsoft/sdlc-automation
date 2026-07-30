<!-- vendored bulletproof-react docs concept on 2026-07-30, source: https://github.com/alan2207/bulletproof-react, license: MIT -->
<!-- Folder-layout CONCEPT only (feature-folder isolation: api/components/types
     per feature, shared cross-cutting code at src root). No package.json,
     tooling config, or code from that repo is copied — only the folder-shape
     idea, cited here for provenance. -->

# Project tree — both profiles

## Adopt-in-place — read the target repo before assuming this shape

Confirm the target repo's actual existing structure before treating any of
this as already true; the tree below is what a react-bootstrap pass
produces, not a claim about what any specific project already has.

```
<project-root>/
├── public/
│   ├── config.js                  # NEW — see react-bootstrap templates/public/config.js
│   ├── config.local.example.js    # NEW — copy to config.local.js (gitignored) locally
│   └── manifest.json              # existing, if present — untouched
├── src/
│   ├── app/                       # composition root — providers, router, layout
│   ├── shared/
│   │   ├── api/                   # HTTP client base class, common types
│   │   └── ...                    # design-system primitives, generic hooks
│   ├── features/
│   │   └── <feature>/
│   │       ├── api/
│   │       │   ├── <feature>.api.ts           # HTTP calls
│   │       │   ├── <feature>.queries.ts       # useQuery/useMutation + query-key factory
│   │       │   └── <feature>.transformers.ts  # wire format <-> domain model
│   │       ├── components/
│   │       └── types/
│   │           └── <feature>-dto.types.ts     # wire shape, matches the API response exactly
│   ├── store/                     # client-state stores (e.g. Zustand slices)
│   └── main.tsx
├── vite.config.ts                 # base path parameterized via BASE_PATH at build time — see SKILL.md
├── tsconfig.json                  # matches this skill's template baseline
├── eslint.config.js               # NEW if the target repo has no lint config yet
├── Dockerfile                     # BASE_PATH ARG + credential-proxy wiring
├── docker-nginx.conf              # adds /api/ auth-proxy location
├── docker-entrypoint.d/
│   └── 50-inject-api-auth.sh      # NEW
└── package.json
```

## Greenfield

Same feature-folder shape from day one — no existing code to reconcile
against.

```
<new-project>/
├── public/
│   ├── config.js
│   └── config.local.example.js
├── src/
│   ├── app/
│   ├── shared/
│   │   └── api/{config.ts,client.ts,base-api.service.ts}
│   ├── features/
│   │   └── <feature>/{api,components,types}/...
│   ├── store/
│   └── main.tsx
├── vite.config.ts
├── tsconfig.json
├── eslint.config.js
├── Dockerfile
├── docker-nginx.conf
├── docker-entrypoint.d/50-inject-api-auth.sh
└── package.json                   # see react-bootstrap/SKILL.md's version table
```
