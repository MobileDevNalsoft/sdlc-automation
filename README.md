# sdlc-automation

A full-stack, enterprise-grade SDLC automation suite: **7 plugins · 4 agents · 40 skills**.

Human-triggered, agent-assisted delivery across **React 19 + Vite 8**, **Flutter + BLoC**, **AI Agents (LangGraph/CrewAI)**, **Oracle DB Schemas**, and **REST/ORDS APIs**. 

Two foundational invariants: **never proceed past an unverified decision**, and **never mutate git state** (commits and pushes remain 100% human-controlled).

---

## 1. Quick Start & Execution

### Global Setup in Antigravity / Claude Code
The plugin is linked into your global configuration at `~/.gemini/config/plugins/sdlc-automation/` with its source repository at `D:\madhan-utils\toolkit\ai-plugins\sdlc-automation`.

### Running a Complete Task
To run an end-to-end task (plan → human approval → implement → verify in parallel → walkthrough):
```bash
/sdlc-core:sdlc-task <task-id or task description>
```

### Scaffolding New Projects (Day 0)
1. **Emit Context & Documentation Suite (All Stacks)**:
   Invoke `docs-architect:docs-scaffold` to generate the 10-document contract in `docs/` (`PRD.md`, `UX_FLOWS.md`, `DESIGN_SYSTEM.md`, `ARCHITECTURE.md`, `DATABASE.md`, `API.md`, `SECURITY.md`, `CODE_STYLE.md`, `TESTING.md`, `AGENTS.md`).
2. **Scaffold React Greenfield App**:
   Invoke `react-sdlc:react-bootstrap` (emits React 19, Vite 8, Tailwind v4 `@theme`, 5-state UI primitives, Axios client with RFC 9457 error handling).
3. **Scaffold Flutter Mobile App**:
   Invoke `flutter-sdlc:flutter-bootstrap` (emits Flutter 3, BLoC/Cubit, GoRouter, Freezed, check_boundaries.dart, 5-state widgets).
4. **Scaffold AI Agent System**:
   Invoke `agent-sdlc:agent-bootstrap` (emits LangGraph StateGraph, typed Pydantic state, SQLite/PG checkpointer, human-in-the-loop review nodes).

---

## 2. The Four Autonomous Agents

Each agent has an explicit `tools` allowlist (never `*`), strict <4 KB context limits, and finishes on a single terminal routing token.

| Agent | Scoped Tools | Terminal Token | Responsibility & When to Use |
|---|---|---|---|
| **@sdlc-plan** | `Read, Write, Edit, Grep, Glob, WebFetch` | `PLAN-READY` / `NEEDS-DECISION` | **Planning Phase**: Loads 3-tier context (AST → Graph → Wiki) *before* reading source. Produces Skill Decision Record, names every affected file, chooses execution strategy, and authors `docs/plans/<task-id>.md`. Never writes code. |
| **@sdlc-developer** | `Read, Write, Edit, Grep, Glob, Bash` | `IMPLEMENTED` / `BLOCKED` | **Implementation Phase**: Dispatched only after plan approval. Implements one vertical slice in dependency order. Raises `SCOPE-REQUEST` before editing any unlisted file. Never mutates git. |
| **@sdlc-verify** | `Read, Grep, Glob, Bash` | `GATE-PASS` / `GATE-FAIL` | **Build & Quality Gate**: Runs compiler, boundary linter, and unit tests. Capped at 2 auto-fix cycles. Quotes verbatim non-zero exit codes. Never summarizes output without proof. |
| **@sdlc-review** | `Read, Grep, Glob, ReportFindings` | `SHIP` / `DO-NOT-SHIP` | **Read-Only Code Review**: Reviews diffs for security vulnerabilities, RFC 9457 compliance, secret leaks, and architectural drift. Has no shell access by design. |

---

## 3. The Seven Modular Plugins (40 Skills)

### 3.1 `docs-architect` — Documentation Lifecycle (6 Skills)
| Skill | Verb | When to Use & Responsibility |
|---|---|---|
| `docs-scaffold` | scaffold-docs | **Day 0 of any project**: Emits the 10-document context suite into `docs/` and root `AGENTS.md`. Establishes context before code. |
| `docs-context` | index | **Start of task & after structural changes**: Establishes or refreshes 3-tier memory (`.code-review-graph/`, `graphify-out/`, `llmwiki/`). |
| `docs-prd` | specify | **Before code**: Writes business-signed MD.050 / PRD with wireframes, validations, and the 10-column Field Properties contract. |
| `docs-onboarding` | onboard | **After greenfield build**: Generates cross-stack architecture trace (`CODEBASE_ONBOARDING.md`) with Mermaid diagrams and Flaws & Risks audit. |
| `docs-reference` | reference | **Post-deployment**: Generates exhaustive schema and REST API reference from the live data dictionary. |
| `docs-guide` | guide | **End-user delivery**: Generates task-oriented user guides with screenshot manifests. |

### 3.2 `react-sdlc` — React 19 + Vite 8 + Tailwind v4 (4 Skills)
| Skill | Verb | When to Use & Responsibility |
|---|---|---|
| `react-bootstrap` | scaffold | Scaffolds React 19 + Vite 8 + Tailwind v4 `@theme`. Emits 5-State UI primitives (`LoadingState`, `EmptyState`, `ErrorState`, `PermissionGate`), RFC 9457 Axios client, Zustand stores, and ESLint boundary config. |
| `react-slice` | slice | Implements one vertical slice: DTO → Transformer → API Client → Query/Mutation Hook → Component with all 5 UI states. |
| `react-verify` | gate | Executes `tsc --noEmit` and `eslint <diff>` with strict boundary enforcement. |
| `react-ship` | release | Generates production Dockerfile with unprivileged runtime and reverse-proxy credential isolation. |

