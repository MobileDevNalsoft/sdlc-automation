-- ============================================================================
-- schema-emit :: lookup-seed.sql
-- Illustrative worked example: ORDER_STATUS -- a new small, closed
-- code/meaning set (PENDING / SHIPPED / CANCELLED / RETURNED). Per
-- schema-model step 2, a lookup-seed this small gets NO new CREATE TABLE when
-- the target schema already centralizes small code sets into a shared
-- lookup-values table -- it's consolidated instead, keyed by an owning
-- application/tenant id + LOOKUP_TYPE (the long-standing Oracle Applications
-- FND_LOOKUP_TYPES/FND_LOOKUP_VALUES-style pattern).
--
-- Replace `app_lookup_owner.app_lookup_values_t` with the target schema's
-- ACTUAL shared lookup table name/owner. If the target schema has no shared
-- lookup table at all, see this skill's SKILL.md and schema-model.md §2 --
-- the right move there is a small dedicated table, not this template.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. PARAMETERS -- no hardcoded application id. Every deployment has its own
--    registered id; never carry a literal from an example into a real run.
-- ----------------------------------------------------------------------------
SET DEFINE ON
SET VERIFY OFF
ACCEPT app_id NUMBER PROMPT 'Application/tenant id that owns this lookup type (required, no default -- look up the real value for this target schema): '

-- ----------------------------------------------------------------------------
-- 1. SEED THE LOOKUP VALUES -- idempotent (safe to re-run; WHEN NOT MATCHED
--    means a second run inserts nothing new).
-- ----------------------------------------------------------------------------
MERGE INTO app_lookup_owner.app_lookup_values_t t
USING (
   SELECT 'ORDER_STATUS' AS lookup_type, 'PENDING'   AS lookup_code, 'Pending'   AS meaning, 'Y' AS enable_flag FROM dual
   UNION ALL
   SELECT 'ORDER_STATUS',                'SHIPPED',                  'Shipped',                 'Y'             FROM dual
   UNION ALL
   SELECT 'ORDER_STATUS',                'CANCELLED',                'Cancelled',               'Y'             FROM dual
   UNION ALL
   SELECT 'ORDER_STATUS',                'RETURNED',                 'Returned',                'Y'             FROM dual
) s
ON ( t.lookup_type = s.lookup_type
 AND t.lookup_code = s.lookup_code )
WHEN NOT MATCHED THEN
INSERT (
   lookup_type,
   lookup_code,
   meaning,
   enable_flag,
   application_id,
   start_date )
VALUES (
   s.lookup_type,
   s.lookup_code,
   s.meaning,
   s.enable_flag,
   &&app_id,
   DATE '1900-01-01' ); -- a conventional far-past sentinel: any START_DATE-based
                         -- "is this lookup value in effect" filter should never
                         -- accidentally exclude a seeded row for having a start
                         -- date "too recent" -- pick a date safely before any
                         -- real data in this schema, not necessarily this exact one.

COMMIT;

-- ----------------------------------------------------------------------------
-- 2. BACKFILL GUARD -- if this MERGE is ever run against a shared table where
--    application_id could already be populated by an earlier partial run,
--    re-assert it explicitly rather than assuming the INSERT above always
--    fires with the right value:
-- ----------------------------------------------------------------------------
UPDATE app_lookup_owner.app_lookup_values_t
   SET application_id = &&app_id
 WHERE lookup_type     = 'ORDER_STATUS'
   AND application_id IS NULL;

COMMIT;

-- ----------------------------------------------------------------------------
-- 3. VERIFICATION QUERY -- run manually after applying the above.
--    Expect: 4 rows -- PENDING/SHIPPED/CANCELLED/RETURNED, all enable_flag = 'Y',
--    all tagged with the application id you supplied in step 0.
-- ----------------------------------------------------------------------------
-- SELECT lv.lookup_code,
--        lv.meaning
--   FROM app_lookup_owner.app_lookup_values_t lv
--  WHERE lv.application_id = &&app_id
--    AND lv.lookup_type    = 'ORDER_STATUS'
--    AND NVL(lv.enable_flag, 'Y') = 'Y'
--  ORDER BY lv.lookup_code ASC;

-- ----------------------------------------------------------------------------
-- 4. SELF-REGISTRATION -- schema-model step 9 / schema-promote's
--    migration-versioning section. Lookup-seeds don't get a row in a table
--    catalog (no new table was created) -- instead, record the new
--    LOOKUP_TYPE, and this migration's version id, in the schema's
--    version/changelog table, plus a one-line note against whichever business
--    table's column this lookup resolves (e.g. "order_status_code resolved
--    via the shared lookup table, lookup_type = ORDER_STATUS").
-- ----------------------------------------------------------------------------
