---
name: docs-prd
description: Use to write or update the page-level application design document (MD.050 / PRD) that a business reviewer signs off on — one Page block per screen carrying Page Description, a Page Design wireframe, the fixed 10-column Field Properties table, Process narrative, and Validations, plus the Buttons, Permissions Catalogue, Sample Roles and Notes appendices. Specification-first, so it works before any code exists; a field with no column behind it is written as a gap rather than invented. Load before writing any PRD or MD050, and before changing one.
---

# docs-prd

**Verb: specify.**

## What this skill is for, and what it is not

This writes the document a **business reviewer signs**. Not developer docs.
The audience is a functional consultant or process owner who will read a page,
picture the screen, and say "the Approver field is missing" — and the document's
whole job is to make that sentence possible before anyone writes code.

That makes it the mirror image of the other three documentation skills:

| Skill | Written from | Exists when |
|---|---|---|
| **`docs-prd`** | requirements, a design, a decision | **before** the code |
| `docs-onboarding` | the code | after the code |
| `docs-reference` | the live data dictionary | after deployment |
| `docs-guide` | the running application | after deployment |

`docs-reference` is the one people reach for by mistake. It generates from
`USER_TAB_COLUMNS` and `USER_ORDS_*`, so on a greenfield app it has nothing to
read and degrades to parsing DDL files. It cannot produce a PRD, and a PRD is
not a substitute for it.

## The rule that makes this skill worth having

**Every page names the access token that gates it, and every field names what
backs it. Anything that cannot be named is written as a gap, in the document,
where the reviewer sees it.**

The failure mode this prevents is the confident-looking specification. A Field
Properties table with a plausible `Varchar2(100)` against every row reads as
finished work, and nobody can tell which rows were designed and which were
filled in to make the table look complete. One `GAP:` in the Remarks column is
worth more than fifty invented types, because it is the only thing that gets
the missing decision made.

Same for access. A page with no gating token is a page nobody can be denied.
If the token is not yet decided, the page says so.

## Document structure

The full section contract, the 10-column table specification, and the wireframe
rules are in **`MD050-STRUCTURE.md`** in this directory. Read it before writing.
Skeleton and per-page templates are in `templates/`.

```
Cover                     Title / Prepared By / Creation Date / Last Updated / Document Version
Version History           Version | Updated By | Date | Summary of Changes
1. Introduction & Scope
  1.1 Functional Coverage
  1.2 Information Hierarchy        Level | Examples | Purpose
  1.3 Access Control Model
Transactions
  Page N : <Screen Name>           x N, each the five-part block below
Other Information
  Buttons                          Name | Description
  Permissions Catalogue            Category | Permission Code | Description
  Sample Roles                     Sample Role | Typical Permissions x Typical Scope
  Notes
Traceability                       unit id -> access token -> tables -> endpoints -> requests
```

### The five-part page block, in this order

1. `Page Description:` — what the screen is for and who reaches it, in prose.
2. *(optional structural list)* — `Layout overview:` / `Sections of the page:` /
   `Tabs available on the page:` / `Entry Points:` / `Workflow states:`. Use one
   when the screen has structure worth enumerating before the field detail.
3. `Page Design:` — the wireframe.
4. `Field Properties:` — the 10-column table.
5. `Process:` — what happens on load and on each action, in prose.
6. `Validations:` — a bulleted list of enforceable rules.

**All six labels appear even when a section is short.** A reviewer scans for
`Validations:` on every page; a page that omits the heading reads as a page with
no validations rather than a page whose validations were not written.

## The Field Properties contract

Ten columns. This order. No additions, no omissions, no renames:

```
Block | Field Name | Data Type | Unique | LOV | Read Only | Required | Enabled for Edit | Hyperlink | Remarks
```

This is the part the business signs off on, and its value comes entirely from
being identical on every page of every document. Full per-column semantics are
in `MD050-STRUCTURE.md`; the three rules that get broken most:

- **`Data Type` is a real physical type or the literal `Derived`.**
  `Varchar2(240)`, `Number(18)`, `Number(5,2)`, `CLOB (HTML)`, `Date`,
  `Date and Time`, `CHAR(1) Y/N`, `Derived`, `Derived (mm:ss)`. Never a
  conceptual type like "text" or "number" — the width is where the decision is.
- **`Block` groups rows and is only written on the first row of its group**,
  blank on continuation rows. That is what makes a 30-row table readable.
- **Flag columns take `Y` or blank, never `N`.** The exemplar convention: a
  blank cell means no. A table mixing `N` and blank makes a reader wonder
  whether the blank ones were considered.

## Wireframes carry real data, not placeholders

The `Page Design:` block is a fenced code block showing the screen with
**example values a reviewer recognises**.

