# MD.050 structure contract

The section-by-section specification `docs-prd` writes to. Rules are numbered
**D1–D24** so a review can cite a violation instead of paraphrasing it.

---

## Front matter

### D1 — Cover block

Six facts, no more:

| Field | Notes |
|---|---|
| Application name | As registered in the app registry, not a marketing name |
| Document title | `<Application> Application Design Document` |
| Prepared By | A person, not a team |
| Creation Date | `dd-Mon-yyyy` |
| Last Updated | `dd-Mon-yyyy`. Must move whenever Version History gains a row |
| Document Version | `M.m` |

### D2 — Version History is mandatory and append-only

| Version | Updated By | Date | Summary of Changes |
|---|---|---|---|
| 1.0 | <name> | 01-Jun-2026 | Initial design |

A row per revision. `Summary of Changes` names the pages touched
(`Pages 7, 12 - leave approval routing`), not "various updates" — the summary is
what a reviewer uses to decide whether their earlier sign-off still holds.

**Never rewrite a historical row.** A correction is a new row.

---

## 1. Introduction & Scope

### D3 — What section 1 must establish

Four things, in prose and tables, before any page appears:

1. What the application is, in two or three sentences.
2. **1.1 Functional Coverage** — the modules/domains in scope at launch, and
   explicitly what is out of scope. An unstated exclusion is read as an
   inclusion.
3. **1.2 Information Hierarchy** — `Level | Examples | Purpose`, one row per
   tier of the app's primary structure. This is what makes navigation
   reviewable before there is navigation.
4. **1.3 Access Control Model** — see D4.

### D4 — The access model is described as the mechanism, not as a role list

A list of role names is not an access model. Section 1.3 states, concretely:

- **What carries the grant** — which table, which column, which external
  identity provider group.
- **What is assigned vs. what is derived.** Derived access is the part people
  get wrong: if "manager" means *someone reports to me* rather than *someone
  gave me a manager role*, that is a query, and it must be written as one:

  ```sql
  EXISTS (SELECT 1 FROM <employee master> WHERE manager_id = :employee_id)
  ```

  A derived role that is documented as an assignable one causes an
  administrator to look for a checkbox that does not exist.
- **How read and write are separated** — a distinct column, a distinct
  permission, or not separated at all.
- **What happens with no access at all** — the sign-in outcome for a user with
  zero grants. Silence here becomes a login loop nobody specified.

### D5 — Scope words are bound to enforcement

Every "only their own", "only their team", "only their department" in the
document must correspond to something in 1.3. If it does not, either the scope
mechanism is missing or the phrase is aspirational; both are worth catching
before build.

---

## Transactions — the page blocks

### D6 — One `Page N : <Screen Name>` heading per screen

Numbered from 1, sequential at creation, **never renumbered afterwards**
(`doc-coherence` owns this rule; it is repeated here because renumbering is
usually attempted while editing the PRD, not while editing the registry).

The heading carries the number and the screen name only. Status, ids and access
go inside the block.

### D7 — The five-part block, in fixed order

`Page Description:` → *(optional structural list)* → `Page Design:` →
`Field Properties:` → `Process:` → `Validations:`

Every label present on every page, even when its content is one line. See
`templates/page-template.md`.

### D8 — `Page Description:`

Prose. What the screen is for, who reaches it, and from where. Two to six
sentences. If the screen serves two audiences with different views (a submitter
and an approver on one form), say so here and give each its own wireframe.

### D9 — The optional structural list

Exactly one of, when useful:

| Label | Use when |
|---|---|
| `Layout overview:` | The page has distinct regions worth naming top-to-bottom |
| `Sections of the page (top-to-bottom):` | Long forms and reading screens |
| `Tabs available on the page:` | Tabbed content |
| `Entry Points:` | The screen is reachable three or more ways |
| `Workflow states:` | The record moves through a lifecycle |
| `Question Types Supported:` | (or similar) a bounded set the page must handle |

Ordering matters and communicates priority: list regions in the order the user
meets them.

### D10 — `Page Design:` wireframe

A fenced code block. Rules:

1. **Real example data**, never placeholders. See `SKILL.md`.
2. **Under ~60 lines.** Longer means the page is doing too much, or the
   wireframe is drifting toward pixel design.
3. **Show state, not just structure** — a filled row, a selected radio, a
   populated count. `Status: Approved` reviews; `Status: [status]` does not.
4. **Include the chrome that carries meaning** — breadcrumb, page title, the
   action buttons — and omit chrome that does not.
5. **Show the empty and error states** when they are non-obvious, as a second
   short block labelled `Page Design (empty state):`.
6. **One wireframe per distinct mode.** Submitter mode and approver mode are two
   blocks, labelled.

### D11 — `Field Properties:` — the fixed 10 columns

```
Block | Field Name | Data Type | Unique | LOV | Read Only | Required | Enabled for Edit | Hyperlink | Remarks
```

Per-column semantics:

| Column | Contents | Rules |
|---|---|---|
| `Block` | Logical group name | Written on the group's **first row only**, blank on continuations. Groups match the wireframe's regions |
| `Field Name` | Label as the user sees it | The on-screen label, not the column name. `Username / Email`, not `USER_EMAIL` |
| `Data Type` | Physical type or `Derived` | D12 |
| `Unique` | `Y` or blank | Business uniqueness, not a DB constraint claim |
| `LOV` | The list's source | D13 |
| `Read Only` | `Y` or blank | Rendered but never editable on this page |
| `Required` | `Y` or blank | Mandatory before the page's primary action succeeds |
| `Enabled for Edit` | `Y` or blank | Editable **on this page**, possibly conditionally — state the condition in Remarks |
| `Hyperlink` | Target, or blank | Where clicking goes. A page number (`Page 6`) or a route |
| `Remarks` | Everything else | Validation hints, defaults, derivations, conditions, and `GAP:` markers |

