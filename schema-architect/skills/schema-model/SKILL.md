---
name: schema-model
description: Use before writing any DDL, when a feature request implies a new or changed Oracle table — walks a business entity through a 9-step model (naming-convention contract, natural key, table/junction/lookup-seed shape, FK + ON DELETE rationale, audit ["WHO"] columns, soft delete, boolean-flag type choice, primary-key population strategy, mandatory FK indexing) and produces the relationship matrix that schema-emit turns into DDL.
---

# schema-model

**Verb: model.**

This skill is the design step. It does not write DDL — `schema-architect:schema-emit` does that, from this skill's output. Never skip straight to `CREATE TABLE`; a table modeled here in five minutes catches FK-cascade mistakes and missing indexes that are expensive to fix once the table has real rows and dependents.

Every recommendation below is a default you can override — but overriding it should be a documented decision in the relationship matrix, not silence.

## 0. Naming convention is a parameter, read once and held constant

Pick (or confirm) these values before step 1, and reuse them for every object you name in this modeling session. Don't mix conventions within one table — a lowercase table with an uppercase index looks like two tool generations collided.

**This table covers DATA objects only.** Procedures, functions, packages, triggers' PL/SQL bodies, and every local identifier inside them are governed by `schema-architect:plsql-conventions` **P1–P4** (`_p` for procedures, `_f` for functions, `_pkg` for packages, `l_`/`p_`/`g_` scope prefixes). The two tables together are the complete naming contract; neither restates the other. If you are about to name a program unit, that is P1, not this section.

