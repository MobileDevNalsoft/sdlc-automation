---
name: flutter-bootstrap
description: Use when scaffolding a brand-new Flutter app, or adopting flutter_bloc/very_good_analysis conventions into an existing Flutter project for the first time. Runs `flutter create`, then overlays a vendored lib/ structure (bootstrap.dart, three flavor entrypoints, feature-folder layout), the very_good_analysis@10.3.0 lint ruleset, a brownfield suppression ledger, build_runner config, and the check_boundaries.dart tool flutter-verify later gates on. Dispatched by sdlc-plan/sdlc-developer by name (flutter-sdlc:flutter-bootstrap) — never invoke flutter create directly without it.
---

# flutter-bootstrap

**Verb: scaffold.**

## Before anything else: what "verified" means for this skill

Every file this skill emits was built from research plus publicly
vendored/fetched sources — **not** against a locally running Flutter project
this session. The architecture choice (`flutter_bloc` — see flutter-sdlc's
plugin description) is a settled decision for this stack: it satisfies
current Flutter community practice for the layered
Service/Repository/Cubit/Screen shape this plugin standardizes on (see
`flutter-slice`'s SKILL.md for the full reasoning, including when to reach
for a full `Bloc` instead of a `Cubit`), not something derived from reading
any specific project's code this session. Nothing here is "confirmed working
end-to-end against a real `pubspec.yaml`." Where a claim
*was* checked against a live, fetched source (pub.dev's package API, Flutter's
own release feed, an upstream package's README/source on GitHub), the fetch is
cited inline with a date. Where it wasn't, the line carries a literal
`ASSUMPTION:` prefix at the point it's made — never collected into an
end-of-file caveats list. `check_boundaries.dart` is the one exception that
*was* executed this session (against a synthetic fixture, not a real project
— see its own section below), because it's a standalone `dart:io` script with
no package dependencies to install first.

## Procedure

1. `flutter create --org <reverse-domain> --platforms android,ios <app_name>`
   — ASSUMPTION: `android,ios` as the platform list is this skill's default;
   narrow or widen it per the actual target project's needs.
2. Overlay this skill's `templates/` directory onto the fresh project's `lib/`:
   `bootstrap.dart`, `main_dev.dart`, `main_staging.dart`, `main_prod.dart` go
   directly under `lib/`. Delete the generated `lib/main.dart` — the three
   flavor entrypoints replace it (see "Why three entrypoints, and why these
   names" below).
3. Create the feature-folder skeleton `check_boundaries.dart` (below) expects:
   ```
   lib/
     app/            # app-shell widgets (App root, theme, router) — not templated by this skill
     core/            <-- shared layer #1: cross-feature imports of this are always allowed
     shared/          <-- shared layer #2: same rule as core/ (see boundary rule below)
     features/
       <feature_name>/
         data/
           services/        # flutter-slice: raw API calls
           repositories/     # flutter-slice: Result<T>-returning abstraction over services/
         domain/             # plain Dart models, no Flutter/http import
         presentation/
           bloc/             # flutter-slice: freezed sealed state + Cubit — named
                              # "bloc/" (not "cubit/") on purpose: flutter-verify's
                              # coverage ratchet scopes to bloc/ + services/ by that
                              # exact directory name, matching common flutter_bloc
                              # ecosystem convention of using "bloc/" for Cubit-only
                              # state layers too (Cubit is part of package:bloc).
           screens/          # flutter-slice: exhaustive switch over state
   ```
   This exact shape is what `flutter-slice` assumes when it names files, and
   what `tools/check_boundaries.dart` assumes when it decides what counts as
   "this feature" vs. "another feature."
4. Copy this skill's `analysis_options.yaml`, `.brownfield.yaml`, and
   `build.yaml` to the project root (same directory as `pubspec.yaml`).
5. Copy this skill's `tools/check_boundaries.dart` to the project's `tools/`
   directory. `flutter-verify` runs it as `dart run tools/check_boundaries.dart`
   — it is a blocking gate check there, not merely advisory.
6. Add the pinned dependencies (table below) to `pubspec.yaml`, pointed at the
   flavor entrypoints and `--dart-define-from-file` config `flutter-ship`
   describes for build/run commands.
7. Run `flutter pub get`, then `dart run build_runner build --delete-conflicting-outputs`
   once the first `flutter-slice` feature adds a `freezed`/`json_serializable`
   annotated file — `build.yaml` is already in place for it.

## Why three entrypoints, and why these names

`main_dev.dart` / `main_staging.dart` / `main_prod.dart` — one flavor, one
`main()`, matching Android product flavors of the same name (`dev`, `staging`,
`prod`) via `flutter run --flavor <name> --target lib/main_<name>.dart`. This
naming is a choice this skill makes, not a Flutter requirement — Flutter only
requires that `--target` and `--flavor` stay consistent across `run`/`build`
and whatever CI later automates them (see `flutter-ship`). Verified against
flutter/website's own flavors guide (`flutter/website`,
`sites/docs/src/content/deployment/flavors.md`, fetched 2026-07-29): the
canonical CLI shape is `flutter (run|build <subcommand>) --flavor <flavor_name>`,
and the `appFlavor` constant from `package:flutter/services.dart` is how a
running app can read back which flavor launched it, matching the Android
product-flavor name set in Gradle.

## The boundary rule `tools/check_boundaries.dart` enforces

A file under `lib/features/<feature_a>/` may not import
`lib/features/<feature_b>/...` directly. Cross-feature code must go through
`lib/core/` or `lib/shared/` instead — those two are the only shared layers,
and are exempt from the check by construction (the script only flags imports
of *other* `features/<name>/` paths, never `core`/`shared`).

Dart has no first-party equivalent of ESLint's `import/no-restricted-paths`,
and a first-party analyzer plugin was explicitly considered and rejected for
this purpose: legacy analyzer plugins are deprecated, the new analyzer-plugin
system is pre-1.0 and tracks analyzer majors tightly, and building
compiler-adjacent infrastructure to enforce one boundary rule is a poor
cost/benefit trade when a plain regex-based script over `import` lines
catches the same violation shape for a fraction of the maintenance cost.
`tools/check_boundaries.dart` is ~45 lines of plain `dart:io` instead: it
reads the package name from
`pubspec.yaml`, walks `lib/features/`, and regex-matches
`import 'package:<name>/features/<other>/...'` lines that don't match the
importing file's own feature folder.

**This was actually run this session** (the one piece of this skill that
could be, since it has zero package dependencies) — against a synthetic
fixture, not any real project:

- A file under `lib/features/product/` importing
  `package:demo_app/features/auth/data/auth_service.dart` → exit code `1`,
  stderr line `lib/features/product/presentation/product_screen.dart:1 —
  imports feature "auth" from inside feature "product" ...`.
- The same file importing only `package:demo_app/core/...` and its own
  feature's files → exit code `0`, stdout `check_boundaries: no cross-feature
  violations in lib/features/.`.
- A project with no `lib/features/` directory at all → exit code `0`, stdout
  `check_boundaries: no lib/features/ (or no pubspec name) — skipping.` (so
  this tool never blocks a project before its first sliced feature exists).

## Vendored `analysis_options.yaml`

`analysis_options.yaml` (this directory) is a byte-for-byte copy of
`very_good_analysis@10.3.0`'s ruleset, fetched directly from
`VeryGoodOpenSource/very_good_analysis` tag `v10.3.0`,
`lib/analysis_options.10.3.0.yaml`, on 2026-07-29 — not reconstructed from
memory. License confirmed the same day from that tag's `LICENSE` file: MIT,
`Copyright (c) 2020 Very Good Ventures`. Per this marketplace's "curate and
vendor rather than take a live upstream dependency" policy, this project's
`analysis_options.yaml` **is** the ruleset (no `include:
package:very_good_analysis/...` pointing at a live pub dependency) — see the
file's own header for exactly which lines are vendored verbatim vs. this
project's additions, and why `.brownfield.yaml` is a separate ledger rather
than something wired in through Dart's `include:` merge mechanism (that
file's header explains the ambiguity that decision avoids).

Do **not** vendor anything from `VeryGoodOpenSource/very_good_core` — that
repo's `LICENSE`/`LICENSE.md` both return 404 (archived, no license file
present), so nothing from it may be copied, even "as provenance." Nothing in
this skill does.

## Dependency versions and why each is pinned where it is

Every version below marked "fetched" was checked live against pub.dev's
package API (`https://pub.dev/api/packages/<name>`) or Flutter's own release
feed on 2026-07-29 — not carried over unverified from an earlier design pass.

| Package | Version | Status | Evidence |
|---|---|---|---|
| Flutter SDK | **3.44.8** | required | fetched: `storage.googleapis.com/flutter_infra_release/releases/releases_windows.json`, `current_release.stable` → version `3.44.8`, `dart_sdk_version` `3.12.2`, `release_date` 2026-07-23. |
| Dart SDK | **3.12.2** | required | same feed as above — paired with Flutter 3.44.8, not looked up independently. |
| very_good_analysis | **10.3.0** | required | fetched: pub.dev API, `latest.version` `10.3.0`, published 2026-06-18. |
| sentry_flutter | **9.25.0** | required | fetched: pub.dev API, `latest.version` `9.25.0`. |
| bloc | 9.2.1 | transitive (via flutter_bloc) | fetched: pub.dev API, published 2026-05-12. |
| flutter_bloc | **9.1.1** | required | fetched: pub.dev API, published 2025-05-02; pub score confirmed `160/160` via `pub.dev/api/packages/flutter_bloc/score`. ASSUMPTION-free staleness note: 9.1.1 hasn't republished in ~15 months while `bloc` core has (9.2.1, May 2026) — this is flagged as **benign** staleness, not urgent, because the pub score is maxed and `bloc_lint` (see `flutter-verify`) is actively maintained against it. |
| freezed | 3.2.5 | required (flutter-slice) | fetched: pub.dev API, latest. |
| freezed_annotation | 3.1.0 | required (flutter-slice) | fetched: pub.dev API, latest. |
| json_serializable | 6.14.0 | required (flutter-slice) | fetched: pub.dev API, latest. |
| json_annotation | 4.12.0 | required (flutter-slice) | fetched: pub.dev API, latest. |
| build_runner | 2.15.3 | required (dev) | fetched: pub.dev API, latest. |
| go_router | 17.3.0 | **recommended, not required** | fetched: pub.dev API, `latest.version` `17.3.0`, published 2026-06-02. Whether to adopt `go_router` (or bump an existing project's pin toward this version) is left to the project being bootstrapped, as its own separate, deliberately-scoped decision — `PlaceholderApp` in `bootstrap.dart` uses plain `MaterialApp`/`Navigator` precisely so this scaffold doesn't force that choice. |
| bloc_concurrency | 0.3.0 | **optional** — add only for a feature that needs a full `Bloc` with event transformers (see `flutter-slice`'s Cubit-vs-Bloc rule); not needed for the `Cubit`-only default path | fetched: pub.dev API, `latest.version` `0.3.0`, published 2025-01-12 — over 18 months stale relative to core `bloc`'s more recent releases, same staleness pattern `flutter-verify` already flags for `bloc_test`; verify it still behaves as expected before relying on it for a new feature. |

`bloc_test`, `mocktail`, `bloc_lint`, `osv-scanner`, `gitleaks`, and
`patrol_finders`/`riverpod_lint` version corrections are `flutter-verify`'s
and `flutter-ship`'s concern respectively (they gate/scan, they don't
scaffold) — see those skills' SKILL.md for the same fetched-evidence
treatment, including one correction to the original design brief (`bloc_lint`'s
actual current version, not the one originally assumed).

## What this skill deliberately does not do

- No `custom_lint`/`solid_lints` — both were independently confirmed broken
  (most pub.dev health checks failing, their own `dart analyze` failing) at
  the time of the design pass that produced this plugin; recommending either
  now would be reintroducing a rejected finding, not a fresh recommendation.
- No Riverpod, GetX, `provider` used as a state-management pattern,
  signals-based state packages, or MobX — `flutter_bloc` is this stack's
  settled state-management decision (see `flutter-slice`'s SKILL.md for the
  Cubit-vs-full-Bloc selection rule *within* that decision); these are not
  "also fine" alternatives — they were surveyed and rejected, and
  reintroducing any of them when planning a feature would silently reopen a
  closed decision rather than build on it. Note for anyone tempted to cite
  Google's own `app-architecture` guidance in favor of Riverpod: that
  guidance endorses neither bloc nor Riverpod by name, prescribes MVVM +
  repository + `Command`, and its own reference app uses bare `provider`
  only for dependency injection, not as a state-management pattern —
  "Google recommends Riverpod" is not a claim this skill makes or supports.
- No Mockito, `injectable`, or `auto_route` either — a different category
  (test mocking, DI codegen, routing codegen) but the same "surveyed once,
  not open for re-litigation per feature" status as the state-management
  cut list above.
- No `golden_toolkit`/`dart_code_metrics` (both discontinued) and no
  `alchemist`+`patrol` stacked together in one bootstrap pass (three testing
  systems before a single test exists is the wrong order of operations) —
  test tooling choices belong to `flutter-verify`, and that skill keeps
  `bloc_test`/`mocktail` as the only required test dependencies here.
