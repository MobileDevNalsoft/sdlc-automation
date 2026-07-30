-- ============================================================================
-- TEMPLATE: backing procedure for a create/replace/update write endpoint
--
-- Section order matters and is the point of this template — it encodes
-- API-CONTRACT.md's rule order directly:
--   1. Tracing          (A18 — instrument every entry point)
--   2. Resolve identity  (A8/A9 — from the credential, before anything else
--                          that might need to know who's calling)
--   3. Idempotency check (A10 — POST-create only; skip for PUT/PATCH/DELETE,
--                          which are idempotent by definition)
--   4. Structural validation — parse + type/shape check, before any DML
--   5. Business-rule validation — before any DML (A19 — both validation
--                          steps complete before the first write)
--   6. Concurrency check (A11 — PUT/PATCH/DELETE only, via If-Match/version)
--   7. DML
--   8. Response — real HTTP status via :status_code (A4), problem+json body
--      on any error path (A5)
--
-- The commented-out LEGACY block at the bottom shows the always-200 /
-- embedded-result-code alternative (API-CONTRACT.md L1) — for reference
-- when migrating an existing endpoint off that pattern, not as a template
-- for new code.
--
-- Wrapped below in a minimal package body shell so the file is a complete,
-- syntactically valid compilation unit on its own — merge just the
-- procedure body into your real engine package if you already have one.
-- ============================================================================

create or replace package body {{APP_PKG}} as

   procedure {{CREATE_PROC}} (
      p_body             in  blob,
      p_idempotency_key  in  varchar2 default null,
      p_token            in  varchar2 default null,
      p_status_code      out number,
      p_forward_location out varchar2,
      p_body_text        out clob
   ) is
      l_identity      varchar2(128);
      l_payload       clob;
      l_{{ID_FIELD}}  number;
      l_now           timestamp := systimestamp;
      l_error_message varchar2(4000);
   begin

   ------------------------------------------------------------------------
   -- 1. TRACING (A18) — every entry point sets module/action before doing
   --    anything else, so a pooled session can be attributed to the
   --    specific endpoint that's currently using it.
   ------------------------------------------------------------------------
      dbms_application_info.set_module(
         module_name => '{{PACKAGE_NAME_UPPER}}',
         action_name => '{{CREATE_PROC_UPPER}}'
      );
      dbms_application_info.set_action(action_name => '{{CREATE_PROC_UPPER}}');

   ------------------------------------------------------------------------
   -- 2. IDENTITY (A8/A9) — resolved from the validated bearer credential,
   --    NEVER from a field in the request payload. A user-identifying field
   --    the client sends (created_by, user_id, acting_as, ...) is at most a
   --    hint to cross-check; the value actually written always comes from
   --    l_identity below.
   ------------------------------------------------------------------------
      l_identity := {{APP_PKG}}_auth.resolve_identity(p_token);
      if l_identity is null then
         p_status_code := 401;
         p_body_text   := {{APP_PKG}}_problem.build(
                              p_title  => 'Unauthenticated',
                              p_status => 401,
                              p_detail => 'Missing, invalid, or expired credential.'
                           );
         return;
      end if;

   ------------------------------------------------------------------------
   -- 3. IDEMPOTENCY (A10) — create-only. If this key was already processed,
   --    return the stored result instead of repeating the mutation.
   ------------------------------------------------------------------------
      if p_idempotency_key is not null then
         begin
            select status_code, forward_location, body_text
              into p_status_code, p_forward_location, p_body_text
              from {{IDEMPOTENCY_TABLE}}
             where idempotency_key = p_idempotency_key
               and identity        = l_identity;
            return;   -- already handled; short-circuit before any new DML
         exception
            when no_data_found then
               null;  -- first time seeing this key; fall through
         end;
      end if;

   ------------------------------------------------------------------------
   -- 4. STRUCTURAL VALIDATION — parse + type/shape check, before any DML.
   ------------------------------------------------------------------------
      begin
         l_payload := to_clob(p_body);
         apex_json.parse(l_payload);
      exception
         when others then
            p_status_code := 400;
            p_body_text   := {{APP_PKG}}_problem.build(
                                 p_title  => 'Malformed request body',
                                 p_status => 400,
                                 p_detail => 'Request body is not valid JSON.'
                              );
            return;
      end;

   ------------------------------------------------------------------------
   -- 5. BUSINESS-RULE VALIDATION — still before any DML (A19). Well-formed
   --    JSON that violates a business rule is 422, not 400 (A4) — that
   --    distinction is the point of separating this step from step 4.
   ------------------------------------------------------------------------
      -- if {{UNIQUENESS_OR_OTHER_CHECK}} then
      --    p_status_code := 422;
      --    p_body_text   := {{APP_PKG}}_problem.build(
      --                         p_title  => '{{REJECTION_TITLE}}',
      --                         p_status => 422,
      --                         p_detail => '{{REJECTION_DETAIL}}'
      --                      );
      --    return;
      -- end if;

      -- Guard clause (A22) for an invariant that should never fail if the
      -- caller is well-behaved, as opposed to an expected user-input
      -- rejection above:
      -- if {{INVARIANT_CHECK}} then
      --    raise_application_error(-20999, '{{INVARIANT_MESSAGE}}');
      -- end if;

   ------------------------------------------------------------------------
   -- 6. DML
   ------------------------------------------------------------------------
      insert into {{TABLE_NAME}} (
         {{ID_FIELD}}, created_by, created_at, updated_by, updated_at
         -- , ... other columns from the payload
      ) values (
         {{ID_SEQUENCE}}.nextval, l_identity, l_now, l_identity, l_now
         -- , ... other values, read via apex_json.get_* (p_path => '...')
      ) returning {{ID_FIELD}} into l_{{ID_FIELD}};

      if p_idempotency_key is not null then
         insert into {{IDEMPOTENCY_TABLE}} (idempotency_key, identity, status_code, forward_location, body_text, created_at)
         values (p_idempotency_key, l_identity, 201, '{{RESOURCES_PLURAL}}/' || l_{{ID_FIELD}}, null, l_now);
      end if;

      commit;

   ------------------------------------------------------------------------
   -- 7. RESPONSE — real HTTP status via :status_code (A4); Location via the
   --    ORDS implicit :forward_location bind, wired through
   --    p_forward_location.
   ------------------------------------------------------------------------
      p_status_code      := 201;
      p_forward_location := '{{RESOURCES_PLURAL}}/' || l_{{ID_FIELD}};
      apex_json.initialize_clob_output;
      apex_json.open_object;
      apex_json.write('{{ID_FIELD}}', l_{{ID_FIELD}});
      apex_json.close_object;
      p_body_text := apex_json.get_clob_output;
      apex_json.free_output;

   exception
      when others then
         rollback;
         l_error_message := sqlerrm;
         p_status_code := 500;
         p_body_text   := {{APP_PKG}}_problem.build(
                              p_title  => 'Internal server error',
                              p_status => 500,
                              p_detail => substr(l_error_message, 1, 300)
                           );
   end {{CREATE_PROC}};

end {{APP_PKG}};
/

-- ============================================================================
-- GET-collection procedures (list endpoints) follow the same section order
-- minus steps 3 and 6's insert (query instead of DML), and stream the
-- response through a CLOB in chunks if it can exceed a single buffer:
--
--   l_offset := 1;
--   loop
--      exit when l_offset > dbms_lob.getlength(l_clob);
--      l_amount := least(32767, dbms_lob.getlength(l_clob) - l_offset + 1);
--      p_body_text := p_body_text || dbms_lob.substr(l_clob, l_amount, l_offset);
--      l_offset := l_offset + l_amount;
--   end loop;
--
-- (Only relevant if you're writing through htp.prn/htp.p directly rather
-- than returning a CLOB out-parameter as this template does; an out-CLOB
-- doesn't need manual chunking.)
-- ============================================================================

-- ============================================================================
-- LEGACY — always-200 with an embedded result-code field (API-CONTRACT.md
-- L1). Shown for recognition/migration reference only; do not use this
-- shape for new procedures.
--
--   apex_json.open_object;
--   apex_json.write('response_code', 201);      -- "real" result hidden in
--                                                 -- the body; HTTP status
--                                                 -- line stays 200 always
--   apex_json.write('response_message', 'Success');
--   apex_json.close_object;
--   htp.p(apex_json.get_clob_output);
--
-- Migrating an endpoint off this shape means: start returning a real
-- :status_code, switch the error body to problem+json (A5), and treat this
-- as a per-endpoint, opt-in change communicated to that endpoint's specific
-- callers — never a global flip across every endpoint in one pass (L1).
-- ============================================================================
