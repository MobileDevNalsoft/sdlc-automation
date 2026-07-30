---
name: schema-emit
description: Use to generate the actual CREATE TABLE/SEQUENCE/TRIGGER/INDEX DDL for a table that schema-model already designed — three real, runnable templates (business table, junction table, lookup-seed), idempotent via a data-dictionary existence check, parameterized for the table-prefix/case convention chosen in schema-model, self-registering in the schema's migration history.
---

# schema-emit

**Verb: emit-ddl.**

This skill turns a `schema-architect:schema-model` relationship matrix into DDL. It does not make design decisions — if you find yourself deciding an `ON DELETE` rule, a WHO-column width, or a PK-population strategy here instead of copying it from the model step, go back and run `schema-model` first.

## Which template to use

| `schema-model` shape | Template |
|---|---|
| Business table | `templates/business-table.sql` |
| Junction table | `templates/junction-table.sql` |
| Lookup-seed (small closed code/meaning set) | `templates/lookup-seed.sql` |

All three are written against a placeholder `APP_` prefix and lowercase table names as the running example — substitute your project's actual registered prefix and the case convention `schema-model` §0 settled on for this session. Each template shows both PK-population strategies (identity column and sequence+trigger) from `schema-model` §7 — comment out the one you're not using.

## Idempotency: check the data dictionary first, don't catch-and-swallow

Oracle has no `CREATE TABLE IF NOT EXISTS`. The common workaround — wrap the DDL in a block and swallow `ORA-00955` ("name is already used by an existing object") — works, but it's not the best available option: it can only tell you *that* the object exists, and a careless version of the same idiom (`WHEN OTHERS THEN NULL` instead of checking the specific `SQLCODE`) will silently swallow a genuine typo or privilege error too, leaving the object half-created with no error raised.

The better pattern is to **query the data dictionary first** and only run the DDL if the object isn't already there:

```sql
DECLARE
   l_count PLS_INTEGER;
BEGIN
   SELECT COUNT(*) INTO l_count
     FROM user_tables
    WHERE table_name = 'APP_CUSTOMER_T';

   IF l_count = 0 THEN
      EXECUTE IMMEDIATE '
         CREATE TABLE app_customer_t ( ... )';
   END IF;
END;
/
```

This is unambiguous about *why* nothing happened (the dictionary says the object already exists — not "some error occurred and we decided it was fine"), and it never has an opportunity to mask an unrelated failure, because the `CREATE` statement is simply never attempted when the guard trips. The same shape covers `CREATE SEQUENCE` (query `USER_SEQUENCES`) and `CREATE INDEX` (query `USER_INDEXES`). `CREATE OR REPLACE TRIGGER`/`VIEW`/`PACKAGE` need no guard at all — `OR REPLACE` is already idempotent by design.

**The actual industry answer to idempotent, repeatable schema deployment is a versioned migration tool** — Flyway or Liquibase are the standard choices, and both work well against Oracle. They track which numbered migration scripts have already been applied (in their own history table) and simply never re-run one that's already recorded, which is a stronger guarantee than either the dictionary-check or the exception-catch pattern can give you on their own, because it also protects against re-running a script whose *effects* have already landed even if the specific object it created was later dropped or renamed. See `schema-promote`'s migration-versioning section for the in-house equivalent when neither tool is available in your environment. Treat the dictionary-check pattern in this skill's templates as what you reach for inside one migration script, not as a substitute for having a migration history at all.

## Self-registration

Every template ends with a comment block showing what to record once the DDL runs: a new row in the schema's migration-version/changelog table (see `schema-promote`'s migration-versioning section) naming the version id, the forward script, and — for a change class that needs one — its paired rollback script. This is a reminder in the file, not automation: no tool here writes to the changelog for you.

## Lookup-seed and application/tenant scoping

If the target schema uses a shared lookup-values table (see `schema-model` §2), rows are typically scoped to the owning application/tenant by an id column (the long-standing Oracle Applications `FND_LOOKUP_VALUES`-style pattern: `LOOKUP_TYPE` + `LOOKUP_CODE`, scoped by an application id). **That id is a parameter you look up for the real target schema — never a literal copied from an example.** The lookup-seed template below prompts for it (`&&app_id`, no hardcoded default) rather than embedding any specific number. If more than one candidate value shows up in the target project's own documentation or code, don't silently pick one — surface the conflict and confirm which is current before seeding anything (`schema-audit`'s lookup-consistency check is where this class of drift gets caught on an ongoing basis).

## Files

- `templates/business-table.sql` — full table + (identity column **or** sequence + BIU trigger) + FK index, worked as a standalone business entity (`APP_ORDER_T`, referencing `APP_CUSTOMER_T`).
- `templates/junction-table.sql` — many-to-many association table, worked as `APP_PRODUCT_CATEGORY_T` linking `APP_PRODUCT_T` to `APP_CATEGORY_T`.
- `templates/lookup-seed.sql` — idempotent `MERGE` into a shared lookup-values table, worked as a new `ORDER_STATUS` lookup type.
