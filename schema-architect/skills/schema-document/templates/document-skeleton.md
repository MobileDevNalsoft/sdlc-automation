<!--
  Schema design document skeleton. Rules: SCHEMA-DOCUMENT.md S1-S22.
  Section 5 entries come from templates/table-catalog-entry.md.
  Replace every <ANGLE_BRACKET> token.
-->

# <Application Name> — Relational Database Schema

|  |  |
|---|---|
| **Application** | <Name> — <one line on what it does> |
| **Application Code / ID** | `<CODE>` / `<id>` <!-- or: unassigned -- confirm with the platform team --> |
| **Target engine** | <Oracle 19c+ \| Oracle 23ai> |
| **Object prefix** | `<XXCODE>` |
| **History-table mode** | <OFF — WHO audit columns only \| ON — `_H` shadow tables> |
| **DDL appendix** | <Included (§12) \| Pointer to db-scripts/ \| Omitted> |
| **Generated** | <dd-Mon-yyyy> |
| **Source of truth** | <SOURCE: ... — one of the four labels in SKILL.md. In this table, not a footnote.> |

---

## 1. Naming legend

Objects compose as `<PREFIX>_NAME_SUFFIX`.

| Object | Suffix | Example |
|---|---|---|
| Table | `_T` | `<PREFIX>_<ENTITY>_T` |
| Sequence | `_SEQ` | `<PREFIX>_<ENTITY>_SEQ` |
| Trigger | `_TRG` | `<PREFIX>_<ENTITY>_BIU_TRG` |
| View | `_V` | `<PREFIX>_<ENTITY>_V` |
| Primary key | `_PK` | `<PREFIX>_<ENTITY>_PK` |
| Unique constraint | `_UK` | `<PREFIX>_<ENTITY>_UK` |
| Foreign key | `_FK` | `<PREFIX>_<ENTITY>_<PARENT>_FK` |
| Check constraint | `_CK` | `<PREFIX>_<ENTITY>_ACT_CK` |
| Index | `_IDX` | `<PREFIX>_<ENTITY>_<COL>_IDX` |

**Flag convention:** <CHAR(1) with CHECK IN ('Y','N') \| native BOOLEAN (23ai+)>.

**Identifier case in source:** <lowercase \| UPPERCASE>. Oracle folds unquoted
identifiers to uppercase in the dictionary regardless (S4).

**Reserved-word avoidance:** no column is named `NAME`, `STATUS`, `TYPE`, `DATE`,
`VALUE`, `COMMENT`, `GROUP`, `ORDER`, `USER`, `LEVEL`, `VERSION`. Qualified forms
used instead: <examples>.

**Abbreviations:**

| Short | Expansion |
|---|---|
| `<ABBR>` | <expansion> |

---

## 2. Audit ("WHO") columns

<State the set, then the three facts in S5: where CREATED_BY comes from, whether
ACTIVE_FLAG is in the set, and that both are omitted from §4's diagrams.>

| Column | Type | Null | Default | Purpose |
|---|---|---|---|---|
| `CREATED_BY` | `VARCHAR2(<n>)` | NOT NULL | — | <resolved session identity — never a request-body field> |
| `CREATION_DATE` | `<DATE \| TIMESTAMP WITH TIME ZONE>` | NOT NULL | `<SYSDATE \| SYSTIMESTAMP>` | Insert timestamp |
| `LAST_UPDATED_BY` | `VARCHAR2(<n>)` | NOT NULL | — | Most recent updater |
| `LAST_UPDATE_DATE` | `<DATE \| TIMESTAMP WITH TIME ZONE>` | NOT NULL | `<SYSDATE \| SYSTIMESTAMP>` | Most recent update |
| `OBJECT_VERSION_NUMBER` | `NUMBER(10)` | NOT NULL | `1` | Optimistic-lock counter |

Every business table additionally carries
`ACTIVE_FLAG CHAR(1) NOT NULL DEFAULT 'Y' CHECK IN ('Y','N')` — positive-form
soft delete, never `IS_DELETED`.

**These columns and `ACTIVE_FLAG` are omitted from every diagram in §4 for
readability, and are present on every table — lookups and junctions included.**

