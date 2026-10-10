# PL/SQL Conventions — P1 to P20

Companion to `schema-architect:schema-model` §0 (data objects) and
`api-architect:api-contract` (HTTP). This file owns **program units, local
identifiers, and the mechanics of producing large payloads without running
the database out of memory.**

Cite by ID (`violates P12`), never by paraphrase.

**Evidence note.** Rules P1–P9 and P15–P20 are convention and long-settled
Oracle practice. Rules **P10–P14** rest on hard, documented Oracle limits
(the PL/SQL `VARCHAR2` ceiling, `ORA-01489`, `ORA-04030`) — those limits are
stated inline where they bite. Where a number is a judgement call rather than
a documented limit, it is labelled as such; do not read a tuning suggestion as
a documented constant.

---

## Naming

## P1 — Program units carry a type suffix

The parameter table. **Read it once, hold it constant for the session**, and
match an existing schema's convention over this default if one already exists
(see the SKILL.md — a lone `_p` among two hundred bare names is drift).

| Object | Suffix | Example |
|---|---|---|
| Procedure | `_p` | `get_orders_p`, `create_customer_p` |
| Function | `_f` | `calc_order_total_f`, `is_active_f` |
| Package | `_pkg` | `order_api_pkg`, `customer_util_pkg` |
| Package spec / body files | `.pks` / `.pkb` | `order_api_pkg.pks` |
| Trigger | `_trg` (+ timing) | `app_order_t_biu_trg` |
| Object / collection type | `_typ` / `_tab` | `order_line_typ`, `order_line_tab` |
| Standalone view | `_v` | `app_customer_active_v` |

**Why a suffix rather than a prefix.** A suffix keeps the *business meaning*
first, so an alphabetical listing of a package's contents groups by subject
(`get_orders_p`, `get_order_lines_p`) instead of by type. A prefix convention
inverts that and makes every procedure sort together under `p_`, which is
useless once a package has thirty of them.

**Inside a package, the suffix is still required.** `order_api_pkg.get_orders_p`
reads redundantly at first glance, but the alternative is that a package body
becomes the one place in the schema where you cannot tell a procedure from a
function by name — precisely where it matters most, since a function can be
called from SQL and a procedure cannot.

## P2 — Scope prefixes on every identifier that is not a program unit

| Kind | Prefix | Example |
|---|---|---|
| Formal parameter (IN) | `p_` | `p_order_id` |
| Formal parameter (OUT / IN OUT) | `p_` + `out_`/`io_` | `p_out_status_code`, `p_io_total` |
| Local variable | `l_` | `l_order_count` |
| Global / package-level variable | `g_` | `g_config_cache` — **see P17 before declaring one** |
| Constant | `c_` | `c_max_page_size` |
| Cursor | `cur_` | `cur_open_orders` |
| Record | `r_` | `r_order` |
| Collection / array | `t_` | `t_order_ids` |
| Exception | `e_` | `e_order_not_found` |

**This prefix set and P1's suffix set do not collide**, even though both use
the letter `p`: `p_` is a *prefix on a parameter*, `_p` is a *suffix on a
procedure*. Stated explicitly because it is the first thing a reader
challenges.

**The reason prefixes matter more in PL/SQL than in most languages:** a local
variable named `order_id` inside a procedure that also queries a column named
`order_id` creates a silent capture — `WHERE order_id = order_id` is
tautologically true and returns every row, with no syntax error and no
warning. `WHERE order_id = l_order_id` cannot do that. This is the single
highest-value convention in this file.

**ORDS parameter and bind naming (A7 cross-reference):** When a procedure is
exposed through an ORDS REST handler:
- **Search parameters**: Name formal parameter `p_search` (and bind `:search`).
  NEVER name it `p_q` or bind `:q`. ORDS reserves `q` for its JSON Filter Object
  query syntax; any plain text passed to `?q=search` is answered by ORDS with a
  `400 Bad Request` before the handler or procedure ever runs.
- **Paging parameters**: Name formal parameters `p_page` and `p_limit` (or
  `p_page_number` and `p_rows_per_page`), binding `:p_page` and `:p_limit`.
  NEVER bind `:limit`, `:page`, `:offset`, or deprecated `:page_size`, which
  are reserved by ORDS internal paging machinery and will be captured or
  overwritten.

