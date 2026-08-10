---
name: schema-document
description: Use to write or update the schema design document a team reviews before DDL ships — the twelve-section artifact carrying the naming legend, audit-column contract, executive summary, mermaid ER diagrams (full plus per-domain), the full table catalog with every column, the relationship matrix with a per-FK ON DELETE rationale, lookup seed data, traceability map, numbered assumptions, coverage report and DDL appendix. Consumes schema-model's design decisions; feeds schema-emit. Load after schema-model has modelled the entities and before schema-emit generates DDL.
---

# schema-document

**Verb: document.**

## Where this sits

`schema-model` is the **procedure** — nine steps that walk an entity to a
decision. `schema-emit` is the **DDL**. Neither produces the artifact a team
actually reviews, and reviewing a folder of `CREATE TABLE` statements is how
FK-cascade mistakes and missing indexes reach production.

```
schema-model      decides        (naming, keys, FKs, ON DELETE, audit, flags, indexes)
schema-document   writes it down  <-- this skill
schema-emit       generates DDL
schema-audit      checks the live schema against it
```

Run this **before** `schema-emit`. A relationship matrix is cheap to argue with
and a deployed FK is not.

## The rule that makes this skill worth having

**The relationship matrix is the document's spine. Every foreign key in the
catalog appears in it with an `ON DELETE` behaviour and a written rationale, and
a blank rationale cell is a review failure rather than a formatting nit.**

`ON DELETE` is the highest-consequence, lowest-attention decision in a schema.
`CASCADE` on the wrong edge silently destroys data years later; `RESTRICT`
everywhere makes ordinary cleanup impossible. The rationale column is what turns
it from a default someone typed into a decision someone made — and the day a
manual cleanup script runs is exactly the day an undocumented default bites.

Two words are usually enough: *"Body has no life without its case"* is a
rationale. *"Standard"* is not.

## The twelve sections

Full per-section contract in **`SCHEMA-DOCUMENT.md`**. Templates in `templates/`.

| § | Section | Why it exists |
|---|---|---|
| — | Header table | Application, engine, prefix, history mode, generated date, **source of truth** |
| 1 | Naming legend | The suffix contract, flag convention, reserved-word avoidance |
| 2 | Audit ("WHO") columns | Stated once, omitted from every diagram, present on every table |
| 3 | Executive summary | Table counts by class, domains, **derived-not-stored list**, denormalizations, volume, sensitivity |
| 4 | ER diagrams | 4.0 full, then per-domain when the schema exceeds 15 tables |
| 5 | Table catalog | Every table, every column, indexes, relationships |
| 6 | Relationship matrix | The spine — see above |
| 7 | Lookup / reference seed data | The actual codes, not "statuses as required" |
| 8 | Cross-cutting conventions | Optimistic locking, soft delete, identity strategy, timestamps |
| 9 | Traceability map | Table -> the PRD unit ids that need it |
| 10 | Assumptions & open questions | Numbered `A-1`, `A-2`, referenced from the catalog |
| 11 | Coverage report | What of the requirements this schema does and does not cover |
| 12 | DDL appendix | Runnable DDL, or a pointer to the emitted scripts |

## The three rules people skip

### Over 15 tables, per-domain sub-diagrams are mandatory

One `erDiagram` with 34 tables renders as a hairball nobody reads, which makes
§4 decorative. Above the threshold, emit 4.0 as a relationships-only overview
(no column blocks) and then one sub-diagram per domain **with** column blocks.

Under 15 tables, one diagram with columns is better than four fragments.

### "Derived, not stored" is an enumerated list, in §3

Name every count, score, progress percentage and status the application computes
at query time. `moduleCount`, `caseCount`, `daysLeft`, `Balance After`,
`assessment status`.

Without that list, the next developer sees a UI showing a count, finds no
column, and adds one — and it goes stale within a sprint. The list is what makes
the absence deliberate instead of an oversight. Each entry gets a justification
in §10 if the reason is not obvious.

### Cross-schema parents get a matrix row saying so

When the parent table lives in a schema you only hold `SELECT` on, a real
`FOREIGN KEY` constraint is not obtainable. The matrix row reads
**`app-enforced, no DB constraint`** with the reason (grant boundary, separate
service), and the FK column is documented as a plain `NUMBER` validated in
application or PL/SQL code.

This is a legitimate, common pattern — not a shortcut — **as long as it is
written down**. Silently drawing it as an FK in §4 and omitting it from §6 is
how a schema acquires referential integrity it does not have.

State the required grant explicitly, including its verb. `SELECT` lets you read
a parent; it does not let you **update** one. A screen that writes to a
cross-schema column needs an `UPDATE` grant, and discovering that at deployment
is worse than arguing about it here.

## Source of truth, declared in the header

Say where the model came from, because it changes how much a reader should trust
it:

| Source | Header wording |
|---|---|
| A live database | `SOURCE: ORACLE DATA DICTIONARY, <schema>@<env>, <date>` |
| Checked-in DDL | `SOURCE: DDL FILES, NOT VERIFIED AGAINST A DATABASE` |
| Reverse-engineered from a front end | `SOURCE: <paths>, REVERSE-ENGINEERED FROM APPLICATION CODE` |
| A PRD, no code yet | `SOURCE: <prd path>, SPECIFICATION ONLY -- NO SCHEMA DEPLOYED` |

**The label goes in the header table, not a footnote.** A reader who does not
know which of these produced the file cannot judge it, and once a schema is
deployed, `docs-architect:docs-reference` supersedes this document for
"what is actually there" — the two answer different questions and the header is
what keeps them straight.

## Updating an existing schema document

Editing §5 alone is the drift this skill exists to prevent. A column change
touches, at minimum, the catalog entry; and often §4's diagram, §6 if it is an
FK, §7 if it is a lookup, §9 if it changes which screens use the table, and §11.

1. Load `sdlc-core:doc-coherence`, resolve affected unit ids.
2. Edit every section the propagation matrix names — that matrix is the
   authority; do not re-derive it here.
3. Regenerate §9 rather than hand-editing it.
4. Add a Version History row if the document carries one, and update the
   header's `Generated` date.
5. Run `check-coherence.ps1`. `ORPHAN-TABLE` fires when the catalog gains a
   table no PRD page claims — usually a genuine finding, either a missing page
   or a table nobody needs.

## What this skill does not do

- **It does not decide.** Naming, keys, `ON DELETE`, audit columns, soft delete,
  flag types, PK population and FK indexing are `schema-model`'s nine steps. If
  a decision is missing, go back there rather than inventing one while writing
  prose — a decision made inside a document is a decision nobody reviewed.
- **It does not generate DDL.** §12 either embeds what `schema-emit` produced or
  points at the scripts. Hand-writing DDL here creates a second version that
  will not match what ships.
- **It does not describe a deployed schema.** That is `docs-reference`, from the
  data dictionary. When the two disagree after deployment, that is real drift
  and a finding, not a discrepancy to smooth over.

## Cross-references

- `schema-architect:schema-model` — the nine-step design procedure this
  documents. Run first.
- `schema-architect:schema-emit` — consumes §5 and §6 to generate DDL.
- `schema-architect:schema-audit` — checks a live schema against these
  conventions once deployed.
- `schema-architect:plsql-conventions` — the naming contract for program units;
  §1 here covers data objects only.
- `sdlc-core:doc-coherence` — owns §9's registry and the propagation matrix.
- `docs-architect:docs-prd` — §9 maps to its page ids. A `Data Type` there that
  disagrees with §5 here is resolved in favour of §5.
- `docs-architect:docs-reference` — supersedes this document for "what is
  deployed" once anything is deployed.
