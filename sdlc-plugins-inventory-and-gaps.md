# SDLC Plugins — File Inventory & Gap Analysis

> **Companion to** [sdlc-automation.md](./sdlc-automation.md) (the v4.0.0 design).
> **Date:** 2026-07-29 · **Subject:** `D:\Madhan_Utils\sdlc-plugins\` — 93 files, 5 plugins, 4 agents, 23 skills, 1 command.
> **Status of the build:** written to disk, structurally verified, **never installed or executed by Claude Code.**

This document does two things. **Part 1** explains every file and why it exists. **Part 2** maps the build against the full delivery lifecycle you described — PRD → architecture → bootstrap → UI/UX → testing → security → backend → documentation → deployment — and states plainly what is missing.

The short version of Part 2, so it isn't buried: **the build covers roughly the middle third of that lifecycle.** It is strongest at backend/schema/API convention enforcement, competent at bootstrap and gating, and has **nothing at all** for requirements intake, UI/UX, test authoring, or document generation. Four of your nine named concerns have zero implementation.

---

## Part 0 — The shape of the thing

Five plugins. One (`sdlc-core`) owns the process; four own a stack.

```
sdlc-plugins/
├── .claude-plugin/marketplace.json   ← the marketplace itself
├── sdlc-core/        process: 4 agents, 7 skills, /sdlc-task
├── react-sdlc/       stack: scaffold · slice · gate · release
├── flutter-sdlc/     stack: scaffold · slice · gate · release
├── schema-architect/ stack: model · emit · audit · promote
└── api-architect/    stack: contract · emit-handler · audit · publish
```

The four stack plugins share one verb pattern — **scaffold → slice → gate → release** — so a task in any stack moves through the same four shapes. That symmetry is the point: `sdlc-developer` doesn't need per-stack logic, it dispatches `<stack>:<verb>` and the skill owns the specifics.

---

## Part 1 — Every file, and why it exists

### 1.1 Marketplace and manifests (6 files)

| File | Size | Why it exists |
|---|---|---|
| `.claude-plugin/marketplace.json` | 1.3 KB | The registry. Declares `name`, `owner`, and 5 `plugins[]` entries with `source` paths relative to the marketplace root. Without this, `/plugin marketplace add` has nothing to read. |
| `sdlc-core/.claude-plugin/plugin.json` | 239 B | Per-plugin manifest. Only `name` is strictly required; `version`/`description`/`author` are here so the plugin UI shows something meaningful. |
| `react-sdlc/…/plugin.json` | 267 B | ↑ |
| `flutter-sdlc/…/plugin.json` | 271 B | ↑ |
| `schema-architect/…/plugin.json` | 273 B | ↑ |
| `api-architect/…/plugin.json` | 298 B | ↑ |

**Reasoning:** these are pure plumbing, but the layout is load-bearing and easy to get wrong. `agents/`, `skills/`, and `commands/` must sit at the **plugin root**, never inside `.claude-plugin/`. Getting that backwards produces a plugin that installs cleanly and then does nothing.

---

### 1.2 `sdlc-core` — the process layer (13 files)

This is the plugin that makes the other four behave consistently. It contains no stack knowledge at all.

#### The four agents (17 KB total)

Each is ~4 KB with an identical six-section skeleton — **ROLE / NON-NEGOTIABLES / PROCEDURE / EVIDENCE RULES / OUTPUT CONTRACT / STOP CONDITIONS** — and ends on a forced uppercase token so a dispatcher can route on the last line.

| File | `tools` | Terminal token | Why this agent exists |
|---|---|---|---|
| `agents/sdlc-plan.md` | `Read, Grep, Glob, WebFetch` | `PLAN-READY` / `NEEDS-DECISION:` | Loads the 3-tier context (code-review-graph → graphify → llmwiki) *before* reading source, names every file it will touch, and produces a **Skill Decision Record** listing rejected candidates with reasons. No write tools — planning that can edit stops being planning. |
| `agents/sdlc-developer.md` | `Read, Write, Edit, Grep, Glob, Bash` | `IMPLEMENTED` / `BLOCKED:` | The only agent that can write. Implements one vertical slice by dispatching a stack skill (`react-sdlc:react-slice` etc.). Forbidden from mutating git, touching files outside the plan, or editing env-swap-generated files. |
| `agents/sdlc-verify.md` | `Read, Grep, Glob, Bash` | `GATE-PASS` / `GATE-FAIL:` | Runs the stack gate and quotes **exit codes verbatim**. Capped at 2 auto-fix cycles, 4 total gate executions. Explicitly must not be downgraded to a cheaper model — it parses compiler output, where a shallow read turns a failure into a false pass. |
| `agents/sdlc-review.md` | `Read, Grep, Glob, ReportFindings` | `SHIP` / `DO-NOT-SHIP:` | Reviews by **reading**. No `Bash` by design — a reviewer with a shell reviews by running things instead. No `Write`/`Edit` either. |

**Why four and not three:** the Bash split. Verify needs a shell; review must not have one. Merging them produces an agent that "reviews" by executing.

**Why they run in parallel:** gates are dispatched simultaneously against the same diff. Chaining them means a security finding can't surface until the build is green — slower, and it hides one class of problem behind another.

#### The seven shared skills (19 KB total)

Procedure lives here and is *referenced* by agents via `skills:` frontmatter, never pasted into agent bodies. That's what keeps agent bodies under 4 KB while five plugins share one convention source.

| File | Verb | Why it exists |
|---|---|---|
| `skills/evidence-contract/SKILL.md` | attest | Defines the only three shapes evidence may take: **exit code + output**, a **`file:line`**, or a **fetched URL**. Everything else carries a literal `ASSUMPTION:` prefix *at the point of use*, never a footnote. Written because the design process itself nearly derailed on contributors carrying 8–15 buried unverified items each. |
| `skills/output-contracts/SKILL.md` | emit | The four literal output templates and their forced tokens, in one place. Prevents four agent bodies from drifting to four slightly different formats. |
| `skills/arbitration/SKILL.md` | arbitrate | What happens when two stages disagree. Writes `docs/decisions/<slug>.md` and escalates to you. Never lets "whichever agent ran second" silently win. |
| `skills/vendoring-freshness/SKILL.md` | refresh | Header format for vendored files (`# vendored <pkg>@<ver> on <date>` + URL + license), license-check rules, and the instruction to **strip persona preambles**. The freshness checker *prints, never blocks* — frozen vendoring is a deliberate choice, not a defect. |
| `skills/secret-scan/SKILL.md` | scan | **Blocking.** Patterns for `VITE_*` credential reads, `.env`/`*.conf`, and — unusually — `*.sql`, because this codebase's real credential leaks have been PL/SQL signer procedures. Documents that `window.__ENV__` is *not* a fix, only a relocation. |
| `skills/walkthrough/SKILL.md` | — | The `docs/walkthroughs/<task-id>.md` template. **Manual verification steps** and **Not done** are both mandatory and non-empty — the former is the compensating control for having no React behavioural tests, the latter because silence about omitted scope reads as completion. |
| `skills/madvibe-task-sync/SKILL.md` | — | Task status as the concurrency lock. Since no agent may branch, `In Progress` is the only thing preventing two tasks interleaving in one working tree. ⚠️ **See gap G11 — the MCP server this depends on is not configured.** |