| Parameter | Default | Notes |
|---|---|---|
| Table prefix | `APP_` (placeholder — substitute your project's actual registered prefix, e.g. a 2–5 letter product/module code) | Every generated example in this skill and in `schema-emit` uses `APP_` literally; treat it as find-and-replace, not a real prefix to ship. |
| Table suffix | `_T` | Some shops omit a table suffix entirely and rely on the prefix alone — also fine, just be consistent. |
| Sequence suffix | `_SEQ` | Only needed if you're using the sequence+trigger PK pattern (§7) instead of an identity column. |
| Trigger suffix | `_BIU_TRG` (before-insert-update) | Same caveat as sequence suffix — only needed for the adopt-in-place / explicit-PK-assignment path in §7. |
| PK constraint suffix | `_PK` | |
| Unique constraint/index suffix | `_UK` (+ ordinal if more than one, e.g. `_UK1`, `_UK2`) | |
| FK constraint suffix | `_FK` + ordinal (`_FK1`, `_FK2`, …) | Ordinal in FK declaration order, not target-table alphabetical order — makes the constraint list readable against the `CREATE TABLE` text top to bottom. |
| Check constraint suffix | `_CK` + ordinal | |
| Non-unique/FK-support index suffix | `_IDX` + ordinal, or `_N1`/`_N2`/… in creation order | Either convention is fine; pick one and hold it. |

**Case is cosmetic, but not free to ignore.** Oracle folds every unquoted identifier to uppercase before storing it in the data dictionary (`USER_TABLES`, `USER_TAB_COLUMNS`, …) regardless of whether you typed the `CREATE TABLE` statement in lowercase, UPPERCASE, or MixedCase. Whatever case you type in source is purely a source-formatting choice — it has zero effect on how the object is matched, joined to, or queried against the dictionary — but a codebase that mixes `create table app_customer_t` in one file and `CREATE TABLE APP_ORDER_T` in another reads as if two different eras of tooling produced it. Declare a case style (this skill defaults to lowercase in running examples, UPPERCASE in the dictionary-query world of `schema-audit`, which is unavoidable since dictionary views always return uppercase) and hold it.

## 1. Identify the business entity and its natural key

Name the entity in business language first ("a customer's placed order", "a line item within an order"), then find its natural key — the thing a human would use to say "that row, not another one." Write both down before touching a column list.

**A sequence or identity column existing is not proof a `PRIMARY KEY` constraint exists.** These are two independent, both-mandatory facts: a generator (sequence, or `GENERATED ... AS IDENTITY`) supplies a *value*; only an actual `PRIMARY KEY` (or `UNIQUE NOT NULL`) constraint stops the database from accepting a *duplicate* one. A table can accumulate an ID-generating sequence for years while a duplicate-key bug sits latent because nobody separately confirmed the constraint. Step 1 isn't done until you've stated the surrogate or natural key *and* named the constraint that will enforce it.

## 2. Decide table vs. junction vs. lookup-seed shape

| Shape | When | Illustrative example |
|---|---|---|
| **Business table** | Entity has its own lifecycle, is referenced by other tables, carries more than a code+meaning | `APP_ORDER_T` — has its own row identity, its own WHO trail, is referenced by `APP_ORDER_LINE_T` |
| **Junction table** | Pure many-to-many association between two entities, no data of its own beyond the link (+ maybe a note/date column) | `APP_PRODUCT_CATEGORY_T` — links `APP_PRODUCT_T` to `APP_CATEGORY_T`, just the two FKs plus WHO/`ACTIVE_FLAG` |
| **Lookup-seed** | A small, closed code/meaning set that changes rarely and doesn't need its own table — goes into a shared lookup-values table (see below) instead of a new `CREATE TABLE` | `ORDER_STATUS` — a handful of rows (`PENDING`/`SHIPPED`/`CANCELLED`/`RETURNED`), seeded via `MERGE`, no new table created for it |

If you catch yourself modeling a table whose only columns are `CODE`, `MEANING`, and `ACTIVE_FLAG`, stop — that's a lookup-seed, not a business table. Route it to `schema-emit`'s lookup-seed template instead of the business-table template.

**Shared lookup table vs. dedicated per-entity lookup table — this is a per-project decision, not a universal rule.** Some schemas centralize every small code/meaning set into one shared table (an Oracle Applications-style `<owning-schema>.APP_LOOKUP_VALUES_T`, keyed by `LOOKUP_TYPE` + `LOOKUP_CODE`, scoped to the owning application/tenant by an application-id-style column — this is the long-standing Oracle E-Business Suite/Fusion `FND_LOOKUP_TYPES`/`FND_LOOKUP_VALUES` pattern). Others give every closed set its own small dedicated table. Both are legitimate. Find out which one the target schema already does *before* modeling a new lookup — introducing the other pattern next to an established one is the drift `schema-audit` exists to catch. If the schema has neither yet and you're establishing the pattern fresh, the shared table scales better once you have more than a handful of small code sets; a dedicated table is simpler when you expect only one or two ever.

## 3. Enumerate FKs and write an explicit ON DELETE rationale for each

No FK in this catalog gets a rationale-free default. For every FK column, write one line: target table, and which of these, with why:

- **RESTRICT (Oracle's default — no `ON DELETE` clause at all)**: the parent must never disappear out from under a live child row without a conscious decision. This is correct for almost everything in a soft-delete schema (§5), since rows are never physically deleted anyway. Default to this unless you have a specific reason not to.
- **CASCADE**: only when the child is *owned* by the parent and has no independent meaning once the parent is gone — a junction row (e.g. `APP_PRODUCT_CATEGORY_T` when either `APP_PRODUCT_T` or `APP_CATEGORY_T` is hard-deleted). Note that in a soft-delete convention hard deletes shouldn't happen to business tables at all (§5), so `CASCADE` mostly matters for junction/child rows under a parent that might still be hard-deleted at the DB layer by a cleanup script, not by everyday app behavior.
- **SET NULL**: the child survives meaningfully without the parent, and the FK column is nullable — e.g. an optional `REFERRED_BY_CUSTOMER_ID` on `APP_CUSTOMER_T` where losing the referrer reference doesn't invalidate the customer.

Write the rationale even though hard deletes are rare in a soft-delete schema — the day someone runs a manual cleanup script is exactly when an undocumented default bites.

**Cross-schema / cross-system FKs that can't be a real DB constraint:** when the parent table lives in a schema, database, or service you don't own — and you can only get a `SELECT` grant, not `REFERENCES` — a DB-level `FOREIGN KEY ... REFERENCES` constraint is not obtainable across that boundary. Document the relationship in the relationship matrix as **"app-enforced, no DB constraint"** and state why (grant boundary, different service/database entirely, etc.), and validate the reference in application/PL-SQL code instead. This is a common, legitimate pattern in any system integrating with an owned-elsewhere master table — not a shortcut, as long as it's written down rather than silently assumed.

## 4. Apply the audit ("WHO") column set

Five columns, no more, no less — this mirrors the long-standing Oracle Applications "WHO columns" convention (which historically also included a sixth, `LAST_UPDATE_LOGIN`, tracking the originating session — commonly dropped today since most schemas have better session/request tracing elsewhere):

`CREATED_BY`, `CREATION_DATE`, `LAST_UPDATED_BY`, `LAST_UPDATE_DATE`, `OBJECT_VERSION_NUMBER` (used as an optimistic-locking counter, not a data-model version).

**Timestamp type — use `TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP`, not `DATE DEFAULT SYSDATE`.** Oracle's `DATE` has no timezone and no sub-second precision — a real limitation once you have any multi-timezone deployment, any need to order same-second events, or any integration that expects ISO-8601 timestamps. `TIMESTAMP WITH TIME ZONE` is the standard choice for new audit columns. `TIMESTAMP WITH LOCAL TIME ZONE` is a reasonable alternative when the application layer normalizes to a single reporting timezone and you don't need the zone-per-row stored. Plain `DATE DEFAULT SYSDATE` should be treated as a **legacy-compatibility note only** — use it when adopting an existing schema that already uses `DATE` for audit columns throughout, so a new table doesn't become the one outlier that stores audit timestamps differently from every sibling table.

**`CREATED_BY`/`LAST_UPDATED_BY` width — size it to what it actually stores, as a documented parameter, not a magic number.** Don't pin an arbitrary width. Decide what identity value the column holds and size accordingly:
- A UUID/GUID subject claim: 36 characters is enough.
- An OAuth/JWT `sub` claim or username: well under 128 characters in nearly all identity providers.
- A full email address stored as the identity: RFC 5321 allows up to 320 bytes in the extreme case (64 local-part + `@` + 255 domain), though real-world addresses are almost always far shorter.

A reasonable default parameter is `VARCHAR2(128 CHAR)`, widened to `VARCHAR2(320 CHAR)` specifically when the column stores a raw email address rather than a shorter subject/username identifier. State which one you chose and why in the relationship matrix notes — that's what makes the width a decision instead of folklore.

**Use character semantics explicitly: `VARCHAR2(n CHAR)`, not bare `VARCHAR2(n)`.** Bare `VARCHAR2(n)` defaults to *byte* semantics, and its actual behavior depends on the database's `NLS_LENGTH_SEMANTICS` setting — which you may not control and which may differ between environments. With multibyte character data (accented names, non-Latin scripts, emoji in free-text fields), byte semantics can silently truncate or reject a string that looks well within the declared length when counted in characters. Declaring `VARCHAR2(n CHAR)` everywhere removes this footgun and makes the column's real capacity legible from the DDL alone, independent of an instance parameter.

**`OBJECT_VERSION_NUMBER` precision:** `NUMBER` (unconstrained) or `NUMBER(10)` are both fine; pick one and hold it for the schema. `DEFAULT 1` on insert, incremented on every update — this is what makes it usable as an optimistic-lock guard (see §5 and the backfill-rollback template in `schema-promote`).

**Nullability:** declare all five `NOT NULL`. A WHO column that's nullable only masks the case where a trigger or application layer failed to populate it — better to have the insert fail loudly than to have a silently incomplete audit trail.

## 5. Apply soft delete via `ACTIVE_FLAG` — and make it actually work

`ACTIVE_FLAG CHAR(1) NOT NULL DEFAULT 'Y' CHECK (ACTIVE_FLAG IN ('Y','N'))` on every business and junction table. Never a physical `DELETE` of a business row; the app-layer convention is `UPDATE ... SET ACTIVE_FLAG = 'N'`. Prefer this positive-form flag (`'Y'` means alive) over a negative-form `IS_DELETED`/`IS_INACTIVE` column — reading `WHERE ACTIVE_FLAG = 'Y'` at every call site is less error-prone than reasoning about double negatives (`WHERE NOT IS_DELETED`).

If the schema already has a shared lookup-values table (§2) with its own enable/active column (e.g. `ENABLE_FLAG`), lookup-seed rows use that instead of a second `ACTIVE_FLAG` — don't add both to the same conceptual "is this row usable" question.

Soft delete only actually works in practice if you also decide these three things — each is commonly skipped, and each turns into a real bug when it is:

1. **Exclusion must be consistent, not ad hoc.** Every query that shouldn't see a soft-deleted row needs the same `ACTIVE_FLAG = 'Y'` predicate — relying on every developer to remember to add it is how a soft-deleted customer resurfaces in a report six months later. Enforce this with a view (`APP_CUSTOMER_ACTIVE_V AS SELECT * FROM APP_CUSTOMER_T WHERE ACTIVE_FLAG = 'Y'`) that application code queries by default, or a documented, lint-enforced predicate discipline if views aren't the house style.
2. **Unique constraints must account for the flag, or they block re-creating a "deleted" natural key.** A plain `UNIQUE (customer_code)` constraint will reject re-inserting `customer_code = 'ACME'` after the original `ACME` row was soft-deleted, even though from the business's point of view that code is free again. Either scope the uniqueness to active rows only (a function-based unique index like `UNIQUE (CASE WHEN ACTIVE_FLAG = 'Y' THEN customer_code END)`, which lets multiple soft-deleted rows share a code but still enforces uniqueness among live ones), or deliberately decide natural keys are never reused and document that choice.
3. **State whether an FK may point at a soft-deleted parent.** Since soft delete doesn't remove the row, the FK constraint itself doesn't care — but the business rule might. Decide explicitly: can a new child row be created referencing a parent that's already `ACTIVE_FLAG = 'N'`? If not, that's an application-layer check (the DB constraint alone won't stop it), and it belongs in the relationship matrix next to the FK it governs.

## 6. Decide the type for boolean-shaped columns

Two legitimate choices, split by a real version boundary:

- **`CHAR(1) CHECK (col IN ('Y','N'))`** — the portable, backward-compatible choice. Correct on Oracle 19c/21c (no native boolean in SQL there), and the right choice on any version when consistency with an existing schema that already uses `CHAR(1)` matters more than using the newest type.
- **Native `BOOLEAN`** — Oracle Database 23ai introduced a native SQL `BOOLEAN` column type (`TRUE`/`FALSE`, plus `NULL`/`UNKNOWN` if the column allows nulls). For a **greenfield** schema targeting 23ai or later, this is the more expressive, self-documenting choice — no more `'Y'`/`'N'` string comparisons for a true/false fact. One real limitation to know before choosing it: **`BOOLEAN` columns cannot be indexed** in 23ai. If the flag will ever be a filter or join predicate that needs an index for performance, `CHAR(1)` remains the safer choice even on 23ai+, since it can be indexed like any other column.

Whichever you choose, apply it consistently across the schema — a mix of `CHAR(1)` flags and native `BOOLEAN` flags on sibling tables is exactly the kind of drift `schema-audit` exists to catch.

## 7. Decide the primary-key population strategy

Two legitimate patterns, split by whether this is a new table or an existing one:

- **Identity column (recommended for new/greenfield tables):** `GENERATED BY DEFAULT ON NULL AS IDENTITY` on the PK column. This has been the market-standard replacement for sequence+trigger PK population since Oracle 12c, and it removes a per-row trigger — measurably slower than an identity column at insert time, and one more object to keep in sync with the table. Use **`GENERATED BY DEFAULT ON NULL`**, not `GENERATED ALWAYS`: `GENERATED ALWAYS AS IDENTITY` raises an error the moment any `INSERT` supplies an explicit value for that column (including during a cross-schema data copy, a restore, or a manual correction) — `GENERATED BY DEFAULT ON NULL` still auto-generates a value when the column is omitted or explicitly `NULL`, but accepts an explicit value when one is supplied, which is exactly what a promotion/copy/migration script needs.
- **Sequence + `BEFORE INSERT` trigger (adopt-in-place path):** keep this pattern when adopting an existing schema that already populates PKs this way — introducing identity columns next to sequence+trigger tables in the same schema is inconsistency, not improvement. It's also the right choice when a cross-schema copy or migration process needs to assign the PK value explicitly on every row (some tooling and some replication approaches work more naturally against a plain sequence than against an identity column, even though `GENERATED BY DEFAULT ON NULL` technically also allows explicit assignment).

See `schema-emit`'s `templates/business-table.sql` and `templates/junction-table.sql` for both patterns written out.

**Sequence `CACHE` value — don't treat one number as gospel; understand the tradeoff.** `CACHE 20` is Oracle's own default when `CACHE` is omitted from `CREATE SEQUENCE`, and it's a reasonable general-purpose value: a larger cache means fewer round-trips to update the sequence's dictionary row under concurrent `NEXTVAL` calls (less contention, better throughput on high-insert tables), at the cost of a larger block of unused values being "burned" and permanently skipped if the instance restarts (cached-but-unissued values are lost, not reclaimed). If gap-free, densely sequential values matter for a specific table (rare — most surrogate keys tolerate gaps fine), lower the cache or use `NOCACHE`, accepting the extra dictionary contention. `ORDER`/`NOORDER` (default `NOORDER`) matters mainly on Oracle RAC: `NOORDER` lets each instance cache and hand out its own range independently (better performance, no cross-instance coordination); `ORDER` forces strictly increasing values across every instance, at real contention cost, and should only be chosen when a specific requirement genuinely demands cross-instance strict ordering.

## 8. Mandatory FK indexing

Oracle automatically indexes a `PRIMARY KEY` and a `UNIQUE` constraint — it does **not** automatically index a `FOREIGN KEY`. Every FK column gets its own explicit `CREATE INDEX`, named per §0. This is genuinely important, not a style preference: an unindexed FK column causes Oracle to take a table-level lock on the *child* table during certain operations on the *parent* (notably deletes), and it turns every join or cascade-delete check that filters on that FK column into a full-table scan the moment the child table gets large. Skip this and a new table silently becomes a locking and performance trap.

The one legitimate exception: if the FK column is already the **leading column** of an existing `UNIQUE`/`PK` index, a separate FK-support index would be redundant — Oracle can use that existing index for the FK-related lookups too. Only skip the dedicated index in that specific case; document which existing index covers it.

## 9. Register the change in the schema's migration history

Don't let a new table exist only as a `CREATE TABLE` someone ran once from a terminal. See `schema-promote`'s migration-versioning section for the full guidance — in short: give this change a monotonic version/id, a forward script, and (if the change class needs one) a paired rollback script, and record it in the schema's version/changelog table (or in Flyway/Liquibase's own history table, if the project uses one of those). If the target project has no migration history mechanism at all yet, say so explicitly in the plan output and treat establishing one as a prerequisite step — don't invent an ad hoc registry file silently.

## Relationship matrix template

Fill this in during step 3, before any DDL exists. One row per FK.

| FK column | Target table | ON DELETE | Rationale |
|---|---|---|---|
| `<child>.<fk_col>` | `<parent_table>` | RESTRICT \| CASCADE \| SET NULL \| (app-enforced, no DB constraint) | one sentence: why this child can/can't outlive this parent |

### Worked example — `APP_ORDER_T`

| FK column | Target table | ON DELETE | Rationale |
|---|---|---|---|
| `customer_id` | `APP_CUSTOMER_T` | RESTRICT (default) | a customer is a shared master entity; an order must not silently lose its customer reference — deleting a customer with live orders is a conscious data-cleanup decision, not an incidental side effect |
| `referred_by_customer_id` | `APP_CUSTOMER_T` | SET NULL | optional self-referencing attribution; the order remains fully meaningful if the referring customer reference is cleared |

This is the shape every relationship matrix should take: name the column, name the target, pick one of the four outcomes, and write the one-sentence reason a future reader won't have to reverse-engineer from the DDL alone.

## Cross-references

- `schema-architect:plsql-conventions` — the program-unit half of the naming contract (`_p`/`_f`/`_pkg`, scope prefixes) plus the large-data rules (P10–P14). This skill's §0 covers data objects only; the two together are the complete contract.
- `schema-architect:schema-emit` turns this skill's relationship matrix into DDL. Never skip straight to `CREATE TABLE`.
- `docs-architect:docs-context` — on a project's first schema task, establish the 3-tier agent context if it is missing. **Set expectations honestly for a database repo:** tier 3 (`llmwiki/`) is the one that reliably pays off, because it is written by an agent and is language-independent. `ASSUMPTION:` **SQL/PL-SQL coverage in the tier-1 and tier-2 extractors was not verified** — both were exercised against JavaScript only (2026-07-31). If `code-review-graph build` reports `0 nodes` on a DDL-only repo, that is the unsupported-language case, not a broken install. Do not promise blast-radius answers for PL/SQL until you have confirmed the parser handles it.
- `docs-architect:docs-reference` generates `docs/reference/schema.md` from the **live data dictionary** — which is also how deployment drift against the checked-in DDL becomes visible. That path needs no code parsing at all, so it works regardless of the above.
- **Column comments are the schema's documentation.** `docs-reference` reports comment coverage as a percentage, so an uncommented schema shows up as a number rather than as a vague sense that the generated docs are unhelpful. Write `COMMENT ON COLUMN` as part of the DDL, not as a later cleanup that never happens.
