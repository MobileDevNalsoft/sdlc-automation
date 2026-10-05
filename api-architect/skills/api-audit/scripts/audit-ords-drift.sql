-- ============================================================================
-- audit-ords-drift.sql
--
-- Purpose: diff what's LIVE in ORDS (USER_ORDS_MODULES / USER_ORDS_TEMPLATES /
-- USER_ORDS_HANDLERS) against a MANIFEST FILE that declares the expected
-- (path, method) surface for a given module — reporting both directions:
--   FILE_ONLY — declared in the manifest, missing from live ORDS
--   LIVE_ONLY — live in ORDS, absent from the manifest (the more dangerous
--               direction: something is running that no contract review or
--               source-control diff ever saw — see API-CONTRACT.md A20)
--
-- Generalized: this does NOT hand-extract or hardcode an endpoint list.
-- The expected surface is read from a manifest JSON file
-- (see ../api-manifest.example.json for the shape), so this script works
-- unmodified for any schema/module — supply your own manifest and set the
-- parameters below.
--
-- ASSUMPTION: written and reviewed for syntactic correctness against the
-- documented USER_ORDS_* / JSON_TABLE / DBMS_LOB APIs, but not executed
-- against a live schema this session. Run it and read the actual output
-- before trusting either section's result.
-- ============================================================================

set linesize 200
set pagesize 200
set serveroutput on
column module_name   format a20
column uri_pattern   format a45
column method        format a8
column drift          format a12

-- ----------------------------------------------------------------------------
-- PARAMETERS — set these before running.
-- ----------------------------------------------------------------------------
define MODULE_NAME        = 'my-api'         -- ORDS module name to audit
define MANIFEST_DIRECTORY = 'API_MANIFEST_DIR'  -- Oracle DIRECTORY object name
                                                 -- pointing at the folder that
                                                 -- holds the manifest file
                                                 -- (see one-time setup below)
define MANIFEST_FILE      = 'api-manifest.json' -- the manifest's filename on
                                                 -- that filesystem path
define PACKAGE_NAME_FILTER = '%'                -- Section 3's package-global
                                                 -- scan filter; '%' audits
                                                 -- every package in the
                                                 -- schema, or narrow it to a
                                                 -- LIKE pattern, e.g.
                                                 -- 'MY_APP%_PKG'

-- ----------------------------------------------------------------------------
-- ONE-TIME SETUP (idempotent, run once per schema):
--   1. A DIRECTORY object the DB can read the manifest file from (requires
--      CREATE ANY DIRECTORY or a DBA to run this once):
--
--        create or replace directory API_MANIFEST_DIR as '/path/to/manifests';
--        grant read on directory API_MANIFEST_DIR to <this schema>;
--
--   2. A small staging table this script uses to shred the manifest JSON
--      into queryable rows (created below if it doesn't already exist).
--
-- ASSUMPTION: DIRECTORY-object filesystem access is unavailable in some
-- environments (e.g. certain managed/cloud DB configurations that restrict
-- BFILE access to specific pre-approved paths). If that's the case here,
-- skip the BFILE load in Section 1 and instead assign the manifest JSON
-- directly to l_clob as a string literal — same JSON_TABLE shredding step
-- works unchanged either way.
-- ----------------------------------------------------------------------------

begin
   execute immediate q'[
      create table api_audit_manifest_stg (
         module_name varchar2(128),
         uri_pattern varchar2(4000),
         method      varchar2(10)
      )
   ]';
exception
   when others then
      if sqlcode != -955 then raise; end if;  -- ORA-00955: table already exists
end;
/

-- ============================================================================
-- SECTION 1 — load the manifest and shred it into the staging table
-- ============================================================================

declare
   l_bfile       bfile;
   l_clob        clob;
   l_dest_offset integer := 1;
   l_src_offset  integer := 1;
   l_lang_ctx    integer := dbms_lob.default_lang_ctx;
   l_warning     integer;
begin
   delete from api_audit_manifest_stg where module_name = '&MODULE_NAME';

   dbms_lob.createtemporary(l_clob, true);

   -- Filesystem load via a DIRECTORY object (see one-time setup above). If
   -- BFILE access isn't available in this environment, replace this whole
   -- BEGIN..END block's body with a direct assignment instead, e.g.:
   --   l_clob := '{"module_name": "&MODULE_NAME", "endpoints": [...]}';
   l_bfile := bfilename('&MANIFEST_DIRECTORY', '&MANIFEST_FILE');
   dbms_lob.fileopen(l_bfile, dbms_lob.file_readonly);
   dbms_lob.loadclobfromfile(
      dest_lob     => l_clob,
      src_bfile    => l_bfile,
      amount       => dbms_lob.lobmaxsize,
      dest_offset  => l_dest_offset,
      src_offset   => l_src_offset,
      bfile_csid   => dbms_lob.default_csid,
      lang_context => l_lang_ctx,
      warning      => l_warning
   );
   dbms_lob.fileclose(l_bfile);

   -- Native SQL/JSON shredding (JSON_TABLE, available since 12.2) — no
   -- APEX_JSON dependency, so this runs in any Oracle schema regardless of
   -- whether Oracle APEX is installed.
   insert into api_audit_manifest_stg (module_name, uri_pattern, method)
   select '&MODULE_NAME', jt.uri_pattern, jt.method
     from json_table(l_clob, '$.endpoints[*]'
             columns (
                uri_pattern varchar2(4000) path '$.path',
                method      varchar2(10)   path '$.method'
             )) jt;

   commit;
   dbms_lob.freetemporary(l_clob);