---

## 3. Executive summary

- **<N> tables** — <n> business, <n> lookup, <n> junction. Plus
  `<externally-owned tables>` referenced but not designed here.
- **Domains:** <Domain 1>, <Domain 2>, … <these become §4's sub-diagrams>.
- **Derived, not stored** (S7) — by the name the UI uses:
  `<name>`, `<name>`, `<name>`.
- **Denormalizations** — `<table>.<column>`: <the query that would otherwise be
  slow>.
- **Volume:** <e.g. all Low (<100K rows); no partitioning>.
- **Sensitivity:** <which tables hold PII; which only reference a table that
  does>.

---

## 4. ER diagram

> WHO columns and `ACTIVE_FLAG` are present on every table but omitted below
> (§2). <Above 15 tables: 4.0 is relationships-only; per-domain sub-diagrams
> carry the columns.>

### 4.0 Full schema

```mermaid
erDiagram
    <PARENT_T> ||--o{ <CHILD_T> : "<verb phrase>"
```

### 4.1 <Domain name>

```mermaid
erDiagram
    <TABLE_T> {
        NUMBER <ENTITY>_ID PK
        VARCHAR2 <ENTITY>_CODE UK "<note>"
    }
```

---

## 5. Table catalog

Column order in every table: surrogate PK → business/natural keys → business
data → FK columns → lookup/code columns → WHO columns (+ `ACTIVE_FLAG`).

<One entry per table, from templates/table-catalog-entry.md.>

---

## 6. Relationship matrix

| Parent | Child | Cardinality | FK column | ON DELETE | Rationale |
|---|---|---|---|---|---|
| `<PARENT_T>` | `<CHILD_T>` | 1:N | `<COL>` | <RESTRICT \| CASCADE \| SET NULL> | <substantive — would this settle an argument? (S17)> |
| `<EXTERNAL_T>` | `<CHILD_T>` | 1:N | `<COL>` | app-enforced, no DB constraint | <which schema owns it, which grant you hold> |

---

## 7. Lookup / reference seed data

<Declare whether lookups are centralized (S20). If so, give the discriminator
and list lookup_type values here rather than inventing per-status tables in §5.>

`<LOOKUP_TYPE>`

| CODE | MEANING | TAG | ENABLE_FLAG |
|---|---|---|---|
| `<CODE>` | <Meaning> | 10 | Y |

**Ordering mechanism:** <display-order/tag column \| alphabetical>.

---

## 8. Cross-cutting conventions

- **Optimistic locking:** <the WHERE OBJECT_VERSION_NUMBER = :expected
  discipline; what a zero-row update means>.
- **Soft delete:** <how ACTIVE_FLAG = 'Y' exclusion is enforced consistently — a
  view, or a lint-enforced predicate>.
- **Unique constraints under soft delete:** <whether natural keys are reusable
  after soft delete, and how>.
- **Identity strategy:** <identity columns \| sequence + trigger>, chosen per
  table and stated.
- **Timestamps:** <event/audit columns vs pure calendar fields>.
- **History tables:** <ON \| OFF, and what provides the audit trail instead>.

---

## 9. Traceability map

<!-- GENERATED from docs/traceability.json by
     sdlc-core:doc-coherence/scripts/check-coherence.ps1. Regenerate, do not
     hand-edit. A prefixed table here that no unit claims is ORPHAN-TABLE. -->

| Table | PRD units |
|---|---|
| `<PREFIX>_<ENTITY>_T` | `<APP>-P07`, `<APP>-P08` |

---

## 10. Assumptions & open questions

**A-1** — <what was assumed>. <Why.> <What changes if it is wrong.>

**Open questions**

**Q-1** — <question>. <Who can answer it.>

---

## 11. Coverage report

**Covered:** <requirement -> tables>.

**Not yet covered:** <requirement -> why, and what it would need>.

<!-- The uncovered list is this section's whole value. A report claiming 100%
     is usually a report that stopped looking. -->

---

## 12. DDL appendix

<The DDL schema-emit produced, or a pointer to db-scripts/. Include the
migration-history registration so this change is versioned rather than something
someone ran once from a terminal.>
