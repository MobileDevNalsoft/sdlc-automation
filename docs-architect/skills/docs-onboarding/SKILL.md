---
name: docs-onboarding
description: Use on first bootstrap of a project, and whenever the architecture changes, to write the onboarding documentation a new developer or agent reads before touching code — one CODEBASE_ONBOARDING.md that owns the cross-stack request trace, plus a per-stack deep-dive (docs/architecture/react.md, flutter.md, schema.md, api.md) for each stack actually detected. Also authors the llmwiki/ files docs-context scaffolds as stubs. Every claim must cite a file path; a section that cannot be grounded is written as a gap, not guessed.
---

# docs-onboarding

**Verb: onboard.**

## The shape, and why it is not one doc per stack

The obvious design — a React doc, a Flutter doc, a schema doc, an API doc — is
the wrong one, and it fails in a specific way worth naming before you build it:

- **The valuable part of onboarding is the part that crosses stacks.** "A user
  clicks Submit → which hook → which endpoint → which PL/SQL package → which
  table → and back." Four per-stack documents have nowhere to put that trace,
  so it either goes missing or gets written four times from four partial
  viewpoints.
- **Four documents duplicate the seams.** The API contract appears in both the
  React doc and the API doc. They drift within a month, and then a reader has
  two answers and no way to tell which is current.

So the split is by **ownership**, with a strict no-duplication rule:

| Document | Owns | Must NOT contain |
|---|---|---|
| `CODEBASE_ONBOARDING.md` | the end-to-end trace, the component map, how to run it, cross-cutting risks | per-stack internals — link instead |
| `docs/architecture/<stack>.md` | that stack's internal layering, conventions, and gotchas | the request trace, or any other stack's internals |
| `llmwiki/*.md` | a thin routing map for agents | anything longer than a few lines — link to the two above |

**One rule keeps them honest: a fact lives in exactly one file.** Everywhere
else links to it. If you find yourself explaining the auth header in both the
React doc and the API doc, it belongs in the trace, and both link there.

## Produce only what the repo actually has

Detect before writing. A `docs/architecture/flutter.md` in a repo with no
Flutter is worse than no file — it will be read and believed.

| Stack | Detect by |
|---|---|
| React | `package.json` with a `react` dependency |
| Flutter | `pubspec.yaml` with `flutter:` |
| Oracle schema | `.sql` DDL, a migrations directory, or a reachable data dictionary |
| REST API | an ORDS module, a route table, or an API manifest |

## CODEBASE_ONBOARDING.md — the required outline

Modelled on a structure proven in practice. Sections marked **required** are
not optional; a document missing them is not an onboarding doc.

1. **TL;DR** *(required)* — what this system does, in five sentences, for
   someone who has never heard of it.
2. **Table of contents** — for anything over ~200 lines.
3. **Architecture at a glance** *(required)* — one diagram. Prefer a mermaid
   block over ASCII: it renders, and it survives edits.
4. **Tech stack** *(required)* — with **versions**, read from the manifests,
   not remembered.
5. **Component map** — each major component, one line, with its directory.
6. **Data model** — tables/entities and their relationships. Link to
   `docs-reference` output rather than restating every column.
7. **End-to-end trace** *(required — this is the centrepiece)*. See below.
8. **Running it locally** *(required)* — the exact commands, in order,
   including prerequisites that fail on a fresh machine.
9. **Flaws and risks** *(required)* — see below.
10. **Glossary** — every domain term a newcomer would have to ask about.

### The end-to-end trace is the centrepiece

Pick **one real, representative user action** and follow it all the way down
and back, naming the actual file at every hop:

