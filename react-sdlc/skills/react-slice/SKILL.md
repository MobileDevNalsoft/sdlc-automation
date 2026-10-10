---
name: react-slice
description: Use when implementing one vertical feature slice end-to-end in a React + Vite + TypeScript project already scaffolded by react-bootstrap — typed DTO at the API boundary through a transformer/mapper through a TanStack Query hook through a presentation component. Use once per feature/endpoint pair, dispatched immediately after a plan names this skill.
---

# react-slice

**Verb: slice.**

## Verified 2026-07-31

Every template in this directory was dropped into a real Vite project
scaffolded from `react-bootstrap`'s templates and checked: `tsc --noEmit`
exit 0, `eslint` exit 0. That matters because these files import
`@/shared/api/base-api.service`, and **before 2026-07-31 nothing emitted that
file** — a project scaffolded by react-bootstrap and then sliced did not
compile. Re-run both commands after editing a template here.

## The seam this skill owns, in order

```
REST/JSON API contract (any backend technology — see templates/api-contract.md)
  -> *-dto.types.ts (wire shape, matches the API response exactly)
    -> *.transformers.ts (wire format <-> domain model — the ONLY place this translation happens)
      -> *.api.ts (extends BaseApiService; { signal } forwarded on every method)
        -> *.queries.ts (query-key factory + useQuery/useMutation, typed with ApiError)
          -> component (never touches a DTO, a wire-format field, or an AxiosError)
```

**The HTTP client is not a choice this skill makes any more.** `react-bootstrap`
settled it: one configured axios instance, reached only through
`BaseApiService`. A feature api service extends that base and inherits the
auth/retry interceptors and the error mapping. Do not construct an axios
instance, call `fetch`, or import `axios` inside a feature — if a `.tsx` or
`*.queries.ts` file imports from `axios`, something has gone around the seam.

Every template file in `templates/` is a complete worked example of one small, generic feature — tagging a `<parent-entity>` with a lookup-coded label, instantiated here as "Product Tags" — chosen because it's small enough to read end-to-end in one sitting but touches every layer above. This is a neutral illustrative domain, not a real feature: copy the *pattern*, don't copy "Product" or "tag" into an unrelated feature's naming.

## This skill's backend assumption: a REST/JSON contract, any implementation

`templates/api-contract.md` describes the endpoint contract this slice's frontend templates assume — plain HTTP verbs (GET list, POST create, DELETE remove), JSON request/response bodies, and errors as an `{ error: { code, message } }` body alongside a non-2xx status. How that contract gets implemented server-side (Node/Express, Django REST Framework, Rails, Spring, a serverless function, a legacy database-backed gateway, anything else) is genuinely out of scope for a *React* SDLC skill — this skill's concern starts at the typed DTO layer that consumes whatever the backend actually returns. If your project's real backend uses a different envelope shape (a `{ data: ... }` wrapper, a GraphQL layer, etc.), adjust the DTO/transformer layer to match it; the pattern (translate once, in one place) is what carries over, not the exact JSON shape below.

## Templates in this skill

| File | Layer |
|---|---|
| `templates/api-contract.md` | The REST/JSON contract this slice's frontend assumes — generic, backend-agnostic. |
| `templates/product-tag-dto.types.ts` | Wire-shape types, matching the contract's field names exactly, no translation. |
| `templates/product-tags.transformers.ts` | `ProductTagTransformers.toModel` / `toCreateRequest` — the translation boundary. |
| `templates/product-tags.api.ts` | HTTP calls for this feature, with an `AbortSignal` threaded through every method. |
| `templates/product-tags.queries.ts` | Query-key factory, `useProductTags`, `useAddProductTag`, `useRemoveProductTag` — each mutation owns its own `invalidateQueries` call. |
| `templates/ProductTagsPanel.tsx` | Terminal component — consumes hooks only. |

## Threading `{ signal }` — a common real-world gap, not a hypothetical

Many codebases wire TanStack Query without ever threading the `signal` TanStack Query already hands into every `queryFn`'s context argument (`queryFn: async ({ signal }) => ...`) through to the actual HTTP call. The capability is usually already there — most HTTP client wrappers accept an options object that includes an abort signal — the gap is that nothing passes it. Before assuming your project already does this, check an existing feature's `*.api.ts`/`*.queries.ts` pair for an actual `{ signal }` call site, not just a method signature that *could* accept one. This skill's templates are the pattern to copy forward: thread `{ signal }` from the query/mutation's context all the way to the HTTP call, so an abandoned query (component unmounted, dependent key changed) actually cancels its in-flight request instead of letting it complete and land in a stale cache write.

## Wire format <-> domain translation — where it happens and where it must not

