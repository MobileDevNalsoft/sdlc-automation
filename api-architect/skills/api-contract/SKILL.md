---
name: api-contract
description: Use whenever an agent or skill is about to design, review, or approve a REST API endpoint — resource-oriented paths and verbs, real HTTP status codes vs. the legacy always-200 pattern, RFC 9457 problem+json error bodies, offset vs. cursor pagination, bearer-token auth, server-side identity resolution, optimistic concurrency, and versioning. Stack-neutral; Oracle ORDS + PL/SQL is the primary worked binding. Load before a plan approves a new-endpoint task and before any review of a handler/route diff.
---

# api-contract

**Verb: contract.**

## What this skill is

A lookup, not a generator. The REST API conventions this plugin recommends
live in **`API-CONTRACT.md`** in this same skill directory, as rules **A1
through A22** plus a clearly separated legacy-patterns-and-migration
section. Read that file — this SKILL.md only tells you when and how to use
it.

The contract is stack-neutral: every rule states the underlying HTTP/REST
principle first, with an "ORDS binding" callout showing the concrete Oracle
ORDS + PL/SQL mechanism where relevant. If your stack isn't ORDS, apply the
rule and substitute your own framework's equivalent (e.g. a status-code
return value instead of an ORDS `:status_code` bind).

## When to load this

- Before a planning step approves a task that adds or changes an API
  endpoint — cite the specific `A#` rules the plan needs to satisfy.
- Before `api-emit-handler` is dispatched to generate a new endpoint — that
  skill's templates already encode these rules, but the dispatching agent
  should still know which rule is which when it explains a deviation.
- During any code-review pass over a handler/route diff — cite the violated
  `A#` by number, don't restate the rule prose in the review comment.
- Whenever someone proposes a new convention (a new path shape, a new
  status-code strategy, a new auth header) — check whether it's already
  covered by A1–A22, or whether it's actually one of the **legacy patterns**
  documented at the bottom of `API-CONTRACT.md` re-appearing under a new
  name. Several plausible-sounding shortcuts (always-200 with an embedded
  result code, a single `/save` endpoint for create-and-update, a custom
  session header) are legacy artifacts with real, stated costs — not
  competing conventions of equal standing.

## How to use the checklist

Cite rules by ID, not by paraphrase — `"violates A9: created_by is read from
the request body, not from the resolved credential"` is a review comment;
`"identity looks wrong here"` is not. This keeps review threads short and
lets `api-audit` and `api-emit-handler` refer back to the same rule numbers.

## The one thing to never forget

Rule **A4** is the single biggest correction this contract makes over
naive/legacy practice: HTTP status codes carry the real result, not a
JSON-embedded field. If you inherit a codebase that returns HTTP 200 for
every outcome (see `API-CONTRACT.md`'s **L1**), that is a legacy pattern to
migrate off incrementally and per-endpoint — never treat it as the target
state for new work, and never propose flipping it globally in one pass (see
L1's migration guidance for why a simultaneous flip is itself a breaking
change).
