# Database Design & Persistence Contract

## 1. Engine & Conventions
- **Database Engine**: [Oracle Database 23ai / PostgreSQL 16 / SQLite 3]
- **Table Naming**: Lowercase plural with snake_case (`employees`, `service_tickets`).
- **Primary Keys**: Surrogate numeric ID (`id` or `<table_singular>_id`).
- **Foreign Keys**: `<referenced_table_singular>_id`.

---

## 2. Invariant Columns (Mandatory on Every Business Table)
Every business table must implement these six operational columns:

| Column Name | Data Type | Nullable | Default | Invariant Purpose |
|---|---|---|---|---|
| `object_version_number` | Number(9) / Integer | No | `1` | Optimistic concurrency token (increments on UPDATE). |
| `active_flag` | Char(1) / Boolean | No | `'Y'` | Soft deletion flag ('Y' active, 'N' deleted). |
| `created_by` | Varchar2(100) | No | Session user | Audit author tracking. |
| `creation_date` | Timestamp | No | `SYSTIMESTAMP` | Record creation timestamp. |
| `last_updated_by` | Varchar2(100) | No | Session user | Last modifier tracking. |
| `last_update_date` | Timestamp | No | `SYSTIMESTAMP` | Last modification timestamp. |

---

## 3. Optimistic Concurrency Control Invariant
Every mutative SQL statement must enforce the version check:

```sql
UPDATE employees
SET name = :p_name,
    object_version_number = object_version_number + 1,
    last_updated_by = :p_user,
    last_update_date = SYSTIMESTAMP
WHERE id = :p_id
  AND object_version_number = :p_expected_version
  AND active_flag = 'Y';
```
If `SQL%ROWCOUNT = 0`, the handler must rollback and emit an HTTP `409 Conflict` response.

---

## 4. Soft Delete Invariant
Data is never dropped from business tables with `DELETE`.
Mutations perform:
```sql
UPDATE employees
SET active_flag = 'N',
    object_version_number = object_version_number + 1,
    last_updated_by = :p_user,
    last_update_date = SYSTIMESTAMP
WHERE id = :p_id
  AND object_version_number = :p_expected_version;
```
All query views filter by `WHERE active_flag = 'Y'`.
