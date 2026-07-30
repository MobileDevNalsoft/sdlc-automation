---
name: vendoring-freshness
description: Use whenever copying a file, config, or agent body from an external source (wshobson/agents, bulletproof-react, very_good_analysis, flutter/website, etc.) into this project — defines the required provenance header and the freshness-check tool that prints drift without blocking on it.
---

# vendoring-freshness

**Verb: refresh.**

## Why vendor instead of depend

Per this project's D7: curate and vendor rather than take a live upstream dependency, so a project never breaks because someone else's package changed underneath it. The cost — no upstream bug fixes flow in automatically — is paid back by recording exactly what was copied and from where, so a human can deliberately re-sync later.

## Required header

Every vendored file gets this as its first lines (adapt comment syntax to the file type):

```
# vendored <package>@<version> on <YYYY-MM-DD>
# source: <upstream URL, ideally pinned to a commit SHA>
# license: <SPDX id> — <any attribution/NOTICE obligation, or "none">
```

For a file assembled from multiple sources (e.g. an agent body that takes structure from one repo and phrasing from another), stack one header block per source.

## Before copying, verify license terms

- MIT / Apache-2.0 / BSD: copy freely; Apache-2.0 additionally requires a NOTICE file entry stating modifications, if any were made.
- CC-BY: attribution string must appear in the vendored artifact itself, not just a changelog.
- No LICENSE file found at all (404, or a repo explicitly archived without one): do not copy, even "verbatim as provenance." Cite the URL in prose instead, and find an alternately-licensed equivalent for anything you need copied.

## Strip the persona tax

Vendored agent bodies frequently arrive with "you are an elite 10x expert" framing. Strip this before it lands in this project — it burns tokens on every invocation and adds nothing a plain second-person ROLE sentence doesn't already say.

## Freshness checking — prints, never blocks

`tools/check-vendored-freshness` (or the project-local equivalent) walks every vendored header, compares its recorded version against the upstream source, and **prints** a drift report. It must never fail a build or a gate — vendored-and-frozen is a deliberate choice (D7's accepted risk), not a defect. Treat its output as a periodic prompt to review, not a gate condition.

## Worked example

```sql
-- vendored oracle-ords-migration/SKILL.md pattern@2026-07-22
-- source: internal .agent/skills/oracle-ords-migration/SKILL.md (this repo)
-- license: none (internal, no external obligation)
```
