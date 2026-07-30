---
name: output-contracts
description: Use to look up the canonical output template and forced terminal token for any sdlc-core agent — the single source of truth so all four agent bodies stay in sync rather than each restating its own copy.
---

# output-contracts

**Verb: emit.**

Each of the four `sdlc-core` agents ends its output with exactly one uppercase token on its own final line. A response that doesn't end this way is malformed — the Main loop (or whatever dispatches these agents) treats the final line as the routing signal, not the prose above it.

## sdlc-plan

Terminal tokens: `PLAN-READY` or `NEEDS-DECISION: <slot>`.

```
## Skill Decision Record
Task class: <...> · Size: <...> · Stack: <...> · Stage: <...>
Candidates surveyed:
  - <skill> — REJECTED: <reason> | SELECTED
Unmet need: <none | description>

## Files to touch
- <path> — <reason>, blast radius: <...>

## Open decisions
- NEEDS-DECISION: <slot> — <why it can't default>

PLAN-READY
```

## sdlc-developer

Terminal tokens: `IMPLEMENTED` or `BLOCKED: <reason>`.

```
## Slice implemented
Skill dispatched: <plugin:skill>
Files touched:
  - <path> (+N/-M) — <what changed>

## Secret scan
<PASS | FOUND: file:line — pattern>

## Not done
- <gap, or "none">

IMPLEMENTED
```

## sdlc-verify

Terminal tokens: `GATE-PASS` or `GATE-FAIL: <check>`.

```
## Gate results
| Check | Command | Exit code | Result |
|---|---|---|---|
| ... | ... | ... | PASS|FAIL|NOT RUN |

## Failing lines (only if any FAIL)
<file>:<line> <message>

GATE-PASS
```

Every check in the stack's gate set gets a row, even when only one failed — a partial table hides which checks were actually attempted.

The set is: **Tier 1 always** (web: typecheck + lint; Flutter: analyze + boundaries + tests; all stacks: `secret-scan`), plus **Tier 2 conditional** (`dependency-audit`, which fires only when the diff touches a manifest, lockfile, container base image, or pinned CI action). A production build is deliberately not in the set — see `sdlc-verify`.

Results are four-valued, and the distinction is load-bearing: `PASS` (ran, clean), `FAIL` (ran, found something), `SKIPPED` (a conditional check correctly didn't fire), `NOT RUN` (tool missing or invocation failed). Never render the last two as `PASS`.

## sdlc-review

Terminal tokens: `SHIP` or `DO-NOT-SHIP: <finding-id>`. Findings themselves go through the `ReportFindings` tool, never restated as prose — the terminal token is the only text output after that call.

## The one rule that applies to all four

**Never end on anything other than the literal token.** No trailing "let me know if you'd like me to..." No summary paragraph after the token. The token is the last line, full stop — that's what makes it machine-parseable by whatever dispatches these agents.
