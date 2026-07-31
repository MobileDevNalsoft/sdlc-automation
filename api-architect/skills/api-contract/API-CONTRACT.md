# REST API Contract

Reviewable checklist, rules **A1–A22**, plus a separately-labeled legacy
section. These rules are stack-neutral — they describe what a well-designed
HTTP API does, independent of implementation language. Oracle ORDS + PL/SQL
is used throughout as **one concrete binding** of the rules (this plugin's
primary worked implementation), called out in "ORDS binding" boxes. If your
stack isn't ORDS, apply the rule and substitute your own framework's
equivalent mechanism.

Cite rules by number in review (`"violates A5"`), not by paraphrase — that's
the point of numbering them.

**Framing note:** a contract file (this one, or an OpenAPI/JSON Schema
document, or a manifest — see A20) is the declared surface. What's actually
deployed can drift from it. Rule A19 and the `api-audit` skill exist because
that drift is a "when," not an "if," on any long-lived API — detect it, don't
assume the file and the live system agree.

---

## A1 — Collections are plural nouns; paths contain nouns, not verbs

`/customers`, `/orders`, `/products` — every top-level collection resource is
a plural noun. No verb in the path (`/getCustomers`, `/customer-list` are
both wrong). This is close to universally agreed practice (Microsoft REST API
Guidelines, Google API Improvement Proposals, Zalando RESTful API Guidelines
all converge on it) and one of the few conventions with no serious
competing school of thought.

## A2 — A single resource is `/<resources>/{id}`

The collection stays plural; the identifier is a path parameter, not a
suffix or a query string (`/customers/{id}`, not `/customers?id={id}` and not
`/customer/{id}`). Pick **one** naming convention for the id parameter
(`{id}` generically, or `{customerId}` per-resource) and apply it
consistently across every endpoint — consistency matters more than which
option you pick.

## A3 — Verb-to-operation mapping is resource-oriented, not action-oriented

| Operation | Method + path | Notes |
|---|---|---|
| Create | `POST /<resources>` | Returns `201 Created` + `Location` header pointing at the new resource |
| List | `GET /<resources>` | Supports pagination (A7), filtering, sorting via query params |
| Read one | `GET /<resources>/{id}` | `404` if it doesn't exist (see A4 on when to use `403` instead) |
| Full replace | `PUT /<resources>/{id}` | Idempotent — the same request repeated produces the same end state. Caller sends the complete resource representation. |
| Partial update | `PATCH /<resources>/{id}` | Caller sends only the fields that change |
| Delete | `DELETE /<resources>/{id}` | Returns `204 No Content` on success |

This is the shape documented by every major public API style guide (Stripe,
GitHub, Microsoft, Google, Zalando) and by RFC 9110 (HTTP Semantics) §9's
method definitions. See the **Legacy Patterns** section for the single
`POST /<resource>/save` alternative and why it's worse.

## A4 — HTTP status codes carry the real result. Do not embed a shadow status in the body.

The single most important rule in this contract. **The HTTP status line is
the result.** A response is not "successful" because a client happened to
parse its body correctly — it is successful because the status line says so,
and every piece of infrastructure between the server and the caller
(reverse proxies, CDNs, load balancers, uptime monitors, HTTP client
libraries, retry middleware, APM/observability tooling) makes decisions
based on that status line without ever looking at the body. See A-Legacy-1
for what breaks when this rule is violated.

