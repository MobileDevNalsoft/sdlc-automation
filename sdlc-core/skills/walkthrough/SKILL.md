---
name: walkthrough
description: Use at the end of the pipeline, after sdlc-verify and sdlc-review both return, to write docs/walkthroughs/<task-id>.md — the terminal artifact a human reviews instead of the pipeline's raw transcripts. Mandatory Not-done section; silence about omitted scope is treated as a claim of completion.
---

# walkthrough

**Verb: document.** Invoked by the pipeline directly at the end of a task, not dispatched by a stack skill.

## Why this exists

Because React has no behavioural regression tests (D2's accepted gap), the walkthrough's manual-verification section is the actual compensating control — a human reading it and clicking through the steps is what catches what the gate can't. This is not paperwork; skipping it means shipping on vibes.

## Required sections, in this order

```markdown
# Walkthrough: <task-id>

## Status
<READY FOR REVIEW | BLOCKED | RED — gate failed after security fix>

## What changed and why
<2-5 sentences, plain language, no restating the diff line-by-line>

## Files touched
| File | Blast radius (from code-review-graph) |
|---|---|
| <path> | <callers/impact, or ASSUMPTION: if the graph wasn't available> |

## Gate results
<the exact table sdlc-verify returned, verbatim — not re-summarized>

## Security findings
| Severity | file:line | Finding |
|---|---|---|
| <...> | <...> | <...> |
(or "None" if sdlc-review returned SHIP with an empty finding list)

## Manual verification steps
1. <concrete, human-executable step — "open /CRM/#/leads, filter by stage=Qualified, confirm the new column sorts descending">
2. <...>
(This section is mandatory and must be non-empty. If you cannot think of a manual check, that itself is a signal the slice may be too thin to verify — say so rather than leaving this empty.)

## Open items
<decisions deferred to docs/decisions/, or "none">

## Not done
<anything the original task asked for that isn't in this diff. This section is mandatory even when the answer is "none" — silence here reads as completion, which is the one thing this section exists to prevent.>
```

## Where it goes

`docs/walkthroughs/<task-id>.md`, one file per task, never appended to or overwritten by a later task — if a task reopens, it gets a new file or a clearly marked new section with its own date.

## The RED case

If a security fix (post-review) breaks the gate, the walkthrough goes to `Status: RED` with both facts stated plainly: what the fix was, and what it broke. Do not revert the fix to force a green gate result — a document that hides a real regression to look complete is worse than one that honestly reports RED.
