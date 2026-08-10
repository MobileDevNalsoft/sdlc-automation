---
name: api-collection
description: Use to produce a runnable Postman v2.1 collection AND the API reference markdown from one API manifest, so the two cannot disagree — folders per resource, a saved example response per request, collection-level bearer auth, and a drift audit that reports a hand-edited collection instead of overwriting it. Fills the gap docs-reference cannot: it works before anything is deployed. Load after api-contract has settled endpoint shape and before publishing or handing an API to a consumer.
---

# api-collection

**Verb: collect.**

## Why this exists alongside `docs-reference`

`docs-reference` generates API documentation from `USER_ORDS_MODULES` /
`USER_ORDS_TEMPLATES` / `USER_ORDS_HANDLERS` — the deployed truth. That is the
right source once something is deployed, and no source at all before.

This skill covers the other half of the lifecycle:

| | `api-collection` | `docs-reference` |
|---|---|---|
| Source | the API manifest (a checked-in file) | the live ORDS dictionary |
| Answers | what the API is **specified** to be | what is **actually** deployed |
| Works | before deployment | after deployment |
| Output | Postman collection + `api.md` | `docs/reference/api.md` |

They will eventually both produce API documentation, and **when they disagree
after deployment that is real drift** — a finding, not a merge conflict.
`api-audit` is what adjudicates it.

## The rule that makes this skill worth having

**One manifest, two outputs, both generated. A hand-edited collection is drift,
reported rather than silently overwritten.**

The usual arrangement is a Postman collection someone maintains by clicking, and
API documentation someone maintains by typing. They diverge immediately, and the
divergence is invisible because nothing compares them. Generating both from one
file makes agreement structural instead of aspirational.

The corollary matters as much: because the collection is generated, **someone
will edit it in Postman anyway** — that is what Postman is for. So this skill
ships an audit that detects it and tells you what was added, rather than a
generator that quietly destroys an afternoon's work on the next run.

## The manifest

**Extends `api-audit`'s `api-manifest.example.json` rather than forking it.**
`api-audit`'s drift script reads `module_name` and `endpoints[].{path,method}`;
everything this skill adds is optional and ignored by that script. One file, two
consumers. See `api-manifest.example.json` here for the full shape.

```json
{
  "module_name": "npt",
  "collection_name": "Nalsoft Portal (NPT)",
  "base_path": "/ords/xxnpt/npt",
  "auth": { "type": "bearer", "variable": "token", "loginEndpoint": "auth/login" },
  "endpoints": [
    {
      "path": "leave/requests", "method": "POST",
      "unit": "NPT-P07", "folder": "Leave", "name": "Create request",
      "summary": "Raise a leave request for the authenticated employee.",
      "requestBody": { "example": { "leave_type_id": 1, "from_date": "2026-08-18" } },
      "responses": [
        { "status": 201, "description": "Created", "example": { "leave_request_id": 142 } },
        { "status": 422, "description": "Validation failed", "problem": true,
          "example": { "type": "about:blank", "title": "Validation failed", "status": 422 } }
      ]
    }
  ]
}
```

Rules **C1–C16** are in **`API-COLLECTION.md`**. The five that get broken:

### C3 — Every request carries a saved example response

A request with a URL and no example is a call list. A request with a real
response body is documentation — it is how a consumer learns the field names, the
null-vs-absent convention, and the date format without asking.

An endpoint with no example is emitted, and `api.md` says
**`NO EXAMPLE CAPTURED`** against it. Never an invented payload: a fabricated
response is worse than an absent one, because a consumer will code against it.

### C4 — Auth is a collection-level variable, never a literal

`{{token}}`, resolved from a collection or environment variable, declared once at
collection level and inherited. Never a bearer string pasted into a request
header.

`sdlc-core:secret-scan` will catch a committed token, but catching it there means
it was already committed. This is the upstream fix. The manifest names the login
endpoint so the collection can ship a pre-request script that fetches a token
rather than tempting anyone to paste one.

### C6 — The legacy always-200 envelope is labelled, not normalized

Where a handler returns `{ response_code, response_message, data }` with HTTP
200 regardless of outcome, the manifest marks it `"legacyEnvelope": true` and
`api.md` renders it under a **Legacy response envelope** heading naming the real
outcome codes carried in the body.