### 3.3 `flutter-sdlc` — Flutter + BLoC + Freezed (4 Skills)
| Skill | Verb | When to Use & Responsibility |
|---|---|---|
| `flutter-bootstrap` | scaffold | Scaffolds Flutter app with `flutter_bloc`, GoRouter, Freezed, `AppTheme` tokens, 5-state widgets, and `tools/check_boundaries.dart`. |
| `flutter-slice` | slice | Implements one mobile vertical slice: Service → Repository returning `Result<T>` → Cubit → Screen with exhaustive state switch. |
| `flutter-verify` | gate | Executes `flutter analyze --fatal-infos`, `check_boundaries.dart`, and `flutter test`. |
| `flutter-ship` | release | Generates Android flavor builds, signing, obfuscation, and symbol mapping. |

### 3.4 `agent-sdlc` — AI Agents (LangGraph / CrewAI) (4 Skills)
| Skill | Verb | When to Use & Responsibility |
|---|---|---|
| `agent-bootstrap` | scaffold-agent | Scaffolds LangGraph StateGraph applications: Pydantic v2 state schemas, SQLite/PostgreSQL checkpointing persistence, human-in-the-loop review nodes, and context firewalls. |
| `agent-slice` | slice-agent | Adds a new specialized agent node, a tool with strict Pydantic parameter schemas, or an edge routing branch to an existing StateGraph. |
| `agent-verify` | verify-agent | Executes `ruff check .`, `mypy src`, and `pytest` state transition tests. |
| `agent-ship` | ship-agent | Builds unprivileged Python Docker container with externalized environment secrets and `/healthz` checkpointer health probes. |

### 3.5 `schema-architect` — Database & Schemas (6 Skills)
| Skill | Verb | When to Use & Responsibility |
|---|---|---|
| `schema-model` | model | Models tables, constraints, foreign keys with explicit `ON DELETE` rules, and indexes. |
| `schema-emit` | emit-ddl | Emits DDL adhering to the 6 invariant columns: `object_version_number`, `active_flag`, `created_by`, `creation_date`, `last_updated_by`, `last_update_date`. |
| `schema-document` | document | Generates the 12-section database design document (MD.070) with ER diagrams and data dictionary. |
| `schema-audit` | audit | Runs SQL audit checks against database dictionaries for convention drift, invalid objects, and sequence gaps. |
| `schema-promote` | promote | Generates forward promotion scripts and versioned rollbacks. |
| `plsql-conventions` | conform | Enforces PL/SQL rules: scope prefixes (`l_`, `p_`, `g_`), bulk fetching, CLOB handling, and package state isolation. |

### 3.6 `api-architect` — REST & ORDS APIs (5 Skills)
| Skill | Verb | When to Use & Responsibility |
|---|---|---|
| `api-contract` | contract | Enforces REST conventions: RFC 9457 error payloads, safe SQL parameter binds (no reserved `:q` or `:limit`), idempotency, and pagination. |
| `api-emit-handler` | emit-handler | Emits ORDS / REST API handlers with input validation, optimistic locking checks, and audit logging. |
| `api-collection` | collect | Emits synchronized Postman v2.1 collection and `api.md` contract from a single manifest. |
| `api-audit` | audit | Audits deployed API endpoints against declared contracts and detects state leakage in connection pools. |
| `api-publish` | publish | Deploys modules to ORDS with automated teardown, definition, schema enabling, and smoke testing. |

### 3.7 `sdlc-core` — Shared Process & Quality (11 Skills)
| Skill | Verb | When to Use & Responsibility |
|---|---|---|
| `evidence-contract` | attest | Enforces factual assertions: requires exit codes, verbatim output, or `file:line` citations. |
| `output-contracts` | emit | Standardizes agent output templates and routing tokens across all tools. |
| `secret-scan` | scan | **Blocking on every task**: Scans diffs for API keys, hardcoded passwords, and Vite client secret inlining. |
| `dependency-audit` | audit | Audits package manifests and lockfiles for known CVEs. |
| `ui-ux-web` | design (web) | Governs web visual design, typography, spacing, and micro-interactions. |
| `ui-ux-mobile` | design (mobile) | Governs mobile UX, thumb reach zones, safe areas, and platform gestures. |
| `ui-ux-review` | review (UI) | Audits UI diffs against Dieter Rams principles and accessibility standards. |
| `arbitration` | arbitrate | Resolves conflicting requirements by writing an ADR in `docs/decisions/` and requesting human sign-off. |
| `vendoring-freshness`| refresh | Enforces attribution headers and freshness dates on all vendored templates and libraries. |
| `walkthrough` | document | Generates `docs/walkthroughs/<task-id>.md` with mandatory manual verification proof. |
| `doc-coherence` | reconcile | Audits cross-document synchronization between PRD, Schema DDL, and API collections. |

---

## 4. Verification & Testing

Every task executed through this suite gates on deterministic tool exits:
```bash
# Web Gate
npm run typecheck && npm run lint && npm run test

# Flutter Gate
flutter analyze --fatal-infos && dart run tools/check_boundaries.dart && flutter test

# AI Agent Gate
ruff check . && mypy src && pytest tests/
```
No task completes without exit code 0 across all applicable gates.