exception
   when others then
      dbms_output.put_line('Manifest load failed: ' || sqlerrm);
      dbms_output.put_line('If BFILE/DIRECTORY access is unavailable here, '
         || 'assign the manifest JSON directly to l_clob instead — see the '
         || 'comment above the bfilename() call.');
      raise;
end;
/

-- ============================================================================
-- SECTION 2 — drift: manifest vs LIVE
-- ============================================================================

with live_endpoints as (
   select t.uri_template as uri_pattern,
          h.method
     from user_ords_modules   m
     join user_ords_templates t on t.module_id = m.id
     join user_ords_handlers  h on h.template_id = t.id
    where m.name = '&MODULE_NAME'
)
select '&MODULE_NAME'            as module_name,
       e.uri_pattern,
       e.method,
       'FILE_ONLY'               as drift          -- declared in the manifest,
                                                    -- missing from live ORDS
  from api_audit_manifest_stg e
 where e.module_name = '&MODULE_NAME'
   and not exists (
          select 1 from live_endpoints l
           where l.uri_pattern = e.uri_pattern
             and l.method      = e.method
       )
union all
select '&MODULE_NAME'            as module_name,
       l.uri_pattern,
       l.method,
       'LIVE_ONLY'               as drift          -- live in ORDS right now,
                                                    -- absent from the manifest
  from live_endpoints l
 where not exists (
          select 1 from api_audit_manifest_stg e
           where e.module_name = '&MODULE_NAME'
             and e.uri_pattern = l.uri_pattern
             and e.method      = l.method
       )
order by drift, uri_pattern, method;

-- Zero rows = manifest and live ORDS agree exactly on (pattern, method)
-- pairs. Any FILE_ONLY row is declared but never (or no longer) live —
-- likely candidate for api-architect:api-publish. Any LIVE_ONLY row is live
-- but not in the manifest at all — per API-CONTRACT.md A20, the manifest is
-- truth: either the manifest is stale and needs the endpoint added, or the
-- live endpoint was hand-created directly against the DB and needs to be
-- reverse-documented into the manifest. This state should not persist.

-- ============================================================================
-- SECTION 2B — module/template/handler COUNT drift (quick summary)
-- ============================================================================

select '&MODULE_NAME'                                            as module_name,
       (select count(*) from user_ords_modules   m where m.name = '&MODULE_NAME') as live_module_count,
       (select count(*) from user_ords_templates t
          join user_ords_modules m on m.id = t.module_id where m.name = '&MODULE_NAME') as live_template_count,
       (select count(distinct uri_pattern) from api_audit_manifest_stg
          where module_name = '&MODULE_NAME')                    as manifest_template_count,
       (select count(*) from user_ords_handlers h
          join user_ords_templates t on t.id = h.template_id
          join user_ords_modules  m on m.id = t.module_id where m.name = '&MODULE_NAME') as live_handler_count,
       (select count(*) from api_audit_manifest_stg
          where module_name = '&MODULE_NAME')                    as manifest_handler_count
  from dual;

-- If live_module_count = 0: the module has never been published under this
-- name, or was deleted (ORDS.DELETE_MODULE) and never redefined. This is the
-- expected state to see BEFORE running api-architect:api-publish for the
-- first time; do not treat a first-run all-FILE_ONLY / zero-live result as a
-- query bug.

-- ============================================================================
-- SECTION 3 — request-scoped state held in package/session-global scope
--
-- Why this matters: ORDS (and most REST middleware over a pooled DB
-- connection generally) executes handler code through a POOLED connection.
-- A variable declared at package level (not inside a procedure/function
-- body) persists for the lifetime of the pooled session that holds that
-- package instance, NOT for the lifetime of a single HTTP request. Under
-- connection pooling, the *next* HTTP request served by that pooled
-- connection can belong to a completely different end user and will still
-- see whatever the previous request left in that package-level variable —
-- a session-state leak across users, not just across requests from the same
-- user. This is the same structural reason SYS_CONTEXT / ambient connection
-- state is wrong for identity (API-CONTRACT.md A9) — a package-level
-- variable is the general case of that same pooled-connection hazard.
--
-- Generalized from a hardcoded package list to a LIKE-pattern filter
-- (&PACKAGE_NAME_FILTER, default '%' = every package in this schema) so this
-- audits any schema, not one hardcoded set of package names.
-- ============================================================================

