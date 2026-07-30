-- ============================================================================
-- audit-invalid.sql
--
-- One query against USER_OBJECTS WHERE STATUS = 'INVALID'. Simple, and
-- commonly missing from schema deploy pipelines anyway -- this is that query,
-- written to be reused rather than re-derived.
--
-- EVIDENCE CONTRACT: violations only. Empty result = PASS = every object in
-- this schema compiled clean.
--
-- This is also schema-promote's final step (its own SKILL.md reuses this
-- exact file rather than re-deriving the query) -- run it standalone during
-- an audit pass, or as the last phase of any cross-environment promotion.
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 100

SELECT object_type,
       object_name,
       status,
       last_ddl_time
  FROM user_objects
 WHERE status = 'INVALID'
 ORDER BY object_type, object_name;

-- ----------------------------------------------------------------------------
-- If this schema needs to see invalid objects OWNED BY ANOTHER SCHEMA it has
-- DBA/SELECT_CATALOG_ROLE visibility into (e.g. auditing a target schema
-- while connected as a shared admin account), use ALL_OBJECTS with an
-- explicit OWNER filter instead -- do not default to DBA_OBJECTS/ALL_OBJECTS
-- without an OWNER predicate, since that silently widens the result to every
-- schema in the database and defeats the "one schema, one deploy" framing
-- this check exists for:
-- ----------------------------------------------------------------------------
-- SELECT owner,
--        object_type,
--        object_name,
--        status,
--        last_ddl_time
--   FROM all_objects
--  WHERE owner = UPPER('&&schema_owner')
--    AND status = 'INVALID'
--  ORDER BY object_type, object_name;

-- ----------------------------------------------------------------------------
-- Recompile attempt before re-running this check (cheapest first move for
-- any INVALID PACKAGE/PACKAGE BODY/TRIGGER/VIEW -- Oracle will often
-- self-heal on next reference, but forcing it here surfaces a REAL
-- compilation error immediately instead of on the first unlucky caller):
-- ----------------------------------------------------------------------------
-- BEGIN
--    FOR o IN (SELECT object_type, object_name
--                FROM user_objects
--               WHERE status = 'INVALID') LOOP
--       BEGIN
--          IF o.object_type = 'PACKAGE' THEN
--             EXECUTE IMMEDIATE 'ALTER PACKAGE ' || o.object_name || ' COMPILE';
--          ELSIF o.object_type = 'PACKAGE BODY' THEN
--             EXECUTE IMMEDIATE 'ALTER PACKAGE ' || o.object_name || ' COMPILE BODY';
--          ELSIF o.object_type = 'TRIGGER' THEN
--             EXECUTE IMMEDIATE 'ALTER TRIGGER ' || o.object_name || ' COMPILE';
--          ELSIF o.object_type = 'VIEW' THEN
--             EXECUTE IMMEDIATE 'ALTER VIEW ' || o.object_name || ' COMPILE';
--          END IF;
--       EXCEPTION
--          WHEN OTHERS THEN
--             DBMS_OUTPUT.PUT_LINE('Still invalid: ' || o.object_type || ' ' || o.object_name || ' -- ' || SQLERRM);
--       END;
--    END LOOP;
-- END;
-- /
-- -- Re-run the primary SELECT above after this block; anything still listed
-- -- is a real compilation error, not a stale dependency-order artifact.
