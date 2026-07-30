-- ============================================================================
-- rollback-backfill-before-image.sql
-- Rollback policy for change class: BACKFILL.
--
-- Capture a KEYED before-image table of every row the backfill is about to
-- touch, BEFORE running the backfill UPDATE -- not a full-table snapshot
-- (that's the DROP-class pattern, rollback-drop-snapshot.sql), a targeted
-- one keyed to exactly the rows in scope, so rollback is a single MERGE back
-- from the before-image rather than a full table swap.
--
-- `APP_` is a PLACEHOLDER prefix -- substitute your project's actual
-- registered prefix.
-- ============================================================================

-- Worked example: a hypothetical backfill setting APP_ORDER_T's new
-- SHIPPED_DATE column for all rows currently NULL where the order status is
-- already SHIPPED, computed as ORDER_DATE + 3 days as a placeholder estimate.

-- 1. Before-image, keyed to the exact WHERE clause the backfill will use --
--    capturing only the columns the backfill will change, plus the PK, keeps
--    this small and makes the rollback MERGE unambiguous. Guarded via a
--    data-dictionary existence check (schema-emit's idempotency pattern),
--    not a catch-and-swallow block.
DECLARE
   l_count PLS_INTEGER;
BEGIN
   SELECT COUNT(*) INTO l_count
     FROM user_tables WHERE table_name = 'APP_ORDER_T_BFR_20260730';

   IF l_count = 0 THEN
      EXECUTE IMMEDIATE '
         CREATE TABLE app_order_t_bfr_20260730 (
            order_id               NUMBER        NOT NULL,
            shipped_date            DATE,
            object_version_number   NUMBER,
            CONSTRAINT app_order_bfr_pk PRIMARY KEY (order_id)
         )';
   END IF;
END;
/

INSERT INTO app_order_t_bfr_20260730 (order_id, shipped_date, object_version_number)
SELECT order_id, shipped_date, object_version_number
  FROM app_order_t
 WHERE shipped_date IS NULL
   AND order_status_code = 'SHIPPED';   -- SAME predicate the backfill UPDATE will use

-- NOTE: COMMENT ON TABLE takes a single string literal, not a concatenation
-- expression (Oracle's grammar does not accept `'a' || 'b'` here) -- keep it
-- as one literal, wrapped in source for readability only.
COMMENT ON TABLE app_order_t_bfr_20260730 IS
   'Before-image for SHIPPED_DATE backfill on APP_ORDER_T, captured 2026-07-30. Retain until 2026-08-29 (30 days) or until the backfill is confirmed correct in prod, whichever is later.';

COMMIT;

-- 2. THEN run the backfill (not part of this template -- this file is the
--    before-image capture + rollback pair, not the backfill itself):
-- UPDATE app_order_t
--    SET shipped_date = order_date + 3,
--        last_updated_by = 'BACKFILL_20260730',
--        last_update_date = SYSTIMESTAMP,
--        object_version_number = object_version_number + 1
--  WHERE shipped_date IS NULL
--    AND order_status_code = 'SHIPPED';
-- COMMIT;

-- 3. ROLLBACK -- if the backfill turns out wrong, restore exactly the rows
--    this before-image captured, using OBJECT_VERSION_NUMBER as the
--    optimistic-lock guard so a row touched again by a live user AFTER the
--    backfill (and therefore no longer matching the version this before-
--    image captured) is left alone rather than clobbered a second time:
-- MERGE INTO app_order_t tgt
-- USING app_order_t_bfr_20260730 src
--    ON (tgt.order_id = src.order_id
--        AND tgt.object_version_number = src.object_version_number + 1)  -- only the version the backfill itself produced
-- WHEN MATCHED THEN UPDATE SET
--    tgt.shipped_date           = src.shipped_date,
--    tgt.object_version_number  = src.object_version_number,
--    tgt.last_updated_by        = 'ROLLBACK_20260730',
--    tgt.last_update_date       = SYSTIMESTAMP;
-- COMMIT;

-- 4. Cleanup reminder (manual, after the stated retention date -- see
--    rollback-drop-snapshot.sql for why this isn't a scheduled job):
-- DROP TABLE app_order_t_bfr_20260730 PURGE;

-- 5. Record this backfill + its rollback pairing in the schema's
--    version/changelog table (schema-promote's migration-versioning
--    section / templates/schema-version-table.sql).