Translation happens in exactly one place per slice: the `*.transformers.ts` file. This isn't only about casing (`snake_case` vs `camelCase`) — it's the single seam where every mismatch between "what the wire sends" and "what the domain model needs" gets resolved: a nullable wire field defaulting to a sensible domain value, a string timestamp becoming a typed value, a numeric status code becoming a named union. A DTO field must never be read directly inside a component or a `*.queries.ts` hook — if you find yourself reading a raw wire-format field inside a `.tsx` file, the transformer is missing a mapping, not the component taking a shortcut.

## Errors: one type, all the way up

`BaseApiService` maps every failure before throwing, so a hook's error type is
`ApiError` and never an `AxiosError`. Type the hooks explicitly
(`UseQueryResult<Model[], ApiError>`), because that is what lets a component
switch exhaustively on `error.detail.kind` — `validation` carries a `fields`
map, `rateLimited` carries `retryAfterSeconds`, and so on.

Practical consequence: a component should not invent its own error copy.
`error.detail.message` is already user-facing and mapped, and `isRetryable`
answers whether offering "Try again" is honest — a retry button on a 403 is a
lie.

## Render all FIVE states. An empty list is not an error. Every write affordance goes through PermissionGate.

```
loading (Skeleton) | empty (EmptyState) | error (ErrorState) | gated (PermissionGate) | loaded
```

The most common defect in this layer is collapsing empty into error or skipping the gated state:
1. **Loading**: Skeleton placeholder reserving exact geometry.
2. **Empty**: `EmptyState` component explaining absence and offering the resolution action.
3. **Error**: `ErrorState` component with honest Retry affordance (never retry on 403).
4. **Gated**: `PermissionGate` component — Group absent renders nothing; `ACCESS_TYPE='V'` renders child disabled with the reason visible.
5. **Loaded**: Normal responsive data view.

Two details worth copying from `ProductTagsPanel.tsx`: use `isPending`, not
`isLoading`, for "there is no data yet" (v5 semantics), and give **mutation**
errors their own surface — the query-level error branch has already returned by
the time a mutation fails, so an unrendered `mutation.error` is silent.

## Presentation layer: this skill wires data and states, not visual design

`ProductTagsPanel.tsx` uses the shared primitives `react-bootstrap` ships
(`Button`, `ErrorState`, `EmptyState`, `Skeleton`, `PermissionGate`) rather than raw
`<button>`/`<div>`. Every write affordance (Create, Update, Delete) must be wrapped
in `<PermissionGate>`. That is an **architecture** decision — states, semantics,
focus handling and RBAC access enforcement get decided once — not a visual one.

Visual design (typography, color, spacing, layout) remains owned by
`sdlc-core:ui-ux-web`, reviewed by `sdlc-core:ui-ux-review`. react-slice's job
ends at "the wiring is correct, all five states render, and write affordances are gated";
hand the visual treatment to those skills rather than inventing styling conventions here.

## What this skill does NOT do

It does not write `docs/walkthroughs/<task-id>.md`. `sdlc-core:walkthrough` formats the final human-facing document from the slice's own output (files touched, the DTO shape, which query keys got added) — this skill's job ends at "the slice compiles and the component renders," not at producing that document. Don't duplicate walkthrough-writing logic here.

## Cross-references

- `react-sdlc:react-bootstrap` must have already run — this skill assumes
  `eslint.config.js`, `tsconfig.json`, the feature-folder shape
  (`src/features/<feature>/{api,components,types}`), **and `src/shared/api/`
  with `BaseApiService` + `ApiError`** already exist. If `BaseApiService` is
  missing, run react-bootstrap rather than hand-writing a substitute — a
  per-feature axios instance would bypass the auth refresh and retry
  interceptors entirely, and nothing would fail loudly to tell you.
- The boundary lint rule enforces that a feature imports only its own subtree,
  `shared/`, and `styles/`. Reaching into another feature is an ESLint error,
  not a convention — navigate via the path constants in
  `@/shared/navigation/routes`, never by importing another feature's symbol.
- `react-sdlc:react-verify` gates the result (`tsc --noEmit`, diff-scoped `eslint`) — this skill does not run those itself. Note the gate does not bundle; if this slice touched bundler config, a tsconfig path/alias, an asset import, or an env-var read, run the production build by hand before handing off.
- `sdlc-core:ui-ux-web` / `sdlc-core:ui-ux-review` own visual/typography/color/layout decisions for whatever component this slice produces — see "Presentation layer" above.
- `sdlc-core:secret-scan` runs over this slice's diff before it's reported `IMPLEMENTED` — a slice that touches backend/API-contract files is in that scanner's scope like any other file, not exempt because "it's a frontend task."
