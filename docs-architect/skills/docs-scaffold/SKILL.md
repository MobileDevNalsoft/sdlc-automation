---
name: docs-scaffold
description: Emits the comprehensive 10-document context and governance suite (PRD, UX_FLOWS, DESIGN_SYSTEM, ARCHITECTURE, DATABASE, API, SECURITY, CODE_STYLE, TESTING, AGENTS) for any new project or major architecture upgrade. Establishes context before code so AI coding agents implement with zero ambiguity. Dispatched by react-bootstrap, flutter-bootstrap, agent-bootstrap, or directly via /sdlc-plan.
---

# docs-scaffold

**Verb: scaffold-docs.**

## What this skill is for

This skill establishes the **deterministic documentation foundation** for an application before implementation code is written. It synthesizes the Vibe Coding Blueprint with enterprise production standards (RFC 9457 error contracts, 5-state UI ladders, optimistic concurrency, boundary linting, and 3-Tier context memory).

## The 10-Document Suite Contract

Every new project or greenfield application must carry these ten documents in `docs/` (with `AGENTS.md` at repository root):

| Document | Primary Owner | Mandatory Invariants |
|---|---|---|
| `docs/PRD.md` | Business / Product | User stories, acceptance criteria, edge cases, non-goals, MVP scope, 10-column Field Properties table. |
| `docs/UX_FLOWS.md` | Product / UI | Step-by-step user journeys; explicitly declares Loading, Empty, Error, Gated, and Loaded states for every flow. |
| `docs/DESIGN_SYSTEM.md` | UI / UX | Design tokens (palette, typography, spacing, radius, shadows), WCAG 2.1 AA contrast rules, component specs. |
| `docs/ARCHITECTURE.md` | Architecture | System topology, data flow, component boundaries, ADR log, failure modes. |
| `docs/DATABASE.md` | Data / Backend | Physical tables, relationships, `object_version_number` concurrency locks, `active_flag` soft deletes, audit columns. |
| `docs/API.md` | Backend / API | Endpoint contracts, query/body schemas, RFC 9457 problem details, idempotency, HTTP status codes. |
| `docs/SECURITY.md` | Security | Auth provider, RBAC permission tokens, client credential isolation, CORS, PII logging prohibition, upload validation. |
| `docs/CODE_STYLE.md` | Engineering | Feature-first folder layout, boundary rules (zero sibling imports), naming conventions, linter rules. |
| `docs/TESTING.md` | QA / Engineering | Unit/Integration/E2E structure, coverage priorities, deterministic test commands (`typecheck`, `lint`, `test`, `build`). |
| `AGENTS.md` | AI Governance | Operational instructions: STE-100 syntax, 3-Tier context protocol, planning/verification gates. |

---

## Execution Procedure

When invoked for a project at `<project-root>`:

1. Create directory `<project-root>/docs/` if not present.
2. Read project archetype from parameters (`react`, `flutter`, `agent`, or `fullstack`).
3. Copy and hydrate each template from `templates/` into `<project-root>/docs/`:
   - Replace project placeholders `[Project Name]`, `[Description]`, `[Target Stack]`.
   - Embed stack-specific conventions (e.g. Tailwind v4 for React, BLoC/ThemeData for Flutter, LangGraph StateGraph for Agent).
4. Write `<project-root>/AGENTS.md` linking to each document in `docs/` and activating the 3-Tier context rules.
5. Initialize or confirm `llmwiki/` synthesized architecture memory (`docs-context`).
6. Report completion with the table of created documents.

---

## The Rule of Honest Specifications

1. **No Invented Decisions**: Any unmade architectural or domain decision must be written as `GAP: [Description of missing decision]` rather than filled with a fictitious default.
2. **Deterministic State Coverage**: A flow without an Error State or Empty State specification is rejected.
3. **No Unenforceable Guidelines**: Every rule in `CODE_STYLE.md` and `SECURITY.md` must link to an automated linter rule, build gate, or verifiable code pattern.
