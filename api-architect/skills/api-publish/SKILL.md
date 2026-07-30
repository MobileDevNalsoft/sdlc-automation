---
name: api-publish
description: Use to publish an ORDS module/handler change safely — idempotent DELETE_MODULE teardown, DEFINE_MODULE under a parameterized schema alias (never hardcoded, since schemas get promoted or cut over between environments), ENABLE_SCHEMA, a drift-audit confirmation, and a runnable .http smoke test. Dispatch after api-emit-handler produces a handler/procedure pair and before calling a task done.
---

# api-publish

**Verb: publish.**

## The one rule

**The checked-in definition is truth** (API-CONTRACT.md A20). If the live
ORDS module and the checked-in module-definition file/manifest ever
disagree, the file wins and gets re-published. You do not "fix" a live
module by hand-editing it to match what's running and leaving the file
stale — that recreates the exact live-vs-file gap `api-architect:api-audit`
was written to catch.

## The sequence

Full runnable form is `templates/publish-module.sql` in this skill
directory. In order:

1. **`ORDS.DELETE_MODULE`** — idempotent teardown. Safe to run whether or
   not the module currently exists; the template narrows its exception
   handler rather than swallowing everything, so a real failure still
   surfaces.
2. **`ORDS.DEFINE_MODULE`** — recreate the module. `p_base_path`,
   `p_items_per_page` (0 — pagination is engine-procedure-owned per
   `api-contract` A7, not ORDS-native), and `p_comments` are parameters, not
   literals.
3. **`ORDS.ENABLE_SCHEMA`** — `p_schema` is the **parameterized schema
   alias**, never a hardcoded literal. Any environment that promotes a
   schema between dev/test/prod, or cuts over between two schema names,
   needs this script to work unmodified against whichever one is current —
   a template hardcoded to one schema breaks the moment that boundary moves.
4. **Run the module's actual handler-definition file** to (re)declare every
   template/handler.
5. **Run `api-architect:api-audit`'s `scripts/audit-ords-drift.sql`** —
   confirm what just got published actually matches the manifest. Zero
   `FILE_ONLY`/`LIVE_ONLY` rows is the pass condition; any row means stop and
   reconcile before calling the publish done.
6. **Run `templates/smoke-test.http`** — a real, runnable HTTP request file
   against the newly published endpoint(s), as the final check. For a
   module on the current, recommended convention, the HTTP status line IS
   the result (A4). Only fall back to reading a body-embedded result-code
   field for a module still on the legacy always-200 convention
   (API-CONTRACT.md L1) — know which convention this specific module is on
   before you read the smoke test's outcome.

## Non-negotiables

- Never hardcode the schema alias into a checked-in publish script. Take it
  as a substitution variable (`&SCHEMA_ALIAS` in the template) every time.
- Never skip step 5. A publish that isn't confirmed by the drift audit is
  not a completed publish — it's an unverified `ORDS.DEFINE_MODULE` call.
- Never assume the smoke test's status line is the always-200 legacy
  convention (or vice versa) — check which convention the module you just
  published is actually on before interpreting the result.
- Any per-deployment identifier (an application ID, tenant ID, or similar
  value your auth layer keys on) is a template parameter, never a literal
  baked into a reusable publish script — a different module in the same
  ORDS instance can use a different value (API-CONTRACT.md A9's identity
  resolution depends on getting this right).

## Stop conditions

- The drift audit (step 5) comes back with any `FILE_ONLY` or `LIVE_ONLY`
  row after a publish you just ran — do not report the publish as done;
  report what's still mismatched and why (partial run? wrong schema alias?
  handler file itself has an error that aborted mid-script?).
- You don't know which schema alias this publish targets — that's a
  `NEEDS-DECISION`, not a default-to-whatever-was-last-used judgment call;
  guessing wrong here means publishing against the wrong schema in an
  environment that's actively mid-promotion or mid-cutover between two.
- The smoke test's result doesn't match what the handler/procedure change
  was supposed to produce — treat that as a failed publish, not a
  "probably a stale token" hand-wave; re-check the token before re-running,
  but don't assume it away.
