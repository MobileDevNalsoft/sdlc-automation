---
name: evidence-contract
description: Use whenever an agent or skill in the sdlc pipeline is about to assert that something is true, ran, passed, or exists — defines the three shapes evidence is allowed to take and bans collecting uncertainty into an end-of-report footnote.
---

# evidence-contract

**Verb: attest.**

## What counts as evidence

Every factual claim in any sdlc-* agent or skill output must be backed by exactly one of:

1. **A command's exit code and its output.** Not "typechecking passed" — `npx tsc --noEmit` exited `0` with no output.
2. **A `file:line` citation.** Not "the config reads the password from env" — `src/api/client/config.ts:13-14`.
3. **A fetched URL.** Not "the current version is 6.4.3" — the registry/docs page fetched, with the version string quoted from it.

Nothing else qualifies. "I believe," "typically," "should be," and "as expected" are not evidence — they're a signal to either go verify or mark the sentence as an assumption.

## The `ASSUMPTION:` prefix

Anything asserted without one of the three evidence shapes above must carry a literal `ASSUMPTION:` prefix **at the point where it's used**, not collected into a "caveats" section at the end of the report. Example:

> `ASSUMPTION: nginxinc/nginx-unprivileged:alpine3.22 executes /docker-entrypoint.d/*.sh — not confirmed against this image's actual entrypoint script.`

This project's own design history is the reason this rule is strict: a prior round of research carried 8–15 self-declared unverified items per contributor, several load-bearing, all buried in footnotes at the end where nobody re-checked them before they got treated as fact. Inline placement is what makes an assumption visible exactly where a reader might otherwise trust it.

## Applying this to gates

"The gate passed" always means: the command ran, and its exit code was 0. A command that was never invoked is `NOT RUN` — stating otherwise, even implicitly by omission, violates this contract. See `output-contracts` for the literal templates that enforce this at the format level.

## Applying this to reviews

A security or convention finding needs `file:line` plus the concrete failure scenario (what input/state triggers it, what breaks). "This looks risky" without a scenario is not a finding — either find the scenario or don't report it.
