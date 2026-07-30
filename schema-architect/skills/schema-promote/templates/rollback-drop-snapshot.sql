-- ============================================================================
-- rollback-drop-snapshot.sql
-- Rollback policy for change class: DROP.
--
-- Pre-drop CREATE TABLE ... AS SELECT snapshot, with a STATED retention
-- date -- not an indefinite "keep it forever, someone will clean it up
-- eventually" table. Run this BEFORE the DROP TABLE it's protecting, never
-- after.
--
-- This layers on top of, not instead of, dropping WITHOUT PURGE: leaving a
-- dropped table in the recyclebin (the default when DROP TABLE is issued
-- without the PURGE keyword) means Flashback can restore it even without
-- this template, but flashback/recyclebin recovery has a retention window
-- governed by tablespace/undo settings and can be silently lost to space
-- pressure. This CTAS snapshot, with an explicit retention date, is the
-- durable fallback once flashback has already expired.
--
-- `APP_` is a PLACEHOLDER prefix -- substitute your project's actual
-- registered prefix.
-- ============================================================================

-- Worked example: dropping APP_ORDER_ARCHIVE_T, a superseded table being
-- replaced by a newer archival design.

-- 1. Snapshot -- guarded via a data-dictionary existence check (idempotent if
--    this script is re-run before the drop actually happens).
DECLARE
   l_count PLS_INTEGER;
BEGIN
   SELECT COUNT(*) INTO l_count
     FROM user_tables WHERE table_name = 'APP_ORDER_ARCHIVE_T_BKP_20260730';

   IF l_count = 0 THEN
      EXECUTE IMMEDIATE '
         CREATE TABLE app_order_archive_t_bkp_20260730
         AS SELECT * FROM app_order_archive_t';
   END IF;
END;
/

-- 2. Record the retention date and reason explicitly -- a snapshot with no
--    stated expiry is indistinguishable from a permanent, unreviewed copy of
--    production data sitting around. Use a COMMENT ON TABLE so the retention
--    date travels with the object itself, not just with whoever remembers
--    writing this script.
-- NOTE: COMMENT ON TABLE takes a single string literal, not a concatenation
-- expression (Oracle's grammar does not accept `'a' || 'b'` here).
COMMENT ON TABLE app_order_archive_t_bkp_20260730 IS
   'Pre-drop snapshot of APP_ORDER_ARCHIVE_T, taken 2026-07-30. Retain until 2026-10-28 (90 days), then DROP. Reason for original drop: superseded by APP_ORDER_ARCHIVE_V2_T.';

-- 3. THEN drop the live table -- without PURGE, so recyclebin/flashback is a
--    second line of defense behind the CTAS snapshot above, not the only
--    one:
-- DROP TABLE app_order_archive_t;

-- 4. Cleanup reminder (run manually after the stated retention date --
--    intentionally NOT automated as a scheduled job in this template, since
--    an unattended DROP on a schedule is exactly the kind of silent data
--    loss this whole pattern exists to prevent):
-- DROP TABLE app_order_archive_t_bkp_20260730 PURGE;

-- 5. Record this drop + its snapshot pairing in the schema's
--    version/changelog table (schema-promote's migration-versioning
--    section / templates/schema-version-table.sql).
