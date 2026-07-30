---
name: react-verify
description: Use to gate a React + Vite + TypeScript diff before it's reported IMPLEMENTED — runs tsc --noEmit and diff-scoped eslint via scripts/gate.ps1, always-on secret scanning, and a dependency audit when the diff touches a manifest or lockfile. Reports the four-state table sdlc-verify's output contract expects. Use immediately after react-slice (or any other change to a react-bootstrap-scaffolded project) is done, before sdlc-review.
---

# react-verify

**Verb: gate.**

## What it runs, and what it costs

| # | Tier | Check | Command | Scope | Illustrative timing |
|---|---|---|---|---|---|
| 1 | always | typecheck | `npx tsc --noEmit` | whole project | ~10-15s on a mid-sized project |
| 2 | always | lint | `npx eslint <diff paths>` | **file list** scoped to the diff, **config** still full-repo | ~20-30s |
| 3 | always | secret-scan | `sdlc-core:secret-scan` → `scripts/scan-secrets.ps1` | diff | <1s |
| 4 | **conditional** | dependency-audit | `sdlc-core:dependency-audit` → `scripts/dependency-audit.ps1` | dependency tree | ~2-5s, and only when triggered |

**Why 3 is always and 4 is not.** Any diff can paste a credential, the scan costs under a second, and the failure is irreversible — so it runs every time. A dependency audit, by contrast, is a pure function of the lockfile: if the diff changed no manifest, the answer is identical to last run and re-computing it just slows every task. The audit script detects its own triggers (manifest, lockfile, container base image, pinned CI action) and reports `SKIPPED` when none are present. `SKIPPED` is **not** `PASS` — see the four states below.

Advisories also get published against dependencies nobody edited, which no per-task trigger can catch. That's what `dependency-audit`'s Tier 3 scheduled workflow is for; wire it up separately.

These numbers are illustrative, not a promised SLA — they will differ with your project's size and machine. Measure your own project's actual timings once (the script prints them) and use that as your baseline; don't assume the numbers above apply to your repo.

`scripts/gate.ps1` runs the two compiler checks, captures each exit code, and prints:

```
## Gate results
| Check | Command | Exit code | Result |
|---|---|---|---|
| typecheck | npx tsc --noEmit | <code> | PASS|FAIL|NOT RUN |
| lint | npx eslint <paths> | <code> | PASS|FAIL|NOT RUN |
```

— the exact table shape `sdlc-verify`'s OUTPUT CONTRACT requires, so that agent can paste this script's output rather than re-deriving the format. `sdlc-verify` appends the `secret-scan` and `dependency-audit` rows from their own scripts, which emit the same shape.

## Four result states, and why the distinction matters

| State | Meaning |
|---|---|
| `PASS` | The command ran, exited clean |
| `FAIL` | The command ran and found something |
| `SKIPPED` | A conditional check correctly didn't fire — its trigger wasn't in the diff |
| `NOT RUN` | The tool is absent, or its invocation failed |

Never collapse the last two into `PASS`. A broken trigger that silently reads green is the same defect class as reporting an unexecuted command as passing, and it is worse than having no check, because it also carries false assurance. Note too that a tool exiting non-zero while emitting parseable output is not a pass — verify the output is the report you expected before trusting a zero count.

## Why there is no production build in this gate

A bundler build is the slowest check available and it re-runs on every fix cycle, so putting it here makes the pipeline feel like it stalls — for a check that mostly repeats what `tsc` already proved. It is deliberately out.

**What that trades away, stated honestly.** `tsc --noEmit` type-checks; it does not bundle. These failure classes therefore escape this gate:

- A module the compiler resolves through `tsconfig` `paths` that the bundler cannot resolve at build time (mismatched alias config).
- Bundler plugin or config errors, and anything that only runs during transform.
- Asset/static imports that type-check via a declaration file but have no real file behind them.
- Import cycles that survive type-checking but break at bundle or runtime.
- `import.meta.env` values that are absent at build time.

