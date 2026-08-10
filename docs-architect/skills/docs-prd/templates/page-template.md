<!--
  Per-page template for an MD.050 Transactions block.
  Copy one of these per screen. Rules: MD050-STRUCTURE.md D6-D17.

  Replace every <ANGLE_BRACKET> token. A token left in place is an unfinished
  page, not a template -- and reads as finished to everyone but you.
-->

## Page <N> : <Screen Name>

`<APP>-P<NN>` · Status: `TO BE BUILT` | `BUILT` | `WITHDRAWN`
<!-- BUILT also cites the implementing file, e.g.
     Implemented in `src/features/<feature>/components/<Component>.tsx` -->

**Page Description:**

<Two to six sentences: what the screen is for, who reaches it, and from where.
If it serves two audiences with different views, say so and give each its own
wireframe below.>

**<Layout overview: | Sections of the page (top-to-bottom): | Tabs available on the page: | Entry Points: | Workflow states:>**
<!-- Optional. Pick at most one. Delete the whole block if the page has no
     structure worth enumerating before the field detail. -->

- <region or state, in the order the user meets it>
- <...>

**Page Design:**

```
<ASCII wireframe. REAL example data, never [placeholders]. Under ~60 lines.
 Show a filled row, a selected option, a populated count -- state, not just
 structure. Include the chrome that carries meaning (breadcrumb, title,
 actions); omit chrome that does not.>
```

<!-- A second block per distinct mode or state, when non-obvious:
**Page Design (empty state):** / **Page Design (Approver Mode):**
-->

**Field Properties:**

| Block | Field Name | Data Type | Unique | LOV | Read Only | Required | Enabled for Edit | Hyperlink | Remarks |
|---|---|---|---|---|---|---|---|---|---|
| <Block> | <On-screen label> | <Varchar2(n) \| Number(p,s) \| CHAR(1) Y/N \| Date \| Date and Time \| CLOB \| Derived> | <Y or blank> | <lookup type, table, scoped query, literal set, or blank> | <Y or blank> | <Y or blank> | <Y or blank> | <Page N or route, or blank> | <defaults, derivations, conditions, `GAP:` markers> |
|  | <next field in the same block> |  |  |  |  |  |  |  |  |

<!-- Block is written on its group's FIRST row only, blank on continuations.
     Flag columns take Y or blank -- never N.
     Every field in the wireframe appears here, and vice versa (D14). -->

**Process:**

<Prose. What happens on load. Then what happens on each action. Name the
queries at a business level, the routing, and the server-side re-checks. State
ordering requirements explicitly. If an action differs by role, say so per
role.>

**Validations:**

- <Field> — <mandatory/optional>; <length or range>; <format>.
- <Cross-field rule stated as a condition.>
- <Duplicate prevention rule.>
- <State-transition legality.>
- Direct-URL access — returns <404|403> for users without `<token>`.

<!-- Every bullet must be testable. "As per business rules" is not a
     validation; either state the rule or log it as an open question. -->

---

<!--
================================================================================
  WORKED EXAMPLE -- delete this section when using the template.
  Shown because the difference between a reviewable page and an unreviewable
  one is almost entirely in the wireframe's specificity.
================================================================================

## Page 7 : Leave Request

`NPT-P07` · Status: `TO BE BUILT`

**Page Description:**

Where an employee raises a leave request and sees the balance it will consume.
Reached from the Leave tile on the Home page, from the Leave Balances screen
(Page 9), and from the Apply action on the holiday calendar. The screen shows
only the requester's own balances; a manager raising leave for themselves sees
the same screen as any employee.

**Sections of the page (top-to-bottom):**

- Balance strip -- one card per leave type the employee is eligible for
- Request form -- type, dates, half-day handling, reason
- Overlap warning -- inline, appears once dates are entered
- Actions -- Cancel, Save as Draft, Submit

**Page Design:**