- **Zero SQL reserved words in formal parameters or variables**:
  Never declare parameters or variables that mirror SQL reserved keywords
  (`p_comment`, `l_date`, `p_number`, `l_uid`, `p_user`, `l_type`, `p_order`,
  `p_mode`, `p_size`, `p_default`, `l_status`). Even with a `p_` or `l_` prefix,
  colliding with reserved concepts obscures SQL statement parsing when
  interacting with native SQL functions. Use concrete domain nouns: `p_comments`
  or `p_comment_text`, `l_target_date`, `p_item_number`, `p_user_id`,
  `p_entity_type`, `p_sort_order`, `p_access_mode`, `p_status_code`.

## P3 — Anchor types to the schema with `%TYPE` and `%ROWTYPE`

`l_customer_name app_customer_t.customer_name%type;` — not
`varchar2(128)`. When the column widens, the PL/SQL follows automatically
instead of failing at runtime with `ORA-06502: character string buffer too
small` in whichever branch happens to hit the long value first.

Use `%rowtype` for a whole-row fetch, and a package-level record type when
the shape is a projection rather than a table.

## P4 — Lowercase source, no quoted identifiers

Oracle folds unquoted identifiers to uppercase in the dictionary regardless
of how you type them, so source case is purely a formatting choice — but mixed
case across files reads as two tool generations colliding (same reasoning as
schema-model §0). This catalog's examples are lowercase.

**Never use double-quoted identifiers** (`"myTable"`). They create objects
that are case-sensitive forever, and every subsequent reference — including
from a client, an ORM, and every ad-hoc query — must quote them identically.

---

## Structure and correctness

## P5 — The package spec is the contract; keep it minimal

Anything not called from outside the package belongs in the body only. A spec
that exposes every helper makes the whole package's internals part of its
public contract, and you cannot refactor a helper without a dependency
recompile cascade.

## P6 — Bind variables always; never concatenate user input into SQL

```sql
-- WRONG — SQL injection, and a hard-parse per distinct value
execute immediate 'select * from app_order_t where status = ''' || p_status || '''';

-- RIGHT
execute immediate 'select * from app_order_t where status = :b1' using p_status;
```

This is a security rule first (injection) and a performance rule second: a
concatenated literal produces a new SQL_ID per distinct value, filling the
shared pool with single-use plans and forcing a hard parse every call. Static
SQL in PL/SQL is bound automatically — dynamic SQL is where this rule gets
broken.

## P7 — Never swallow an exception

```sql
-- WRONG — the error is gone, and the caller believes it succeeded
exception when others then null;

-- WRONG — loses the original error's line number and backtrace
exception when others then raise_application_error(-20001, 'failed');

-- RIGHT — log with the backtrace, then re-raise
exception
   when others then
      log_error_p(p_context   => 'get_orders_p',
                  p_message   => sqlerrm,
                  p_backtrace => dbms_utility.format_error_backtrace);
      raise;
```

`raise;` (bare) preserves the original exception and its stack.
`dbms_utility.format_error_backtrace` is what gives you the *line that
actually threw* rather than the line that caught.

Catch **named** exceptions where you can act on them specifically
(`no_data_found` → return a 404 per A4); reserve `when others` for
log-and-re-raise.

## P8 — Engine procedures do not COMMIT

Transaction control belongs to the caller — the outermost unit that knows
what a complete business transaction is. A procedure that commits internally
cannot be composed into a larger transaction, and turns a partial failure into
half-applied state.

The one legitimate exception is a genuinely independent unit of work
(auditing, error logging) declared `pragma autonomous_transaction`, which
must commit precisely because it is meant to survive the caller's rollback.

## P9 — Validate before mutating

Mirrors `api-contract` A19. Run every check first, then mutate — so a request
that fails validation has changed nothing, and no rollback is needed to keep
the row consistent.

---

## Large data — P10 to P14

**This is the section most often skipped.** The failure mode is not a wrong
answer; it is a procedure that works in dev against 50 rows and takes the
database down in production against 5 million.

## P10 — Decide chunking by BOUNDEDNESS, not by current row count

