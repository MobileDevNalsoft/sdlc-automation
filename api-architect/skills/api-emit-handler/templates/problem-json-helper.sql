-- ============================================================================
-- TEMPLATE: RFC 9457 problem+json builder (api-contract A5)
--
-- VERIFIED: RFC 9457 ("Problem Details for HTTP APIs") obsoletes RFC 7807 and
-- defines the application/problem+json media type with fields type, title,
-- status, detail, instance, plus arbitrary problem-specific extensions
-- (confirmed against the RFC text at rfc-editor.org).
--
-- One small reusable function per package (or one shared utility package
-- across all resources) that every write/read procedure calls on an error
-- path, instead of hand-assembling the JSON inline at each call site.
-- ============================================================================

create or replace package {{APP_PKG}}_problem as

   -- p_extensions is an optional pre-built JSON object fragment (without the
   -- surrounding braces) for problem-specific fields — e.g.
   -- '"balance": 30, "requested": 50' — or null if there are none.
   function build (
      p_type       in varchar2 default 'about:blank',
      p_title      in varchar2,
      p_status     in number,
      p_detail     in varchar2 default null,
      p_instance   in varchar2 default null,
      p_extensions in varchar2 default null
   ) return clob;

end {{APP_PKG}}_problem;
/

create or replace package body {{APP_PKG}}_problem as

   function build (
      p_type       in varchar2 default 'about:blank',
      p_title      in varchar2,
      p_status     in number,
      p_detail     in varchar2 default null,
      p_instance   in varchar2 default null,
      p_extensions in varchar2 default null
   ) return clob is
      l_out clob;
   begin
      apex_json.initialize_clob_output;
      apex_json.open_object;
      apex_json.write('type', p_type);
      apex_json.write('title', p_title);
      apex_json.write('status', p_status);
      if p_detail is not null then
         apex_json.write('detail', p_detail);
      end if;
      if p_instance is not null then
         apex_json.write('instance', p_instance);
      end if;
      apex_json.close_object;
      l_out := apex_json.get_clob_output;
      apex_json.free_output;

      -- Splice extension fields into the object if supplied. This string
      -- surgery (drop the closing '}', append ",<extensions>}") is simpler
      -- than teaching apex_json a variable-shape extension object; if your
      -- extensions need to be structured (nested objects/arrays), build the
      -- whole payload with apex_json.write calls directly instead of this
      -- helper for that one call site.
      if p_extensions is not null then
         l_out := rtrim(rtrim(l_out), '}') || ',' || p_extensions || '}';
      end if;

      return l_out;
   end build;

end {{APP_PKG}}_problem;
/

-- ============================================================================
-- Usage inside a handler procedure (see engine-procedure-template.sql):
--
--   p_body_text := {{APP_PKG}}_problem.build(
--                     p_title    => 'Insufficient balance',
--                     p_status   => 422,
--                     p_detail   => 'Account ' || l_id || ' has a balance of '
--                                   || l_balance || ', a transfer of '
--                                   || l_requested || ' was requested.',
--                     p_instance => '/{{RESOURCES_PLURAL}}/' || l_id || '/transfers/' || l_txn_id,
--                     p_extensions => '"balance": ' || l_balance || ', "requested": ' || l_requested
--                  );
--   p_status_code := 422;
--
-- Set the response Content-Type to application/problem+json on every path
-- that returns this builder's output — owa_util.mime_header
-- ('application/problem+json') before writing p_body_text, or the
-- equivalent for your handler's declared media type.
-- ============================================================================
