# Security Guidelines & Threat Mitigations

## 1. Authentication & Session Identity
- **Provider**: [OAuth2 / OIDC / Oracle IDCS / JWT Bearer]
- **Token Handling**:
  - Web SPAs store refresh tokens in `HttpOnly; SameSite=Strict; Secure` cookies where possible.
  - In-memory access token storage with single-flight silent refresh.
- **Identity Invariant**: Identity is ALWAYS resolved server-side from the verified session context. Payloads containing `user_id` or `email` are advisory and never trusted for authorization.

---

## 2. Authorization & RBAC Contract
- **Permission Matrix**: Every screen and action belongs to an explicit screen group.
- **Access Types**:
  - `F` (Full Access): Read + Create + Edit + Delete permitted.
  - `V` (View Only): Read permitted. All write/edit buttons must render disabled with an informative tooltip (`PermissionGate`).
  - None: Route blocks access (HTTP 403 Forbidden).

---

## 3. Secret Isolation & Zero-Leakage Invariant
1. **No Client-Side Inlining**: Never use `VITE_*` for database credentials or private API keys. Vite inlines `VITE_*` strings into public JS bundles at build time.
2. **Reverse Proxy Credential Pattern**: Backend credentials sit in Docker secrets / environment variables inside the Nginx container, injected via `proxy_set_header`.
3. **Repository Cleanliness**: `.env`, `.env.local`, and private certificates are permanently barred by `.gitignore`.

---

## 4. Logging & PII Sanitization
Never write to application or server logs:
- Passwords or hashes
- API bearer tokens or session cookies
- Credit card or bank numbers
- Personally identifiable credentials
