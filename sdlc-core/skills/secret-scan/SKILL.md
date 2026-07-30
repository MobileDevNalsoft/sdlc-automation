---
name: secret-scan
description: Use before any diff is reported IMPLEMENTED or SHIP — scans for credentials in build-time-inlined env vars, env-file generator scripts, database signer/credential procedures, connection strings, and committed key/keystore files. Blocking — a hit fails the check, it is not advisory.
---

# secret-scan

**Verb: scan.**

## Why database source files are explicitly in scope

Most secret scanners stop at `.env`, `.conf`, and application source. This one also scans `.sql` and equivalent stored-procedure sources, because signing and credential logic frequently lives there: a function that signs a JWT, builds a push-notification payload, or authenticates to an external service embeds its key as a literal string inside a `CREATE OR REPLACE` body — and that file is usually committed, because committing it is how the deploy is tracked. A scanner pointed only at `.env` misses this class entirely.

Treat any database source file whose name contains `sign`, `jwt`, `token`, `auth`, `cert`, `key`, or a push-service name as high-priority, before running the generic patterns.

## Patterns to check (blocking on any match)

| Pattern | Why it's a hit |
|---|---|
| A build-time-inlined env var holding a credential — e.g. a bundler prefix like `VITE_*`, `NEXT_PUBLIC_*`, `REACT_APP_*`, `PUBLIC_*` matched against `PASSWORD` / `SECRET` / `KEY` / `TOKEN` | These prefixes are **substituted at build time**, so the literal value is baked into the shipped bundle and readable by anyone who loads the app. This is not the same as a server-side runtime env read — there is no point at which the browser doesn't have it. Any credential behind such a prefix is already disclosed. |
| A hardcoded credential literal inside a script that *generates* or rewrites an env file | The secret isn't in the (usually gitignored) env file — it's in the committed generator that writes it. Scanning only for `.env` in the tree gives a false pass here. |
| A stored-procedure / database-function body containing a literal that matches a secret shape: `-----BEGIN`, a long base64 blob, a bearer/API-key format, or an assignment to a password-like identifier | Deployed database source is normally committed for change tracking, so an embedded key is committed with it. |
| Any `Authorization`, `Basic `, or `Bearer ` literal in source, or a credential embedded in a connection string or URL (`scheme://user:pass@host`) | Credentials in URLs also leak into logs, referrers, and error reports — the exposure is wider than the file itself. |
| `.env`, `*.conf`, `*.pem`, `*.key`, `*.p12`, `*.jks`, `*.keystore`, cloud-credential JSON, or a mobile signing-properties file **tracked in git at all** | Credential-shaped by convention regardless of content. Check `git ls-files`, not just working-tree contents — a file deleted today is still in history. |
| A private key or keystore referenced by a build/deploy config that isn't gitignored | The config naming it is often the only clue the key was committed alongside. |

## Procedure

1. `git diff --name-only` (or the equivalent file list from the agent that dispatched you) to get every touched file.
2. For each file, grep the patterns above. Do not skip `.sql` files just because the diff is "a frontend task" — a slice can touch both.
3. Any match is a blocking finding: `file:line`, the pattern matched, and a one-line remediation — move the value to a secret store the client never reads (platform secret manager, orchestrator secret, database wallet), and terminate the credentialed call server-side.
4. Report `PASS` only if every touched file was actually checked — a file you didn't get to is not a pass, it's `NOT RUN` for that file.

## What does not count as a fix

**Relocating a browser-reachable secret to a different browser-reachable place.** Moving a credential from a build-time-inlined env var to a runtime global on `window`, a fetched config file, or `localStorage` changes where it sits, not who can read it — anyone with dev tools still has it. The same applies to obfuscating or base64-encoding it.

The actual fix is that the client never holds the credential at all: a server-side component (reverse proxy or backend endpoint) holds it, injects it into the upstream call, and exposes only an authenticated, scoped endpoint to the client. If a browser can reach the value in any form, it is disclosed.

**Rotation, not history rewriting.** Once a credential has been pushed, treat it as compromised and rotate it. Scrubbing git history reduces future exposure but does not un-disclose what was already published — and it invalidates every clone. Rotate first; decide about history separately.
