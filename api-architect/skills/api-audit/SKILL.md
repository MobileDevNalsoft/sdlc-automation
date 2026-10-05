---
name: api-audit
description: Use to check whether a LIVE ORDS module (USER_ORDS_MODULES/USER_ORDS_TEMPLATES/USER_ORDS_HANDLERS) actually matches a declared API manifest, and to scan a schema's packages for package-level global variables that leak request state under a pooled connection model. Manifest-driven and parameterized — works for any module/schema, not one hardcoded endpoint list. Run before and after api-publish, and whenever a review needs to confirm a claim about what's "actually live" rather than what a file says.
---

# api-audit

**Verb: audit.**

## What this skill is

One real, runnable script: `scripts/audit-ords-drift.sql`. Two things it checks:

1. **Drift check** — the expected `(uri_pattern, method)` surface, read from
   a **manifest JSON file** (see `api-manifest.example.json` in this skill
   directory for the shape), diffed against `USER_ORDS_TEMPLATES`/
   `USER_ORDS_HANDLERS` actually live in the schema. Reports `FILE_ONLY`
   (declared in the manifest, missing from live ORDS) and `LIVE_ONLY` (live,
   not declared) rows, plus a module/template/handler count summary.
2. **Package-global scan** — finds variables declared at package level (not
   inside a procedure/function) across the schema's packages, via PL/Scope
   (`USER_IDENTIFIERS`) if compiled with `PLSCOPE_SETTINGS='IDENTIFIERS:ALL'`,
   with a text-heuristic fallback (`USER_SOURCE` regex) if not.
3. **Reserved parameter bind scan** — scans `USER_ORDS_HANDLERS.source` for
   prohibited ORDS reserved or implicit parameters (`:q`, `:limit`, `:page`,
   `:offset`, `:page_size`, `:page_offset`, `:fetch_offset`, `:fetch_size`,
   `:row_offset`, `:row_count`). Flags collisions (e.g. `:q` breaking text
   searches with 400 Bad Request) that must be rebound to `:search`, `:p_limit`,
   or `:p_page`.

Both are parameterized (`&MODULE_NAME`, `&MANIFEST_DIRECTORY`,
`&MANIFEST_FILE`, `&PACKAGE_NAME_FILTER`) — this script does not hardcode a
project's module name, endpoint list, or package names. Supply your own
manifest and filter to audit any schema.

## Why manifest-driven, not hand-extracted

A hand-extracted endpoint list (grepping a handler-definition file for its
literal path/method arguments and pasting them into the script as a `VALUES`
clause) is exactly the kind of drift-prone artifact this skill exists to
prevent — it goes stale the moment the source file changes and nobody
remembers to re-run the extraction. A manifest file is instead the
canonical, version-controlled expected-surface declaration this script
reads directly; keeping it current is a normal part of changing the API
surface, the same as updating any other checked-in contract artifact
(API-CONTRACT.md A20).

## Why the package-global scan matters

Any REST middleware that executes application code over a **pooled**
database connection (ORDS is the concrete case here, but this generalizes)
creates the same hazard: a variable declared at package/module scope lives
for the pooled session's lifetime, not the HTTP request's. The next request
served by that same pooled connection can belong to a completely different
end user and will still observe whatever the previous request left behind.
This is the general form of the same hazard that rules out ambient
session/connection context as an identity source in `api-contract`'s A9 —
under pooling, session-scoped state is not request-scoped state, and
treating it as such is a cross-user data leak vector, not a style nit.

## How to use it

1. Write (or update) a manifest file for the module you're auditing —
   copy `api-manifest.example.json`, replace the example `customers`/
   `orders`/`products` entries with your module's real endpoints.
2. Set the script's parameters (`MODULE_NAME`, `MANIFEST_DIRECTORY`,
   `MANIFEST_FILE`) and run **Section 1–2**. Read the `FILE_ONLY`/
   `LIVE_ONLY` rows before asserting anything about what's "currently live."
3. If BFILE/DIRECTORY filesystem access isn't available in this environment
   (some managed/cloud DB configurations restrict it), assign the manifest
   JSON directly to the script's `l_clob` variable as a string literal
   instead of loading it from a file — the `JSON_TABLE` shredding step
   downstream is unchanged either way; see the inline comment at that point
   in the script.
4. Run **Section 3** to check for package-level state, narrowing
   `PACKAGE_NAME_FILTER` from its default `'%'` (every package in the
   schema) if you only need specific packages. If `3A` (PL/Scope) returns
   nothing and you know a target package has package-level declarations,
   recompile with `PLSCOPE_SETTINGS='IDENTIFIERS:ALL'` first (the exact
   `ALTER PACKAGE`/`ALTER PACKAGE BODY` statements are in the script's
   comments) rather than trusting an empty result.
5. Run **Section 4** to check for any handlers binding ORDS reserved or implicit
   parameters (`:q`, `:limit`, `:page`, `:offset`, etc.). Any row returned is an
   active failure or collision risk that must be rebound before publishing.
6. Any finding here is evidence for a review pass or an `api-publish` gate —
   cite the actual row (`uri_template`/`method`/`matched_reserved`/`identifier_name`),
   don't summarize it away.

## What this script does NOT do

- It does not detect an identity-from-payload violation (API-CONTRACT.md
  A9) — that's a semantic pattern (identity resolved from a credential, then
  never actually used; a payload field trusted instead), not something
  queryable from `USER_ORDS_*` or `USER_IDENTIFIERS`. Flag that class of
  issue by manual review (grep for the identity-resolution call followed by
  no later reference to its result in the same procedure) until/unless a
  future version of this skill automates it.
- It does not execute `ORDS.DEFINE_MODULE`/`DELETE_MODULE`/`ENABLE_SCHEMA` —
  that's `api-architect:api-publish`'s job. This skill only ever reads.

## Stop conditions

- `USER_ORDS_MODULES` has zero rows for the module under audit — say so
  plainly ("module not published") rather than treating an empty diff as
  "everything matches."
- The manifest file can't be loaded (missing DIRECTORY grant, wrong
  filename, malformed JSON) — report the load failure and stop; do not
  proceed to report an empty diff as if it were a clean result.
- PL/Scope metadata is absent and you can't recompile in this session (e.g.
  read-only access) — report Section 3 as `NOT RUN` for method 3A, fall back
  to 3B, and say which method actually produced the finding.