**Why that is acceptable rather than reckless:** the release path bundles before anything reaches an environment — `react-ship`'s container build runs the production build in its builder stage. A broken build cannot ship silently; it fails at release instead of at gate. The cost is that you learn about it later, when the context is colder.

**Run it yourself when the diff warrants it.** Touching `vite.config.*`, `tsconfig` `paths`, an alias, a bundler plugin, an asset pipeline, or an env-var read? Run the build once by hand before handing off — those are exactly the changes typecheck cannot speak to. A useful cheaper habit for large projects is a scheduled or pre-release build job, separate from this gate.

## Why lint is the slow one, and why scoping the file list doesn't fix that

`eslint <file1> <file2> ...` only narrows which files get linted — it does not narrow which config gets loaded. ESLint's flat config (`eslint.config.js`) is evaluated in full for every invocation regardless of how many files are on the command line, so a one-file diff still pays the full config-load cost. This is "diff-gated at full strength": the diff's files are checked against the complete project ruleset, not a relaxed subset — don't read a fast diff lint as evidence the file would pass a full-repo run, and don't read a slow full-repo run as a sign something is wrong with the diff-scoping itself. Recommend a **weekly full-repo `eslint .` report** as a separate, non-blocking scheduled job (not wired into this gate) so drift in files nobody's touched recently still surfaces on some cadence.

## `gate.ps1` usage

```powershell
# From the project root, gates whatever's currently changed (unstaged + staged):
./scripts/gate.ps1

# Or gate an explicit file list (e.g. from a plan's "files to touch"):
./scripts/gate.ps1 -DiffPaths src/features/products/api/products.queries.ts, src/features/products/components/ProductCard.tsx
```

It does not auto-fix or retry — that policy (how many fix-and-rerun cycles are allowed, how many total gate executions per task) lives in `sdlc-core`'s `sdlc-verify` agent, which decides whether to re-invoke this script. This script's only job is to run once, honestly, and print `GATE-PASS` or `GATE-FAIL: <check>` as its last lines.

## The strict-flag ladder — one flag at a time, each with its own acceptance criterion

Do **not** add `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, `noImplicitOverride`, and `noPropertyAccessFromIndexSignature` to `tsconfig.json` all at once — a multi-flag jump makes it impossible to tell which flag caused which new error, and produces a wall of unrelated fixes in one diff. Adopt in this order, one rung at a time:

| Rung | Flag | Acceptance criterion to adopt it |
|---|---|---|
| 1 | `noUncheckedIndexedAccess` | Diff-scoped `tsc --noEmit` runs show **0** new errors attributable to this flag for **two consecutive weeks** of normal development activity (not a one-time clean run — sustained). |
| 2 | `exactOptionalPropertyTypes` | Same two-consecutive-week bar, measured only after rung 1 has already been adopted and stable — don't measure both flags' error counts in the same window, that reintroduces the "which flag caused this" ambiguity the ladder exists to avoid. |
| 3 | `noImplicitOverride` | Same bar. Usually cheaper than rungs 1-2 unless your codebase has deep inheritance chains, but still gated the same way — don't skip the measurement because it "should" be cheap. |
| 4 | `noPropertyAccessFromIndexSignature` | Same bar. Expected to interact with any `[key: string]`-shaped DTO fields tolerated via a `@typescript-eslint/no-explicit-any: 'off'` exception in react-bootstrap's `eslint.config.js` template — re-check whether that exception is still needed once this rung lands; it may become removable. |

Track adoption state in `tsconfig.json` itself (react-bootstrap's template ships the four flags as a commented-out block for exactly this reason — flip one line, not four, when a rung's criterion is met).

## Cross-references

- `react-sdlc:react-bootstrap` ships the `eslint.config.js`/`tsconfig.json` this gate runs against — if either is missing, `gate.ps1` reports that check `NOT RUN` rather than inventing a substitute command.
- `react-sdlc:react-slice` is what's usually being gated.
- `sdlc-core:output-contracts` and `sdlc-core:evidence-contract` define the exact table shape and the "a command you didn't run is NOT RUN, never a silent pass" rule this skill's output must honor.
