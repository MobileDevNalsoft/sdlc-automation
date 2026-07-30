-- ============================================================================
-- TEMPLATE: GET collection, paginated
-- Applies api-contract rules A1 (plural collection path), A3 (GET /<resources>
-- for list), A4 (real HTTP status codes), A7 (offset by default, cursor for
-- large/mutating collections), A8 (bearer-token auth), A9 (server-side
-- identity), A18 (tracing at entry).
--
-- Fill in every {{PLACEHOLDER}}. Replace <resources> with your real plural
-- resource name (e.g. customers, orders, products) — do not invent a new
-- path shape; A1 is "<resources>" for the collection root, full stop.
-- ============================================================================

begin
  ords.define_template(
     p_module_name => '{{MODULE_NAME}}',
     p_pattern     => '{{RESOURCES_PLURAL}}',    -- e.g. 'customers', 'orders'
     p_comments    => '{{RESOURCE_LABEL}} collection'
  );
  ords.define_handler(
     p_module_name => '{{MODULE_NAME}}',
     p_pattern     => '{{RESOURCES_PLURAL}}',
     p_method      => 'GET',
     p_source_type => ords.source_type_plsql,
     -- Bind-variable casing is an internal implementation detail (A6) — pick
     -- one casing and use it consistently for bind names; it does not have
     -- to match the wire-format field casing, which is a separate decision.
     p_source      => 'DECLARE l_tok VARCHAR2(2000); BEGIN '
                    || 'l_tok := {{APP_PKG}}.get_bearer_token; '  -- A8 — see auth helper note below
                    || '{{APP_PKG}}.{{GET_COLLECTION_PROC}}('
                    ||   'p_page_number => :page_number, '
                    ||   'p_page_size   => :page_size, '
                    ||   'p_cursor      => :cursor, '        -- optional, see cursor variant below (A7)
                    ||   'p_status      => :status, '        -- optional filter, drop if unused
                    ||   'p_token       => l_tok, '
                    ||   'p_status_code => :status_code, '   -- A4 — real HTTP status out-bind
                    ||   'p_body_text   => :body_text); '    -- CLOB out-bind for the response
                    || 'END;'
  );
end;
/

-- ----------------------------------------------------------------------------
-- Real ORDS handlers pass their bind list inline as a single string like the
-- concatenation above — it's shown split across lines here only for
-- readability. ords.define_handler's p_source is a single VARCHAR2/CLOB
-- value; when you emit this for real, keep it as one string.
--
-- A8 auth note: `{{APP_PKG}}.get_bearer_token` is a small helper —
-- `owa_util.get_cgi_env('HTTP_AUTHORIZATION')` with the leading `Bearer `
-- prefix stripped — not a built-in ORDS function. Write it once, reuse it
-- from every handler, rather than inlining the CGI-env call per handler.
-- ----------------------------------------------------------------------------

-- ============================================================================
-- Matching engine-procedure signature (default: offset pagination, A7).
-- See templates/engine-procedure-template.sql for the full body skeleton.
-- ============================================================================
--
--   procedure {{GET_COLLECTION_PROC}} (
--      p_page_number  in  number   default 1,
--      p_page_size    in  number   default 20,
--      p_status       in  varchar2 default null,
--      p_token        in  varchar2 default null,
--      p_status_code  out number,
--      p_body_text    out clob
--   );
--
-- Response body shape (A4/A5 — real status via :status_code, body is plain
-- success payload, not problem+json, since this is the success path):
--
--   {
--     "data": [ { ... }, { ... } ],
--     "page_number": <number>,
--     "page_size": <number>,
--     "total_count": <number>
--   }
--
-- `total_count` requires a COUNT(*) over the filtered set — acceptable for a
-- small/static collection, but see the cursor variant below once the
-- collection is large or actively written to (A7).
-- ============================================================================

-- ============================================================================
-- CURSOR / KEYSET PAGINATION VARIANT (A7) — recommended once the collection
-- is large or concurrently mutated. Offset pagination can skip or duplicate
-- rows when rows are inserted/deleted between page fetches, and COUNT(*) for
-- total_count gets expensive at scale. Cursor pagination avoids both by
-- keying off the last row's sort key instead of a row offset.
--
-- Handler binds `:cursor` (opaque, client-supplied, echoed back from the
-- previous page's `next_cursor`) and `:limit` instead of `:page_number`.
--
--   procedure {{GET_COLLECTION_PROC}}_cursor (
--      p_cursor       in  varchar2 default null,  -- opaque, decodes to (created_at, id)
--      p_limit        in  number   default 20,
--      p_token        in  varchar2 default null,
--      p_status_code  out number,
--      p_body_text    out clob
--   );
--
-- Query shape — requires a stable, unique sort key (a monotonically
-- increasing id, or a (created_at, id) composite; never a mutable field):
--
--   select *
--     from {{TABLE_NAME}}
--    where (created_at, {{ID_FIELD}}) > (l_cursor_created_at, l_cursor_id)
--      -- l_cursor_created_at/l_cursor_id decoded from the opaque p_cursor,
--      -- or (MINDATE, MINVALUE)-equivalent bounds when p_cursor is null
--    order by created_at, {{ID_FIELD}}
--    fetch first p_limit rows only;
--
-- Response body omits total_count (or exposes it as a separate, explicitly
-- "approximate/expensive" opt-in field) and returns next_cursor instead:
--
--   {
--     "data": [ ... ],
--     "next_cursor": "<opaque-token-or-null-if-last-page>",
--     "has_more": true
--   }
-- ============================================================================