| Code | Meaning | Use it when |
|---|---|---|
| `200 OK` | Success, response has a body | Default success for GET/PUT/PATCH |
| `201 Created` | Success, new resource created | POST that creates something; include `Location` |
| `204 No Content` | Success, no body | DELETE, or PUT/PATCH that returns nothing |
| `400 Bad Request` | The request is malformed | Invalid JSON, wrong types, missing required fields — the request could not even be understood |
| `401 Unauthorized` | The caller is not authenticated | Missing/invalid/expired credential. (Misnamed by history — it really means "unauthenticated.") |
| `403 Forbidden` | The caller is authenticated but not allowed | Valid credential, insufficient permission for this specific action/resource |
| `404 Not Found` | No resource at this URI | Also used deliberately to hide existence — see below |
| `409 Conflict` | The request conflicts with current server state | Duplicate unique key, stale version on a concurrent update (see A11) |
| `422 Unprocessable Content` | Well-formed request, semantically invalid | Valid JSON/types, but violates a business rule (e.g. `end_date` before `start_date`) |
| `429 Too Many Requests` | Rate limit exceeded | Include `Retry-After` (A12) |
| `500 Internal Server Error` | Unexpected server-side fault | Unhandled exception; log it, don't leak internals to the client |
| `503 Service Unavailable` | A dependency is down or the server is shedding load | Include `Retry-After` when known |

**Pairs people confuse:**

- **401 vs 403** — 401 means "I don't know who you are" (or your credential
  is invalid/expired). 403 means "I know who you are, and you're not allowed
  to do this." Returning 401 for a permission failure tells the client to
  re-authenticate, which will never fix the problem — that's a 403.
- **400 vs 422** — 400 is "I couldn't even parse/understand this request"
  (wrong JSON shape, wrong type, missing required field). 422 is "I
  understood it perfectly, and it's invalid for a business reason" (a
  well-formed date that's in the past when it must be in the future). Don't
  collapse these — a client that gets 400 should fix its request-building
  code; a client that gets 422 should show the user a validation message.