Do not quietly rewrite it as `201`/`422` in the documentation. The document's
job is to describe what a consumer will actually receive; a doc that describes
the intended contract while the deployed handler returns something else is the
precise failure this whole plugin is arranged to avoid. `api-contract` A2 covers
migrating the pattern; documenting it accurately is a separate obligation from
fixing it.

### C9 — Paths are written once, in ORDS template form

`leave/requests/:id/approve`. Not `{id}`.

ORDS templates and Postman path variables use the same `:name` syntax, so a
single spelling needs zero transformation between the manifest, the collection
and `api.md`. Introducing `{id}` in the documentation means a translation step,
and a translation step means the `sdlc-core:doc-coherence` endpoint check starts
missing endpoints that are genuinely present.

### C12 — The collection id is deterministic

`info._postman_id` is derived from the collection name, not generated randomly.
A random id changes on every emit, so a checked-in collection shows a diff on
every run and reviewers learn to ignore its diffs entirely.

## The two scripts

Both ASCII-only, per the house convention — Windows PowerShell 5.1 reads a
BOM-less `.ps1` as ANSI, so a literal em-dash in source breaks the parse.

### `scripts/emit-collection.ps1`

Manifest → collection **and** markdown, in one run, so they cannot come from
different manifest versions.

```powershell
./emit-collection.ps1 -Manifest docs/api/npt-api-manifest.json `
                      -OutCollection docs/api/npt-postman-collection.json `
                      -OutMarkdown docs/reference/api.md
```

Exit 0 emitted · 1 manifest invalid · 2 could not run.

**It refuses to overwrite a collection that changed after it wrote it.** The
marker it stamps into `info.description` carries a hash of the emitted content,
so three cases are distinguished rather than conflated:

| Existing file | Without `-Force` |
|---|---|
| Untouched since the last emit | overwritten — the manifest is newer, that is the point |
| **Edited after the last emit** | **REFUSED** — those edits are not in the manifest |
| Not produced by this script at all | REFUSED |

The middle row is the one that matters. Checking only for the marker's presence
lets a hand-edit to an already-generated collection be destroyed silently, and
generate-then-tweak-in-Postman is the whole workflow.

### `scripts/audit-collection.ps1`

Both directions, before you regenerate:

```powershell
./audit-collection.ps1 -Manifest docs/api/npt-api-manifest.json `
                       -Collection docs/api/npt-postman-collection.json
```

| Code | Meaning |
|---|---|
| `MISSING-IN-COLLECTION` | Manifest declares it; the collection has no such request |
| `EXTRA-IN-COLLECTION` | The collection has a request the manifest does not declare — usually a hand edit worth keeping, so **fold it into the manifest** rather than regenerating over it |
| `METHOD-MISMATCH` | Same request name, different verb |
| `EXAMPLE-MISSING` | Request has no saved response |

Exit 0 in sync · 1 drift · 2 could not run.

`EXTRA-IN-COLLECTION` is the finding that earns the script. Someone adds a useful
request in Postman; a naive generator deletes it on the next run and nobody
notices until they need it.

## What this skill does not do

- **It does not decide endpoint shape.** Paths, verbs, status codes, pagination,
  auth and concurrency are `api-architect:api-contract` rules A1–A23. A manifest
  that violates them produces a faithful collection of a bad API.
- **It does not deploy.** `api-publish` does.
- **It does not run the requests.** If `newman` is present, the smoke folder is
  runnable by hand:
  `newman run <collection> --folder Smoke --env-var base_url=...`. If `newman` is
  absent, report **NOT RUN** — never infer that a request works from the fact
  that it was generated.
- **It does not verify the examples are real.** An example copied from a live
  response is documentation; one written from imagination is fiction with the
  same syntax. Where an example was not captured from an actual call, the
  manifest should say so with `"exampleSource": "hand-written"` and `api.md`
  renders that.

## Cross-references

- `api-architect:api-contract` — rules A1–A23 for the shape this documents.
- `api-architect:api-audit` — reads the same manifest against the live ORDS
  dictionary. Run it after deployment; run this before.
- `api-architect:api-emit-handler` — its templates implement what the manifest
  declares.
- `api-architect:api-publish` — publishes the module the manifest describes.
- `sdlc-core:doc-coherence` — each request's description opens with the unit id
  so `COLLECTION-MISSING` and `ORPHAN-REQUEST` can resolve.
- `sdlc-core:secret-scan` — C4 exists so this never has anything to find here.
- `docs-architect:docs-reference` — supersedes `api.md` for "what is deployed"
  once the module is live.
