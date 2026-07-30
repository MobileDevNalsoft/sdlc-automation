---
name: schema-promote
description: Use when DDL/DML that has been verified in a source environment (dev/test) needs to move to a target environment (prod) — fixes the promotion apply order (grants, then DDL/data, then sequence realignment, then package specs, then package bodies, then an invalid-object check), pins AUTHID to definer rights, forbids silent grant-failure swallowing, gives a rollback template per change class, and adds a migration-history mechanism so every promotion is versioned and auditable.
---

# schema-promote

**Verb: promote.**

This skill governs moving verified schema/package changes from a source schema (dev/test) to a target schema (prod) — or, more generally, between any two environments in a promotion pipeline. Substitute your project's actual source/target schema names everywhere `<SOURCE_SCHEMA>`/`<TARGET_SCHEMA>` appear below.

## Apply order — and why grants go first

1. **Grants**
2. **DDL / data**
3. **Sequence realignment**
4. **Package specs**
5. **Package bodies**
6. **Invalid-object check** (final, mandatory)

Grants-first is the safer default independent of any specific project's existing scripts: discovering a missing grant mid-DDL/data-sync means stopping partway through a multi-table operation, whereas an unused grant costs nothing. Sequence realignment runs *after* data sync, not before — aligning a sequence to `MAX(id)` before the new rows land leaves it behind again the moment they do. Package specs before bodies, and dependencies before dependents, because a body that references another package's public spec needs that spec compiled first, or it fails with a dependency error that has nothing to do with the body's own correctness.

See `templates/promote-source-to-target.sql` for the full six-phase orchestration script.

## AUTHID — definer rights, as the default recommendation