- **404 vs 403 for existence-hiding** — when a resource's *existence* is
  itself sensitive (a private document, another tenant's record), returning
  403 confirms "this exists but you can't see it," which is itself a leak.
  Return 404 instead so an unauthorized caller can't distinguish
  "doesn't exist" from "exists, not yours." Document this choice explicitly
  wherever it's used, since it's an intentional deviation from the literal
  401-vs-403 semantics above.

**ORDS binding:** a PL/SQL-source-type handler sets the real status via the
`:status_code` implicit bind variable. **VERIFIED:** `:status_code` is
documented in Oracle's own ORDS Developer's Guide, "Implicit Parameters"
chapter, with an explicit "Since" column value of **18.3** (confirmed against
the version-tagged 18.3 doc set directly, not just the general/latest docs).
Confirm the deployed ORDS version is ≥18.3 before relying on it — this is a
real precondition, not boilerplate caution, since ORDS instances several
majors behind current are common in the wild.

## A5 — Error response body: RFC 9457 `application/problem+json`

**VERIFIED:** RFC 9457 ("Problem Details for HTTP APIs") obsoletes RFC 7807
(confirmed directly against the RFC text at rfc-editor.org) and is the
current standard for machine-readable HTTP error bodies. Media type
`application/problem+json`. Fields:

```json
{
  "type": "https://example.com/problems/insufficient-balance",
  "title": "Insufficient balance",
  "status": 422,
  "detail": "Account 7 has a balance of 30, but a transfer of 50 was requested.",
  "instance": "/accounts/7/transfers/abc-123",
  "balance": 30,
  "requested": 50
}
```

- `type` — a URI identifying the problem category (defaults to `about:blank`
  if you don't have one; a real URI that resolves to human-readable docs is
  more useful, but doesn't need to be internet-routable for an internal API).
- `title` — short, human-readable, stable across occurrences of the same
  `type` (don't interpolate request-specific data into it — that belongs in
  `detail`).
- `status` — the HTTP status code repeated in the body, for clients that log
  the body without the transport layer. Advisory — the actual response
  status line is authoritative if they ever disagree.
- `detail` — human-readable, specific to *this* occurrence.
- `instance` — a URI identifying this specific occurrence (a request ID or
  the resource path is fine).
- Anything else (`balance`, `requested` above) is a problem-type-specific
  **extension** — this is expected and part of the spec, not a violation of it.

Set the response `Content-Type` to `application/problem+json` on error paths.
A client (or gateway) can then distinguish "this is a structured error" from
"this is just a JSON body" without inspecting the status code first.

**ORDS binding:** set `:body_text` (or `:body` for a BLOB) to the
problem+json payload, `:status_code` to the matching status, and set
`Content-Type` via `owa_util.mime_header('application/problem+json')` (or the
handler's declared media type) before writing. See
`api-emit-handler`'s `templates/problem-json-helper.sql` for a reusable
builder procedure.

## A6 — JSON field casing: pick one, document it, enforce it at one boundary

Neither `snake_case` nor `camelCase` is objectively correct — both are
widely used in production APIs (Stripe and GitHub use snake_case; most
JavaScript-ecosystem APIs and Google APIs use camelCase). What actually
matters:

1. **Pick one casing for the wire format** and use it for every field, in
   every request and response body, with no exceptions carved out for
   "just this one field."
2. **Translate at exactly one boundary.** If your database or backend
   language has a different native convention (e.g. `snake_case` SQL
   columns feeding a `camelCase` wire format), do that translation in a
   single mapper/serialization layer — not ad hoc at each handler, and never
   left to the frontend to paper over inconsistently.
3. Document the choice in this contract so a new endpoint doesn't introduce
   a second casing by accident.

Bind/parameter names inside your implementation (ORDS bind variables,
PL/SQL formal parameters, ORM column mappings) are internal and don't have to
match the wire casing — but be deliberate about where the translation
happens, and don't let an internal naming quirk leak onto the wire.

## A7 — Pagination: offset by default, cursor/keyset for large or actively-changing collections

**Offset pagination** (`?page=2&page_size=20`, response includes
`total_count`) is a fine default — simple to implement, simple for clients
to reason about, supports "jump to page N." Keep it for small, relatively
static collections.

It has two real costs once a collection is large or being written to
concurrently:

- **Drift.** If rows are inserted or deleted between page fetches, offset
  pagination can skip rows or return duplicates across pages — the *n*-th
  row by insertion order isn't stable while the underlying set mutates.
- **`COUNT(*)` cost.** Computing `total_count` requires scanning (or at best
  index-scanning) the full filtered set on every page request, which gets
  expensive as the table grows.

**Cursor (keyset) pagination** is the standard fix for both, and is what
most large-scale public APIs actually use for feed/collection endpoints
(GitHub, Stripe, Slack). Instead of an offset, the client sends an opaque
cursor derived from the **last row's sort key** on the previous page:

```
GET /orders?limit=20&cursor=eyJpZCI6MTIzNDV9
```

```json
{
  "data": [ ... ],
  "next_cursor": "eyJpZCI6MTIzNTY=",
  "has_more": true
}
```

Requirements: a **stable, unique sort key** (a monotonically increasing id
or `(created_at, id)` composite — never a mutable field), and the query
becomes `WHERE (created_at, id) > (:cursor_created_at, :cursor_id) ORDER BY
created_at, id FETCH FIRST :limit ROWS ONLY` rather than `OFFSET`. No
`total_count` is provided (or it's provided as a separate, explicitly
"approximate/expensive" opt-in field) — that's the tradeoff for pagination
that doesn't drift.

Recommendation: ship offset pagination for anything genuinely small and
mostly-static; use cursor pagination for anything user-facing at scale,
anything with a high write rate, or anything where "the same row appearing
twice" or "a row silently skipped" is a real problem for the caller.

See **A23** for the prior question — whether this collection needs pagination
at all, and what to do when it is too big for any synchronous response.

### ORDS binding — three facts that change what you write

Fetched from Oracle's ORDS implicit-parameters documentation, 2026-07-31.

**1. Use `:fetch_offset` / `:fetch_size`. The `:page_*` pair is deprecated.**

| Parameter | Status |
|---|---|
| `:fetch_offset`, `:fetch_size` | **Recommended** (12c+), pairs with the row-limiting clause |
| `:page_offset`, `:page_size` | **Deprecated** |
| `:row_offset`, `:row_count` | Legacy — the `row_number()` wrapper approach |

```sql
select * from app_order_t
 order by order_id desc
offset :fetch_offset rows fetch next :fetch_size rows only
```

ORDS sets `:fetch_size` to *page size + 1* — the extra row is how it decides
whether a next page exists, and it is never returned to the client. Do not
"correct" the off-by-one.

**2. Those names are RESERVED — do not reuse them as custom bind names.**

In a `source_type_plsql` handler, ORDS binds any parameter whose name matches
an implicit parameter with **its own** value. So a handler that declares
`:page_size` intending "the client's requested page size" is naming a
deprecated ORDS implicit parameter, and what arrives is whatever ORDS decides
to supply — not necessarily the query parameter the client sent.

Name custom binds so they cannot collide: `:p_page`, `:p_limit`, `:p_cursor`.
`api-emit-handler`'s collection template uses the non-colliding names for
exactly this reason.

**3. A PL/SQL handler returning a `SYS_REFCURSOR` gets NO automatic
pagination.**

ORDS auto-paginates its own SQL-based (`source_type_query`) handlers. It does
**not** paginate a ref cursor handed back from a PL/SQL block — the client
receives the whole cursor. If you return a ref cursor from a collection
endpoint, **pagination is entirely your code's responsibility**, and the
absence of it will not produce an error, just an unbounded response.

This is why this plugin's collection template hand-rolls pagination with
explicit binds and a materialized CLOB body rather than returning a ref
cursor — see `plsql-conventions` P14 for the trade-off table.

## A8 — Authentication: `Authorization: Bearer <token>`

Use the standard `Authorization: Bearer <token>` header (RFC 6750) with
either a validated JWT (self-contained, signature-checked, short-lived) or
an opaque token checked against a server-side session store. This beats a
custom header (`X-API-Key`, `X-Session-Token`, etc.) for concrete reasons,
not just convention:

- Every API gateway, reverse proxy, load balancer, and HTTP client library
  already understands the `Authorization` header — logging redaction,
  auth-passthrough rules, and SDK auth helpers are built around it for free.
- A custom header gets no such support; every consumer has to be told about
  it individually, and generic tooling (e.g. an API gateway's built-in JWT
  validation) can't help you.
- It's what every API documentation/client-generation tool (OpenAPI security
  schemes, Postman, generated SDKs) expects by default.

**ORDS binding:** read the header the same way as any other — ORDS has
first-class OAuth2/JWT-based security options (`ords.enable_schema` with
`p_auto_rest_auth`, or OAuth2 client-credentials flows since 18.3), or, if
authentication is handled by a custom PL/SQL layer, extract the bearer token
via `owa_util.get_cgi_env('HTTP_AUTHORIZATION')` and strip the `Bearer `
prefix. Either way it's the standard header name — only the validation logic
behind it is custom.

## A9 — Identity is always resolved server-side from the credential — never trusted from the payload

This is the one rule in this contract that is not up for debate and has no
"it depends" — get this wrong and you have an authorization bypass, not a
style nit.

The user performing an action (`created_by`, `updated_by`, "who is this
request acting as") is **always** re-derived server-side from the validated
credential (the JWT's subject claim, or the session record the opaque token
resolves to) — **never** trusted from a field the client put in the request
body. A `created_by` or `user_id` field in a POST/PUT body is, at most, an
advisory hint a server may cross-check; it must never be the value actually
written.

**The attack this prevents:** a client sets `created_by` (or `user_id`,
`acting_as`, etc.) in the request payload to someone else's identity. If the
server trusts it, every record that client creates is now attributed to a
different person — forged audit trails at minimum, and if any
authorization decision anywhere reads that field back (e.g. "the creator can
always edit their own record"), a straightforward privilege escalation.

**A specific trap under connection pooling:** if your database session
context (Oracle `SYS_CONTEXT`, or any equivalent ambient-session mechanism in
another stack) is used as an identity source, and your API layer runs over a
**pooled** connection, that context reflects the **pool's proxy/service
user** — not the end user who made the HTTP request. A different end user's
request can reuse the same pooled connection on the next call and would
silently inherit whatever identity the context mechanism reports. This makes
pooled session context structurally wrong as an identity source, independent
of any application-level bug — resolve identity from the validated
credential on every request, and never from ambient connection state.

## A10 — Idempotency keys for unsafe, retryable operations

Any `POST` that has a side effect a client might need to retry (payment
creation, order placement) should accept an `Idempotency-Key` header. The
server stores the key alongside the operation's result; a retried request
with the same key returns the original result instead of performing the
operation twice. This is the mechanism Stripe popularized and is now
common practice for any API where "the client's connection dropped after
the server processed the request, before the response arrived" is a real
scenario (which is: every network call).

`PUT` and `DELETE` are idempotent by definition (A3) and don't need this;
it's specifically for `POST`, where "create the same thing twice" is
otherwise indistinguishable from "the retry is expected to be a no-op."

## A11 — Optimistic concurrency: `ETag` / `If-Match`, or an explicit version field

For `PUT`/`PATCH`/`DELETE` on a resource that might be concurrently modified,
give the client a way to say "only apply this if the resource hasn't changed
since I last read it":

- Server returns an `ETag` (or a `version` field in the body) with every
  `GET`/`PUT`/`PATCH` response.
- Client sends it back as `If-Match: <etag>` on the next `PUT`/`PATCH`/`DELETE`.
- Server compares against the current value: match → proceed; mismatch →
  `409 Conflict` (or `412 Precondition Failed` for the `If-Match` header
  case specifically) with a problem+json body (A5) explaining the conflict.

Without this, "last write wins" silently discards a concurrent change with
no signal to either client that it happened. A version column
(`OBJECT_VERSION_NUMBER`, `version`, `updated_at` used as a compare value) is
the same idea implemented as an ordinary column instead of the HTTP
conditional-request mechanism — either is fine; `ETag`/`If-Match` is more
discoverable to generic HTTP tooling, a version column is simpler to
implement directly in SQL.

## A12 — Rate limiting: `429` + `Retry-After`

When a caller exceeds a rate limit, return `429 Too Many Requests` with a
`Retry-After` header (seconds, or an HTTP date) telling the client when it's
safe to retry. Optionally include `X-RateLimit-Limit` /
`X-RateLimit-Remaining` / `X-RateLimit-Reset` (a de facto convention, not a
formal RFC, but extremely widely deployed) so well-behaved clients can
self-throttle before hitting the limit at all.

## A13 — Request/correlation ID propagation

Every request should carry (or be assigned, if absent) a correlation ID —
accept an inbound `X-Request-Id` / `traceparent` (W3C Trace Context) header
if the caller sends one, generate one if not, and:

- Include it in every log line touched while handling the request.
- Return it in the response (same header name) so a client can quote it back
  when reporting an issue.
- Propagate it to any downstream call the handler makes, so a single request
  is traceable end-to-end across services.

## A14 — Structured logging

Log request handling as structured data (JSON lines, or your platform's
structured-logging equivalent) — method, path, status, latency, correlation
ID (A13), resolved identity (A9) — rather than free-text lines. This is what
makes A13's correlation ID actually useful: a log aggregator can filter on
it instantly; grepping free text at scale cannot.

## A15 — Input validation at the boundary

Validate structurally (types, required fields, formats) before any
business logic runs, and explicitly decide — and document — what happens to
fields the schema doesn't recognize: reject the request (safer default,
catches client typos and stale integrations early) or ignore silently
(more lenient, but hides mistakes). Either is defensible; an *undocumented*
default is not, because a client can't tell whether an unrecognized field
being ignored is "supported behavior" or "we haven't validated this yet."

## A16 — CORS and security headers

For any endpoint reachable from a browser: an explicit CORS policy
(`Access-Control-Allow-Origin` scoped to actual known origins, not `*` on
anything that accepts credentials) rather than an accidental wildcard.
Baseline security response headers (`X-Content-Type-Options: nosniff`,
`Content-Security-Policy` where applicable, `Strict-Transport-Security` on
anything served over TLS) belong at the gateway/proxy layer if you have one,
or on every response if you don't.

## A17 — Versioning: pick a mechanism, prefer not needing it

Two common mechanisms:

- **URI-path versioning** (`/v1/customers`, `/v2/customers`) — simplest to
  reason about, trivially routable/cacheable per version, but a new major
  version means maintaining parallel URL trees.
- **Media-type/header versioning** (`Accept: application/vnd.example.v2+json`,
  or a custom `X-API-Version` header) — keeps one URL per resource across
  versions, but is less visible (you can't tell the version from the URL
  alone) and less friendly to simple tooling (curl-by-hand, browser
  address bar).

Either is defensible; URI-path versioning is more common for public APIs
because of its operational simplicity (per-version routing, caching,
deprecation-by-path). Whichever you choose, the more important practice is
**additive-change-first**: prefer adding new optional fields/endpoints over
bumping a version at all. Most "we need v2" situations are actually a
backward-compatible addition in disguise; reserve a real version bump for
genuine breaking changes (removing/renaming a field, changing a type,
changing a status code's meaning).

## A18 — Instrument every entry point for traceability

Every request-handling entry point should record enough for an operator to
attribute load, latency, or a stuck session to the specific endpoint/action
that produced it — not just "something in this process is slow." Concretely:
set a module/action (or your platform's equivalent session-tagging
mechanism) at the top of every handler before any other logic runs.

**ORDS/PL-SQL binding:** `DBMS_APPLICATION_INFO.SET_MODULE` /
`.SET_ACTION` at the top of every procedure, so `V$SESSION.MODULE`/`.ACTION`
identifies which endpoint a given pooled session is currently executing —
without this, every pooled session looks identical in `V$SESSION` and a
stuck or expensive session can't be attributed to a specific endpoint.

## A19 — Validation before any mutation

Structural validation (A15), then business-rule validation, both complete
**before** the first write. A handler that starts writing and then discovers
a later field is invalid has to either leave a partial write in place or
implement compensating rollback logic — both worse than rejecting the whole
request up front. Order: parse/structural checks → business-rule checks →
identity resolution (A9) → concurrency check (A11) → the actual mutation →
response.

## A20 — The checked-in contract is truth; drift is detected, not tolerated

Whatever your source of truth is for "what the API surface looks like" (an
OpenAPI document, a manifest file, hand-written route definitions in a
repo) — that checked-in definition wins over whatever is actually live. If
a live deployment and the checked-in definition ever disagree, the fix is to
**republish from the file**, not to hand-edit the live system to match
reality and leave the file stale. A gap between "declared" and "live" is a
finding to close, not a state to leave standing — see the `api-audit` skill,
which diffs both directions (declared-not-live, and live-not-declared; the
second is the more dangerous one, since it means something is running that
no one's contract review ever saw).

## A21 — Contract-first for greenfield; enforced hand-written DTOs for retrofits

For a **new** API surface, an OpenAPI (or JSON Schema / gRPC / GraphQL SDL,
depending on style) contract as the source of truth, with client and
server-stub code generated from it, is current best practice — it keeps the
contract and the implementation from silently diverging, and gives you
request/response validation and client SDKs for free. Don't reject codegen
as a blanket policy; it earns its keep on new work.

For a **large existing hand-rolled surface** where retrofitting full
contract-first tooling isn't practical in one pass, the pragmatic path is:
hand-written DTOs/types living in the same commit as the handler that uses
them (a review or CI check that flags one changing without the other), plus
runtime schema validation at the client boundary (e.g. a dev-mode schema
parse that fails loudly on an unexpected shape) as the actual drift
tripwire. This is a transitional strategy for an existing codebase, not the
target state — migrate toward A21's contract-first approach incrementally
as surfaces get touched, rather than treating hand-written DTOs as
permanent.

## A22 — Assertions/guard clauses complement, not replace, automated tests

A guard-clause idiom (raise a specific, catchable error on a violated
invariant, before proceeding) is a good lightweight defense for conditions
that should be structurally impossible if callers are well-behaved — but
it's not a substitute for an actual automated test suite (unit tests around
business logic, contract tests around the API surface, an integration
suite hitting real endpoints). Use both: guard clauses for defensive runtime
invariants, a real test framework for the "does this endpoint do what it
claims" question. Don't let "we have assert-style guard clauses" stand in
for "we have tests."

## A23 — Large payloads: decide by boundedness, and know which of the four shapes you need

A7 covers *how* to paginate. A23 covers the prior question — **does this
response need bounding at all, and if the data is genuinely huge, is a
synchronous REST call even the right delivery mechanism.**

### Step 1 — classify the collection

Same test as `schema-architect:plsql-conventions` P10, and the two must agree:
the API shape and the PL/SQL that fills it are one decision, not two.

| Class | Test | Shape |
|---|---|---|
| **Bounded by construction** | closed set, grows only by deliberate human insert (lookup/code/status/country lists) | **Return it whole. No pagination.** |
| **Bounded by business rule** | children of one parent, capped by the domain (order lines, contact phone numbers) | Return whole **only if** you can name the cap and it is small. State the cap in the contract. |
| **Caller-driven / unbounded** | anything filtered or grown by users (orders, events, audit, search) | **Paginate (A7).** Offset for small/static, cursor for large/mutating. |
| **Bulk / export scale** | reconciliations, full extracts, feeds — "all of it", by design | **Not a synchronous endpoint.** See step 3. |

**Paginating a 12-row lookup table is a defect too.** It adds a page loop, a
count, and cursor handling to every client for zero benefit. "Always
paginate" is as wrong as "never paginate" — the classification is the rule.

### Step 2 — cap what you serve, regardless of what was asked for

Every paginated endpoint declares a **maximum** page size and clamps to it
silently rather than honouring `?page_size=1000000`:

```
page_size: default 20, max 100   (values above max are clamped, not rejected)
```

An uncapped `page_size` is a denial-of-service vector that needs no
attacker — one enthusiastic client integration will find it. Clamping rather
than erroring keeps a naive client working instead of breaking it with a 400
it does not know how to handle. Document the cap in the contract so the
clamp is not a surprise.

### Step 3 — when it genuinely is "all of it", stop using a request/response

A synchronous HTTP call is the wrong shape for a multi-million-row extract,
and no timeout increase fixes it — a load balancer, reverse proxy, or gateway
between you and the client will terminate a long-held connection regardless
of what the database is capable of. Use one of:

- **Async export job.** `POST /exports` → `202 Accepted` + a job id;
  `GET /exports/{id}` reports status; the payload is fetched from a
  pre-signed URL or object store when ready. This is what large public APIs
  do, and it survives the client disconnecting.
- **Streaming response** (`Transfer-Encoding: chunked`, NDJSON or CSV). Viable
  when the consumer can process incrementally *and* nothing between you and
  it buffers the whole body. Note the real cost: **you cannot send a
  meaningful HTTP error status once the first byte is on the wire** — the
  status line is already sent, so a mid-stream failure has to be signalled
  in-band, which every consumer must then handle.
- **Cursor pagination the client loops** (A7). Simplest, and usually the right
  answer for "large but not enormous" — no new infrastructure.

### Step 4 — compression is not a substitute for bounding

`Content-Encoding: gzip` is worth enabling for JSON (it compresses well), but
it reduces *bytes on the wire*, not the memory the server used to build the
payload or the time the database spent producing it. A 200 MB response
gzipped to 12 MB still built 200 MB in server memory first. Compress **and**
bound; never compress **instead of** bounding.

### ORDS binding

- The database-side mechanics — `BULK COLLECT ... LIMIT`, CLOB assembly with
  `DBMS_LOB`, `JSON_ARRAYAGG ... RETURNING CLOB` — are
  `plsql-conventions` **P12–P13**. A handler that respects A23 and ignores
  P13 will still fail, with `ORA-06502`, at exactly the size it was built for.
- A response body assembled into a `VARCHAR2` out-bind is capped at **32,767
  bytes**. Any collection response must use a `CLOB` out-bind from the start.

---

## Legacy patterns and how to migrate off them

These patterns are common in **older codebases** — including ones built on
ORDS + PL/SQL specifically, where they were often the path of least
resistance before the alternatives below existed or were well understood.
They are documented here **only** so you can recognize them and migrate
deliberately — not as options for new work.

### L1 — Always-HTTP-200, real result embedded as a body field

**What it looks like:** every response — success, validation failure, auth
failure, server error — returns HTTP `200`, with a JSON field (commonly
named `response_code`, `status_code`, `result_code`, or similar) carrying
the "real" outcome as an integer.

**Why it's a genuine problem, not just a style preference:** it breaks every
piece of standard HTTP-aware infrastructure sitting between your server and
the caller. A reverse proxy or CDN caches it as a successful response. A
load balancer's health check reports the backend healthy. An uptime monitor
shows 100% success during an actual outage. Standard HTTP client libraries
(which raise/reject on 4xx/5xx by convention) silently treat every failure
as success, so callers must remember to unwrap and re-check a body field on
literally every call or they'll miss failures. Retry middleware that
decides "retry on 5xx, don't retry on 4xx" can't function at all, because
everything looks like a 200 to it. Observability tooling that alerts on
error-rate-by-status-code sees a flat 100% success line no matter what's
actually happening.

**How to migrate off it — incrementally, per endpoint, never globally:**

1. Confirm your runtime actually supports setting a real status from
   application code (for ORDS: confirm the deployed version is ≥18.3 and
   the `:status_code` bind is available — verified in A4 above).
2. For **new endpoints only**, use real status codes and problem+json (A4,
   A5) from day one. Don't add another instance of this pattern.
3. For **existing endpoints**, migrate one at a time, opt-in, with the
   endpoint's version/path signaling the change (e.g. a new path-versioned
   route, or a header the client opts into) — never flip the whole surface
   at once. A simultaneous status-code change across every endpoint is a
   breaking change for every client that reads the embedded field today, and
   there is no way to roll it out safely as one atomic switch; every
   consumer would need to change in lockstep with the server, which is
   almost never actually possible in practice (native mobile clients you
   can't force-update, other teams' integrations, etc.).
4. Keep the legacy shape's endpoints legacy-shaped until each is
   individually migrated and its clients confirmed updated. A mixed surface
   during migration is expected and fine; a silent partial migration nobody
   tracked is not — track which endpoints are on which convention.

### L2 — Single `POST /<resource>/save` handling both create and update

**What it looks like:** one write endpoint per resource; the server decides
create-vs-update internally (commonly: "does an id exist in the payload,
and if so does a row with that id already exist").

**Tradeoff, stated honestly:** fewer handlers to write and maintain — a real
advantage if your framework makes each new endpoint expensive to add. But:
no idempotency semantics (retrying a "create" half of this endpoint can
create a duplicate, since the server-side decision of create-vs-update is
itself not idempotent the way `PUT` is by definition), ambiguous intent
(a client meaning "update" that accidentally omits the id silently becomes
a create), and it cannot express a genuine partial update (`PATCH`
semantics) without the caller resending the entire object and the server
guessing which fields were deliberately unchanged versus deliberately
cleared.

**Migration path:** introduce `POST /<resources>` (create) and
`PUT`/`PATCH /<resources>/{id}` (update) as new, additive endpoints
alongside the existing `/save` endpoint; do not remove `/save` until every
caller has moved off it. Point new client code at the new endpoints
immediately; this is a pure addition; it doesn't force an immediate
breaking migration the way L1's status-code change does, since the old and
new endpoints can coexist indefinitely.

### L3 — Custom session header via a low-level CGI/environment read

**What it looks like:** a custom header (e.g. `X-Session-Token`,
`X-Api-Session`) read through a low-level environment/CGI accessor rather
than through a documented, first-class auth mechanism — functional, but
resting on a mechanism (raw CGI-environment access) that isn't a documented,
version-stability-guaranteed API in most stacks and needs re-verification
after a platform upgrade.

**Migration path:** move to `Authorization: Bearer <token>` (A8) for new
work. If you can't change the header name for existing integrated clients
immediately, at minimum move the *validation* logic to a first-class,
documented mechanism, and dual-accept both header names during a
transition window, logging which one each caller actually used so you know
when it's safe to drop the old one.
