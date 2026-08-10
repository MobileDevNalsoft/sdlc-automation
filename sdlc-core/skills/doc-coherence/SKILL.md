---
name: doc-coherence
description: Use whenever a design document set (PRD/MD050, schema design, API reference, Postman collection) is created or CHANGED — owns the traceability registry that binds a screen to its access token, tables, endpoints and collection requests, plus the propagation contract that makes an architecture change edit every artifact that references it instead of leaving three of the four stale. Load before docs-prd, schema-document, or api-collection writes anything, and again after any of them changes a fact.
---

# doc-coherence

**Verb: reconcile.**

## The rule that makes this skill worth having

**A change to an architectural fact is not done when one document reflects it.
It is done when every document the registry links to that fact has been
edited.**

Four documents describing one system will always drift, because drift is
cheaper than propagation at the moment of the edit. Someone renames a column,
updates the schema doc because that is the file they had open, and the PRD's
Field Properties table keeps the old name forever. Six weeks later two
documents disagree and nobody knows which one the build followed.

Traceability sections do not fix this. A section listing what relates to what
is a *record* of coherence, not a *mechanism* for it — it goes stale by exactly
the same means as everything else. What fixes it is a machine-readable registry
plus a checker that fails, and that is what this skill owns.

## Why this lives in `sdlc-core` and not in one of the three plugins

The registry spans `docs-architect` (PRD), `schema-architect` (schema doc) and
`api-architect` (API reference + collection). If each plugin carried its own
copy of the format, the three copies would drift from each other — the same
defect `output-contracts` exists to prevent among the four agent bodies. One
owner, three consumers, referenced by scoped name.

## The registry

`docs/traceability.json` is the single source. Everything else — including the
human-readable `docs/traceability.md` — is generated from it.

One entry per **unit**, where a unit is one screen and everything that screen
needs to exist. Schema in `templates/traceability.schema.json`.

```json
{
  "app":       { "code": "NPT", "appId": 74, "objectPrefix": "XXNPT", "groupPrefix": "NPT_" },
  "artifacts": {
    "prd":        "docs/NPT-MD050-Application-Design.md",
    "schema":     "docs/NPT-schema-design.md",
    "api":        "docs/reference/api.md",
    "collection": "docs/api/npt-postman-collection.json"
  },
  "units": [
    {
      "id":     "NPT-P07",
      "screen": "Leave Request",
      "prdPage": 7,
      "status": "TO BE BUILT",
      "access": {
        "personas":   ["EMPLOYEE"],
        "groups":     ["NPT_LEAVE_REQUEST"],
        "accessType": "M",
        "isAdmin":    false
      },
      "tables":             ["XXNPT_LEAVE_REQUEST_T", "XXNPT_LEAVE_BALANCE_T"],
      "endpoints":          ["POST /npt/leave/requests", "GET /npt/leave/balances"],
      "collectionRequests": ["Leave / Create request", "Leave / Get balances"],
      "sourceFiles":        ["src/features/leave/components/LeaveRequestPage.tsx"]
    }
  ]
}
```

### The id is the join key, and it is immutable

`<APP>-P<NN>`, zero-padded, assigned once. A single `grep NPT-P07` across the
repo must return the PRD page, the schema tables, the API endpoints and the
collection request. That property is the whole design, and it survives exactly
as long as ids do not move.

**Page numbers are never renumbered.** Not to close a gap, not to reorder
sections, not to make the document read better. Renumbering invalidates every
id in the registry and every cross-reference in three other documents at once,
and there is no way to review that diff.

- A new screen **appends** the next id, wherever it belongs in reading order.
  Ordering is a presentation concern; give the page a position and leave its
  number alone.
- A removed screen becomes `Page N : <name> — WITHDRAWN` with a pointer to
  what replaced it, and its unit stays in the registry with
  `"status": "WITHDRAWN"`. Deleting the entry orphans every inbound reference.

### `status` values

| Value | Meaning |
|---|---|
| `TO BE BUILT` | Specified, no code yet. `sourceFiles` may be empty or aspirational. |
| `BUILT` | Code exists. Every path in `sourceFiles` must resolve on disk. |
| `WITHDRAWN` | Specified then dropped. Kept for inbound references. |

`BUILT` with a non-existent `sourceFiles` path is a failure, not a warning —
it is the shape of a claim that something was implemented when it was not.

## UPDATE MODE — the propagation contract

This is the half that gets skipped, and it is the reason this skill exists.

### Procedure

1. **Classify the change.** One of: screen, access token, table/column, lookup
   type, endpoint, contract shape (status codes / envelope / auth).
2. **Resolve affected units** from the registry — every unit whose `tables`,
   `endpoints`, `access` or `collectionRequests` names the changed fact. Do not
   resolve this from memory or from what you just edited; query the registry.
3. **Build the edit set** from the propagation matrix below. The matrix is not
   advisory: a cell with content is a file you must open.
