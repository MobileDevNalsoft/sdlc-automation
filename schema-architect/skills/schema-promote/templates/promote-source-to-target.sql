-- ============================================================================
-- promote-source-to-target.sql
--
-- Source-environment -> target-environment promotion orchestration, in apply
-- order:
--   1. GRANTS            2. DDL / DATA          3. SEQUENCE REALIGNMENT
--   4. PACKAGE SPECS     5. PACKAGE BODIES       6. INVALID-OBJECT CHECK
--
-- Substitute the actual schema names for <SOURCE_SCHEMA> (dev/test, where the
-- change was verified) and <TARGET_SCHEMA> (prod, or whichever environment is
-- being promoted to) and the actual table/object prefix for <APP>_ throughout.
--
-- Grants-before-DDL is the safer default: discovering a missing grant
-- mid-DDL/data-sync means stopping partway through a multi-table operation,
-- whereas an unused grant costs nothing. Sequence realignment runs AFTER data
-- sync, not before -- aligning a sequence to MAX(id) before the new rows land
-- leaves it behind again the moment they do.
--
-- AUTHID: every promoted package should default to DEFINER rights (the
-- Oracle default -- no explicit AUTHID clause) unless a specific package
-- genuinely needs invoker rights (schema-promote's SKILL.md explains the
-- consequence set). Grants below target the PACKAGE OWNER schema
-- (<TARGET_SCHEMA>), not the caller -- a definer-rights package executes with
-- its OWNER's privileges, so the caller needs EXECUTE on the package, not DML
-- on the underlying tables the package touches internally.
-- ============================================================================


