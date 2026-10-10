# API Design & Wire Protocol Contract

## 1. REST Standards & Conventions
- **Base URL**: `/api/v1` (or `/ords/<schema>/v1`)
- **JSON Casing**: Wire format uses `snake_case` payloads; frontend adapters transform to `camelCase`.
- **Safe Bindings**: Never bind reserved `:q`, `:limit`, `:page`, or `:offset` directly in SQL templates. Use `:search`, `:p_limit`, `:p_page`.

---

## 2. RFC 9457 Problem Details Contract
All error responses (4xx, 5xx) must emit the RFC 9457 standard payload:

```json
{
  "type": "https://api.example.com/errors/conflict",
  "title": "Optimistic Concurrency Conflict",
  "status": 409,
  "detail": "Record was modified by another user since it was retrieved (current version: 2, expected: 1).",
  "instance": "/api/v1/employees/102",
  "code": "CONCURRENCY_CONFLICT",
  "invalid_params": []
}
```

---

## 3. Idempotent Retry Policy
- **Safe Methods**: `GET`, `HEAD`, `OPTIONS` are strictly read-only and retryable.
- **Idempotent Mutations**: `PUT`, `DELETE` are retryable when paired with `object_version_number`.
- **Non-Idempotent Mutations**: `POST` calls require an `Idempotency-Key` header UUID if automatic retries are enabled on network dropped packets.

---

## 4. Endpoint Contract Specification

### `GET /api/v1/[resources]`
- **Purpose**: Fetch paginated collection.
- **Permissions**: `ACCESS_TYPE IN ('V', 'F')`
- **Query Parameters**:
  - `p_page`: Integer (default 1)
  - `p_limit`: Integer (default 20, max 100)
  - `search`: String (optional search query)
- **Response 200 OK**:
  ```json
  {
    "items": [],
    "total": 0,
    "has_more": false,
    "limit": 20,
    "offset": 0
  }
  ```

### `PUT /api/v1/[resources]/{id}`
- **Purpose**: Update entity with optimistic lock check.
- **Headers**: `If-Match: "{object_version_number}"` (or embedded in JSON body).
- **Responses**:
  - `200 OK`: Updated entity with incremented version number.
  - `400 Bad Request`: Payload validation failure (RFC 9457).
  - `401 Unauthorized`: Token missing or expired.
  - `403 Forbidden`: Insufficient privilege (`ACCESS_TYPE='V'`).
  - `409 Conflict`: Version token mismatch.
