---
name: schema-audit
description: Use to check a live schema against schema-model's/schema-emit's conventions after DDL has shipped, or periodically as a drift check — four parameterized .sql scripts (conventions, sequences, lookups, invalid objects) that return violations only, so an empty result set is a genuine PASS.
---

# schema-audit

**Verb: audit.**

Run these four scripts against a live schema; all are read-only (no `UPDATE`/`DELETE`/`DROP` anywhere in any of the four, except the one deliberately-optional hard-fail wrapper noted in each file, which still only reads).

## The evidence-contract shape these scripts follow

Every query in every script here is an **exhaustive negative filter**: it selects rows that *fail* a condition, over the full population of tables/columns/sequences under a given prefix — not a sample, not a spot-check. That means an empty result set is a real, load-bearing PASS, not "we didn't find anything to report." Don't collapse that distinction when reporting results — "0 rows returned" is the pass condition itself, worth stating as such rather than silently moving on.

One check (`scripts/audit-lookups.sql` CHECK 1) is explicitly the exception and is labeled as such in the file: "lookup-shaped" can't be determined with certainty from column metadata alone, so that check produces a candidate list for human review, not a deterministic violation. Every other check in all four files is deterministic.

## Files

| Script | Catches |
|---|---|
| `scripts/audit-conventions.sql` | Tables missing any of the 5 audit ("WHO") columns; `CREATED_BY`/`LAST_UPDATED_BY` at the wrong width; `VARCHAR2` columns using byte semantics instead of `VARCHAR2(n CHAR)`; `OBJECT_VERSION_NUMBER` not `NUMBER`-family; WHO columns declared nullable; a boolean-shaped column that isn't `CHAR(1)` and isn't a legitimate native `BOOLEAN`; audit-timestamp columns mixing `DATE` and `TIMESTAMP WITH TIME ZONE` across sibling tables under the same prefix; a table with an identity column or a NEXTVAL-driving trigger but no actual `PRIMARY KEY` constraint. |
| `scripts/audit-sequences.sql` | A table whose implied sequence doesn't exist (sequence+trigger PK strategy only — see `schema-model` §7); a sequence not on the configured expected `CACHE` size; a sequence with `CYCLE` on (rejected — a cycling PK-backing sequence would eventually reissue an id). |
| `scripts/audit-lookups.sql` | A lookup-shaped table that was never consolidated into the shared lookup-values table (candidate list, human review); a `LOOKUP_TYPE` whose rows are missing the application/tenant id tag that makes them visible to their owning app; duplicate `(LOOKUP_TYPE, LOOKUP_CODE)` pairs. |
| `scripts/audit-invalid.sql` | Every `INVALID` object in the schema (`USER_OBJECTS.STATUS = 'INVALID'`). Running this after every PL/SQL deploy is genuinely important and commonly skipped — it's also reused verbatim as `schema-promote`'s final phase. |

## Why the surrogate-key-without-PK check matters

`audit-conventions.sql`'s last check exists because a sequence, an identity column, or a NEXTVAL-populating trigger existing on a table is **not** evidence that a `PRIMARY KEY` constraint exists — those are two independent, both-mandatory facts (see `schema-model` §1). A table can generate unique-looking values for years while nothing in the database actually stops a duplicate id from being inserted, because the generator and the uniqueness guarantee are enforced by two different objects. This check closes that gap by flagging any table that shows PK-generation machinery (an `IDENTITY_COLUMN = 'YES'` column, or a trigger body referencing `.NEXTVAL` for that table) without a corresponding `PRIMARY KEY` constraint in `USER_CONSTRAINTS`.

## What "PASS" means when reporting results

State the row count explicitly, per check, even when it's zero: "`audit-conventions.sql` CHECK 1: 0 rows — PASS" is a complete, correct report line. "`audit-conventions.sql`: PASS" (unqualified, no per-check breakdown) hides which of the checks in that one file were actually run — a partial result set reported as a blanket pass is exactly the kind of silent gap this discipline exists to prevent.

## Parameters every script prompts for

None of these scripts hardcode a schema, prefix, application id, or expected width. Each prompts (`ACCEPT`) for the values that apply to the schema you're actually auditing — supply the real ones for that target, never a value copied from this skill's own examples.
