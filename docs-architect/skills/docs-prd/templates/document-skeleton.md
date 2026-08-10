<!--
  MD.050 document skeleton. Rules: MD050-STRUCTURE.md D1-D24.
  One Page block per screen from templates/page-template.md.

  Replace every <ANGLE_BRACKET> token.
-->

# <Application Name> — Application Design Document

|  |  |
|---|---|
| **Application** | <Application name as registered in the app registry> |
| **Application Code** | `<CODE>` |
| **Application ID** | `<id>` <!-- or: unassigned -- confirm with the platform team. Never invent one. --> |
| **Object Prefix** | `<XXCODE>` |
| **Document Type** | MD.050 Application Design (page-level design) |
| **Prepared By** | <Name> |
| **Creation Date** | <dd-Mon-yyyy> |
| **Last Updated** | <dd-Mon-yyyy> |
| **Document Version** | <M.m> |

## Version History

| Version | Updated By | Date | Summary of Changes |
|---|---|---|---|
| 1.0 | <Name> | <dd-Mon-yyyy> | Initial design |

<!-- Append-only. Name the pages a revision touched. Never rewrite a row. -->

---

# 1. Introduction & Scope

<Two or three sentences: what this application is and who uses it.>

## 1.1 Functional Coverage

**In scope at launch:**

- **<Domain>** — <the screens/capabilities it contains>
- <...>

**Explicitly out of scope:**

- <capability someone will otherwise assume is included, and where it lives instead>

<!-- An unstated exclusion is read as an inclusion. -->

## 1.2 Information Hierarchy

| Level | Examples | Purpose |
|---|---|---|
| <Tier 1> | <examples> | <what this tier is for, and where the user meets it> |
| <Tier 2> | <examples> | <...> |

## 1.3 Access Control Model

<Prose: what carries a grant, in which table and column.>

**What is assigned:**

| Concept | Carried by | Values |
|---|---|---|
| <Baseline access> | <table.column> | <values> |
| <Role / persona> | <table.column> | <values> |
| <Read vs write> | <table.column> | <values> |
| <Admin> | <table.column> | <values> |
| <Screen visibility> | <mechanism> | <naming convention> |

**What is derived (not assignable — there is no checkbox for these):**

| Concept | Resolved by |
|---|---|
| <e.g. Manager> | `EXISTS (SELECT 1 FROM <employee master> WHERE manager_id = :employee_id)` |
| <e.g. Owner> | <the row's created_by equals the caller> |

**A user with no grants at all:** <the exact sign-in outcome and message.>

<!-- D5: every "only their own / their team / their department" in this document
     must map to something above. -->

---

# Transactions

<!-- One block per screen, from templates/page-template.md.
     Numbered from 1, sequential at creation, NEVER renumbered afterwards. -->

## Page 1 : <Screen Name>

<...>

---

# Other Information

## Buttons

| Name | Description |
|---|---|
| <Button label> | <what it does, its side effects, and its permission gate> |

## Permissions Catalogue

<State how a new token is introduced: created by an administrator in the
identity provider (so this table is a snapshot of convention), or compiled into
the code (so adding one is a release). These have opposite operational
consequences and a reader cannot guess which applies.>

| Category | Permission Code | Description |
|---|---|---|
| <Domain> | `<TOKEN>` | <what holding it permits, and at what scope> |

## Sample Roles

<Illustrative compositions of the catalogue above — not a fixed role list.
Delete the word "sample" only if the application genuinely hard-codes roles.>

| Sample Role | Typical Permissions × Typical Scope |
|---|---|
| <Role name> | <tokens> × <scope> |

## Notes

<Cross-cutting facts, so they are not repeated per page:>

- Date format throughout the application is `dd-Mon-yyyy` (for example 18-Aug-2026).
- Date and time format is `dd-Mon-yyyy hh:mm` in the user's timezone; <UTC|SYSDATE> stored at the database level.
- <Audit-logging scope.>
- <Rich-text sanitisation policy.>
- <Upload limits and allowed types.>
- <Soft-delete semantics; whether anything is ever physically deleted.>
- <Delete confirmation policy.>
- <Session and idle timeouts.>

---

# Traceability

<!-- GENERATED from docs/traceability.json by
     sdlc-core:doc-coherence/scripts/check-coherence.ps1 -Markdown.
     Hand-editing this section is drift. Regenerate it. -->

| Unit | Screen | Status | Access | Tables | Endpoints |
|---|---|---|---|---|---|
| `<APP>-P01` | <Screen> | <status> | <access> | <tables> | <endpoints> |
