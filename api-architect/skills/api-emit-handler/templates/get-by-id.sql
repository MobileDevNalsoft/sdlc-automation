-- ============================================================================
-- TEMPLATE: GET single resource by id
-- Applies api-contract A2 (/<resources>/{id}), A3 (GET one), A4 (real status
-- codes — 404 when absent, 403 vs 404 existence-hiding tradeoff), A8/A9
-- (bearer auth, server-side identity), A18 (tracing at entry).
-- ============================================================================

begin
  ords.define_template(
     p_module_name => '{{MODULE_NAME}}',
     p_pattern     => '{{RESOURCES_PLURAL}}/:id',   -- e.g. customers/:id — keep the id
                                                     -- param name consistent across every
                                                     -- endpoint (A2); this template uses
                                                     -- the generic :id form, the
                                                     -- per-resource form (:customerId) is
                                                     -- equally valid if that's your house
                                                     -- convention — just pick one.
     p_comments    => '{{RESOURCE_LABEL}} detail'
  );
  ords.define_handler(
     p_module_name => '{{MODULE_NAME}}',
     p_pattern     => '{{RESOURCES_PLURAL}}/:id',
     p_method      => 'GET',
     p_source_type => ords.source_type_plsql,
     p_source      => 'DECLARE l_tok VARCHAR2(2000); BEGIN '
                    || 'l_tok := {{APP_PKG}}.get_bearer_token; '
                    || '{{APP_PKG}}.{{GET_DETAIL_PROC}}('
                    ||   'p_id          => :id, '
                    ||   'p_token       => l_tok, '
                    ||   'p_status_code => :status_code, '  -- A4
                    ||   'p_body_text   => :body_text); '
                    || 'END;'
  );
end;
/

-- ============================================================================
-- Matching engine-procedure signature:
--
--   procedure {{GET_DETAIL_PROC}} (
--      p_id          in  number,          -- required, no default
--      p_token       in  varchar2 default null,
--      p_status_code out number,
--      p_body_text   out clob
--   );
--
-- Inside the procedure (see engine-procedure-template.sql for the full
-- skeleton): resolve identity/authorization from the token first (A9), then
-- look up the row.
--
--   - Row found, caller authorized  -> p_status_code := 200, body is the resource
--   - Row not found                 -> p_status_code := 404, problem+json body (A5)
--   - Row exists, caller NOT allowed -> p_status_code := 403 ordinarily (A4) —
--     UNLESS the resource's existence is itself sensitive (a private record,
--     another tenant's data), in which case return 404 instead of 403 so an
--     unauthorized caller can't distinguish "doesn't exist" from "exists, not
--     yours" (A4's existence-hiding note). Decide which applies per resource
--     and document the choice — don't leave it as an accident of whichever
--     branch happened to run first.
--
-- problem+json 404 body example (A5):
--   {
--     "type": "about:blank",
--     "title": "Not Found",
--     "status": 404,
--     "detail": "No {{RESOURCE_LABEL}} with id 12345.",
--     "instance": "/{{RESOURCES_PLURAL}}/12345"
--   }
-- ============================================================================