#### The entry point

| File | Why |
|---|---|
| `commands/sdlc-task.md` | The `/sdlc-task` pipeline: select task → plan → **stop for human approval** → lock → implement → gate+review in parallel → walkthrough → status update → **stop before commit**. Two hard human checkpoints, and it never mutates git. |

---

### 1.3 `react-sdlc` — React + Vite + TypeScript (28 files)

#### `react-bootstrap` (14 files, ~53 KB) — scaffold

| File | Why it exists |
|---|---|
| `SKILL.md` (12.5 KB) | Two version profiles (greenfield vs. adopt-in-place), each pin justified against what's actually installed. Also carries the cut list, so rejected choices don't get re-proposed. |
| `templates/eslint.config.js` | The repo has **zero** lint config today. Two trap comments are inline and load-bearing: `@eslint/js`'s npm `latest` is 10.0.1 (must hand-pin 9.39.5), and `@tanstack/eslint-plugin-query`'s flat config is an **Array** that must be spread, not nested. |
| `templates/tsconfig.json` | Matches the live config verbatim; the strict-flag ladder sits here as commented-out entries owned by `react-verify`. |
| `templates/package.scripts.snippet.json` | Adds `typecheck` and `lint` — neither exists in `package.json` today, which is why the repo has never type-checked. |
| `templates/Dockerfile` | Two-stage build with a `BASE_PATH` ARG. Every unconfirmed behaviour is marked inline against a numbered `react-ship` stop condition. |
| `templates/docker-nginx.conf` | The live config plus one new `/ords/` location. |
| `templates/docker-entrypoint.d/50-ords-auth.sh` | **The actual security fix.** Reads the ORDS credential from a Docker secret at container start and writes the `Authorization` header nginx injects — so the browser never receives it in any form. |
| `templates/public/config.js` + `config.local.example.js` | Runtime config with committed dev defaults + gitignored override, because a container entrypoint never runs under `vite dev`. Explicitly *not* for credentials. |
| `templates/forms/schema.ts`, `useEntityForm.ts`, `EntityForm.tsx` | react-hook-form + zod wiring (your resolved decision), modeled on the real Lead-save shape. |
| `templates/router-migration-example.tsx` | The one-line `react-router-dom` → `react-router` import change, verified against 14 real import sites. |
| `templates/project-tree.md` | Folder layout for both profiles. Vendors bulletproof-react's *concept only*, with header — never its `package.json`, which is 14 months stale. |

