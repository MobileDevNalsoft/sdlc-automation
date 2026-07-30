-- ============================================================================
-- TEMPLATE: resource-oriented write endpoints
-- POST /<resources>            create                (A3, A10 idempotency-key)
-- PUT  /<resources>/{id}        full replace           (A3, A11 concurrency)
-- PATCH /<resources>/{id}       partial update          (A3, A11 concurrency)
-- DELETE /<resources>/{id}      delete                 (A3, A11 concurrency)
--
-- See the bottom of this file for the legacy single-POST-/save alternative
-- and why these four are preferred for new work (API-CONTRACT.md L2).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- POST /<resources> — create. Returns 201 + Location on success (A3, A4).
-- Accepts an optional Idempotency-Key header (A10) so a client retry after a
-- dropped connection doesn't create a duplicate row.
-- ----------------------------------------------------------------------------
begin
  ords.define_template(
     p_module_name => '{{MODULE_NAME}}',
     p_pattern     => '{{RESOURCES_PLURAL}}',
     p_comments    => 'Create {{RESOURCE_LABEL}}'
  );
  ords.define_handler(
     p_module_name => '{{MODULE_NAME}}',
     p_pattern     => '{{RESOURCES_PLURAL}}',
     p_method      => 'POST',
     p_source_type => ords.source_type_plsql,
     -- ORDS hands POST bodies to a PL/SQL handler as a BLOB via the implicit
     -- :body bind (or :body_text for CLOB) — convert to CLOB and
     -- apex_json.parse (or json_value/json_table) inside the procedure,
     -- never on the outer handler line.
     p_source      => 'DECLARE l_tok VARCHAR2(2000); l_idem VARCHAR2(200); BEGIN '
                    || 'l_tok  := {{APP_PKG}}.get_bearer_token; '
                    || 'l_idem := owa_util.get_cgi_env(''HTTP_IDEMPOTENCY_KEY''); '
                    || '{{APP_PKG}}.{{CREATE_PROC}}('
                    ||   'p_body          => :body, '
                    ||   'p_idempotency_key => l_idem, '
                    ||   'p_token         => l_tok, '
                    ||   'p_status_code   => :status_code, '
                    ||   'p_forward_location => :forward_location, '  -- ORDS implicit bind ->
                    ||                                                -- Location header (A3)
                    ||   'p_body_text     => :body_text); '
                    || 'END;'
  );
end;
/

-- Matching engine-procedure signature:
--
--   procedure {{CREATE_PROC}} (
--      p_body             in  blob,
--      p_idempotency_key  in  varchar2 default null,
--      p_token            in  varchar2 default null,
--      p_status_code      out number,
--      p_forward_location out varchar2,   -- relative path of the new resource,
--                                         -- e.g. '{{RESOURCES_PLURAL}}/12345' —
--                                         -- ORDS turns this into the response's
--                                         -- Location header when :status_code = 201
--      p_body_text        out clob
--   );
--
-- See engine-procedure-template.sql for the full body: idempotency-key
-- check first (if p_idempotency_key was seen before, return the stored
-- result instead of re-running the mutation), then structural validation,
-- business validation, identity resolution, insert, response.

-- ----------------------------------------------------------------------------
-- PUT /<resources>/{id} — full replace. Idempotent: the same request applied
-- twice produces the same end state (A3). Supports optimistic concurrency
-- via If-Match / a version field (A11).
-- ----------------------------------------------------------------------------
begin
  ords.define_template(
     p_module_name => '{{MODULE_NAME}}',
     p_pattern     => '{{RESOURCES_PLURAL}}/:id',
     p_comments    => 'Replace {{RESOURCE_LABEL}}'
  );
  ords.define_handler(
     p_module_name => '{{MODULE_NAME}}',
     p_pattern     => '{{RESOURCES_PLURAL}}/:id',
     p_method      => 'PUT',
     p_source_type => ords.source_type_plsql,
     p_source      => 'DECLARE l_tok VARCHAR2(2000); l_if_match VARCHAR2(200); BEGIN '
                    || 'l_tok      := {{APP_PKG}}.get_bearer_token; '
                    || 'l_if_match := owa_util.get_cgi_env(''HTTP_IF_MATCH''); '
                    || '{{APP_PKG}}.{{REPLACE_PROC}}('
                    ||   'p_id          => :id, '
                    ||   'p_body        => :body, '
                    ||   'p_if_match    => l_if_match, '
                    ||   'p_token       => l_tok, '
                    ||   'p_status_code => :status_code, '
                    ||   'p_body_text   => :body_text); '
                    || 'END;'
  );