-- ============================================================================
-- PHASE 1 -- GRANTS (run first; safer default even when a later phase turns
-- out not to need every grant -- a missing grant discovered mid-DDL is worse
-- than one granted and unused)
-- ============================================================================
-- Every grant failure other than a specifically-identified, genuinely benign
-- one MUST stop the promotion -- never wrap a grant in a blanket
-- `EXCEPTION WHEN OTHERS THEN NULL;`, which swallows a real failure (wrong
-- schema, object doesn't exist yet, insufficient privilege to grant) exactly
-- as quietly as it swallows the "already granted" case it was probably
-- written to tolerate.
BEGIN
   FOR t IN (
      SELECT table_name
        FROM user_tables
       WHERE table_name LIKE '<APP>_%'
         AND table_name NOT LIKE '%\_BKP\_%' ESCAPE '\'
   ) LOOP
      BEGIN
         EXECUTE IMMEDIATE 'GRANT SELECT, INSERT, UPDATE, DELETE ON <TARGET_SCHEMA>.' || t.table_name || ' TO <SOURCE_SCHEMA>';
         DBMS_OUTPUT.PUT_LINE('[GRANT] ' || t.table_name || ' -> <SOURCE_SCHEMA>: OK');
      EXCEPTION
         WHEN OTHERS THEN
            IF SQLCODE = -1749 THEN
               -- ORA-01749: you may not GRANT/REVOKE privileges to/from
               -- yourself -- expected/harmless when run as the owning schema
               -- itself (e.g. <SOURCE_SCHEMA> = <TARGET_SCHEMA> in a
               -- single-schema-per-environment layout).
               DBMS_OUTPUT.PUT_LINE('[GRANT] ' || t.table_name || ' -> <SOURCE_SCHEMA>: skipped (self-grant)');
            ELSE
               -- Every other failure STOPS the promotion. Do not swallow.
               RAISE_APPLICATION_ERROR(-20950,
                  'Grant failed on ' || t.table_name || ': ' || SQLERRM);
            END IF;
      END;
   END LOOP;

   FOR s IN (
      SELECT sequence_name FROM user_sequences WHERE sequence_name LIKE '<APP>_%'
   ) LOOP
      BEGIN
         EXECUTE IMMEDIATE 'GRANT SELECT ON <TARGET_SCHEMA>.' || s.sequence_name || ' TO <SOURCE_SCHEMA>';
         DBMS_OUTPUT.PUT_LINE('[GRANT] ' || s.sequence_name || ' -> <SOURCE_SCHEMA>: OK');
      EXCEPTION
         WHEN OTHERS THEN
            IF SQLCODE = -1749 THEN
               DBMS_OUTPUT.PUT_LINE('[GRANT] ' || s.sequence_name || ' -> <SOURCE_SCHEMA>: skipped (self-grant)');
            ELSE
               RAISE_APPLICATION_ERROR(-20950,
                  'Grant failed on ' || s.sequence_name || ': ' || SQLERRM);
            END IF;
      END;
   END LOOP;

   DBMS_OUTPUT.PUT_LINE('[PHASE 1] Grants complete.');
END;
/

-- Package-execute grant for the definer-rights packages this promotion ships
-- (repeat one line per package -- explicit, not a wildcard loop, because
-- EXECUTE grants are sensitive enough to want in the diff/review, not
-- generated silently):
GRANT EXECUTE ON <TARGET_SCHEMA>.<app>_engine_pkg TO <SOURCE_SCHEMA>;


-- ============================================================================
-- PHASE 2 -- DDL / DATA
-- Run schema-emit's guarded CREATE TABLE/SEQUENCE/TRIGGER/INDEX statements
-- for any new objects first, THEN the data sync. The data-sync procedure
-- itself (per-table MERGE/comparison logic moving rows from <SOURCE_SCHEMA>
-- to <TARGET_SCHEMA>) is project-specific and out of scope for this
-- template -- this template only fixes the ORDERING it sits in.
-- ============================================================================
-- @schema-emit-output-for-this-promotion.sql   -- (new objects, if any)
-- @sync-data-source-to-target.sql               -- (existing-table data sync, project-specific)


-- ============================================================================
-- PHASE 3 -- SEQUENCE REALIGNMENT
-- Run AFTER data sync, not before -- a sequence aligned to MAX(id) before the
-- new rows land would immediately be behind again. The realignment procedure
-- itself (per-sequence offset adjustment) is project-specific; this template
-- only fixes where it sits in the apply order.
-- ============================================================================
-- @sync-sequences-source-to-target.sql


-- ============================================================================
-- PHASE 4 -- PACKAGE SPECS (before bodies; dependencies before dependents)
-- Compile every promoted package's SPEC first, in dependency order (a
-- package that references another promoted package's public types/constants
-- needs that package's spec to already exist, even before either BODY is
-- touched). List explicitly -- do not let this be a wildcard
-- "compile everything under <APP>_%" pass, since dependency order matters
-- and a wildcard doesn't respect it.
-- ============================================================================
-- @<app>-engine-pkg-spec.sql
-- @<app>-dashboard-pkg-spec.sql   -- (if it depends on <app>_engine_pkg's spec)


-- ============================================================================
-- PHASE 5 -- PACKAGE BODIES (after ALL specs above; same dependency order)
-- ============================================================================
-- @<app>-engine-pkg-body.sql
-- @<app>-dashboard-pkg-body.sql


-- ============================================================================
-- PHASE 6 -- INVALID-OBJECT CHECK (final step, mandatory)
-- Reuses schema-audit's audit-invalid.sql verbatim -- do not re-derive this
-- query here. One source of truth for "is the schema clean" avoids two files
-- drifting to different definitions of INVALID.
-- ============================================================================
-- @../../schema-audit/scripts/audit-invalid.sql
--
-- A non-empty result at this point means STOP: the promotion is NOT
-- complete, regardless of what phases 1-5 reported. Report per
-- schema-audit's "state the row count, even when it's zero" rule -- "0 rows
-- -- PASS" is the only acceptable close-out line for this phase.


-- ============================================================================
-- PHASE 7 (implicit, not numbered above) -- RECORD THIS PROMOTION
-- Add a row to the schema-version/changelog table (schema-promote's
-- migration-versioning section / templates/schema-version-table.sql), or let
-- Flyway/Liquibase record it automatically if this project uses one of
-- those. A promotion that isn't recorded didn't leave an auditable trace
-- that it happened, in what order, or by whom.
-- ============================================================================