**The reason this skill exists at all:** `switch-env.cjs:88-94` hardcodes both ORDS credential pairs in a git-tracked file, and `config.ts:13-14` reads `VITE_API_PASSWORD`, which Vite inlines into the built bundle. The Dockerfile + nginx + entrypoint trio is the fix; the version pins are secondary.

#### `react-slice` (9 files, ~26 KB) — slice

One complete worked example ("Lead Tags") spanning every layer, chosen to be small enough to read end-to-end:

`templates/01-ddl.sql` → `02-engine-procedure.sql` → `03-ords-handler.sql` → `lead-tag-dto.types.ts` → `lead-tags.transformers.ts` → `lead-tags.api.ts` → `lead-tags.queries.ts` → `LeadTagsPanel.tsx`

**Why a worked example rather than abstract instructions:** the seam is the thing that goes wrong. Each file is modeled on real code (`xxcrm_get_leads_p` at `xxcrm-engine-pkg.sql:2345-2470`; the `/leads` handler at `ords-xxcrm-all-handlers.sql:115-165`), so the pattern is copyable rather than interpretable.

Two rules it enforces: snake_case↔camelCase translation happens **only** in `*.transformers.ts`, and `{ signal }` threads through every call. The second is a real gap it found — `BaseApiService` already accepts `AbortSignal`, TanStack Query already provides one, and **zero** existing call sites forward it, so abandoned queries complete and land in stale cache writes.

#### `react-verify` (2 files) — gate

`SKILL.md` + `scripts/gate.ps1` (PowerShell, since this machine is Windows). Runs `tsc --noEmit` + `eslint <diff>` + `vite build` and prints the exact table shape `sdlc-verify`'s output contract requires, so the agent pastes rather than re-derives. Also documents the strict-flag ladder — one flag at a time, each with a stated acceptance criterion.

#### `react-ship` (2 files) — release

`SKILL.md` + `scripts/ship.sh` (bash, mirroring the real `deploy.sh` SSH-heredoc pattern). **The script refuses to execute** until `REACT_SHIP_STOP_CONDITIONS_CONFIRMED=yes` is set, because five container behaviours were never verified: entrypoint execution on the unprivileged image, `--base` flag forwarding through npm, `ARG` expansion in a `COPY` **destination**, tag currency, and whether a UID-101 write into a chowned directory succeeds. Each has a concrete confirmation command in the SKILL.md.

**This refusal is the design working.** An unverified deploy path that runs is worse than one that stops.

---

### 1.4 `schema-architect` — Oracle DDL (15 files)