The question is never "is this a lot of rows today." It is **"what is the
ceiling, and who controls it."**

| Class | Test | Chunking needed? |
|---|---|---|
| **Bounded by construction** | A closed set whose size is fixed by the data model — a lookup/code set, a status list, a country list. Growth requires a human to insert a row deliberately. | **No.** Fetch it whole. Chunking here is pure complexity with no payoff. |
| **Bounded by a business rule** | Children of one parent where the domain caps the count — line items on an order, phone numbers on a contact. State the cap explicitly. | **No** — *if* you can name the cap and it is small (dozens/low hundreds). Write the cap in a comment; the next reader must not have to re-derive it. |
| **Unbounded / caller-driven** | Anything the caller filters or the user grows without limit — orders, events, audit rows, search results, any `WHERE` over a transaction table. | **Yes.** Paginate at the API (A7/A23) *and* chunk internally (P12). |
| **Genuinely huge, non-interactive** | Exports, reconciliations, bulk feeds. | **Yes**, plus streaming rather than a materialized payload (P14). |

**The trap this table exists to prevent:** "it's only ever a few rows" is a
statement about *today's data*, not about the schema. If nothing in the model
enforces the ceiling, it is unbounded — treat it as such. A `WHERE
customer_id = :x` on an orders table is unbounded even though most customers
have three orders, because one customer will eventually have forty thousand.

**And the opposite trap, which is real too:** paginating a 12-row lookup table
adds a page loop, a total count, and a cursor to every client for no benefit.
Not everything needs chunking. That is the whole point of the table.

## P11 — `SELECT ... BULK COLLECT INTO` with no LIMIT is a memory bug

```sql
-- WRONG — loads the ENTIRE result set into session PGA at once.
-- On a large table this is ORA-04030 (out of process memory), and it fails
-- the whole instance's memory budget, not just this session's query.
select * bulk collect into l_orders from app_order_t;
```

Unbounded `BULK COLLECT` is only acceptable against a **P10 bounded-by-
construction** set, and even then only where you can state the ceiling.

## P12 — Chunk with `BULK COLLECT ... LIMIT` and an explicit exit

```sql
declare
   c_batch_size constant pls_integer := 500;   -- tuning value, see below
   cur_orders   sys_refcursor;
   t_orders     t_order_tab;
begin
   open cur_orders for select * from app_order_t where status = p_status;
   loop
      fetch cur_orders bulk collect into t_orders limit c_batch_size;
      exit when t_orders.count = 0;

      -- process the batch here

      -- EXIT PLACEMENT IS LOAD-BEARING: `exit when cur_orders%notfound`
      -- placed BEFORE processing silently drops the final partial batch,
      -- because the fetch that returns the last 37 rows also sets %NOTFOUND.
      -- Test on `.count = 0` after processing, or check %NOTFOUND only after
      -- the batch has been handled.
   end loop;
   close cur_orders;
end;
```

**On the batch size:** 100–1000 is the usual working range, and **500 here is
a starting point, not a documented constant.** The trade is round-trips
(smaller batches = more context switches between the SQL and PL/SQL engines)
against PGA per session (larger batches = more memory × every concurrent
session). Measure against your own row width; a table with a CLOB column
wants a far smaller batch than one with five numbers.

## P13 — Build large text as a CLOB with `DBMS_LOB`, not with `||`

Two separate hard limits, and both bite in the same place:

- A PL/SQL `VARCHAR2` variable maxes at **32,767 bytes**. Exceed it and you
  get `ORA-06502`.
- `LISTAGG` raises **`ORA-01489: result of string concatenation is too long`**
  once its result exceeds the SQL `VARCHAR2` limit (4,000 bytes by default;
  32,767 with `MAX_STRING_SIZE=EXTENDED`).

So any response body that can grow with row count **must** be a `CLOB` from
the start. Converting later is a rewrite of every assembly site.

```sql
-- WRONG — O(n²). Each `l_body := l_body || x` copies the whole accumulated
-- CLOB. At a few thousand appends this dominates the procedure's runtime.
l_body := l_body || l_row_json;

-- RIGHT — appends in place.
dbms_lob.createtemporary(l_body, cache => true);
...
dbms_lob.writeappend(l_body, length(l_row_json), l_row_json);
...
dbms_lob.freetemporary(l_body);   -- ALWAYS, including on the exception path
```