-- 3A. PRECISE method (PL/Scope) — requires packages to have been compiled
-- with PLSCOPE_SETTINGS='IDENTIFIERS:ALL'. If this returns zero rows on a
-- package you know has package-level state, PL/Scope metadata likely isn't
-- present — recompile first:
--   alter package   <pkg> compile plscope_settings='IDENTIFIERS:ALL' reuse settings;
--   alter package body <pkg> compile plscope_settings='IDENTIFIERS:ALL' reuse settings;
--
-- ASSUMPTION: whether packages in this schema were compiled with PL/Scope
-- enabled is environment-specific and not verified here — run the ALTER
-- statements above first if 3A comes back empty on a package you expect to
-- have findings.

select ui.name              as identifier_name,
       ui.type               as identifier_type,
       ui.object_name        as package_name,
       ui.line, ui.col,
       ui.usage              as usage_kind          -- 'DECLARATION', 'ASSIGNMENT', 'REFERENCE', ...
  from user_identifiers ui
 where ui.object_name like '&PACKAGE_NAME_FILTER'
   and ui.object_type in ('PACKAGE', 'PACKAGE BODY')
   and ui.type = 'VARIABLE'
   and ui.usage = 'DECLARATION'
   -- Package-level declarations sit at usage_context_id = 0 (top-level block
   -- of the package, not nested inside a PROCEDURE/FUNCTION's own DECLARE
   -- section). A variable declared inside a procedure has a non-zero
   -- usage_context_id pointing back to that procedure's identifier.
   and ui.usage_context_id = 0
 order by ui.object_name, ui.line;

-- 3B. FALLBACK heuristic (no PL/Scope required) — flags candidate top-level
-- declarations by looking at USER_SOURCE lines between the package body's
-- opening ("AS"/"IS") and the first top-level PROCEDURE/FUNCTION keyword.
-- This is a text heuristic, not a parse — it can both over- and
-- under-report (e.g. it will misfire on a multi-line declaration split
-- across rows, or on a commented-out line that merely looks like one). Use
-- 3A when PL/Scope is available; use 3B only as a quick smell-test when it
-- isn't.

with body_lines as (
   select s.name, s.line, s.text,
          min(case when regexp_like(s.text, '^\s*(procedure|function)\s', 'i') then s.line end)
             over (partition by s.name) as first_subprogram_line
     from user_source s
    where s.name like '&PACKAGE_NAME_FILTER'
      and s.type = 'PACKAGE BODY'
)
select name as package_name, line, trim(text) as candidate_declaration
  from body_lines
 where line < nvl(first_subprogram_line, 999999)
   and regexp_like(text, '^\s*[a-zA-Z][a-zA-Z0-9_]*\s+(varchar2|number|date|timestamp|boolean|clob|blob|pls_integer|binary_integer|t_\w+)', 'i')
   and not regexp_like(text, '^\s*(procedure|function|type|subtype|cursor|pragma)\s', 'i')
 order by name, line;

-- Any row out of 3A or 3B is a candidate to review by hand: is it read-only
-- constant-like state set once at package init (lower risk), or is it
-- written to per-request (a real leak vector that must move to a local
-- variable, a package-level associative array keyed by session/token
-- instead, or a table)? This script flags candidates; it does not and
-- cannot automatically decide which category a given variable falls into.

-- ============================================================================
-- SECTION 4 — Handlers binding ORDS reserved or implicit parameter names
--
-- Why this matters:
--   1. ':q' is reserved by ORDS for its JSON filter query object. If a handler
--      binds ':q' and a client sends plain text '?q=text', ORDS returns
--      400 Bad Request at the gateway before the handler ever executes.
--      Free-text search MUST use ':search' / '?search='.
--   2. ':limit', ':page', ':offset' are reserved by ORDS for internal paging.
--      Handlers binding ':limit', ':page', or ':offset' will have those values
--      captured or overwritten by ORDS internal paging calculations.
--      Pagination MUST use ':p_limit', ':p_page', ':p_offset' (or rows_per_page).
--   3. ':page_size', ':page_offset', ':row_offset', ':row_count' are deprecated
--      implicit binds that ORDS populates with its own state.
--
-- Any row returned here is a violation that must be rebound.
-- ============================================================================

column matched_reserved format a20
column uri_template     format a45

select m.name                                              as module_name,
       t.uri_template,
       h.method,
       h.source_type,
       regexp_substr(h.source, ':(q|limit|offset|page|page_size|page_offset|fetch_offset|fetch_size|row_offset|row_count)([^[:alnum:]_]|$)', 1, 1, 'i') as matched_reserved
  from user_ords_handlers  h
  join user_ords_templates t on t.id = h.template_id
  join user_ords_modules   m on m.id = t.module_id
 where m.name like '&MODULE_NAME'
   and regexp_like(h.source, ':(q|limit|offset|page|page_size|page_offset|fetch_offset|fetch_size|row_offset|row_count)([^[:alnum:]_]|$)', 'i')
 order by m.name, t.uri_template, h.method;

