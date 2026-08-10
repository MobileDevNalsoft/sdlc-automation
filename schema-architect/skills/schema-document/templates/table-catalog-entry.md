<!--
  Section 5 table-catalog entry. Rules: SCHEMA-DOCUMENT.md S11-S15.
  One per table. Column order is FIXED (S11):
    surrogate PK -> natural keys -> business data -> FK columns
    -> lookup/code columns -> WHO columns (+ ACTIVE_FLAG)
-->

### 5.<n> `<PREFIX>_<ENTITY>_T`

**Purpose:** <One line. What a ROW is -- "a single leave request raised by an
employee", not "the leave request table".>

<!-- Only when the table has any: -->
**Denormalizations:** <column> (<the query that would otherwise be slow>).

| Column | Type | Null | Key | Default | Notes |
|---|---|---|---|---|---|
| `<ENTITY>_ID` | `NUMBER` | NOT NULL | PK | identity | Surrogate |
| `<ENTITY>_CODE` | `VARCHAR2(<n>)` | NOT NULL | UK |  | <natural key; scope of uniqueness> |
| `<BUSINESS_COL>` | `VARCHAR2(<n>)` | NOT NULL |  |  | <meaning> |
| `<PARENT>_ID` | `NUMBER` | NOT NULL | FK |  | -> `<PREFIX>_<PARENT>_T` |
| `EMPLOYEE_ID` | `NUMBER` | NOT NULL |  |  | `XXINT_EMPLOYEE_MASTER_T.EMPLOYEE_ID`. App-enforced, no DB constraint (§6) |
| `<STATUS>_CODE` | `VARCHAR2(30)` | NOT NULL |  |  | Lookup `<LOOKUP_TYPE>` (§7) |
| `ACTIVE_FLAG` | `CHAR(1)` | NOT NULL |  | `'Y'` | `Y/N` |
| WHO ×5 | see §2 |  |  |  |  |

**Indexes:**
- `<PREFIX>_<ENTITY>_PK` — primary key (automatic).
- `<PREFIX>_<ENTITY>_<PARENT>_IDX` — FK support on `<PARENT>_ID`. **Required**;
  Oracle does not index foreign keys (S15).
- `<PREFIX>_<ENTITY>_UK` — unique `(<cols>)`.

**Relationships:** child of `<PREFIX>_<PARENT>_T`; parent of
`<PREFIX>_<CHILD>_T`. <Cross-schema references named, with their grant.>

**Volume:** <only if it differs from the §3 default.>

<!-- Assumptions are CITED, never restated (S14): e.g. "(A-3)" -->

---

<!--
================================================================================
  WORKED EXAMPLE -- delete when using the template.
================================================================================

### 5.4 `XXNPT_LEAVE_REQUEST_T`

**Purpose:** One leave request raised by one employee, covering a contiguous
date range and moving through a Draft -> Pending -> Approved/Rejected lifecycle.

**Denormalizations:** `DAYS_REQUESTED` (recomputed server-side on submit and
stored, because the holiday calendar it derives from is mutable -- a balance
recomputed from today's calendar would silently restate history).

| Column | Type | Null | Key | Default | Notes |
|---|---|---|---|---|---|
| `LEAVE_REQUEST_ID` | `NUMBER` | NOT NULL | PK | identity | Surrogate |
| `REQUEST_NUMBER` | `VARCHAR2(20)` | NOT NULL | UK |  | Human reference, e.g. `LR-2026-00142` |
| `FROM_DATE` | `DATE` | NOT NULL |  |  | Inclusive |
| `TO_DATE` | `DATE` | NOT NULL |  |  | Inclusive; `>= FROM_DATE` (CK) |
| `FIRST_DAY_HALF_FLAG` | `CHAR(1)` | NOT NULL |  | `'N'` | `Y/N` |
| `LAST_DAY_HALF_FLAG` | `CHAR(1)` | NOT NULL |  | `'N'` | `Y/N` |
| `DAYS_REQUESTED` | `NUMBER(5,2)` | NOT NULL |  |  | Denormalized -- see above. Scale 2 carries half-days |
| `LEAVE_REASON` | `VARCHAR2(500)` | NOT NULL |  |  | 20-500 chars, enforced in app |
| `LEAVE_TYPE_ID` | `NUMBER` | NOT NULL | FK |  | -> `XXNPT_LEAVE_TYPE_T` |
| `EMPLOYEE_ID` | `NUMBER` | NOT NULL |  |  | `XXINT_EMPLOYEE_MASTER_T.EMPLOYEE_ID`. App-enforced, no DB constraint (§6, A-2) |
| `APPROVER_ID` | `NUMBER` | NULL |  |  | Resolved from the employee master's `MANAGER_ID` at submit and frozen, so a later re-org does not rewrite who approved (A-4) |
| `LEAVE_STATUS_CODE` | `VARCHAR2(30)` | NOT NULL |  | `'DRAFT'` | Lookup `XXNPT_LEAVE_STATUS` (§7) |
| `ACTIVE_FLAG` | `CHAR(1)` | NOT NULL |  | `'Y'` | `Y/N` |
| WHO ×5 | see §2 |  |  |  |  |

**Indexes:**
- `XXNPT_LEAVE_REQUEST_PK` — primary key (automatic).
- `XXNPT_LEAVE_REQ_TYPE_IDX` — FK support on `LEAVE_TYPE_ID`.
- `XXNPT_LEAVE_REQ_EMP_IDX` — `(EMPLOYEE_ID, FROM_DATE)`. Serves both the
  per-employee history screen and the overlap check, which is the hot path on
  every submit.
- `XXNPT_LEAVE_REQ_APPR_IDX` — `(APPROVER_ID, LEAVE_STATUS_CODE)`. Serves the
  manager's pending-approvals inbox.
- `XXNPT_LEAVE_REQUEST_UK` — unique `(REQUEST_NUMBER)`.

**Relationships:** child of `XXNPT_LEAVE_TYPE_T`; parent of
`XXNPT_LEAVE_REQUEST_DAY_T`. References `XXINT_EMPLOYEE_MASTER_T` twice
(`EMPLOYEE_ID`, `APPROVER_ID`) with no DB constraint — XXINT grants `SELECT`
only (§6).

**Volume:** Medium. ~40 requests/employee/year; no partitioning below 5M rows.
-->