### D12 — `Data Type` is physical, or the literal `Derived`

Allowed: `Varchar2(n)`, `Number(p)`, `Number(p,s)`, `CHAR(1) Y/N`, `Date`,
`Date and Time`, `CLOB`, `CLOB (HTML)`, `BLOB`, `Derived`, `Derived (<shape>)`,
`Multi-select`, `Multi-select User`.

Not allowed: `text`, `string`, `number`, `boolean`, `date?`, `TBD`, empty.

**The width is the decision.** `Varchar2(60)` and `Varchar2(4000)` are different
specifications and a reviewer who knows the business can tell you which is
wrong. `text` cannot be wrong, which is why it is worthless.

`Derived` means computed at render time and stored nowhere. Say what from, in
Remarks. A `Derived` field with no derivation is a `GAP:`.

### D13 — `LOV` names a source, not a possibility

Write the actual source: a lookup type (`XXNPT_LEAVE_STATUS`), a table
(`Active modules in selected pillar`), a scoped query
(`Users where manager_id = current user`), or a literal set
(`Passed / Failed`).

Write `GAP: LOV source undecided` if it is not decided. Never write `Yes` — the
whole value of the column is *which* list.

Cascading lists state their parent: `Dependent (cascading) on Pillar`.

### D14 — Every field in the wireframe appears in the table, and vice versa

The two are one specification in two views. A field drawn but not tabulated has
no type; a field tabulated but not drawn has no home. Both are review findings.

### D15 — `Process:`

Prose. What happens **on load** and what happens **on each action**. Name the
queries at a business level ("loads all modules the user has scope into"),
the routing, and the server-side re-checks. This is where an ordering
requirement gets stated — that a validation happens before a mutation, that a
notification fires after a commit.

If an action's outcome differs by role, say so per role.

### D16 — `Validations:`

A bulleted list. Each bullet is **enforceable**: a reader must be able to write
a test from it.

```
- Leave Reason -- mandatory when Leave Type = 'Other'; 20 to 500 characters.
- Duplicate prevention -- a second Pending request cannot overlap an existing
  Pending or Approved range for the same employee.
- Approver -- cannot be the requester, unless Allow Self-Approve is On.
```

Not enforceable, and therefore not written: "as per business rules", "standard
validations apply", "should be validated properly".

Cover, where they apply: mandatory fields, lengths and ranges, formats,
uniqueness, cross-field conditions, duplicate prevention, permission re-checks
on the server, state-transition legality, and what direct-URL access returns
for a user who lacks access. That last one is the most-skipped and the most
security-relevant: `Returns 404 for users without <token>, even by direct URL`.

### D17 — Server-side re-check is stated, per page, whenever the UI hides something

"The UI hides the button when the user lacks the permission" is not an access
control. If the endpoint also rejects the call, say both. If it does not, that
is a finding, not a detail.

---

## Other Information

### D18 — Buttons

`Name | Description`, one row per distinct button in the application, described
by **what it does**, including its side effects and its permission gate. One
catalogue for the whole document — a button described inconsistently on two
pages is exactly what this section exists to prevent.

### D19 — Permissions Catalogue

`Category | Permission Code | Description`. The complete, closed set of tokens
the application checks, grouped by domain.

State how a new token is introduced. If tokens are IDCS groups created by an
administrator, the catalogue is a **snapshot of convention** and says so; if
they are compiled into the code, adding one is a release and the catalogue says
that instead. These have opposite operational consequences and the reader cannot
guess which applies.

### D20 — Sample Roles are labelled illustrative

`Sample Role | Typical Permissions x Typical Scope`. Compositions of D19's
tokens, explicitly **examples**, not a fixed role list — unless the application
genuinely hard-codes roles, in which case they are not samples and the heading
must not say they are.

### D21 — Notes

Cross-cutting facts that would otherwise be repeated on every page: date and
date-time formats, timezone storage, audit-logging scope, rich-text
sanitisation, upload limits and allowed types, soft-delete semantics,
confirmation-before-delete, session timeouts.

A rule that appears in Notes does not need repeating per page. That is the
point of the section.

### D22 — Traceability

Generated from `docs/traceability.json` (owned by `sdlc-core:doc-coherence`).

| Unit | Screen | Access | Tables | Endpoints | Collection |
|---|---|---|---|---|---|
| `NPT-P07` | Leave Request | `EMPLOYEE` · `NPT_LEAVE_REQUEST` · M | `XXNPT_LEAVE_REQUEST_T` | `POST /npt/leave/requests` | `Leave / Create request` |

Hand-editing this section is drift. Regenerate it.

---

## Cross-document rules

### D23 — The PRD does not decide physical schema or endpoint shape

It **requests** them. `Data Type` should agree with the schema document and the
path in `Process:` should agree with the API reference — but where they
disagree, the schema document and the API reference win on their own subject
matter, and the disagreement is resolved by editing the PRD (or by
`sdlc-core:arbitration` if it is a real decision rather than a slip).

Writing an authoritative-sounding type into a PRD for a table that does not
exist yet creates a second source of truth whose fictional status is invisible.

### D24 — A page is not finished while any part of it reads as finished but is not

The document's worth is a reviewer's ability to trust that an unmarked page was
designed. One un-marked guess destroys that for every page, because the reader
now has to verify all of them. Mark the gap; the gap is the deliverable.
