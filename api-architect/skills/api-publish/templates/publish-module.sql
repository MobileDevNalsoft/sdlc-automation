-- ============================================================================
-- publish-module.sql — the api-publish sequence
--
-- FILE IS TRUTH (API-CONTRACT.md A20): if a live ORDS module ever disagrees
-- with its checked-in module-definition file/manifest, THE FILE WINS.
-- Re-publish from the file; do not hand-edit the live module to match what's
-- running and leave the file stale — that is exactly the drift
-- api-architect:api-audit exists to catch.
--
-- Sequence, in order, each step gated on the previous succeeding:
--   1. ORDS.DELETE_MODULE   — idempotent teardown (safe if module doesn't exist)
--   2. ORDS.DEFINE_MODULE   — recreate under a PARAMETERIZED schema alias
--   3. ORDS.ENABLE_SCHEMA   — enable REST for that schema/base-path mapping
--   4. [[run this module's real handler-definition file here to redefine
--       every template/handler]]
--   5. Run api-architect:api-audit's scripts/audit-ords-drift.sql to confirm
--      what just got published matches the manifest
--   6. Run the .http smoke test (templates/smoke-test.http) as the final
--      check against the actually-running endpoint
--
-- Why the schema alias must be a substitution variable, never a literal:
-- any environment that promotes a schema across environments (dev/test/
-- prod, or a blue-green schema cutover) needs this script to work unmodified
-- against whichever schema is current — a publish script hardcoded to one
-- schema name breaks the instant that boundary moves.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- PARAMETERS — set these before running. Do not inline literals below.
-- ----------------------------------------------------------------------------
define MODULE_NAME     = 'my-api'           -- ORDS module name
define BASE_PATH        = 'my-api/'         -- ORDS module base path (trailing slash)
define SCHEMA_ALIAS     = 'APP_SCHEMA'      -- <-- the schema this module runs
                                             --     against for THIS environment.
                                             --     NEVER hardcode this — always
                                             --     pass it in per deployment
                                             --     (e.g. dev/test/prod, or
                                             --     either side of a schema
                                             --     promotion cutover).
define APPLICATION_ID   = ''                -- deployment-specific application/
                                             --     tenant identifier if your
                                             --     auth layer uses one (A9's
                                             --     identity resolution may
                                             --     need it). Treat it as a
                                             --     per-deployment parameter,
                                             --     never a literal baked into
                                             --     a reusable template — a
                                             --     different module in the
                                             --     same ORDS instance can use
                                             --     a different value.
define ITEMS_PER_PAGE   = 0                 -- 0 = pagination is handled by
                                             --     the engine procedures
                                             --     themselves (API-CONTRACT.md
                                             --     A7), not by ORDS-native
                                             --     paging
define MODULE_COMMENTS  = 'My API'

-- ----------------------------------------------------------------------------
-- STEP 1 — Idempotent teardown
-- ----------------------------------------------------------------------------
begin
   ords.delete_module(p_module_name => '&MODULE_NAME');
exception
   when others then
      -- ORA-20001-class "module does not exist" is expected on a first
      -- publish; anything else should still surface, so this is
      -- intentionally narrow rather than a blanket WHEN OTHERS swallow.
      if sqlcode not in (-20001) then
         raise;
      end if;
end;
/

-- ----------------------------------------------------------------------------
-- STEP 2 — Recreate the module under the parameterized schema
-- (module definitions in ORDS are schema-scoped by which schema you're
-- connected as / which schema owns the module — SCHEMA_ALIAS above is what
-- makes this script safe to re-run unmodified against any environment)
-- ----------------------------------------------------------------------------
begin
   ords.define_module(
      p_module_name    => '&MODULE_NAME',
      p_base_path      => '&BASE_PATH',
      p_items_per_page => &ITEMS_PER_PAGE,
      p_status         => 'PUBLISHED',
      p_comments       => '&MODULE_COMMENTS'
   );
end;
/

-- ----------------------------------------------------------------------------
-- STEP 3 — Enable REST for the schema this module's handlers actually run
-- against. p_schema is the parameterized alias, not a literal.
-- ----------------------------------------------------------------------------
begin
   ords.enable_schema(
      p_enabled             => true,
      p_schema              => '&SCHEMA_ALIAS',
      p_url_mapping_type    => 'BASE_PATH',
      p_url_mapping_pattern => '&BASE_PATH',
      p_auto_rest_auth      => false
   );
   commit;
end;
/

-- ----------------------------------------------------------------------------
-- STEP 4 — Run this module's real handler-definition file(s) here (not
-- inlined into this template — this template only owns module lifecycle,
-- not any specific handler catalog):
--
--   @your-handler-definitions.sql
--
-- ----------------------------------------------------------------------------

-- ----------------------------------------------------------------------------
-- STEP 5 — Confirm the publish actually took: run the drift audit
--
--   @api-architect/skills/api-audit/scripts/audit-ords-drift.sql
--
-- Zero FILE_ONLY / zero LIVE_ONLY rows is the pass condition. Any row means
-- either step 4 didn't run cleanly, or the manifest and the module you just
-- published disagree — stop and reconcile before calling this publish done.
-- ----------------------------------------------------------------------------

-- ----------------------------------------------------------------------------
-- STEP 6 — Smoke test against the live, just-published endpoint:
--
--   templates/smoke-test.http (this skill directory)
--
-- Read the response status line first (A4 — real HTTP status codes) and
-- the body second. If this module is still on the legacy always-200
-- convention (API-CONTRACT.md L1) because it hasn't been migrated yet, the
-- real signal is the body's embedded result-code field instead — check
-- which convention this specific module is on before reading the smoke
-- test's pass/fail.
-- ----------------------------------------------------------------------------