4. **Make every edit.** Not "flag for a follow-up", not "note in the changelog".
   A propagation pass that leaves a known-stale sibling has failed even if the
   file it did edit is perfect.
5. **Update the registry**, then regenerate `docs/traceability.md`.
6. **Add a Version History row** to every document you touched. A reviewer's
   only cheap signal that a document moved is its version table.
7. **Run `scripts/check-coherence.ps1`.** Non-zero exit means the pass is
   incomplete. Fix, do not annotate.

### The propagation matrix

| Change | PRD (MD050) | Schema document | `api.md` | Postman collection |
|---|---|---|---|---|
| **New screen** | New `Page N` block (all five parts), Buttons, Permissions Catalogue, Traceability | §5 catalog, §6 matrix, §7 seed if it adds a lookup, §9 map | New endpoint entries | New folder + requests + saved examples |
| **Screen withdrawn** | Page marked `WITHDRAWN` + pointer | §5 note if tables now unused | Endpoints marked deprecated | Requests removed |
| **Field renamed** | Field Properties row, the wireframe, any Validation naming it | Column in §5 | Request/response schema | Request body + saved example |
| **Column added / retyped** | Field Properties row *if the field is surfaced*; otherwise no PRD change | §5 catalog, §6 if it is an FK, §11 coverage | Schema block | Example payload |
| **New lookup type** | `LOV` column + the Validation bounding it | §7 seed data | Enum on the param or schema | Example values |
| **Access token changed** | §1.3, Permissions Catalogue, the page's Remarks | — | Endpoint auth section | Folder-level auth note |
| **Endpoint path/verb changed** | `Process:` prose naming it | — | Path + method | Request URL + folder |
| **Endpoint removed** | `Process:` / `Validations:` naming it | — | Removed, noted as deprecated | Request removed |
| **Status code / envelope changed** | `Validations:` | — | Status table + problem+json cases | Saved example response |
| **Table renamed** | Traceability section | §4 diagrams, §5, §6, §9 | — | — |

Two cells deserve their empty state read carefully. A column change that is
never surfaced on a screen genuinely does not touch the PRD — writing a Field
Properties row for it would invent a field. And an access-token change never
touches the schema document, because access lives in the central tables the
schema document only references.

### What does NOT count as propagation

- Editing one document and adding "TODO: update the others".
- Regenerating a document wholesale and assuming the diff is right because the
  generator ran. A regenerated PRD that silently dropped a hand-written
  Validation is a loss, not a refresh. Diff before accepting.
- Updating the registry without editing the artifacts. The registry is an
  index, not the documentation; a correct index over stale documents is worse
  than an obviously missing one, because the checker then passes.

## The checker

`scripts/check-coherence.ps1` — the mechanism that makes the contract more than
an intention.

```powershell
./check-coherence.ps1                                   # registry at docs/traceability.json
./check-coherence.ps1 -Registry path/to/traceability.json
./check-coherence.ps1 -Markdown                         # also regenerate traceability.md
```

Seven checks, per unit and in reverse:

| Code | Fires when |
|---|---|
| `PRD-MISSING` | The unit id does not appear in the PRD |
| `SCHEMA-MISSING` | A declared table does not appear in the schema document |
| `API-MISSING` | A declared endpoint does not appear in `api.md` |
| `COLLECTION-MISSING` | A declared request name does not appear in the collection |
| `SOURCE-MISSING` | A `BUILT` unit names a `sourceFiles` path that does not exist |
| `ORPHAN-TABLE` | The schema document defines a prefixed table no unit claims |
| `ORPHAN-REQUEST` | The collection holds a request no unit claims |

Exit codes: **0** clean · **1** drift found · **2** could not run (registry
absent or unparseable).

**Exit 2 is not exit 0.** A checker that cannot find its registry has told you
nothing, and reporting nothing as clean is the one failure mode that makes
every other check in this skill worthless. Same rule as
`sdlc-core:evidence-contract`.

### What the checker cannot do

It matches names, so it catches *absence*, not *disagreement*. A Field
Properties row saying `Varchar2(100)` against a column that is `VARCHAR2(240)`
passes every check here — both documents mention the field. Type-level
agreement needs a reader, and the propagation matrix is what tells that reader
where to look. Do not read a green checker as "the documents agree".

## Cross-references

- `docs-architect:docs-prd` owns the PRD and writes its Traceability section
  from this registry.
- `schema-architect:schema-document` owns §9, the traceability map, likewise.
- `api-architect:api-collection` stamps each request's description with the
  unit id so `ORPHAN-REQUEST` and `COLLECTION-MISSING` can resolve.
- `sdlc-core:evidence-contract` owns the `NOT RUN` / exit-2 rule.
- `sdlc-core:arbitration` is where a genuine disagreement between two documents
  goes when it is a decision rather than a drift — this skill detects, it does
  not adjudicate.
