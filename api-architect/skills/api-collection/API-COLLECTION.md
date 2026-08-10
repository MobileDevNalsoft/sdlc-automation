# API collection & reference — rules C1–C16

The contract `api-collection`'s scripts implement. Cite by number in review.

Endpoint *shape* rules live in `api-contract`'s `API-CONTRACT.md` as A1–A23.
These rules govern only how a specified API becomes a collection and a reference
document.

---

## The manifest

### C1 — The manifest is the single source; both outputs are generated

Collection and markdown come from one file in one run. Neither is hand-authored,
and neither is the source for the other.

The manifest is checked in and reviewed like code. It is the artifact a change
to the API edits.

### C2 — The manifest extends `api-audit`'s, it does not fork it

`api-audit/api-manifest.example.json` requires `module_name` and
`endpoints[].{path, method}`. Every field this skill adds is **optional** and
ignored by `audit-ords-drift.sql`.

One manifest serving pre-deployment generation and post-deployment drift audit is
the point. Two manifests would drift from each other, which is the defect this
whole skill exists to remove, reintroduced one level up.

### C3 — Every endpoint carries at least one saved response example

| State | `api.md` renders | Collection |
|---|---|---|
| Example captured from a real call | The body | Saved response |
| Hand-written example (`"exampleSource": "hand-written"`) | The body, labelled `EXAMPLE NOT CAPTURED FROM A LIVE CALL` | Saved response, same label in its name |
| No example | `NO EXAMPLE CAPTURED` | Request with no saved response |

**Never fabricate a body and present it as captured.** A consumer codes against
examples; a fictional field name costs more than an admitted blank. The
distinction between "captured" and "hand-written" is the whole reason the third
column exists.

### C4 — Auth is a collection-level variable

Declared once at collection level as `{{token}}`, inherited by every request.
`base_url` likewise. No literal host, no literal credential, anywhere in the
file.

The manifest's `auth.loginEndpoint` lets the collection ship a login request and
a pre-request script that stores the token into the collection variable. That
removes the reason anyone would paste one.

### C5 — Real status codes are documented per endpoint

Every response a consumer can receive: the success code, the validation failure,
the auth failure, the not-found, the conflict. With RFC 9457 `problem+json`
bodies for the failures, per A4.

An endpoint documented with only its happy path is documented for the case
nobody needs help with.

### C6 — The legacy always-200 envelope is labelled, never normalized

`"legacyEnvelope": true` renders under a **Legacy response envelope** heading in
`api.md`, stating that HTTP is always 200 and the real outcome is in
`response_code`, and listing the `response_code` values.

Documenting the intended contract instead of the delivered one makes the document
actively harmful. Fixing the pattern is A2's business; describing it truthfully
is this rule's, and the second does not wait for the first.

---

## Collection structure

### C7 — One folder per resource, named for the resource

`Leave`, `Assets`, `Tickets`. Not `GET requests` / `POST requests` — grouping by
verb makes a consumer looking for "everything about leave" read the whole
collection.

Sub-folders one level deep, maximum. Beyond that a collection navigates worse
than the markdown.

### C8 — Request names are imperative and unique within their folder

`Create request`, `Approve request`, `List balances`. Not `POST /leave/requests`
— the method and URL are already displayed by Postman, and duplicating them
means a renamed path leaves a stale name behind.

The `Folder / Request name` pair is the join key `doc-coherence` matches on, so
it must be stable. Renaming a request is a registry edit.

### C9 — Paths use ORDS template form, once

`leave/requests/:id/approve`. Never `{id}`, and never both.

ORDS templates and Postman path variables share the `:name` syntax, so one
spelling flows through the manifest, the collection, `api.md` and the traceability
registry with no transformation. A translation step would make
`doc-coherence`'s endpoint check fail on endpoints that are genuinely documented.

### C10 — Path variables are declared, not just interpolated

Postman's `url.variable` array carries each `:name` with a description and a
sample value, so the request is runnable on open rather than after the consumer
guesses what `:id` wants.

### C11 — Query parameters are enumerated, including the ones left disabled

Every optional filter appears in `url.query` with `"disabled": true` and a
description. A consumer discovers a filter by seeing it greyed out; they do not
discover it by reading a paragraph.

Pagination parameters follow A7 — for ORDS, `:fetch_offset` / `:fetch_size`.
`:page_size` is deprecated **and reserved**, and a PL/SQL handler's ref cursor is
**not** auto-paginated, so a manifest claiming pagination on such a handler is
claiming behaviour that does not exist.

### C12 — `info._postman_id` is deterministic

Derived from the collection name by hash, not randomly generated. A checked-in
file that changes identity on every emit trains reviewers to ignore its diffs,
which is how a real change gets waved through.

### C13 — A `Smoke` folder is emitted when the manifest marks endpoints for it

`"smoke": true` on an endpoint adds it to a `Smoke` folder, ordered so a login
runs first. Runnable with:

```
newman run <collection> --folder Smoke --env-var base_url=<host> --env-var token=<token>
```

If `newman` is absent, that is **NOT RUN**. A generated smoke folder is not
evidence that anything passes — nothing was executed.

---

## `api.md`

### C14 — Structure

1. **Header** — module, base path, auth scheme, and the source label
   (`SOURCE: API MANIFEST, NOT VERIFIED AGAINST A DEPLOYED MODULE`) so a reader
   knows this is the specification and not the deployment.
2. **Endpoint index** — one table: method, path, unit id, summary. This is what
   people actually read.
3. **Per endpoint** — path and method, unit id, auth requirement, path variables,
   query parameters, request body with its example, every response with its
   status and example, and error cases.
4. **Legacy envelope section**, if any endpoint carries C6.

### C15 — The source label is in the header, not a footnote

Same rule as `docs-reference` and `schema-document`. A reader who does not know
whether a document describes the specification or the deployment cannot judge a
disagreement, and disagreements are the interesting part.

---

## Regeneration

### C16 — Never regenerate over unaudited hand edits

`emit-collection.ps1` stamps a hash of the emitted content into
`info.description`, and on the next run recomputes it from the file on disk. A
mismatch means the file changed after it was written, and the run **refuses**
unless `-Force` is passed. An untouched file is overwritten freely — a newer
manifest is the reason to regenerate.

Presence of the marker alone is not enough to check. A collection that this
script generated and a person then edited still carries the marker, and that is
precisely the case worth protecting.

Order of operations:

1. `audit-collection.ps1` — see what diverged.
2. `EXTRA-IN-COLLECTION` findings: decide per request. A useful request someone
   added in Postman gets **folded into the manifest**; only then does the
   generator own it.
3. `emit-collection.ps1 -Force`.
4. `check-coherence.ps1` — the registry, the PRD and the schema document agree.

A generator that silently destroys the work its own workflow invites is worse
than no generator, because the loss is discovered later and blamed on the person
who lost it.
