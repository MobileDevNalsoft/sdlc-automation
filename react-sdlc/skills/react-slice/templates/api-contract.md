<!-- templates/api-contract.md — react-slice worked example: "Product Tags" -->
<!--
Generic REST/JSON contract for a small feature: tagging a parent entity
(here, a "Product") with a lookup-coded label. This is a neutral illustrative
example, not a copied artifact from any real project — swap "product"/"tag"
for whatever entity/relationship the real slice actually needs.

How this contract gets implemented server-side is out of scope for react-slice
(a React SDLC skill) — any backend technology can serve it. What matters to
the frontend layers below is the shape: plain HTTP verbs, JSON bodies, and a
consistent error shape.
-->

# API contract: Product Tags

## `GET /products/:productId/tags`

List the active tags on a product.

**Response 200:**

```json
{
  "tags": [
    {
      "tag_id": 123,
      "tag_code": "FEATURED",
      "tag_label": "Featured",
      "created_by": 7,
      "created_by_name": "Jordan Lee",
      "created_at": "2026-07-30T14:22:00Z"
    }
  ]
}
```

## `POST /products/:productId/tags`

Add a tag to a product.

**Request body:**

```json
{ "tag_code": "FEATURED" }
```

**Response 201:**

```json
{
  "tag": {
    "tag_id": 124,
    "tag_code": "FEATURED",
    "tag_label": "Featured",
    "created_by": 7,
    "created_by_name": "Jordan Lee",
    "created_at": "2026-07-30T14:30:00Z"
  }
}
```

## `DELETE /products/:productId/tags/:tagId`

Remove a tag from a product.

**Response 204:** empty body.

## Errors

Any non-2xx response returns:

```json
{ "error": { "code": "TAG_NOT_FOUND", "message": "Tag 124 does not exist on product 55." } }
```

A machine-readable `code` plus a human-readable `message`, alongside the HTTP status that already carries the pass/fail signal — don't duplicate that signal inside the body with a second status-like field (e.g. a redundant `response_code`/`response_message` pair next to the real HTTP status); the transport layer already carries it, and a second copy of the same fact is one more place for the two to disagree.
