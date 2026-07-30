---
name: dependency-audit
description: Use to check a project's dependencies for known vulnerabilities. Fires as a gate check only when the diff touches a manifest, lockfile, container base image, or pinned CI action; otherwise it runs on a schedule, because advisories get published against dependencies nobody edited. Reports PASS, FAIL, SKIPPED, or NOT RUN — never a silent pass.
---

# dependency-audit

**Verb: audit (dependencies).**

## Why this is not a per-task check

An audit result is a **pure function of the dependency tree**. If the diff didn't change a manifest or lockfile, the answer is byte-identical to the last run, and running it again buys nothing while making every task slower. That is the whole argument for not putting it in Tier 1.

But the tree isn't the only input — **advisories are published over time, against code nobody touched.** A lockfile untouched for six months can become vulnerable with no diff at all. Per-task gating structurally cannot catch that.

So this check needs two triggers, and neither alone is sufficient:

| Tier | When it runs | Catches |
|---|---|---|
| **2 — conditional** | The diff touches a dependency-defining file (list below) | A change that *introduces* a vulnerable version or a new transitive dependency |
| **3 — scheduled** | On a clock, weekly or per-release | A newly published advisory against an unchanged tree |

## Tier 2 path triggers

Run as a gate check when the diff touches any of these. If none are touched, the gate row reads `SKIPPED (no dependency files in diff)` — which is **not** the same as `PASS`, and must never be rendered as one.

| Ecosystem | Trigger paths |
|---|---|
| Node / web | `package.json`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `npm-shrinkwrap.json`, `.npmrc` |
| Dart / Flutter | `pubspec.yaml`, `pubspec.lock` |
| Containers | `Dockerfile*`, `*.dockerfile`, compose files — **a base image tag is a dependency**, and `FROM node:20-alpine` pulls a whole distro's CVEs |
| CI | Workflow files with pinned action or image versions |
| Other ecosystems | `requirements*.txt`, `poetry.lock`, `Pipfile.lock`, `go.mod`/`go.sum`, `Gemfile.lock`, `pom.xml`, `*.csproj` — same principle |

Container and CI triggers are the ones teams forget. A pinned base image is as much a dependency as anything in `package.json`, and it typically carries far more code.

## Commands

`scripts/dependency-audit.ps1` detects the ecosystem from what's present and runs the right tool. Verified behaviour, not assumed:

- **Node**: `npm audit --audit-level=high --omit=dev` — **confirmed to exit `1`** when a high-or-critical advisory is present and `0` when clean, and `--json` emits `{ auditReportVersion, vulnerabilities, metadata }` where `metadata.vulnerabilities` gives per-severity counts and `vulnerabilities[<pkg>].severity` gives each package's level. The script parses that shape.
- **Dart/Flutter**: `osv-scanner --lockfile=pubspec.lock`. `ASSUMPTION:` osv-scanner's exact flags and exit codes were not executed during authoring (the tool was absent). If invocation fails, the row reports `NOT RUN`, never `PASS`.
- **Containers**: image scanning (trivy/grype) is **not** wired in. `ASSUMPTION:` untested here. Treat base-image CVEs as a documented gap rather than a covered case, and don't imply coverage you don't have.

## Why `--audit-level=high --omit=dev` and not everything

This is the decision that determines whether the check survives contact with a real team. `npm audit` at default settings is famously noisy: it reports advisories in dev-only tooling that never ships, and transitive advisories with no available fix. A gate that fails constantly and unfixably gets disabled — and a disabled check is worth strictly less than an honest gap, because it also carries false assurance.

So: **`high` and `critical` only, production dependencies only.** Everything below that threshold belongs in the Tier 3 scheduled report, where it informs without blocking.

Do not "fix" a noisy audit by dropping the threshold to `critical` or adding `--force`. If a specific advisory genuinely doesn't apply, allowlist it explicitly, with a reason and an expiry — see below.

## The allowlist, and why entries expire

`templates/audit-allowlist.json` suppresses specific advisories. Every entry requires four fields: the advisory id, the package, a **reason**, and an **expiry date**.

The expiry is the load-bearing part. A permanent suppression is indistinguishable from not having the check — it silently becomes policy, and nobody revisits it. An expiring entry **fails the gate once it lapses**, which forces a decision: has upstream shipped a fix, is the reasoning still true, or does this need a real remediation? Suppressions should rot loudly.

The script reports every suppression it applied, and every entry within 14 days of expiry as a warning. A suppression nobody can see is a lie by omission.

## The result states, and why each is distinct

| State | Meaning | Affects verdict? |
|---|---|---|
| `PASS` | The tool ran, and returned a real report with nothing at or above threshold | — |
| `FAIL` | The tool ran and found advisories at or above threshold | Yes → exit 1 |
| `SKIPPED` | The tool exists, but no trigger path was in the diff — correctly not run | No → exit 0, reported as `SKIPPED`, never as `PASS` |
| `NOT RUN` | The tool is absent, or its invocation failed. **A missing tool is never a pass.** | Yes → exit 2 (INCOMPLETE) |
| `NOT COVERED` | A permanent, documented scope gap — e.g. container image scanning, which was never wired in | No |

Two distinctions do real work here:

**`SKIPPED` is not `PASS`.** Collapsing them is the same defect class as reporting an unexecuted command as passing — the thing `evidence-contract` exists to prevent. A broken trigger that silently reads green is worse than no check at all, because it manufactures confidence. When every runnable row is skipped, the verdict says `SKIPPED`, not `PASS`.

**`NOT COVERED` is not `NOT RUN`.** A permanent scope gap is different from a tool that should have worked and didn't. Counting the former as the latter would make every single run return INCOMPLETE — and a check that is *always* incomplete gets ignored, which costs more than the gap it was flagging. So the gap stays visible in the table and stays out of the verdict.

**Parsing successfully is not the same as having a report.** `npm audit` emits its own errors as valid JSON (`{"error":{"code":"ENOLOCK"}}`), which parses cleanly, contains no vulnerabilities, and would otherwise count as a clean pass on a command that failed. The script therefore requires the report shape (`auditReportVersion`, or `metadata` + `vulnerabilities`) before trusting a zero count. A missing lockfile is reported as `NOT RUN` with that specific reason.

## Tier 3 scheduled runs

`templates/scheduled-audit.yml` is a GitHub Actions workflow running weekly plus on demand. It audits at a **lower threshold** than the gate (`moderate`), because a scheduled report can afford noise the gate can't, and it opens or updates an issue rather than failing a build nobody is watching.

If the project has no CI, run the same script on a calendar reminder and put the output in the walkthrough. That is worse than automation but far better than nothing — the failure mode this tier addresses (an advisory published against untouched code) is invisible by construction until someone looks.

## Reporting

Output goes into `sdlc-verify`'s gate table as one row per ecosystem audited. Cite the tool's actual exit code, the per-severity counts, and the specific package names at or above threshold — never "some vulnerabilities found". A finding a developer can't act on without re-running the tool wasn't reported, it was mentioned.
