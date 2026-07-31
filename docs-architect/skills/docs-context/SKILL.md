---
name: docs-context
description: Use at the start of any bootstrap pass, and after any structural code change, to establish or refresh the 3-tier agent context — the code-review-graph AST graph, the graphify structural graph, and the llmwiki/ architecture memory. Detects which tiers are missing and creates them for a greenfield or an existing project; reports NOT RUN for any tier whose tool is absent rather than degrading to a silent pass. Dispatched by react-bootstrap, flutter-bootstrap, schema-model, and api-contract on first run.
---

# docs-context

**Verb: index.**

## What the three tiers are, and why they are not interchangeable

They answer different questions at different costs. Using the wrong one wastes
context, which is the entire point of having three.

| Tier | Artifact | Answers | Cost |
|---|---|---|---|
| 1 — AST | `.code-review-graph/graph.db` | "who calls this function, what breaks if I change it" — exact call sites and blast radius | cheap query, expensive first build |
| 2 — structural | `graphify-out/graph.json` | "how do these components relate across the stack" — UI ↔ API ↔ DB, cross-module | medium |
| 3 — synthesized | `llmwiki/*.md` | "how is this system built, deployed, and conventionally written" — prose an agent reads before touching anything | free to read, written by an agent |

**Read tier 3 first, then 1 or 2 as needed, then source files.** Reading source
first is the behaviour this skill exists to prevent.

## The critical asymmetry: two are tools, one is not

- `code-review-graph` — an external CLI (Python). **May not be installed.**
- `graphify` — an external CLI. **May not be installed.**
- `llmwiki` — **not a tool.** There is no `llmwiki` binary. It is a directory
  of markdown an *agent writes and maintains*. No amount of installing will
  produce it.

This is why tier 3 is the one that silently rots: nothing regenerates it, so
it drifts from the code until someone notices it is lying. Treat a stale
llmwiki as worse than a missing one — a missing one sends you to the source,
a stale one sends you confidently to the wrong answer.

## Procedure

Run `scripts/ensure-context.ps1` (see below) or do it by hand:

### 1. Detect

```
.code-review-graph/graph.db   present?
graphify-out/graph.json       present?
llmwiki/index.md              present?
```

### 2. Establish what is missing

> ### Both CLIs act on the CURRENT WORKING DIRECTORY — `cd` first
>
> Neither takes a reliable target-path flag, and this bit for real while
> building this skill (2026-07-31):
>
> - **`code-review-graph` has no `--path`.** Run from the wrong directory it
>   builds a graph of *that* directory and reports success. In testing it
>   returned `83 nodes` for a two-file project — because it had graphed the
>   plugin repo the shell happened to be sitting in. Nothing errored.
> - **`graphify update <path>`** writes `graph.json` under the target, but
>   writes its incremental cache (`manifest.json`, keyed by absolute paths)
>   into `./graphify-out` relative to **CWD** — littering the caller's
>   directory with a half-populated `graphify-out/`.
>
> `ensure-context.ps1` wraps every invocation in `Push-Location`. **If you run
> these by hand, `cd` into the project first** and sanity-check the node count
> against the project's actual size. A node count that looks wrong is the only
> signal you get.

**Tier 1 —** if the CLI exists:

```
cd <project-root>            # NOT optional, see above
code-review-graph build      # full build, first time
code-review-graph status     # confirm: Nodes/Edges/Files > 0
```

> **`status` is NOT a read-only probe.** Running it in a repo with no graph
> **creates** `.code-review-graph/` and runs its schema migrations, then
> reports `Nodes: 0 … Last updated: never`. Verified 2026-07-31. So "does the
> directory exist" is not a safe existence test after anything has called
> `status` — test on the reported node count instead.
>
> It writes its own `.code-review-graph/.gitignore` containing `*`, so the
> database never lands in a commit. Do not add a second ignore rule for it.

**Tier 2 —** if the CLI exists:

```
graphify update .            # extract + cluster; no LLM required
```

**Tier 3 —** author it. There is no command. Four files:

| File | Contents |
|---|---|
| `llmwiki/index.md` | Links to the other three + the token-optimization rules an agent must follow in this repo |
| `llmwiki/architecture.md` | System design, entry points, components, data flow |
| `llmwiki/deployment.md` | Build, environments, CI/CD, secrets handling |
| `llmwiki/conventions.md` | Coding standards, state management, API patterns — or a pointer to the stack skills that own them |

**Keep tier 3 thin and link-heavy.** Its job is routing an agent to the right
place, not restating what `docs-onboarding` writes. If `index.md` starts
growing sections rather than links, the content belongs in
`CODEBASE_ONBOARDING.md` and `index.md` should link to it.

### 2b. Decide what gets committed — this is not obvious and it is usually got wrong