```
+----------------------------------------------------------------------------+
| Nalsoft Portal | Leave Request          Ravi Kumar  |  Bell  |  Sign out   |
+----------------------------------------------------------------------------+
| Home  >  Leave  >  New Request                                             |
+----------------------------------------------------------------------------+
|  Earned Leave        Casual Leave        Sick Leave       Comp Off         |
|  12.5 available      4.0 available       6.0 available    1.0 available    |
|  2.5 pending         0.0 pending         0.0 pending      0.0 pending      |
+----------------------------------------------------------------------------+
|  Leave Type *      [ Earned Leave                                     v ]  |
|  From Date *       [ 18-Aug-2026 ]     To Date *   [ 20-Aug-2026 ]         |
|  Half Day          [x] First day is a half day   [ ] Last day is half day  |
|  Days Requested      2.5   (excludes 1 holiday: 19-Aug-2026 Independence)   |
|  Balance After       10.0                                                   |
|  Reason *          [ Family function at hometown.                       ]  |
|                                                                             |
|  ! Ravi Kumar has an Approved leave on 20-Aug-2026. Overlapping dates are   |
|    not allowed -- adjust the To Date.                                       |
|                                                                             |
|  Approver          Suresh Krishnan  (your reporting manager)                |
+----------------------------------------------------------------------------+
|                        [ Cancel ]  [ Save as Draft ]  [ Submit Request ]   |
+----------------------------------------------------------------------------+
```

**Field Properties:**

| Block | Field Name | Data Type | Unique | LOV | Read Only | Required | Enabled for Edit | Hyperlink | Remarks |
|---|---|---|---|---|---|---|---|---|---|
| Balance Strip | Leave Type Name | Varchar2(60) |  |  | Y |  |  |  | One card per eligible type. |
|  | Available | Number(5,2) |  |  | Y |  |  |  | Derived: entitlement - taken - pending. |
|  | Pending | Number(5,2) |  |  | Y |  |  |  | Derived: sum of Pending requests. |
| Request Form | Leave Type | Varchar2(30) |  | XXNPT_LEAVE_TYPE, filtered to types the employee is eligible for | | Y | Y |  | Drives the balance card highlighted above. |
|  | From Date | Date |  |  |  | Y | Y |  | Not more than 90 days ahead. |
|  | To Date | Date |  |  |  | Y | Y |  | Must be >= From Date. |
|  | First Day Half | CHAR(1) Y/N |  |  |  |  | Y |  | Enabled only when From Date is a working day. |
|  | Days Requested | Derived (Number(5,2)) |  |  | Y |  |  |  | Working days in range, minus holidays, minus half-day adjustments. |
|  | Balance After | Derived (Number(5,2)) |  |  | Y |  |  |  | Available - Days Requested. Turns red when negative. |
|  | Reason | Varchar2(500) |  |  |  | Y | Y |  | Mandatory for all types. 20 to 500 characters. |
| Routing | Approver | Derived |  |  | Y |  |  | Page 8 | XXINT_EMPLOYEE_MASTER_T.MANAGER_ID of the requester. GAP: behaviour when MANAGER_ID is null is not yet decided. |

**Process:**

On load the page reads the requester's eligible leave types and their balances
as at today, and resolves the approver from the employee master's MANAGER_ID.
Days Requested and Balance After recompute on every change to type, dates or
half-day flags -- client-side for responsiveness, and recomputed server-side on
submit, which is the value that is stored.

Submit re-checks eligibility, balance sufficiency and overlap on the server
before inserting, then notifies the approver. Save as Draft persists without
any of those checks and without notifying anyone. Cancel discards.

A request whose Balance After would be negative is rejected on submit, not
merely warned about, unless the leave type permits a negative balance.

**Validations:**

- Leave Type -- mandatory; must be a type the employee is eligible for today.
- From Date -- mandatory; not earlier than the configured backdating window;
  not more than 90 days in the future.
- To Date -- mandatory; must be >= From Date.
- Days Requested -- must be > 0 after holiday and half-day adjustment. A range
  containing only holidays and weekends is rejected.
- Reason -- mandatory; 20 to 500 characters.
- Overlap -- rejected when any Pending or Approved request for the same
  employee covers any date in the range.
- Balance -- rejected when Balance After < 0, unless the leave type's
  Allow Negative Balance flag is Y.
- Approver -- a request cannot be raised when the employee has no MANAGER_ID;
  the message names the HR contact.
- Direct-URL access -- returns 403 for users without an active access row for
  app 74.
-->