Promoted packages should use **DEFINER rights** (Oracle's default — no `AUTHID CURRENT_USER` override) unless a specific package genuinely needs to operate on the *caller's own* objects rather than the package owner's. The consequence set, generalized:

- A definer-rights package executes with the **owner's** privileges, regardless of who calls it — the caller doesn't need DML grants on the tables the package touches internally, only `EXECUTE` on the package itself.
- Roles are **disabled** inside definer-rights PL/SQL — a definer-rights procedure can't rely on a role granted to the invoking session; any privilege it needs must be granted directly to the owner (or via a role granted to the owner, since role-based privilege resolution still works for the owner's own security context, just not the caller's).
- Grants in the promotion's grant phase therefore target the **package owner schema** (`<TARGET_SCHEMA>`), not the caller: `GRANT EXECUTE ON <TARGET_SCHEMA>.<package> TO <CALLER_SCHEMA_OR_ROLE>`.

**Invoker rights (`AUTHID CURRENT_USER`)** is the right choice specifically when the same package code needs to operate on whichever schema's own objects the current caller owns — a shared utility package called from many different schemas, each acting on its own local tables, is the classic case. Don't default to it; it's an exception you reach for when the definer-rights consequence set above would actually break the package's purpose.

Grant `EXECUTE` per package explicitly, one line per package, rather than a wildcard loop — an `EXECUTE` grant is sensitive enough to want visible in a diff, not generated silently.

## Grants must be explicit — never silently swallowed

Wrapping every grant in a blanket `EXCEPTION WHEN OTHERS THEN NULL;` is a real, common anti-pattern: it swallows a genuine grant failure (wrong schema, object doesn't exist yet, insufficient privilege to grant) exactly as quietly as it swallows a harmless "already granted" case. `templates/promote-source-to-target.sql` does not do this — it distinguishes one specific, identified, genuinely benign error (`ORA-01749`, "you may not GRANT/REVOKE privileges to/from yourself" — expected when a script runs as the owning schema and tries to grant to itself) from every other failure, which it raises and stops the promotion for instead of continuing past an object that never actually got its grant. Only tolerate a failure by its specific error number, identified and commented, never by a blanket handler.

## Recompile order for cross-schema dependencies

Same rule as phases 4–5 above, generalized: whenever object A's compilation depends on object B (A's spec references B's public type, A's body calls B's procedure), B compiles first — specs before bodies, and within each of those, dependencies before dependents. Don't wildcard-recompile (`ALTER PACKAGE <prefix>% COMPILE` style loops) as a substitute for getting this order right — a wildcard pass can compile things in whatever order the catalog happens to return them, which is not guaranteed to respect the dependency graph. Oracle's own automatic dependency-tracking recompile (on next reference) is not a substitute for verifying compile success at promotion time rather than on the first unlucky caller in prod.

## Final step: invalid-object check

Reuse `schema-audit:scripts/audit-invalid.sql` verbatim as phase 6 — don't re-derive the `USER_OBJECTS WHERE STATUS = 'INVALID'` query here. One source of truth for "is the schema clean" avoids two copies of that query drifting to different definitions of invalid over time. A non-empty result at this phase means the promotion is **not** complete, regardless of what phases 1–5 reported — report the row count explicitly (`schema-audit`'s "state the count, even at zero" rule applies here too).

## Rollback policy — varies by change class

| Change class | Rollback approach | Template |
|---|---|---|
| **Additive** (new table, new column, new package) | No rollback needed — safe to leave in place even if a feature built on top of it is reverted separately. Nothing existing depended on it before promotion, so nothing breaks by its continued existence. | none |
| **Drop** | Pre-drop `CREATE TABLE ... AS SELECT` snapshot with a stated retention date. Flashback/recyclebin recovery has a retention window governed by tablespace/undo settings and can be lost to space pressure; a CTAS snapshot with an explicit retention date is the durable fallback once flashback has already expired. Drop without `PURGE` as the first line of defense, and treat the CTAS snapshot as the second line, not a replacement for it. | `templates/rollback-drop-snapshot.sql` |
| **Backfill** | A keyed before-image table, captured with the *same* `WHERE` predicate the backfill itself will use, before the backfill `UPDATE` runs — not a full-table snapshot, just the rows and columns in scope. Rollback is a `MERGE` back from the before-image, guarded by `OBJECT_VERSION_NUMBER` so a row a live user touched again *after* the backfill isn't clobbered a second time by the rollback. | `templates/rollback-backfill-before-image.sql` |
| **Package change** (spec or body) | `git checkout <sha> -- <file> && @<file>` — redeploy the prior version straight from source control rather than hand-reconstructing it. This only works if the prior version is actually committed; a package edited and promoted without ever being committed has no `<sha>` to check out, which is itself a reason to commit before promoting, not after. | none (a two-command git+sqlplus sequence, not a standalone `.sql` file) |

## Migration versioning — every promotion is a numbered, recorded change

A promotion pipeline with no migration history has no answer to "what's actually been applied to this environment, in what order, by whom, and can we get back to a known state." Fix that with a version/changelog mechanism, whichever of these two paths fits the project:

**If a versioned migration tool is available or can be adopted:** use **Flyway** or **Liquibase** — both are the standard industry tools for this, both work against Oracle, and both already implement everything below (a history table, checksum verification of applied scripts, ordered application, and a hard rule against editing an applied migration). Prefer adopting one of these over building the equivalent by hand when the project's tooling allows it.

**If neither is available in the target environment:** build the in-house equivalent, which is what `templates/schema-version-table.sql` provides:

- A **schema-version/changelog table** recording every applied change: a monotonic version id or label, a description, the forward script's name, the paired rollback script's name (if this change class has one — see the rollback-policy table above), who applied it and when, and a checksum of the script actually run (so an edit to an already-applied script is detectable, not silently invisible).
- **One migration per change**, not a batch of unrelated changes in one script — a migration that bundles five unrelated table changes is five things to roll back together even when only one of them turns out wrong.
- **Forward and rollback scripts as a pair**, named so the pairing is obvious (e.g. a shared version id or label in both filenames), even when the rollback script's actual content is "no rollback needed" for an additive change (see the rollback-policy table) — the pairing should exist and say that explicitly, not be silently absent.
- **An applied migration is immutable.** Once a migration has run against any real environment, it does not get edited — a mistake discovered later gets fixed by a *new* migration, not by rewriting history. This is the same rule Flyway/Liquibase enforce via checksum validation; the in-house equivalent enforces it by team discipline plus the checksum column doing the same detection job.

## Files

- `templates/promote-source-to-target.sql` — the six-phase orchestration script.
- `templates/rollback-drop-snapshot.sql` — CTAS snapshot + stated retention date, worked example.
- `templates/rollback-backfill-before-image.sql` — keyed before-image + `OBJECT_VERSION_NUMBER`-guarded rollback `MERGE`, worked example.
- `templates/schema-version-table.sql` — in-house migration-history table + a worked forward/rollback migration pair, for environments without Flyway/Liquibase.