| Skill | Files | Why |
|---|---|---|
| `schema-model` | `SKILL.md` (14.9 KB) | The 9-step feature-request → DDL procedure, a relationship matrix with per-FK `ON DELETE` rationale, and the FK-indexing step (Oracle doesn't auto-index FKs the way it does PKs). Also documents the CRM-lowercase vs. XXUCL-uppercase convention split as a **per-project parameter**, not a universal rule. |
| `schema-emit` | `SKILL.md` + `business-table.sql`, `junction-table.sql`, `lookup-seed.sql` | Three real templates, idempotent via the `ORA-00955`-guard idiom (Oracle has no `CREATE TABLE IF NOT EXISTS`). |
| `schema-audit` | `SKILL.md` + 4 scripts | `xx-audit-conventions.sql`, `-sequences.sql`, `-lookups.sql`, `-invalid.sql`. **All four greenfield** — none existed anywhere. Every query is an exhaustive negative filter, so empty output is a real pass. |
| `schema-promote` | `SKILL.md` + 3 templates | XXINT→XXMGNT six-phase promotion, definer rights (your resolved decision), explicit per-package `EXECUTE` grants, and rollback policy varying by change class (additive / drop / backfill / package). |

**What makes these grounded rather than theoretical:** the audit scripts are written against real defects found on disk — `flw_up_required VARCHAR2(1)` violating the CHAR(1) rule, `XXCRM_RESOURCE_INDUSTRY_T`'s nullable WHO columns, and a lookup seed whose own backfill targets the wrong `lookup_type`. `schema-promote` explicitly refuses to copy the live `EXCEPTION WHEN OTHERS THEN NULL` grant-swallowing at `xxcrm-sync-xxint-to-xxmgnt.sql:28,40`.

---

### 1.5 `api-architect` — ORDS + PL/SQL (13 files)

| Skill | Files | Why |
|---|---|---|
| `api-contract` | `SKILL.md` + **`ORDS-HOUSE-CONTRACT.md` (16.8 KB)** | Rules **A1–A14** as a reviewable checklist plus a status-code map. Reviews cite `A#` by number rather than restating prose. The largest single file in the marketplace, and the one with the longest useful life. |
| `api-emit-handler` | `SKILL.md` + 4 templates | GET collection (paginated), GET by id, POST `/save`, and the engine-procedure skeleton — each modeled on a real handler with `file:line`. Every emitted procedure must open with `DBMS_APPLICATION_INFO.SET_MODULE` (a new requirement, absent from both existing packages). |
| `api-audit` | `SKILL.md` + `xx-audit-ords-drift.sql` (13.6 KB) | Diffs 56 hand-extracted handler rows against live `USER_ORDS_TEMPLATES`/`USER_ORDS_HANDLERS`, reporting `FILE_ONLY`/`LIVE_ONLY`. Plus a package-global-variable scan — those leak session state under ORDS's pooled connections. |
| `api-publish` | `SKILL.md` + `publish-module.sql`, `smoke-test.http` | `DELETE_MODULE` → `DEFINE_MODULE` (parameterized schema alias) → `ENABLE_SCHEMA` → drift audit → runnable smoke test. Enforces **file is truth**. |

**The single most important convention captured:** business rejections are returned as **HTTP 200 with a JSON-embedded `response_code`**, never a real 4xx. There are zero `:status_code` binds anywhere in the codebase. The contract therefore documents real 4xx as an explicit **proposal for new endpoints only**, gated on confirming the deployed ORDS version — not as something that already works.

---

### 1.6 `flutter-sdlc` — Flutter + bloc (23 files)

⚠️ **Built without an accessible Flutter project.** Every version and CI claim is `ASSUMPTION:`-marked. The authoring agent stalled partway; `flutter-ship/SKILL.md` was written separately to close the hole.

| Skill | Files | Why |
|---|---|---|
| `flutter-bootstrap` | `SKILL.md`, `analysis_options.yaml` (10.9 KB, vendored `very_good_analysis@10.3.0`, MIT header), `.brownfield.yaml`, `build.yaml`, 3 flavor entrypoints, `bootstrap.dart`, `tools/check_boundaries.dart` | The `.brownfield.yaml` matters: it lets strict analysis land on an existing codebase without instantly failing on legacy code. `check_boundaries.dart` is ~20 lines of Dart instead of an analyzer plugin — Dart has no `import/no-restricted-paths` equivalent, and a first-party analyzer plugin was the worst cost/benefit item in the whole design. |
| `flutter-slice` | `SKILL.md` + 8 Dart templates | Service → Repository returning `Result<T>` → Cubit with freezed sealed state → Screen with exhaustive `switch`. Every file was `dart format`-verified — the only real verification these got. |
| `flutter-verify` | `SKILL.md` + `coverage_ratchet.dart` | Blocking: `analyze --fatal-infos`, boundaries, `flutter test`. Advisory: bloc lint, coverage ratchet. |
| `flutter-ship` | `SKILL.md` + `key.properties.example` | Android flavors, signing, obfuscation **paired with symbol upload**, versionCode strategy. iOS is an explicit stub — impossible on win32 without a macOS runner. |

**Worth noting:** the flutter agent live-fetched pub.dev and found that the design doc's `bloc_lint@0.1.0-dev.24` **never existed** — the real history runs `0.1.0 → 0.2.0-dev.* → … → 0.4.2`. It corrected the doc rather than propagating the error. This is the evidence contract doing its job on the design document itself.

---

## Part 2 — Coverage against your lifecycle, and the gaps

### 2.1 The map

| Lifecycle stage you named | Coverage | Where it lives |
|---|---|---|
| **PRD / prompted requirements → architecture** | ❌ **None** | — |
| **Bootstrap: scalable architecture** | 🟡 Partial | `react-bootstrap/project-tree.md`, `flutter-bootstrap` |
| **Bootstrap: state management** | 🟡 Thin | Versions pinned; no store-architecture templates |
| **Bootstrap: routing** | 🟡 Thin | Import-migration example only; no route architecture |
| **UI/UX, frontend design, web design** | ❌ **None** | — |
| **Testing** | ❌ **Near-none** | Flutter runs `flutter test`; nothing *authors* tests |
| **Security** | 🟡 Partial | `secret-scan` (blocking), `sdlc-review` |
| **Backend / API best practices** | ✅ **Strong** | `schema-architect`, `api-architect` |
| **Technical docs / API docs / user guides (docx, screenshots)** | ❌ **None** | `walkthrough` writes one `.md` |
| **Deployment** | 🟡 Partial | `react-ship` (refuses to run), `flutter-ship` (thin) |

**Four of nine have zero implementation.** That is the honest headline.

### 2.2 The gaps, ordered by consequence

**G1 — No requirements intake. Nothing turns a PRD into work.**
`sdlc-plan` plans *one already-existing task*. There is no path from "here is a PRD / here is what I want" to epics, features, tasks, or an architecture proposal. The entire front of your lifecycle is missing. This is the largest gap and everything else in the pipeline assumes it's already been done by hand.
*To close:* a `sdlc-core:requirements-intake` skill (PRD → epic/feature/task decomposition with acceptance criteria) and a `sdlc-core:architect` skill (requirements → ADR + component/data-flow design). Probably a fifth agent, since decomposition is a different context shape from planning one task.

**G2 — No UI/UX layer whatsoever.**
You have `ui-ux-pro-max`, `frontend-design`, and `dataviz` installed. The design doc explicitly said stage skills should *delegate* to `ui-ux-pro-max` for all visual/typography/UX guidance and never restate design rules. **I did not implement that delegation.** `react-slice` emits a component with no design guidance at all — no layout system, no design tokens, no component-library convention, no accessibility pass, no responsive strategy, no dark mode.
*To close:* a `react-sdlc:react-ui` skill that delegates to `ui-ux-pro-max`, and a cross-reference from `react-slice`'s component step into it. Same for `flutter-slice` → mobile design.

**G3 — Nothing authors tests.**
React has no test tooling at all (an accepted gap in the design, but still a gap). Flutter *runs* `flutter test` but nothing *writes* the tests. There is no TDD path, no test-generation skill, no fixture/factory convention, no E2E strategy. `superpowers:test-driven-development` exists as a skill but nothing in this marketplace routes to it.
*To close:* a `<stack>-test` skill per stack, plus wiring the React test profile (vitest + RTL) that was pinned-but-never-installed.

**G4 — No document generation. Zero docx, zero screenshots.**
This was an explicit ask and there is nothing. No technical documentation generator, no API reference generator, no user guide, no docx output, no screenshot capture, no button/element highlighting or annotation. `walkthrough` writes a single markdown file about one task's changes — that is a change log, not documentation.
*To close:* the largest net-new build here. Needs (a) a doc-generation skill per artifact type (technical / API reference / user guide), (b) a markdown→docx converter (Pandoc, or `docx` via a script), (c) a browser-driven screenshot capture step, and (d) an annotation pass to highlight buttons/regions. The screenshot+annotation half is a genuine engineering task, not a prompt — likely Playwright driving the app, capturing named selectors, and compositing highlight overlays.

**G5 — Security is one scanner, not a practice.**
`secret-scan` is real and blocking, and `sdlc-review` reads diffs for security. But there's no dependency/CVE scanning (`osv-scanner`/`gitleaks` are *mentioned* in flutter-bootstrap, never implemented), no OWASP checklist, no threat modeling, no SAST, no authn/authz review skill. The repo's own `axios`/`vite` CVEs — the §0 items — remain the strongest evidence that dependency scanning is needed and absent.
*To close:* a `sdlc-core:dependency-audit` skill and an OWASP-structured review skill. A `/security-review` command already exists in your harness and could be routed to.

**G6 — State management and routing are pinned, not architected.**
`react-bootstrap` pins zustand 5.0.14 and react-router 7.18.2 and stops. There are no store-slice templates, no selector conventions (despite the design noting zustand selector footguns), no persistence/hydration pattern, no route-tree architecture, no guards, no lazy-loading or code-splitting strategy. The CRM's actual store split across `src/stores/` and legacy `src/store/` is documented in `AGENTS.md` but not addressed by any skill.
*To close:* extend `react-bootstrap` with store and route architecture templates; it's the cheapest gap on this list.

**G7 — Deployment is half-built by design, and CI doesn't exist.**
`react-ship` deliberately refuses to run until five container behaviours are confirmed — correct, but it means there is no working deploy path today. `flutter-ship` is admittedly the thinnest file in the set. There is no CI/CD pipeline generation at all (the repo has no `.github/workflows`), no IaC, no automated rollback, no environment promotion beyond the DB layer.

**G8 — The §8 multi-harness generator was never built.**
This was in the design doc and I did not implement it. Consequently: `.agent/agents/` is still 20 agents with **10 carrying dangling skill references**, `security-auditor` and `penetration-tester` still hold `Write`/`Edit` on read-only roles, and the 4 flat `.claude/skills/*.md` files that never load are still there. The design's own test — "the generator exits non-zero when a skill is deleted out from under an agent" — cannot be run.

**G9 — No observability, i18n, performance, or accessibility skills.**
`sentry_flutter` appears in the Flutter bootstrap; React has nothing. No i18n/l10n anywhere (flagged unresolved for Flutter in the design and still unresolved). No performance profiling. No a11y audit beyond `jsx-a11y` lint rules.

**G10 — No schema migration versioning.**
`schema-promote` moves objects between schemas but there's no migration history, no version table, no forward/backward migration pairing. Rollback is a documented policy, not an executable artifact.

**G11 — `madvibe-mcp` is not configured, and `/sdlc-task` depends on it.**
I verified this: `.mcp.json` contains only `oracle-db` and `code-review-graph`. The `madvibe-task-sync` skill and step 1 of `/sdlc-task` both call a server that isn't connected in this project. **As written, the pipeline's entry point cannot complete its first step.** Either the server needs configuring, or `/sdlc-task` needs a fallback that accepts a task description directly.

**G12 — Nothing has been executed.**
No plugin has been installed. No agent has run. No gate has fired. The `claude` CLI isn't on PATH in this shell, so even `plugin validate` never ran — all verification was my own structural checking (JSON parsing, frontmatter fields, reference resolution, tool allowlists), not the loader's.

### 2.3 What I'd do next, in order

1. **Configure or stub `madvibe-mcp`** (G11) — the pipeline has no working entry point without it. Cheapest possible fix, highest blocking value.
2. **Install and run one real task end-to-end** (G12) — every other estimate here is theoretical until the loader has accepted these files once.
3. **Wire UI/UX delegation** (G2) — you already own the skills; this is connection work, not authoring, and it's the gap most visible in daily use.
4. **Build requirements intake** (G1) — the largest missing capability, and the one that changes what the pipeline is *for*.
5. **Build document generation** (G4) — the largest *net-new* engineering effort, and worth scoping separately (the screenshot/annotation half especially).

Items 3–5 are each comparable in size to one of the stack plugins already built. Attempting all three in one pass would repeat the mistake the design doc's own D13 was written to prevent.