Three artifacts, three different answers. Getting this wrong produces either a
useless graph for teammates or a permanent source of merge conflicts.

| Artifact | Commit? | Why |
|---|---|---|
| `.code-review-graph/` | **No** | Contains absolute paths and is fully regenerable. The tool writes its own `.gitignore` containing `*` — do not add a second rule. |
| `graphify-out/graph.json` | **Yes** | The shareable output. A teammate cloning the repo gets a usable structural graph without a rebuild. |
| `graphify-out/GRAPH_REPORT.md`, `graph.html`, `.graphify_labels.json` | **Yes** | Human-readable outputs; small and reviewable. |
| `graphify-out/manifest.json` | **No** | **Verified 2026-07-31:** keys are ABSOLUTE paths (`D:\Projects\app\src\x.ts`) plus `mtime` floats. On a teammate's machine every key mismatches, so the incremental cache is useless to them — and every run rewrites the file, so it conflicts on every merge. |
| `graphify-out/cache/**` | **No** | Same reasoning, at ~1 file per source file. |

So the recommended `.gitignore` addition is:

```gitignore
# graphify: keep the shareable graph, drop the machine-specific cache
graphify-out/cache/
graphify-out/manifest.json
```

**`llmwiki/` is committed — always.** It is documentation, it is the tier a new
teammate or agent reads first, and it is the only one of the three that no tool
can regenerate.

> **A note on graph.json merge conflicts.** Two people adding modules on
> separate branches both rewrite `graph.json`, and the textual merge is
> unpleasant. graphify ships a union merge driver for exactly this
> (`graphify merge-driver <base> <current> <other>`, installed via its hook).
> Set it up before the first conflict rather than after.
>
> `ASSUMPTION:` that merge driver was **not** exercised in this pass — the
> capability is read from the CLI's own help output, not from a merge that was
> performed. Verify before relying on it.

### 3. Report honestly

```
| Tier | Artifact | Result |
|---|---|---|
| 1 AST | .code-review-graph/graph.db | CREATED | REFRESHED | PRESENT | NOT RUN (tool absent) |
| 2 structural | graphify-out/graph.json | ... |
| 3 llmwiki | llmwiki/index.md | ... |
```

**`NOT RUN` is never `PASS`.** A missing tool is a real, reportable state — the
same rule `sdlc-core:evidence-contract` applies everywhere else. Silently
skipping a tier and reporting success means the next agent believes it has a
blast-radius graph it does not have, and trusts an answer nothing verified.

## Refresh, not just create — and this is the half that gets skipped

Creating the graphs once is easy; keeping them true is the actual work. A
graph that is three months stale is **worse than absent**, because it answers
confidently and wrongly.

| After | Run |
|---|---|
| any structural change (new/renamed/deleted function, class, module) | `code-review-graph update` (incremental) |
| new module, route, or major component | `graphify update .` |
| architecture or deployment change | hand-edit `llmwiki/architecture.md` / `deployment.md` |
| large refactor that deleted a lot of code | `graphify update . --force` — without it, graphify refuses to overwrite a graph that would end up with fewer nodes (a guard against a broken extraction silently shrinking the graph) |

Wire the first two into the same place your project already runs post-change
automation. If there is nowhere, say so — do not invent a git hook silently;
a hook that a teammate has not installed is a check that only runs on your
machine.

## Adopting into an EXISTING project

Same procedure, two differences worth stating:

1. **The first `code-review-graph build` on a large repo is slow** — it parses
   every file. Run it once, deliberately, not inside a task someone is waiting
   on. Afterwards `update` is incremental and cheap.
2. **Write `llmwiki/` from what the code actually does, not from what the
   stack skills say it should do.** On a greenfield scaffold those are the
   same; on an adopted repo they are frequently not, and a tier-3 doc that
   describes the intended architecture rather than the real one is exactly the
   confidently-wrong artifact this skill warns about. Where they differ, write
   the real behaviour and note the intended one as a gap.

## MCP registration (optional, do not do it silently)

Both CLIs can register themselves with the coding platform:

```
code-review-graph install      # registers its MCP server
graphify install --platform claude
```

This edits **user-level** configuration outside the repository, so it affects
every project on the machine, not just this one. **Ask before running it** —
it is not a project-scoped change and it is not obvious from a repo diff that
it happened.

## Cross-references

- `docs-architect:docs-onboarding` consumes these graphs to write
  `CODEBASE_ONBOARDING.md`. Run this skill first — onboarding written without
  the graphs is written from whatever files the agent happened to open.
- `react-sdlc:react-bootstrap`, `flutter-sdlc:flutter-bootstrap`,
  `schema-architect:schema-model`, `api-architect:api-contract` dispatch this
  skill on first run.
- `sdlc-core:evidence-contract` owns the `NOT RUN` vs `PASS` rule this skill's
  report table obeys.