**`freetemporary` is not optional.** A temporary LOB that is not freed lives
until the session ends; under a pooled connection model (P17) the session does
not end, so the leak accumulates across unrelated requests until the temp
tablespace fills.

**Prefer generating the JSON in SQL where you can** — `JSON_OBJECT` /
`JSON_ARRAYAGG` are usually faster and shorter than hand-assembling text.
Critically: **add `RETURNING CLOB`**, or the aggregate inherits the same
`VARCHAR2` ceiling and fails at exactly the scale you built it for:

```sql
select json_arrayagg(
          json_object('id' value order_id, 'total' value order_total)
          returning clob)
  into l_body
  from app_order_t;
```

## P14 — Ref cursor vs materialized payload

| Approach | Use when | Cost |
|---|---|---|
| **Materialized CLOB** (build the whole body, return it) | Paginated collections, single resources — anything with a bounded page size. This is what `api-emit-handler`'s templates do. | Whole page held in memory at once. Fine at a page; fatal at a million rows. |
| **`SYS_REFCURSOR` out-parameter** | Large reads where the consumer can stream, and where you are *not* hand-building JSON. | **ORDS does not auto-paginate a PL/SQL handler's ref cursor** — see A7. If you return one, pagination is entirely yours. |
| **Chunked/streamed export** | Non-interactive bulk export. | Needs a job/file/stage mechanism, not a synchronous REST call. A request that takes four minutes will be killed by some proxy in between regardless of what the database can do. |

**The rule of thumb:** a synchronous HTTP request should return a *page*, not
a *dataset*. If the honest answer to "how many rows could this return" is
"as many as exist," the endpoint needs pagination (A7) or it needs to become
an asynchronous export job (A23) — not a bigger timeout.

---

## Runtime behaviour

## P15 — `FORALL` for bulk DML

```sql
forall i in 1 .. t_order_ids.count
   update app_order_t
      set status = p_status
    where order_id = t_order_ids(i);
```

One context switch instead of N. A row-by-row loop of single-row DML ("slow
by slow") is the most common PL/SQL performance defect. Pair with
`save exceptions` when partial success is acceptable, and read
`sql%bulk_exceptions` afterwards — otherwise one bad row rolls back the batch.

## P16 — `PLS_INTEGER` for loop counters and array indexes

`PLS_INTEGER` uses hardware arithmetic; `NUMBER` is a software-emulated
decimal type. For a counter incremented millions of times the difference is
measurable. Use `NUMBER` when the value is *data* (a monetary amount, an id
from a column) and `PLS_INTEGER` when it is *control flow*.

## P17 — No request state in package-level globals under pooled connections

A package-level variable persists for the life of the **database session**,
not the request. ORDS (and any connection-pooled client) hands the same
session to unrelated requests in sequence, so a `g_current_user_id` set by
request A is still set when request B arrives — and request B may read another
user's identity.

This is a **security** defect, not a tidiness one, and it is the reason
`api-architect:api-audit` ships an automated package-global scan.

Legitimate package-level state is limited to genuinely immutable, non-request
data: constants, and caches keyed such that a stale entry is harmless. Request
state is passed as parameters, always.

## P18 — `COALESCE` over `NVL` by default

`NVL` evaluates **both** arguments regardless of whether the first is null, so
`nvl(l_x, expensive_lookup_f(...))` runs the lookup every time. `COALESCE`
short-circuits, and takes more than two arguments. Use `NVL` only where you
specifically want the eager evaluation, which is almost never.

## P19 — A function called from SQL must be deterministic and side-effect free

If it will be used in a `WHERE`, `SELECT`, or index expression, it must not
write data and must return the same output for the same input. Mark it
`deterministic` only when it genuinely is — the optimizer will cache results
on that promise, and a wrongly-marked function returns stale answers that are
extremely hard to trace.

## P20 — Instrument every entry point

Mirrors A18. Each public procedure logs entry with its correlation/request id
and exits with an outcome, so a failure in production can be traced to a
request without a debugger. Pair with P7's backtrace logging: entry/exit gives
you *where*, the backtrace gives you *why*.
