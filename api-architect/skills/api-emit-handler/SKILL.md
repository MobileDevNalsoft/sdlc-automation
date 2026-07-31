---
name: api-emit-handler
description: Use when a plan calls for a new REST endpoint (GET collection with pagination, GET by id, or a create/replace/update/delete write endpoint) plus its backing procedure. Dispatched by a developer/build agent by name when a task needs a new API handler. Provides ready-to-fill templates for the confirmed handler shapes, following api-contract's rules — Oracle ORDS + PL/SQL is the worked implementation, generalizable to any stack.
---

# api-emit-handler

**Verb: emit-handler.**

## What this skill is

Real, fillable templates in `templates/` — not pseudocode. Each is a
concrete Oracle ORDS + PL/SQL binding of the stack-neutral rules in
`api-architect:api-contract`'s `API-CONTRACT.md`; read that file first if you
haven't — these templates implement rules A1–A22, they don't re-explain them.

| Template | Shape | Rules applied |
|---|---|---|
| `templates/get-collection-paginated.sql` | `GET /<resources>` — offset pagination by default, cursor/keyset variant included | A1, A3, A4, A7, A8, A9, A18 |
| `templates/get-by-id.sql` | `GET /<resources>/{id}` | A2, A3, A4, A8, A9, A18 |
| `templates/write-operations.sql` | `POST /<resources>` create, `PUT`/`PATCH /<resources>/{id}`, `DELETE /<resources>/{id}` — plus the legacy single-`/save` alternative for reference | A3, A4, A10, A11, A18 |
| `templates/engine-procedure-template.sql` | The backing procedure body for a create/write endpoint | A4, A5, A8, A9, A10, A18, A19, A22 |
| `templates/problem-json-helper.sql` | RFC 9457 `application/problem+json` builder, called from every error path | A5 |

## Non-negotiables (do not deviate without a `BLOCKED:`/`NEEDS-DECISION:`)

1. **Every emitted procedure opens with tracing** (A18 — `DBMS_APPLICATION_INFO.SET_MODULE`/`SET_ACTION` for the ORDS binding, or your platform's equivalent). Check for it before calling any generated code done.
2. **Structural validation, then business-rule validation, both before any DML** (A19). See `engine-procedure-template.sql` sections 4–5.
3. **Identity is resolved from the validated credential, never from the request payload** (A9). A payload field naming a user is at most a hint to cross-check, never the value actually written.
4. **New endpoints use real HTTP status codes (A4) and RFC 9457 problem+json error bodies (A5) by default.** The legacy always-200/embedded-result-code shape (L1 in `API-CONTRACT.md`) is for *existing* endpoints only, migrated one at a time — never start a new endpoint that way. For the ORDS binding specifically: confirm the deployed ORDS version is ≥18.3 before relying on the `:status_code` bind (verified against Oracle's own 18.3-tagged docs — see `API-CONTRACT.md` A4); if you can't confirm the version this session, say so explicitly rather than guessing.
5. **Prefer resource-oriented verbs** (`POST /<resources>`, `PUT`/`PATCH`/`DELETE /<resources>/{id}`) over a single `/save` endpoint for new work (A3). Emit the legacy `/save` shape only when the task explicitly asks for it (e.g. adding one more write path to an existing resource that already uses that convention).
6. **Unsafe retryable writes accept an idempotency key** (A10); concurrent-safe updates support optimistic concurrency via `If-Match`/a version field (A11).
7. **JSON field casing is consistent, and translated at exactly one boundary** (A6) — do not let a second casing convention slip in because "it's just this one field."

## Procedure

1. Confirm which shape(s) the task needs — a new resource typically needs
   all of: list, detail, create, and at least one of replace/update/delete.
2. Copy the relevant template(s), fill every `{{PLACEHOLDER}}` — do not leave
   a placeholder token in emitted code.
3. Fill `engine-procedure-template.sql` for each write endpoint's backing
   procedure. Keep the section order (tracing → identity → idempotency →
   structural validation → business validation → concurrency → DML →
   response) — it's the point of the template, not incidental formatting.
4. Wire every error path through `problem-json-helper.sql`'s builder rather
   than hand-assembling problem+json inline at each call site.
5. Hand off to `api-architect:api-audit` after publishing (via
   `api-architect:api-publish`) to confirm the new template/handler actually
   landed as declared.

## The PL/SQL these templates generate is bound by `plsql-conventions`

Every engine procedure emitted here is PL/SQL, so it is governed by
`schema-architect:plsql-conventions` (P1–P20) as well as by the HTTP contract.
The four that bite hardest in a handler:

- **P1** — the procedure carries the `_p` suffix (or the target schema's own
  convention, if it already has one).
- **P13** — a collection response body is a **`CLOB` out-bind, never
  `VARCHAR2`**. PL/SQL's `VARCHAR2` caps at 32,767 bytes, so a `VARCHAR2` body
  fails at precisely the size the endpoint was built to serve. Assemble with
  `dbms_lob.writeappend` or `JSON_ARRAYAGG ... RETURNING CLOB`.
- **P17** — no request state in package globals. Under ORDS's pooled
  connections a package variable outlives the request and leaks into the next
  one, which is an identity-disclosure bug, not untidiness. `api-audit` scans
  for this.
- **P12** — chunk internal fetches with `BULK COLLECT ... LIMIT`.

Bind naming: the collection template deliberately avoids `:page_size` /
`:page_offset`, which are **reserved ORDS implicit parameter names** — see
A7's ORDS binding section before renaming any bind.

## Stop conditions

- The task asks for a path shape not covered by A1–A3 (e.g. a nested
  sub-resource, a bulk/batch endpoint) — that's a `NEEDS-DECISION`, not a
  judgment call to improvise silently.
- The task returns a `SYS_REFCURSOR` from a collection handler — **ORDS does
  not paginate it** (A7). Either hand-roll pagination or convert to the
  materialized-CLOB shape these templates use; do not ship an unbounded
  cursor and assume ORDS bounds it.
- The task asks for real HTTP status codes on an ORDS PL/SQL handler and the
  deployed ORDS version hasn't been confirmed ≥18.3 — stop and surface this
  as a precondition, don't ship `:status_code` binds on a guess.
- The task asks to keep using the always-200/embedded-result-code shape for
  a *new* endpoint "for consistency" — push back; consistency with a legacy
  pattern is not a reason to extend it (A4, L1). Emitting the legacy shape is
  fine when explicitly asked for an *existing*, not-yet-migrated resource.