```
User clicks "Submit" on the order form
  -> src/features/orders/components/OrderForm.tsx      (RHF + zod validation)
  -> src/features/orders/api/orders.queries.ts         useCreateOrder
  -> src/features/orders/api/orders.api.ts             extends BaseApiService
  -> src/shared/api/http-client.ts                     auth + retry interceptors
  -> POST /api/orders                                  nginx injects credential
  -> ORDS handler ORDER_MODULE /orders POST            order_api_pkg.create_order_p
  -> APP_ORDER_T insert                                + APP_ORDER_LINE_T children
  <- 201 + Location header                             A4 real status code
  <- invalidateQueries(['orders','list'])              list refetches
```

**Every arrow must name a real file, and every file must exist.** This is the
single highest-value section, because it is the only place a reader learns how
the layers actually connect — and it is the one thing that cannot be inferred
from any single stack's documentation.

If a hop cannot be traced, write `UNTRACED: <what and why>` rather than
inventing a plausible path. Use the tier-1 graph
(`code-review-graph detect-changes <file>`) to find real call sites instead of
guessing from names.

### "Flaws and risks" is required, and it is the section that gets deleted

An onboarding document that reads as though everything is fine is not trusted
by anyone who has worked in the codebase for a week — and it teaches a new
joiner nothing about where the sharp edges are.

Write what is actually true: the module everyone is afraid to change, the
missing test coverage, the known race, the migration that was never finished,
the credential handling that is weaker than it should be. Be specific and
non-blaming — "`order_api_pkg` has no tests and three known callers" is useful;
"the code is bad" is not.

**Never delete this section to make the document look better.** If it is
genuinely empty, say so explicitly and date it, so a reader knows it was
considered rather than dropped.

## Per-stack deep-dives

`docs/architecture/<stack>.md`, one per detected stack. Each covers **only its
own layer**:

| Stack | Cover | Link out for |
|---|---|---|
| `react.md` | folder architecture and the enforced boundary rule, server vs client state split, routing and guards, the API client and error union, design tokens | the request trace; the API contract |
| `flutter.md` | bootstrap and flavors, Service → Repository → Cubit → Screen, sealed `Result`/state, DI, the boundary checker | the request trace; the API contract |
| `schema.md` | naming contract, audit columns, soft delete, PK strategy, FK/index rules, migration versioning | full table listings (that is `docs-reference`) |
| `api.md` | the A-rules this project actually follows, auth, pagination choice per endpoint class, error envelope | full endpoint listings (that is `docs-reference`) |

**Prefer linking to the owning skill over restating it.** `react.md` should say
"boundaries are enforced by `boundaries/dependencies`; see react-bootstrap
trap 2 for the proof procedure" — not re-explain the rule. A restatement is a
copy that will drift; a link cannot.

## Grounding: every claim cites a file

This is the rule that separates documentation from confident fiction.

- A statement about behaviour cites the file that implements it.
- A version number is read from a manifest, never recalled.
- A command is one that was **run**, or is labelled `UNVERIFIED`.
- Anything that could not be established is written as an explicit gap.

**Prohibited:** describing what the architecture *should* look like based on
the stack skills, when the repo does something else. On a fresh scaffold those
agree; on an adopted codebase they routinely do not, and the intended-design
version is exactly the confidently-wrong artifact that makes people stop
trusting docs. Write the real behaviour; note the intended one as a gap.

## Refresh

| Trigger | Action |
|---|---|
| a new stack appears | add its deep-dive; add its hop to the trace |
| a layer's conventions change | edit that deep-dive only |
| the request path changes | edit the trace — the one most often missed, because the change lives in a feature diff and nothing points back here |
| a risk is fixed | remove it from "flaws and risks" and note when |

Re-run `docs-context` first, so the trace is rebuilt against a current graph
rather than a stale one.

## Cross-references

- `docs-architect:docs-context` must run first — it provides the graphs this
  skill traces with, and scaffolds the llmwiki stubs this skill fills in.
- `docs-architect:docs-reference` owns exhaustive table and endpoint listings.
  Link to it; never inline a full column list here.
- `sdlc-core:walkthrough` is per-task and disposable; this is per-project and
  maintained. Different audiences, different lifetimes — do not merge them.