end;
/

-- Matching engine-procedure signature — on a version mismatch, set
-- p_status_code := 409 (or 412 for the literal If-Match precondition-failed
-- case) with a problem+json body explaining the conflict (A5, A11):
--
--   procedure {{REPLACE_PROC}} (
--      p_id          in  number,
--      p_body        in  blob,
--      p_if_match    in  varchar2 default null,
--      p_token       in  varchar2 default null,
--      p_status_code out number,
--      p_body_text   out clob
--   );

-- ----------------------------------------------------------------------------
-- PATCH /<resources>/{id} — partial update. Caller sends only the fields
-- that change; every field omitted from the body is left untouched (A3).
-- Same concurrency handling as PUT (A11).
-- ----------------------------------------------------------------------------
begin
  ords.define_handler(
     p_module_name => '{{MODULE_NAME}}',
     p_pattern     => '{{RESOURCES_PLURAL}}/:id',   -- same template as PUT/DELETE — one
                                                     -- template, three methods (A2)
     p_method      => 'PATCH',
     p_source_type => ords.source_type_plsql,
     p_source      => 'DECLARE l_tok VARCHAR2(2000); l_if_match VARCHAR2(200); BEGIN '
                    || 'l_tok      := {{APP_PKG}}.get_bearer_token; '
                    || 'l_if_match := owa_util.get_cgi_env(''HTTP_IF_MATCH''); '
                    || '{{APP_PKG}}.{{PATCH_PROC}}('
                    ||   'p_id          => :id, '
                    ||   'p_body        => :body, '
                    ||   'p_if_match    => l_if_match, '
                    ||   'p_token       => l_tok, '
                    ||   'p_status_code => :status_code, '
                    ||   'p_body_text   => :body_text); '
                    || 'END;'
  );
end;
/

-- Inside {{PATCH_PROC}}: parse the body, and for every field present, use
-- `coalesce`/an explicit "was this key present in the JSON at all" check
-- (not just "is it null") to distinguish "field omitted, leave unchanged"
-- from "field explicitly set to null, clear it" — a plain `nvl` collapses
-- that distinction incorrectly for PATCH semantics.

-- ----------------------------------------------------------------------------
-- DELETE /<resources>/{id} — 204 No Content on success (A3). Same concurrency
-- handling as PUT/PATCH if the resource has a version field (A11).
-- ----------------------------------------------------------------------------
begin
  ords.define_handler(
     p_module_name => '{{MODULE_NAME}}',
     p_pattern     => '{{RESOURCES_PLURAL}}/:id',
     p_method      => 'DELETE',
     p_source_type => ords.source_type_plsql,
     p_source      => 'DECLARE l_tok VARCHAR2(2000); l_if_match VARCHAR2(200); BEGIN '
                    || 'l_tok      := {{APP_PKG}}.get_bearer_token; '
                    || 'l_if_match := owa_util.get_cgi_env(''HTTP_IF_MATCH''); '
                    || '{{APP_PKG}}.{{DELETE_PROC}}('
                    ||   'p_id          => :id, '
                    ||   'p_if_match    => l_if_match, '
                    ||   'p_token       => l_tok, '
                    ||   'p_status_code => :status_code, '
                    ||   'p_body_text   => :body_text); '
                    || 'END;'
  );
end;
/

-- ============================================================================
-- LEGACY ALTERNATIVE — single POST /<resource>/save (API-CONTRACT.md L2)
--
-- One POST endpoint per resource; the procedure decides create-vs-update
-- internally (typically: does the payload carry an id, and if so does a row
-- with that id already exist).
--
--   ords.define_handler(
--      p_module_name => '{{MODULE_NAME}}',
--      p_pattern     => '{{RESOURCES_PLURAL}}/save',
--      p_method      => 'POST',
--      p_source_type => ords.source_type_plsql,
--      p_source      => '...{{APP_PKG}}.{{SAVE_PROC}}(p_body => :body, ...)...'
--   );
--
-- Tradeoff, stated plainly: fewer handlers to add per resource — but no
-- idempotency semantics (a retried "create" can double-insert, since the
-- create-vs-update branch itself isn't idempotent the way PUT is by
-- definition), ambiguous create-vs-update intent when the id is accidentally
-- omitted, and no way to express a genuine partial update without the
-- caller resending the whole object. Prefer the four endpoints above for new
-- work; keep this shape only where it's already deployed and not yet
-- migrated (L2's migration guidance: add the new endpoints alongside it,
-- don't remove /save until callers have moved off it).
-- ============================================================================
