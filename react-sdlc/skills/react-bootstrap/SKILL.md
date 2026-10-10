---
name: react-bootstrap
description: Scaffolds a production-grade React 19 + TypeScript + Vite 8 application with Tailwind CSS v4 CSS-first design tokens, strict feature boundaries, 5-state UI primitives, Axios RFC 9457 client, Zustand stores, and full 10-document context generation via docs-scaffold.
---

# react-bootstrap

**Verb: scaffold.**

## 1. Architectural Invariants

Every React application scaffolded by this skill must uphold five non-negotiable architectural invariants:

1. **Strict Vertical Feature Slices**: Features reside exclusively under `src/features/<feature>/`. Zero imports between sibling features. Enforced by `eslint-plugin-boundaries`; violations fail the build.
2. **Tokens-Only Styling**: `src/styles/tokens.css` is the sole file defining raw colors via Tailwind v4 `@theme`. Feature code is strictly forbidden from using raw hex colors or ad-hoc Tailwind palette classes.
3. **5-State UI Ladder**: Every async data-rendering screen must handle all 5 states: Loading (`Skeleton`), Empty (`EmptyState`), Error (`ErrorState`), Gated (`PermissionGate`), and Loaded. Every write affordance must be wrapped in `PermissionGate`.
4. **RFC 9457 API Client**: Centralized Axios client (`src/shared/api/http-client.ts`) handles Bearer authentication, single-flight token refresh, idempotent-only retries, and RFC 9457 Problem Details error parsing.
5. **Context Before Code**: Dispatches `docs-architect:docs-scaffold` on Day 0 to emit the 10-document context suite into `docs/` and root `AGENTS.md`.

---

## 2. Directory Structure Contract

```
<project-root>/
├── docs/                             # Emitted by docs-scaffold
│   ├── PRD.md
│   ├── UX_FLOWS.md
│   ├── DESIGN_SYSTEM.md
│   ├── ARCHITECTURE.md
│   ├── DATABASE.md
│   ├── API.md
│   ├── SECURITY.md
│   ├── CODE_STYLE.md
│   └── TESTING.md
├── src/
│   ├── app/
│   │   ├── router/router.tsx         # React Router v8 with lazy route leaves
│   │   └── App.tsx                   # Composition root & providers
│   ├── features/                     # Isolated vertical slices
│   │   └── <feature>/
│   │       ├── api/                  # DTOs, queries, transformers
│   │       ├── components/           # Feature UI
│   │       └── types/                # Domain models
│   ├── shared/
│   │   ├── api/                      # http-client.ts, query-keys.ts
│   │   ├── store/                    # auth-store.ts, ui-store.ts, access-store.ts
│   │   ├── ui/                       # Button, Skeleton, EmptyState, ErrorState, PermissionGate
│   │   └── lib/                      # cn.ts extended with @theme tokens
│   └── styles/
│       └── tokens.css                # Tailwind v4 @theme token definitions
├── AGENTS.md                         # Operational instructions for AI coding assistants
├── vite.config.ts
├── eslint.config.js                  # Boundaries configuration
├── tsconfig.json
└── package.json
```

---

## 3. Scaffolding Procedure

1. **Initialize Project Substrate**:
   ```bash
   npm create vite@latest <project-name> -- --template react-ts
   ```
2. **Install Pinned Dependencies**:
   - Runtime: `react@^19.0.0`, `react-dom@^19.0.0`, `react-router@^8.3.0`, `@tanstack/react-query@^5.60.0`, `zustand@^5.0.0`, `axios@^1.8.0`, `clsx`, `tailwind-merge`.
   - Tooling: `@tailwindcss/vite@^4.0.0`, `tailwindcss@^4.0.0`, `typescript@^5.9.0`, `vite@^8.0.0`, `vitest@^3.0.0`.
   - Boundary Linter: `eslint@^9.20.0`, `eslint-plugin-boundaries@^5.0.0`, `typescript-eslint`.
3. **Emit 10-Document Context Suite**:
   Invoke `docs-architect:docs-scaffold` targeting `react` profile. Emits `docs/` and root `AGENTS.md`.
4. **Overlay Design Tokens & UI Primitives**:
   - Copy `src/styles/tokens.css` with semantic variables.
   - Copy `src/shared/ui/` primitives (`Button.tsx`, `Skeleton.tsx`, `EmptyState.tsx`, `ErrorState.tsx`, `PermissionGate.tsx`, `cn.ts`).
5. **Configure Boundary Rules in `eslint.config.js`**:
   Prohibit imports across `src/features/*`. Enforce that features only import from `src/shared/` or their own slice.
6. **Establish 3-Tier Agent Context**:
   Invoke `docs-architect:docs-context` to build AST and structural dependency graphs.
7. **Run Verification Gates**:
   - `npm run typecheck` (`tsc --noEmit`)
   - `npm run lint`
   - `npm run test`
   - `npm run build`