Write `HCM/HR/01 - Business Unit wise Reference Data Sets` and
`Time remaining: 47:21` and `18 / 24 cases - Assessment pending`. Not
`[case id]`, not `[timer]`, not `Lorem ipsum`.

This is not decoration. A wireframe full of `[field]` tokens is unreviewable —
the reader cannot tell a date from a duration, cannot see that the status column
has no room for its longest value, and cannot notice that the field they need is
absent. Concrete sample data is what turns the wireframe into a review
instrument. Where a real value is not yet known, use a clearly-marked plausible
one rather than a placeholder, and say so in Remarks.

Keep wireframes ASCII-drawable and under about 60 lines. A wireframe that needs
a screenshot is a screenshot, and belongs to `docs-guide` after the screen
exists.

## Refusals — what this skill will not write

Each of these produces a labelled gap in the document instead of prose that
reads finished:

| Situation | What goes in the document |
|---|---|
| No column/derivation backs a field | `GAP: no column backs this field` in Remarks |
| The gating token is undecided | `GAP: access token not yet decided` in the page's Remarks, and the page is listed in the Traceability section with an empty access cell |
| An LOV's source is unknown | `GAP: LOV source undecided` — never a guessed lookup type |
| A screen exists in code but was not read | Do not write the page. Read the component, or mark the page `SPECIFICATION ONLY - not reconciled against code` |
| A validation is described as "as per business rules" | Not written. Either state the enforceable rule or record it as an open question |

**Never invent an Oracle type to fill a cell.** The physical type is a schema
decision that belongs to `schema-architect:schema-model`; borrowing a plausible
one here creates a second, competing source of truth that nobody knows is
fictional.

## Status labelling, per page

A PRD usually mixes screens that exist with screens that do not. Say which:

- `TO BE BUILT` — specified, no code yet.
- `BUILT` — code exists, and the page cites the implementing file. Cite it as
  a path, e.g. `src/features/leave/components/LeaveRequestPage.tsx`.
- `WITHDRAWN` — specified then dropped; the page stays, with a pointer to what
  replaced it. Never delete a page or renumber around it.

These are the same three values `sdlc-core:doc-coherence` records, deliberately:
the registry's `status` and the page's label are the same fact and must not be
maintained independently.

## Updating an existing PRD

**Never regenerate the whole document to make one change.** A PRD accumulates
hand-written Validations and reviewer-negotiated wording that no generator will
reproduce; a wholesale rewrite loses them silently and the diff is too large to
review.

1. Load `sdlc-core:doc-coherence` and resolve which units the change touches.
2. Edit only the affected page blocks, plus any of Buttons / Permissions
   Catalogue / Traceability the change reaches.
3. Add a **Version History row**. A PRD whose content moved but whose version
   table did not has silently invalidated every sign-off against it.
4. Run `check-coherence.ps1`. It is the only mechanical check that the schema
   document and the API reference kept up.

`doc-coherence`'s propagation matrix is the authority on which sibling documents
a given change class must also touch. Do not re-derive it here.

## Page numbering

Immutable, per `doc-coherence`. Pages append; withdrawn pages keep their number.
Renumbering breaks every `<APP>-P<NN>` id in the registry and every
cross-reference in the schema document, the API reference and the collection,
in a diff no reviewer can check.

Reading order is a **presentation** concern. If page 23 belongs between 6 and 7,
say so in `1.2 Information Hierarchy` or a reading-order list — do not move it.

## `docx` output

Emit markdown always. If the reviewer needs Word:

```
pandoc <prd>.md -o <prd>.docx
```

If `pandoc` is absent, report **NOT RUN** and hand over the markdown. Never
describe the docx as produced, and never hand-build one — per
`sdlc-core:evidence-contract`, an unexecuted conversion is not a conversion.

Two things do not survive the conversion cleanly and are worth knowing before
promising a Word file: wide Field Properties tables need landscape section
breaks, and fenced wireframes need a monospace style applied. Both are manual
post-steps in Word. Say that rather than letting someone discover it.

## Cross-references

- `sdlc-core:doc-coherence` owns the registry, the ids, and the propagation
  matrix. Load it before writing and again before changing.
- `schema-architect:schema-model` owns physical types and table design. A
  Field Properties `Data Type` should agree with it, and where the schema does
  not exist yet, the PRD's type is a **request** to that skill, not a decision.
- `api-architect:api-contract` owns endpoint shape. A `Process:` section naming
  an endpoint must use the path that skill's rules produce.
- `docs-architect:docs-onboarding` documents the code; when a PRD page is
  `BUILT`, that skill's trace is the place the implementation is explained.
- `sdlc-core:evidence-contract` owns the NOT RUN rule the pandoc step obeys.
