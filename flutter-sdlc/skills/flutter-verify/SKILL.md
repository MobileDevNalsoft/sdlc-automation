---
name: flutter-verify
description: Use to gate a Flutter/flutter_bloc diff — runs the blocking checks (flutter analyze --fatal-infos, dart run tools/check_boundaries.dart, flutter test, always-on secret scanning) plus a dependency audit when pubspec changes, and the advisory non-blocking checks (bloc lint, a bloc/+services/-scoped coverage ratchet). A failing blocking check is GATE-FAIL; a failing advisory check is reported but never blocks.
---

# flutter-verify

**Verb: gate.**

## Blocking vs. advisory — the one distinction that matters here

| Check | Tier | Blocking? | Command |
|---|---|---|---|
| Static analysis | always | **Blocking** | `flutter analyze --fatal-infos` |
| Feature boundaries | always | **Blocking** | `dart run tools/check_boundaries.dart` (scaffolded by `flutter-bootstrap`) |
| Unit/widget tests | always | **Blocking** | `flutter test` |
| Secret scan | always | **Blocking** | `sdlc-core:secret-scan` → `scripts/scan-secrets.ps1` |
| Dependency audit | **conditional** | **Blocking** when it fires | `sdlc-core:dependency-audit` → `scripts/dependency-audit.ps1` |
| Bloc-specific lints | always | Advisory | `dart run bloc_lint` (or `bloc_lint`'s CLI entrypoint — see version note below) |
| Coverage ratchet | always | Advisory | `dart run tools/coverage_ratchet.dart` (this directory's `scripts/coverage_ratchet.dart`, copied to `tools/` alongside `check_boundaries.dart`) |

**On the two security rows.** Secret scanning is always-on because any diff can paste a credential, it costs under a second, and the failure is irreversible once pushed. The dependency audit is conditional because its result is a pure function of `pubspec.lock` — if the diff touched no `pubspec.yaml`/`pubspec.lock`, the answer is unchanged from last run. Its script detects that and reports `SKIPPED`, which is **not** `PASS`.

`ASSUMPTION:` the Dart path uses `osv-scanner --lockfile=pubspec.lock`, whose flags and exit codes were not executed during authoring (the tool was absent). If invocation fails, the row reports `NOT RUN`, never a pass. `dart pub outdated` is not a substitute — it reports staleness, not advisories.

Advisories are also published against packages nobody edited, which no per-task trigger catches by construction. Wire up `dependency-audit`'s scheduled workflow separately for that.

A blocking check that fails is `GATE-FAIL: <check>`, full stop — sdlc-verify's
own output contract handles that. An advisory check that fails is reported in
the same gate-results table but never turns a `GATE-PASS` into a `GATE-FAIL`
on its own; sdlc-verify's fixed gate command set for Flutter is exactly the
three blocking commands above (`flutter analyze --fatal-infos`,
`dart run tools/check_boundaries.dart`, `flutter test`) — the two advisory
checks are this skill's addition on top, reported for visibility, not parity.

## Why bloc lint is advisory, not blocking — corrected from the original design brief

**This is a live correction, not the original assumption.** The design brief
that produced this plugin stated `bloc_lint` was pinned at a
`0.1.0-dev.24` prerelease. A live fetch this session
(`pub.dev/api/packages/bloc_lint`, 2026-07-29) shows that version **never
existed** in `bloc_lint`'s published history at all — the real history runs
`0.1.0` -> `0.2.0-dev.0` through `dev.6` -> `0.2.1` -> `0.3.0`...`0.3.7` ->
`0.4.0`...`0.4.2`, with `0.4.2` published 2026-07-04 (25 days before this
fetch) and no `-dev` suffix in sight at the current tip. That original figure
should be treated as wrong and superseded by this one.

Even with that correction, this skill keeps `bloc_lint` **advisory, not
blocking**, for a reason that doesn't depend on the exact version: its
exit-code behavior and false-positive rate have not been run against this
project's own code this session (no locally-accessible Flutter project was
available — see `flutter-bootstrap`'s SKILL.md framing note), so a bad lint
run must not be able to fail the gate outright on day one. Re-evaluate
blocking status once it's been run for real against actual project code.

## The coverage ratchet — scope, not a fixed target

`scripts/coverage_ratchet.dart` (this directory) parses a `coverage/lcov.info`
(produced by `flutter test --coverage`) and sums hit/found lines **restricted
to paths containing `/bloc/` or `/services/`** — never the whole repo. A flat
`--min-coverage 100` requirement was explicitly rejected for a codebase with
~0 existing tests (see cut list below); a ratchet instead requires only that
this run's scoped coverage ratio not fall below the last recorded baseline
(`coverage/.coverage_ratchet_baseline.json`), and raises the baseline on any
improvement. First run ever always passes and just records the starting
point — there's nothing to ratchet against yet.

Copy `scripts/coverage_ratchet.dart` to the project's `tools/` directory
(alongside `flutter-bootstrap`'s `check_boundaries.dart`) and invoke it as
`dart run tools/coverage_ratchet.dart`.

**This was actually executed this session** against a synthetic
`lcov.info` fixture (not a real project's test run):

- First run, no baseline file yet, 4/6 scoped lines hit (66.7%, correctly
  excluding a `presentation/screens/` file from the same fixture that the
  `/bloc/`/`/services/` path filter doesn't match) → exit `0`, baseline
  written.
- Same coverage again → exit `0`, `PASS — 66.7% (was 66.7%; 4/6 lines)`.
- Coverage dropped to 3/6 (50.0%) → exit `1`,
  `FAIL — bloc/+services/ coverage dropped from 66.7% to 50.0% (3/6 lines)`.
- Coverage improved to 6/6 (100.0%) → exit `0`, baseline raised to `1.0`.
- `coverage/lcov.info` missing entirely → exit `1`,
  `coverage/lcov.info not found — run \`flutter test --coverage\` first.`

`bloc_test@10.0.0` and `mocktail@1.0.5` are this scope's test dependencies
(added by `flutter-bootstrap`, exercised by `flutter-slice`'s templates) —
see the staleness note on `bloc_test` immediately below before assuming
either needs an urgent bump.

## bloc_test@10.0.0 — stale relative to core bloc, disclosed rather than hidden

Fetched pub.dev data, 2026-07-29: `bloc_test`'s latest published version is
`10.0.0`, published **2025-01-12** — over 18 months before this fetch. In
that same window, core `bloc` published `9.2.1` on **2026-05-12**. This is
genuine staleness, not a guess: `bloc_test` is the version actually sitting in
this blocking-adjacent gate (`flutter test` runs against it), and it has not
been re-published since core `bloc` moved forward. **Do not silently bump it
without testing** — flag it in any gate report that touches test tooling, and
treat a `bloc_test` upgrade as its own verified change, not a drive-by pin
bump.

Contrast with `flutter_bloc@9.1.1` (published 2025-05-02, also over a year
stale relative to today): that one is flagged in `flutter-bootstrap`'s
SKILL.md as **benign** staleness — its pub score is a fetched-confirmed
`160/160` and `bloc_lint` (however advisory) is actively maintained against
it. The two packages are stale for the same surface reason (no recent
republish) but carry different real risk, which is why one gets an urgent
flag and the other doesn't — staleness alone isn't the signal, "still the
version this gate actually exercises, unverified after core moved" is.

## What flutter-verify does not decide

- Whether a failing advisory check should ever become blocking — that's a
  decision for whoever runs this skill repeatedly on real code and observes
  the false-positive rate; this skill doesn't pre-commit to a timeline.
- `osv-scanner`/`gitleaks` dependency-and-secret scanning — these are CI/local
  additions this marketplace tracks, but wiring them into a specific CI
  workflow file is `flutter-ship`'s concern (and that skill's own SKILL.md is
  explicit that its CI content carries zero live fetches behind it this
  session, unlike the fetched evidence above).
