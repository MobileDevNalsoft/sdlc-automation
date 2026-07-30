-- ============================================================================
-- audit-lookups.sql
--
-- Flags: (1) a lookup-shaped table (small, closed code/meaning set) that
-- isn't consolidated into the shared lookup-values table pattern (candidate
-- list, not a deterministic violation -- see CHECK 1's note), and (2) a
-- LOOKUP_TYPE whose rows are missing the application/tenant id tag that makes
-- them visible to the app that owns them, and (3) duplicate
-- LOOKUP_TYPE+LOOKUP_CODE pairs.
--
-- Replace `app_lookup_owner.app_lookup_values_t` below with the target
-- schema's ACTUAL shared lookup table name/owner.
--
-- EVIDENCE CONTRACT: violations only, except where a check is explicitly
-- labeled a CANDIDATE list (CHECK 1) -- empty result = PASS for every
-- deterministic check.
-- ============================================================================

SET DEFINE ON
SET VERIFY OFF
SET LINESIZE 200
SET PAGESIZE 100

ACCEPT table_prefix CHAR PROMPT 'Table/lookup-type prefix to audit (e.g. APP): '
ACCEPT app_id NUMBER PROMPT 'This project''s application/tenant id (required, no default): '

-- ----------------------------------------------------------------------------
-- CHECK 1 (CANDIDATE LIST, not a deterministic violation) -- small tables
-- shaped like a code/meaning lookup that exist as their OWN table instead of
-- being consolidated into the shared lookup-values table.
--
-- "Lookup-shaped" can't be determined with certainty from column metadata
-- alone -- this is a heuristic (few columns, has a CODE-like column and a
-- MEANING/NAME/DESC-like column), so results here are candidates for human
-- review, not a definitive convention violation.
--
-- If this schema's own convention is dedicated per-entity lookup tables
-- rather than a shared consolidated one (schema-model.md §2 -- both are
-- legitimate, pick per project), don't run this check at all, or treat every
-- hit as expected-by-design rather than drift.
-- ----------------------------------------------------------------------------
SELECT t.table_name,
       (SELECT COUNT(*) FROM user_tab_columns c WHERE c.table_name = t.table_name) AS column_count
  FROM user_tables t
 WHERE t.table_name LIKE UPPER('&&table_prefix') || '\_%' ESCAPE '\'
   AND (SELECT COUNT(*) FROM user_tab_columns c WHERE c.table_name = t.table_name) <= 9
   AND EXISTS (
       SELECT 1 FROM user_tab_columns c
        WHERE c.table_name = t.table_name
          AND (c.column_name LIKE '%\_CODE' ESCAPE '\' OR c.column_name = 'CODE')
       )
   AND EXISTS (
       SELECT 1 FROM user_tab_columns c
        WHERE c.table_name = t.table_name
          AND (c.column_name IN ('MEANING', 'NAME', 'DESCRIPTION')
               OR c.column_name LIKE '%\_MEANING' ESCAPE '\'
               OR c.column_name LIKE '%\_NAME' ESCAPE '\'
               OR c.column_name LIKE '%\_DESC' ESCAPE '\')
       )
 ORDER BY 1;

-- ----------------------------------------------------------------------------
-- CHECK 2 -- a LOOKUP_TYPE under this prefix that has at least one row with a
-- NULL or mismatched application/tenant id. This class of drift is easy to
-- introduce by hand: a seed script that inserts lookup rows without the
-- scoping id, followed by a backfill that targets the wrong LOOKUP_TYPE, or
-- simply never runs, leaves rows that exist in the table but are invisible to
-- whatever app-layer query filters by that id.
-- ----------------------------------------------------------------------------
SELECT lv.lookup_type,
       COUNT(*)                                                        AS total_rows,
       SUM(CASE WHEN lv.application_id IS NULL THEN 1 ELSE 0 END)      AS null_app_id_rows,
       SUM(CASE WHEN lv.application_id <> &&app_id THEN 1 ELSE 0 END)  AS mismatched_app_id_rows
  FROM app_lookup_owner.app_lookup_values_t lv
 WHERE lv.lookup_type LIKE UPPER('&&table_prefix') || '%' ESCAPE '\'
 GROUP BY lv.lookup_type
HAVING SUM(CASE WHEN lv.application_id IS NULL THEN 1 ELSE 0 END) > 0
    OR SUM(CASE WHEN lv.application_id <> &&app_id THEN 1 ELSE 0 END) > 0
 ORDER BY 1;

-- ----------------------------------------------------------------------------
-- CHECK 3 -- duplicate LOOKUP_TYPE + LOOKUP_CODE pairs (should be impossible
-- under the idempotent MERGE pattern in schema-emit's lookup-seed.sql, but a
-- hand-run INSERT bypassing that template could still create one).
-- ----------------------------------------------------------------------------
SELECT lv.lookup_type,
       lv.lookup_code,
       COUNT(*) AS row_count
  FROM app_lookup_owner.app_lookup_values_t lv
 WHERE lv.lookup_type LIKE UPPER('&&table_prefix') || '%' ESCAPE '\'
 GROUP BY lv.lookup_type, lv.lookup_code
HAVING COUNT(*) > 1
 ORDER BY 1, 2;
