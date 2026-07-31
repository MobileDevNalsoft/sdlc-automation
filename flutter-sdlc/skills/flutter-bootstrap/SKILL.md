---
name: flutter-bootstrap
description: Use when scaffolding a brand-new Flutter app, or adopting flutter_bloc/very_good_analysis conventions into an existing Flutter project for the first time. Runs `flutter create`, then overlays a vendored lib/ structure (bootstrap.dart, three flavor entrypoints, get_it DI, a dio client with auth/retry interceptors, go_router with an auth redirect guard, secure + key-value storage behind interfaces, a centralized design-token theme, shared widgets, l10n scaffolding, feature-folder layout), the very_good_analysis@10.3.0 lint ruleset, a brownfield suppression ledger, build_runner config, and the check_boundaries.dart tool flutter-verify later gates on. Dispatched by sdlc-plan/sdlc-developer by name (flutter-sdlc:flutter-bootstrap) — never invoke flutter create directly without it.
---

# flutter-bootstrap

**Verb: scaffold.**

## Before anything else: what "verified" means for this skill

This skill has been through two passes, and they earned different amounts of
trust. Conflating them would be the exact dishonesty this preamble exists to
prevent, so they are separated here and the distinction is maintained
throughout the file.

**Pass 1 (2026-07-29, the original design pass).** Every file emitted then was
built from research plus publicly vendored/fetched sources — **not** against a
locally running Flutter project. Nothing from that pass is "confirmed working
end-to-end against a real `pubspec.yaml`."

**Pass 2 (2026-07-30, the revision that added DI/HTTP/routing/storage/theme/
l10n).** A live Flutter app *was* available: a project scaffolded from this
skill's own pass-1 templates, at Flutter 3.41.6 / Dart 3.11.4, with 8 passing
tests. Three distinct classes of claim came out of it, and only the first two
are verified:

1. **Verified by execution.** Dependency resolution (`flutter pub get` and
   `flutter pub add --dry-run` outcomes, including two *real* resolver
   failures — see the `build_runner` and `intl` rows in the dependency table),
   `flutter gen-l10n` behaviour and its `l10n.yaml` key handling, coverage
   header behaviour under `flutter test --coverage`, and the a11y/text-scale
   test results quoted in the theme and shared-widget sections. These were run.
2. **Verified by reading a fetched source.** pub.dev package APIs, upstream
   CHANGELOGs and READMEs on raw.githubusercontent.com, and — new in this pass
   and better evidence than any of them for this SDK — files read directly out
   of the *installed* Flutter SDK (`ColorScheme.fromSeed`'s signature,
   `Durations`/`Easing` values, `flutter_test`'s WCAG constants,
   `flutter_localizations`' exact `intl` pin). Cited inline with a date.
3. **NOT verified: the template files themselves.** The `templates/` tree
   emitted by pass 2 — `core/di/`, `core/network/`, `core/router/`,
   `core/storage/`, `core/theme/`, `shared/widgets/`, `app/` — has **not been
   compiled, analyzed, or run as a set.** Individual designs were checked
   against the vendored ruleset by reading, and a *reference implementation* of
   the theme + component + l10n slice was compiled at 0 analyzer issues with
   14/14 tests passing on 3.41.6 — but at different paths than the ones these
   templates use (`lib/theme/` rather than `lib/core/theme/`), so even that
   result does not transfer without re-running `flutter analyze --fatal-infos`
   after the copy. **Treat the first `flutter analyze` + `flutter test` after
   the overlay as part of the scaffold, not as a formality.**

Where a claim was checked against a live, fetched source, the fetch is cited
inline with a date. Where it wasn't, the line carries a literal `ASSUMPTION:`
prefix at the point it's made — never collected into an end-of-file caveats
list. `check_boundaries.dart` remains the one script that *was* executed
(against a synthetic fixture, not a real project — see its own section below),
because it's a standalone `dart:io` script with no package dependencies to
install first.

## The toolchain this revision was verified against

**Flutter 3.41.6 / Dart 3.11.4** — read from the installed SDK at
`/c/flutter_windows_3.41.6-stable/` on 2026-07-30 and from the live app's
`environment: sdk: ^3.11.4`.

This **corrects** the pass-1 table below, which named Flutter 3.44.8 / Dart
3.12.2 as "required". Those numbers were and are correct as *the current stable
release* (fetched 2026-07-29 from
`storage.googleapis.com/flutter_infra_release/releases/releases_windows.json`,
`current_release.stable` → `3.44.8`, `dart_sdk_version` `3.12.2`, release date
2026-07-23) — but they are not what anything here was verified against, and
several pins in the table exist *because* of 3.11.4. Stating "requires 3.44.8"
would have quietly invalidated every pin justified by the analyzer ceiling.

The target `environment:` block gains an explicit `flutter:` key:

```yaml
environment:
  sdk: ^3.11.4
  flutter: '>=3.38.0'
```

The `flutter:` floor is new. `go_router 17.3.0` declares `flutter >=3.38.0`
(fetched from its pubspec, 2026-07-30); without the key, a teammate on an older
SDK gets a resolver error that names go_router rather than the SDK, which is a
worse error message for the same failure.

**Second-order risk, recorded because it will bite later:** on Flutter 3.44.8 /
Dart 3.12.2, `freezed` may have moved past `analyzer <11.0.0`, at which point
several pins here (`build_runner 2.15.1` especially) become *wrong in the other
direction* — a version-specific workaround read as permanent truth. Every pin
below states the SDK it was verified against for exactly this reason.

## Before you start: the gate may already be failing

`flutter analyze --fatal-infos` against the live app on 2026-07-30 reported
**24 issues, all `info`/`warning`** — i.e. that app did **not** pass
flutter-verify's own blocking analyze gate *before* any of this revision's
changes. (Its 8/8 passing tests are a separate and true fact.) Enumerated here
so nobody re-derives them, and because four of them get *worse* if the DI
refactor is done naively:

- `sort_pub_dependencies` at `pubspec.yaml:36` and `:61` — **inserting the new
  dependencies "alphabetically" into an already-unsorted block does not fix
  this.** The whole block must be re-sorted, `flutter: sdk:` included; the lint
  sorts every key regardless of comment grouping.
- `discarded_futures` at `bootstrap.dart:90`, `main_dev.dart:30`,
  `main_prod.dart:27`, `main_staging.dart:26` — keeping `void main()` while
  `bootstrap` becomes async **multiplies** these. All three mains become
  `Future<void> main() async { ... await bootstrap(config, ...); }`.
- `cascade_invocations` at `bootstrap.dart:116`, `:123` — which is why every
  registration sketch in the DI template uses `getIt..registerX()..registerY()`.
- `public_member_api_docs` at `bootstrap.dart:36,42,43,44,77` (plus `:134`,
  `:136`) — four of these are on `FlavorConfig`'s fields, and the move to
  `lib/core/config/flavor_config.dart` does **not** fix them by itself; the doc
  comments have to be written.
- `avoid_print` at `tools/check_boundaries.dart:20` (and `:53`) and
  `use_raw_strings` at `:33`. **This skill's own shipped copy of that script has
  the same two findings** — see its section below.
- A `warning` at `analysis_options.yaml:210:7`: `'simple_directive_paths' isn't
  a recognized lint rule - undefined_lint`. See the analysis_options section.

Run `flutter analyze --fatal-infos` **before** the overlay so you know which
findings you inherited and which you caused.

## Procedure

1. `flutter create --org <reverse-domain> --platforms android,ios <app_name>`
   — ASSUMPTION: `android,ios` as the platform list is this skill's default;
   narrow or widen it per the actual target project's needs.
2. **Overlay `templates/` onto `lib/`.** Every template file carries its own
   destination in its header comment — that header, not this list, is the
   authoritative destination, because two files' template paths deliberately do
   **not** match their destinations. Delete the generated `lib/main.dart`; the
   three flavor entrypoints replace it. The two exceptions to "template path ==
   `lib/` path":
   - `templates/l10n.yaml` → **the project root**, next to `pubspec.yaml`. Not
     `lib/`. `flutter gen-l10n` only reads `l10n.yaml` from the directory it is
     run in; a copy under `lib/` is silently ignored and the generator falls
     back to defaults that are not these.
   - `templates/l10n/l10n.dart` → **`lib/l10n/l10n.dart`** — same path, no
     translation needed. The destination is fixed, not stylistic: other
     templates (and every screen flutter-slice writes) hard-code
     `import 'package:<pkg>/l10n/l10n.dart';`. An earlier revision shipped
     this template at `templates/core/extensions/build_context_l10n.dart`,
     whose own path implied a `lib/core/extensions/` destination that would
     have left every one of those imports unresolved; it was moved so the
     template path and its destination are the same string.
   - `templates/l10n/app_en.arb` → **`lib/l10n/arb/app_en.arb`** (matching
     `arb-dir:` in `l10n.yaml`).
3. **Replace the placeholder package name.** Templates import
   `package:my_app/...`. Replace `my_app` with the `name:` field from
   `pubspec.yaml` in every copied file. `always_use_package_imports` means
   there are no relative imports to rewrite — but it also means a missed
   placeholder is a compile error, not a lint, so it surfaces immediately.
4. Create the feature-folder skeleton `check_boundaries.dart` expects — see the
   tree below. `lib/core/` and `lib/shared/` now arrive populated by the
   overlay; `lib/features/` starts empty and is filled one slice at a time by
   `flutter-slice`.
5. Copy `analysis_options.yaml`, `.brownfield.yaml`, and `build.yaml` to the
   project root (same directory as `pubspec.yaml`).
6. Copy `tools/check_boundaries.dart` to the project's `tools/` directory.
   `flutter-verify` runs it as `dart run tools/check_boundaries.dart` — a
   blocking gate check there, not merely advisory.
7. **Add the pinned dependencies (table below) to `pubspec.yaml`, and re-sort
   the whole `dependencies:`/`dev_dependencies:` blocks** — see the
   `sort_pub_dependencies` note above. Point the flavor entrypoints and
   `--dart-define-from-file` config at what `flutter-ship` describes.
8. **Add `generate: true` to `pubspec.yaml`'s `flutter:` section**, alongside
   `uses-material-design: true`:

   ```yaml
   flutter:
     uses-material-design: true
     generate: true
   ```

   Verified on 3.41.6 (2026-07-30): with `l10n.yaml` present and this flag
   absent, `flutter gen-l10n` refuses outright — *"Attempted to generate
   localizations code without having the flutter: generate flag turned on."* It
   is a pubspec flag, so `l10n.yaml` cannot set it.
9. **Set `minSdkVersion` to at least 23** in `android/app/build.gradle`.
   `flutter_secure_storage`'s own README (fetched 2026-07-30) states
   *"Minimum Android SDK is now 23 (Android 6.0+)"*. This fails at build time,
   not analyze time, so it is easy to discover late.
10. `flutter pub get`. **If it fails, read the resolution-risk column of the
    dependency table before changing any pin** — two of the pins there exist
    because of resolver failures that were actually observed, and "upgrading to
    latest" reintroduces both.
11. `flutter gen-l10n`. This produces `lib/l10n/gen/app_localizations.dart` and
    `app_localizations_en.dart`. **Commit them.** Verified: `flutter test` does
    **not** run `gen-l10n` — with `lib/l10n/gen/` deleted, `flutter test` failed
    to compile (*"The getter 'AppL10n' isn't defined"*) and did not regenerate
    it. If a team insists on gitignoring them, `flutter-verify`'s step list
    must gain a mandatory `flutter gen-l10n` **before both** `analyze` and
    `test`; this skill's recommendation is to commit and leave flutter-verify
    unchanged. The generated files carry `ignore_for_file: type=lint` and
    `// coverage:ignore-file` (via `l10n.yaml`'s `header:`), so they pollute
    neither gate.
12. `dart run build_runner build --delete-conflicting-outputs` — needed once
    the first `flutter-slice` feature adds a `freezed`/`json_serializable`
    annotated file. `build.yaml` is already in place for it. Nothing in
    *this* skill's templates is codegen-annotated, so this step is a no-op at
    scaffold time.
13. `flutter analyze --fatal-infos` and `flutter test`. **This is the step that
    turns the templates from "designed against the ruleset" into "known to
    satisfy it" — see the preamble.** Expect to fix things here.
14. Record the platform prerequisites in the generated project's README (they
    fail at compile/run time on a new contributor's machine, which is what
    makes them README material rather than a code comment). From
    `flutter_secure_storage`'s README, fetched 2026-07-30: **Linux** needs the
    Libsecret development *and* runtime packages; **Windows** needs the C++ ATL
    libraries from the Visual Studio Build Tools; **web** *"only works on HTTPS
    or localhost environments"* and the README warns that without HSTS and
    correct headers *"you could be subject to a javascript hijack"* — plainly,
    **on web this is not equivalent to Keychain/Keystore**, so an XSS is a token
    compromise. Also note for web: `hive_ce`'s `initFlutter()` skips
    `path_provider` when `kIsWeb` and uses IndexedDB, which is origin-scoped and
    user-clearable — **treat web key-value storage as a cache, never a source of
    truth.**
15. **Establish the 3-tier agent context — `docs-architect:docs-context`,
    `-Mode Ensure`.** Not optional, and deliberately last: the graphs need code
    to graph, so this runs once `lib/` is populated and analyzing. Then
    dispatch `docs-architect:docs-onboarding` to write
    `CODEBASE_ONBOARDING.md`, `docs/architecture/flutter.md`, and the
    `llmwiki/` files the script leaves as `STUB`. See the section below for
    what each tier is and what gets committed.

## First run: establish the 3-tier agent context

Before or immediately after the overlay, dispatch
**`docs-architect:docs-context`**. It detects and creates the three context
tiers, for a greenfield `flutter create` *and* for an adopt-in-place pass:

```powershell
./ensure-context.ps1 -Mode Detect    # report only
./ensure-context.ps1 -Mode Ensure    # create what is missing
```

| Tier | Artifact | Who builds it |
|---|---|---|
| 1 AST / blast radius | `.code-review-graph/graph.db` | `code-review-graph build` |
| 2 structural | `graphify-out/graph.json` | `graphify update .` |
| 3 architecture memory | `llmwiki/*.md` | **an agent — there is no llmwiki tool** |

**Why a scaffold ships this rather than leaving it to whoever adopts it
later.** Every task in this pipeline is executed by an agent working through a
context window. Without the graphs, answering "what breaks if I change this
Cubit" means opening files until the answer appears — expensive, and it
silently truncates on a large project, so the agent proceeds on a *partial*
picture without knowing it. The graphs turn that into a lookup. Retrofitting
them onto a mature codebase is a chore nobody schedules; establishing them at
scaffold time costs one command.

A tier whose CLI is absent reports `NOT RUN`, never `PASS`, and the script
exits non-zero — so a graph that was never built cannot be mistaken for one
that was. Tier 3 is only *scaffolded* by the script (marked `STUB`);
`docs-architect:docs-onboarding` authors it.

**What to commit** (full reasoning in `docs-context`): commit `llmwiki/` and
`graphify-out/graph.json`; **do not** commit `graphify-out/manifest.json` or
`graphify-out/cache/**` — their keys are absolute machine paths, so they are
useless to a teammate and rewrite on every run. `.code-review-graph/` ignores
itself. Add to `.gitignore`:

```gitignore
graphify-out/cache/
graphify-out/manifest.json
```

**`ASSUMPTION:` Dart/Flutter coverage in the tier-1 and tier-2 extractors was
not verified in this pass** — both tools were exercised against JavaScript
only (2026-07-31). If `code-review-graph build` reports `0 nodes` on a Flutter
project, that is the language-support case the script's `NOT RUN` branch
covers, not a broken install. Check before relying on blast-radius answers
here.

## The `lib/` tree this skill produces

```
lib/
  bootstrap.dart                  Async startup: binding, DI (which does storage
                                  init), Bloc.observer, Sentry, runApp.
  main_dev.dart                   dev entrypoint: builds a const FlavorConfig,
  main_staging.dart               awaits bootstrap(config, () => const App()).
  main_prod.dart

  app/
    app.dart                      Root widget: MaterialApp.router + theme /
                                  darkTheme / themeMode + l10n delegates.
                                  Reads getIt, never a static.
    router.dart                   Re-export of core/router/*, so `app/router.dart`
                                  is a valid import path. The logic is in core/.

  core/                           <-- shared layer #1: cross-feature imports of
                                      this are always allowed
    config/
      flavor_config.dart          enum Flavor + immutable FlavorConfig.
                                  NO static field. (See breaking changes.)
    di/
      injector.dart               `final GetIt getIt` + configureDependencies().
    error/
      app_error.dart              sealed AppError + its concrete variants.
    network/
      dio_client.dart             buildDio(...) — the ordered interceptor chain.
      auth_interceptor.dart       QueuedInterceptor: token stamp + single-flight
                                  401 refresh.
      retry_interceptor.dart      Hand-written, idempotent methods only.
      dio_error_mapper.dart       mapDioException(DioException) -> AppError.
    router/
      app_router.dart             createRouter(AuthCubit) — the ONE aggregator
                                  that imports every feature's routes file.
      routes.dart                 abstract final class AppRoutes — path strings.
      go_router_refresh_stream.dart  VENDORED (deleted upstream in go_router
                                  5.0.0) with a provenance header.
    storage/
      secure_store.dart           abstract interface class SecureStore.
      key_value_store.dart        abstract interface class KeyValueStore.
      flutter_secure_store.dart   SecureStore over flutter_secure_storage.
      hive_key_value_store.dart   KeyValueStore over an INJECTED open hive_ce Box.
      in_memory_key_value_store.dart  Test double — no Hive init, no
                                  path_provider platform channel.
      storage_keys.dart           Every storage key string, in one place.
    theme/
      app_colors.dart             The only file allowed to write a Color literal.
      app_theme.dart              light()/dark() from ONE seed + every component
                                  sub-theme.
      app_tokens.dart             AppTokens ThemeExtension + space/radius/motion.
      app_typography.dart         The single font seam. Ships as identity.
    result.dart                   sealed Result<T> — shipped by flutter-slice,
                                  not by this skill.

  l10n/
    l10n.dart                     BuildContext.l10n extension (hand-written).
    arb/
      app_en.arb                  Hand-written source strings + @key descriptions.
    gen/                          GENERATED by `flutter gen-l10n`, COMMITTED.
      app_localizations.dart      Carry ignore_for_file: type=lint and
      app_localizations_en.dart   // coverage:ignore-file automatically.

  shared/                         <-- shared layer #2: same rule as core/
    widgets/
      app_button.dart             AppButton (primary/secondary/text, isLoading).
      app_text_field.dart         AppTextField (token radius, focus ring,
                                  required autofillHints).
      app_gap.dart                AppGap — every gap in the app, never a
                                  SizedBox with a number in it.
      app_loader.dart             AppLoader + AppLoader.overlay().
      app_error_view.dart         Full-screen failure with an always-present retry.
      app_empty_state.dart        Empty state — visually distinct from a failure.

  features/
    <feature_name>/               <-- written by flutter-slice, one at a time
      data/
        dto/                      json_serializable DTOs
        services/                 raw API calls, injected Dio
        repositories/             Result<T>-returning abstraction over services/
      domain/                     plain Dart models, no Flutter/dio/json import
      presentation/
        bloc/                     freezed sealed state + Cubit — named "bloc/"
                                  (not "cubit/") on purpose: flutter-verify's
                                  coverage ratchet scopes to bloc/ + services/
                                  by that exact directory name, matching the
                                  flutter_bloc ecosystem convention of using
                                  "bloc/" for Cubit-only state layers too
                                  (Cubit is part of package:bloc).
        screens/                  exhaustive switch over state
        <feature>_routes.dart     `List<RouteBase> get <feature>Routes` + the
                                  feature's own path constants.
```

**What ships as a template vs. what you write.** `templates/` is the
authoritative list; every file in it names its own destination. Three
components the architecture specifies are **not** in `templates/` as of this
revision and must be written during the first slice — say so rather than
letting a reader assume the overlay is complete:

- `shared/widgets/app_scaffold.dart` — `AppScaffold`, which owns the screen
  gutter, `SafeArea`, the optional AppBar, and tap-outside keyboard dismissal.
  **Its `GestureDetector` must carry `excludeFromSemantics: true`.** That is not
  a style note: running `meetsGuideline(labeledTapTargetGuideline)` against the
  reference implementation on 2026-07-30 produced
  `expected tappable node to have semantic label, but none was found` for
  exactly this widget, and adding the flag was the verified fix.
- `shared/widgets/app_error_banner.dart` — inline, collapsible,
  `AnimatedSize` so it grows from zero height instead of shoving the form down,
  `Semantics(liveRegion: true, container: true)`.
- `shared/widgets/app_snack.dart` — `AppSnack.success/error/info`.

Likewise `test/a11y_test.dart` (contrast + 48dp tap target + labelled target,
parameterised over both brightnesses, with `tester.ensureSemantics()`) and
`test/theme_scale_test.dart` (`[1.0, 1.3, 2.0]` × every screen, asserting
`tester.takeException()` is null) are specified but not templated. **Write them
early.** The text-scale test caught a real `RenderFlex overflowed by 136 pixels`
in already-reviewed button code during the research pass; it is the highest-yield
check in the whole scaffold.

## Breaking changes for projects scaffolded from the older templates

Three things were deleted from `bootstrap.dart`. If you are migrating a project
scaffolded before this revision, all three break at compile time — which is the
good case, because they break loudly.

| Gone | Replacement | Migration |
|---|---|---|
| `enum Flavor` + `class FlavorConfig` **with `static late FlavorConfig current;`** | `lib/core/config/flavor_config.dart`, same two types, **without the static**; the instance is registered with `getIt.registerSingleton<FlavorConfig>(config)` and read as `getIt<FlavorConfig>()` or passed as a parameter. | Delete every `FlavorConfig.current` read. The `main_*.dart` files already build the config; pass it to `bootstrap(config, ...)` instead of assigning a static. |
| `class AppDependencies` | `get_it`. `configureDependencies(config)` in `lib/core/di/injector.dart` registers everything; widgets resolve from `getIt`. | Delete the parameter bag and every constructor that threaded it down the tree. `bootstrap`'s signature changed from `bootstrap(Widget Function(AppDependencies) builder)` to `bootstrap(FlavorConfig config, Widget Function() builder)` — the builder takes no arguments now. |
| `class PlaceholderApp` | `lib/app/app.dart` ships a real `App` root. | **A project scaffolded from the old template very likely has a `test/widget_test.dart` that pumps `PlaceholderApp`.** That test must be retargeted at `App` in the same commit or the migration does not compile. This was confirmed against the live app, where that test does exactly that. |

**Why the static was a defect, not a style disagreement** — stated because a
future reader will otherwise be tempted to put it back for convenience.
Reading `FlavorConfig.current` before assignment throws
`LateInitializationError`; every widget test had to assign it before pumping;
and because it is **one mutable slot on one class**, two differently-flavored
tests in the same isolate overwrite each other. The fix is not "use get_it
because DI is nice" — it is specifically that the config becomes a *value*
passed as a parameter and registered as an **immutable instance**, so there is
no writable slot left to race on.

**The honest limit of that fix:** `GetIt.instance` is itself process-global
mutable state. get_it is a service locator; that does not vanish because we
adopted a package. What it buys over the static is real but bounded —
deterministic LIFO teardown on `reset()` (get_it 9.0.0's one breaking change in
the whole 9.x line, quoted from its CHANGELOG, fetched 2026-07-30: *"**BREAKING**:
Disposal order now always follows strict LIFO (Last-In-First-Out) based on
registration order"* — which is a *benefit* for test isolation), `isRegistered()`
for assertions, type-keyed override seams, and scopes. For tests that must be
fully independent, `GetIt.asNewInstance()` returns a container with no shared
state; that is precisely the class of test the old static broke.

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

Each `main()` is now `Future<void> main() async` and **awaits** `bootstrap` —
see the `discarded_futures` note in "the gate may already be failing".

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
`tools/check_boundaries.dart` is ~55 lines of plain `dart:io` instead: it
reads the package name from `pubspec.yaml`, walks `lib/features/`, and
regex-matches `import 'package:<name>/features/<other>/...'` lines that don't
match the importing file's own feature folder.

**This was actually run** (the one piece of this skill that could be, since it
has zero package dependencies) — against a synthetic fixture, not any real
project:

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

### This revision requires NO change to the script — confirmed by reading it

Both copies were read on 2026-07-30 (this skill's `tools/check_boundaries.dart`
and the live app's, which are identical). Two facts make everything the revision
added a non-event:

- It only walks `Directory('lib/features')` (line 18, `listSync(recursive: true)`
  at line 31). **`lib/core/**` and `lib/shared/**` are never scanned at all.**
- Its regex (lines 26-28) matches only `package:$pkg/features/([^/'"]+)/`, and
  it flags a match only when `group(1) != ownFeature` (line 38). An import of
  `package:$pkg/core/…` or `package:$pkg/shared/…` **cannot match the pattern.**

So `core/router/app_router.dart` importing every feature's routes file,
`core/di/injector.dart` importing every feature's Cubit, and features importing
`shared/widgets` all pass the existing script unmodified. That is not a
loophole to be closed — it is exactly the seam the script's own header
describes. **This section deliberately does not invent work.**

The consequence for navigation is worth stating explicitly, because it is what
keeps the rule enforceable once routing exists: **cross-feature navigation
carries no import.** `lib/core/router/routes.dart` holds a core-owned
`abstract final class AppRoutes { static const String login = '/login'; ... }`,
and feature A calls `context.go(AppRoutes.profile)` — a **string from `core`**,
not a symbol from feature B.

### Three additive rules, recommended but NOT implemented

The design-token rule ("no raw `Color(0x…)`, `EdgeInsets.all(16)`, `Duration(…)`
or `BorderRadius.circular(8)` under `lib/features/**`") and the component rule
("features use `AppButton`/`AppTextField`/`AppScaffold`, never `FilledButton`/
`TextField`/`Scaffold` directly") are, as shipped, **conventions**. Conventions
drift within two slices. Three deny-list rules would make them machine-enforced:

| Rule | Deny under `lib/features/**` | Also scan |
|---|---|---|
| R1 storage packages | `package:hive_ce`, `package:hive_ce_flutter`, `package:flutter_secure_storage`, `package:shared_preferences` | **`lib/core/network/**` too** — an interceptor must depend on `SecureStore`, not on `FlutterSecureStorage`, or `core/network` becomes a second leak point. |
| R2 raw design literals | `Color(0x`, `EdgeInsets\.\w+\(\s*\d`, `Duration\(`, `BorderRadius\.circular\(\s*\d` | Allowed only under `lib/core/theme/**` and `lib/shared/widgets/**`. |
| R3 raw framework widgets | `ElevatedButton`, `FilledButton`, `OutlinedButton`, `TextField`, `TextFormField`, `Scaffold(` | Allowed only under `lib/shared/widgets/**`. |

**Not implemented in the shipped script, and the reason matters:** R1-R3 require
scanning directories *beyond* `lib/features/`, which is a structural change to
the script's loop rather than one more regex. Budget for it, and re-run the
three synthetic-fixture cases above afterwards.

**Also outstanding on that script:** it currently trips `avoid_print` (lines 20
and 53) and `use_raw_strings` (line 33, the escaped `'\\'` argument to
`replaceAll`) under this skill's own vendored ruleset — 3 of the 24 findings
listed earlier. The correct fix for the first is
`stdout.writeln`, which is the right call in a `dart:io` script anyway. It has
not been made here.

## Vendored `analysis_options.yaml` — unchanged this revision

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

**No exclusion was added for the generated l10n output, and that is a verified
decision, not an oversight.** `flutter analyze --fatal-infos` was run over
`lib/l10n/gen/` with this exact vendored ruleset on 2026-07-30: **zero** issues
from those files. The generated header carries `// ignore_for_file: type=lint`,
which blankets every lint — including `public_member_api_docs`,
`lines_longer_than_80_chars`, and `always_use_package_imports` (the generated
file uses a relative `import 'app_localizations_en.dart';`). **Do NOT add
`lib/l10n/gen/` to `analyzer: exclude:`.** An unnecessary exclude is a place
real problems later hide.

**One known finding this file itself causes, deliberately left in place.**
`flutter analyze --fatal-infos` emits:

```
warning - 'simple_directive_paths' isn't a recognized lint rule -
analysis_options.yaml:210:7 - undefined_lint
```

Reproduced on 2026-07-30 in a clean scratch package containing nothing but this
file, so it is a ruleset/analyzer mismatch — very_good_analysis@10.3.0
references a rule that analyzer 10.0.1 does not know — and **not** app code. It
is a `warning`, so it trips `--fatal-infos`. The analyzer version is not freely
choosable here: it is held at 10.x by `freezed 3.2.5` (see the dependency
table). **Record it in `.brownfield.yaml` with the freezed→analyzer chain as its
stated reason; do NOT silently delete the line** — a future analyzer upgrade
would then lose the rule with nobody noticing. That ledger entry has not been
written yet.

## `build.yaml` — unchanged this revision

`build.yaml` still configures exactly two builders: `json_serializable`
(`field_rename: snake`, `explicit_to_json: true`) and
`source_gen:combining_builder`'s `// coverage:ignore-file` preamble, which is
what keeps generated `.freezed.dart`/`.g.dart` out of flutter-verify's coverage
ratchet. Both key shapes were fetched verbatim from json_serializable's README
on 2026-07-29; freezed documents no `build.yaml` section at all for these
defaults.

**Nothing was added, because no new code generator was adopted.** The one that
was seriously evaluated — `hive_ce_generator` — was rejected as a default (see
the cut list), so there is no new builder to configure and no new generated
path to exclude. If a team later adopts it, `build.yaml` will need a matching
entry *and* the co-execution caveat in that cut-list row.

## Dependency versions and why each is pinned where it is

**How to read the Evidence column.** Every row names who fetched it and when.
Rows dated **2026-07-29** come from this skill's original design pass; rows
dated **2026-07-30** come from the research pass that produced this revision.
None of them were re-fetched while this file was written on 2026-07-31 —
**version "latest" claims are point-in-time and will drift.** Nothing here is
stated from memory: anything unfetched carries an inline `ASSUMPTION:` marker.

Two constraints dominate the whole table and are worth reading before any
individual row:

- **`freezed 3.2.5` declares `analyzer >=9.0.0 <11.0.0`** (fetched
  `pub.dev/api/packages/freezed/versions/3.2.5`, 2026-07-30). Note it is a
  **window with a floor**, not merely a ceiling — the `>=9.0.0` floor kills more
  candidate generators than the `<11.0.0` ceiling does. Every codegen proposal
  must be checked against **both** bounds.
- **`lean_builder ^1.2.0` (analyzer `^13.0.0`, sdk `>=3.12.0`) is a dependency
  of both `injectable_generator 3.1.1` and `auto_route_generator 10.6.0`.** That
  whole generator family is categorically off-limits while freezed 3.2.5 is
  pinned. **Check future codegen proposals for `lean_builder`, not just for a
  direct `analyzer` constraint** — checking only the direct constraint would
  have wrongly cleared `auto_route_generator`, whose own
  `analyzer >=10.0.0 <14.0.0` *does* overlap the ceiling.

### Toolchain

| Component | Version | Status | Evidence |
|---|---|---|---|
| Flutter SDK | **3.41.6** | what everything here was verified against | read from the installed SDK at `/c/flutter_windows_3.41.6-stable/` and the live app's `environment:` block, 2026-07-30. **Supersedes the pass-1 claim of "3.44.8 required"** — 3.44.8 is current stable, but nothing here was checked on it. |
| Dart SDK | **3.11.4** | same | paired with Flutter 3.41.6 in the same installation; `environment: sdk: ^3.11.4`. |
| Flutter (current stable, for reference only) | 3.44.8 / Dart 3.12.2 | **not** what this was verified on | fetched 2026-07-29: `storage.googleapis.com/flutter_infra_release/releases/releases_windows.json`, `current_release.stable` → `3.44.8`, `dart_sdk_version` `3.12.2`, release date 2026-07-23. Several pins below will need re-evaluation on this toolchain — see "second-order risk" above. |
| very_good_analysis | **10.3.0** | vendored, **not** a pub dependency | fetched 2026-07-29: pub.dev API, `latest.version` `10.3.0`, published 2026-06-18. Copied byte-for-byte into `analysis_options.yaml`. |

### `dependencies:` — listed in `sort_pub_dependencies` order

| Package | Version | Status | Evidence | Resolution risk vs. analyzer<11 / freezed 3.2.5 / build_runner 2.15.1 / the intl pin |
|---|---|---|---|---|
| `bloc` | 9.2.1 | transitive (via flutter_bloc), pinned anyway | fetched 2026-07-29: pub.dev API, published 2026-05-12. Unchanged this revision. | **None.** No analyzer dep. |
| `cupertino_icons` | `^1.0.8` | inherited from `flutter create` | the `flutter create` default. Left as a caret — the only caret in `dependencies:`, and it is inherited rather than chosen. | **None.** |
| `dio` | **5.11.0** | **required — NEW** | fetched 2026-07-30: pub.dev API, latest `5.11.0`, published 2026-07-25T12:54:21Z. env `sdk >=2.18.0 <4.0.0`; deps `async ^2.8.2, collection ^1.16.0, http_parser ^4.0.0, meta ^1.5.0, mime >=1.0.0 <3.0.0, path ^1.8.0, dio_web_adapter >=1.1.0 <3.0.0`. Score 160/160, 3,687,151 downloads/30d, publisher `flutter.cn`. | **None** — declares no `analyzer`/`build`/`source_gen`. **Do not pin below 5.11.0:** its changelog (fetched `raw.githubusercontent.com/cfug/dio/main/dio/CHANGELOG.md`, 2026-07-30) records *"Fix concurrent requests hanging when interceptors share failing Futures"* — a hang in exactly the concurrent-interceptor scenario the 401 refresh queue creates. |
| `flutter` | `sdk: flutter` | required | SDK. Included here because `sort_pub_dependencies` sorts it with everything else. | n/a |
| `flutter_bloc` | **9.1.1** | required | fetched 2026-07-29: pub.dev API, published 2025-05-02; pub score `160/160` via `pub.dev/api/packages/flutter_bloc/score`. **flutter_bloc + Cubit remains the settled state-management decision.** ASSUMPTION-free staleness note: 9.1.1 hasn't republished in ~15 months while `bloc` core has (9.2.1, May 2026) — flagged **benign**, not urgent, because the pub score is maxed and `bloc_lint` (see `flutter-verify`) is actively maintained against it. | **None.** |
| `flutter_localizations` | `sdk: flutter` | **required — NEW** | read from the installed SDK at `/c/flutter_windows_3.41.6-stable/flutter/packages/flutter_localizations/pubspec.yaml`, 2026-07-30: declares `environment: sdk: ^3.9.0-0` and `dependencies: intl: 0.20.2` — **an exact pin, not a caret range.** | **This is the source of the intl pin.** See the `intl` row. |
| `flutter_secure_storage` | **10.3.1** | **required — NEW** | fetched 2026-07-30: pub.dev API, latest `10.3.1`, published 2026-05-27. env `sdk >=3.3.0 <4.0.0, flutter >=3.19.0`. Score 150/160, 3,262,361 downloads/30d, publisher `steenbakker.dev`. **Resolution PROVEN:** `flutter pub add --dry-run` in the live app resolved 10.3.1 + `_darwin 0.3.2`, `_linux 3.0.1`, `_platform_interface 2.0.2`, `_web 2.1.1`, `_windows 4.2.2`, holding analyzer at 10.0.1. | **None.** Its *own* `dev_dependencies` list `very_good_analysis >=6.0.0 <10.1.0` — that is the package's internal lint choice, has zero effect on a consumer, and is **not** a conflict with this project's vendored 10.3.0 despite looking like one. |
| `freezed_annotation` | 3.1.0 | required (flutter-slice) | fetched 2026-07-29: pub.dev API, latest. | **None** (annotation-only). |
| `get_it` | **9.2.1** | **required — NEW** | fetched 2026-07-30: pub.dev API, latest `9.2.1`, published 2026-02-20. Deps `async ^2.11.0, collection ^1.17.1, meta ^1.9.1` — pure Dart, **no flutter SDK dep, no analyzer dep**. env `sdk >=3.0.0 <4.0.0`. One-day discrepancy recorded rather than smoothed: the upstream CHANGELOG header reads `## [9.2.1] - 2026-02-19` while pub.dev's publish timestamp is 2026-02-20. | **None** — it cannot interact with the analyzer ceiling at all. |
| `go_router` | **17.3.0** | **required** (was "recommended, not required") | fetched 2026-07-30: pub.dev API, latest `17.3.0`, published 2026-06-02. Deps `collection ^1.15.0, flutter (sdk), flutter_web_plugins (sdk), logging ^1.0.0, meta ^1.7.0`. env `sdk ^3.10.0, flutter >=3.38.0`. First-party (`flutter/packages`). **The pass-1 citation of 17.3.0 was correct and is still current** — a rare case needing no correction, only a status change. | **None** for the ceiling. **Raises the effective Flutter floor to 3.38.0** — hence the explicit `flutter:` key in `environment:`. Separately: `GoRouterRefreshStream` was **removed** in go_router 5.0.0 and is **vendored** into `core/router/` with a provenance header — any tutorial importing it from `package:go_router` is stale and will not compile. |
| `hive_ce` | **2.19.3** | **required — NEW** | fetched 2026-07-30: pub.dev API, latest `2.19.3`, published 2026-02-03T10:49:41Z. env `sdk ^3.4.0`; deps `meta ^1.14.0, crypto ^3.0.0, web >=0.5.0 <2.0.0, isolate_channel ^0.6.0, json_annotation ^4.9.0`. Score 160/160, 806,531 downloads/30d, `is:wasm-ready`. GitHub API `IO-Design-Team/hive_ce`: `archived=false`, `pushed_at 2026-07-29`, 348 stars, 9 open issues. **Resolution PROVEN** by live `flutter pub add --dry-run` (30 deps changed, no version-solving failure). | **None** — declares no analyzer dep. This is the maintained successor to `hive`; the original is rejected on maintenance grounds, not resolution grounds (see cut list). |
| `hive_ce_flutter` | **2.3.4** | **required — NEW** | fetched 2026-07-30: pub.dev API, latest `2.3.4`, published 2026-01-09T23:40:17Z. env `sdk ^3.4.0, flutter >=3.27.0`; deps `flutter (sdk), hive_ce ^2.16.0, path_provider ^2.0.10, path ^1.8.2`. Resolved live to 2.3.4 + `path_provider 2.1.6` and its five platform impls. | **None.** Brings `path_provider` transitively — **do not declare `path_provider` directly** (dead weight plus one more line to keep sorted; `depend_on_referenced_packages` will demand it anyway if your own code ever imports it). |
| `intl` | **`any`** | **required — NEW, and the ONE deliberate exception to the house style of exact pins** | fetched 2026-07-30: pub.dev API, latest is `0.20.3`, published 2026-06-25T09:21:11Z, env `sdk ^3.9.0`. **The trap was reproduced live that day:** a scratch package with `intl: ^0.20.3` + `flutter_localizations: {sdk: flutter}` failed `flutter pub get` with *"Note: intl is pinned to version 0.20.2 by flutter_localizations from the flutter SDK. … version solving failed."* Re-running with `0.20.2` resolved. `docs.flutter.dev`'s i18n page (fetched same day) recommends literally `intl: any`, *"allowing the version pinned by flutter_localizations to be used"*, and the generated `app_localizations.dart` header repeats it verbatim. | **HIGH — this is resolution risk #1.** `any` (or the exact `0.20.2`) is mandatory; **a caret constraint is an immediate hard `flutter pub get` failure.** `flutter pub outdated` will report "0.20.3 available" forever — expected noise, not a bug. **Do not "tidy" `any` into a caret.** `ASSUMPTION:` intl 0.20.2's own declared sdk constraint was not separately fetched; it resolved cleanly under `sdk ^3.11.4`, which is sufficient for the verdict but is not a verified reading of its range. |
| `json_annotation` | 4.12.0 | required (flutter-slice) | fetched 2026-07-29: pub.dev API, latest. | **None** (annotation-only). |
| `sentry_flutter` | **9.25.0** | required | fetched 2026-07-29: pub.dev API, `latest.version` `9.25.0`. | **None.** |

### `dev_dependencies:` — listed in `sort_pub_dependencies` order

| Package | Version | Status | Evidence | Resolution risk |
|---|---|---|---|---|
| `bloc_test` | 10.0.0 | required (flutter-verify's concern) | pinned per `flutter-verify`'s SKILL.md; flagged there as stale relative to core `bloc`. | **None.** |
| `build_runner` | **2.15.1** | **required (dev) — CORRECTED from 2.15.3** | **This correction is verified fact, not a preference.** The pass-1 table said 2.15.3 ("fetched: pub.dev API, latest", 2026-07-29). On 2026-07-30, `flutter pub get` with 2.15.3 **actually failed to resolve**: 2.15.3 requires `analyzer >=13.3.0`, which has empty intersection with freezed 3.2.5's `analyzer <11.0.0`. Fetched `pub.dev/api/packages/build_runner/versions/2.15.1`: published 2026-07-08, `analyzer >=8.0.0 <14.0.0`, `build ^4.0.7` — resolves, holding analyzer at 10.0.1. | **This IS the ceiling in action.** Keep at exactly **2.15.1** until freezed relaxes past analyzer 11. A future agent "upgrading to latest" reintroduces the exact failure that produced this pin. |
| `flutter_test` | `sdk: flutter` | required | SDK. | n/a |
| `freezed` | **3.2.5** | required (flutter-slice) | fetched 2026-07-30 at `pub.dev/api/packages/freezed/versions/3.2.5`: `analyzer >=9.0.0 <11.0.0`, `build >=3.0.0 <5.0.0`, `source_gen >=3.0.0 <5.0.0`, env `sdk >=3.8.0 <4.0.0`. (Pass 1 recorded only "latest".) | **This IS the ceiling.** The `>=9.0.0` **floor** matters as much as the `<11.0.0` ceiling — see the two dominating constraints above. |
| `json_serializable` | 6.14.0 | required (flutter-slice) | fetched 2026-07-29: pub.dev API, latest. | **None new** — already resolving under the ceiling today. |
| `mocktail` | 1.0.5 | required (flutter-verify's concern) | pinned per `flutter-verify`'s SKILL.md. | **None.** |

### Optional, per-feature only

| Package | Version | Status | Evidence |
|---|---|---|---|
| `bloc_concurrency` | 0.3.0 | **optional** — add only for a feature that needs a full `Bloc` with event transformers (see `flutter-slice`'s Cubit-vs-Bloc rule); not needed for the `Cubit`-only default path | fetched 2026-07-29: pub.dev API, `latest.version` `0.3.0`, published 2025-01-12 — over 18 months stale relative to core `bloc`, the same staleness pattern `flutter-verify` already flags for `bloc_test`; verify it still behaves as expected before relying on it. |

`bloc_lint`, `osv-scanner`, `gitleaks`, and `patrol_finders`/`riverpod_lint`
version corrections are `flutter-verify`'s and `flutter-ship`'s concern
respectively (they gate/scan, they don't scaffold) — see those skills' SKILL.md
for the same fetched-evidence treatment, including one correction to the
original design brief (`bloc_lint`'s actual current version, not the one
originally assumed).

## What this skill deliberately does not do

### First: what changed, and that the change was deliberate

**An earlier revision of this list rejected more than it does now, and a future
reader must not "fix" that back.** On 2026-07-30 the plugin's owner explicitly
overrode three of its stances for this stack. Recorded here with the reversal
visible, rather than rewritten to look like it was always this way:

| Previously | Now | Note |
|---|---|---|
| `go_router` "recommended, not required" — with `PlaceholderApp` using plain `MaterialApp`/`Navigator` *"precisely so this scaffold doesn't force that choice"* | **ADOPTED as a required default**, including declarative auth redirect guards | `PlaceholderApp` is deleted, so that parenthetical is obsolete rather than merely outdated. |
| DI: no service locator; hand-threaded `AppDependencies` only | **`get_it` ADOPTED as the required default**, with **hand-written registration** | The old text said *"no Mockito, `injectable`, or `auto_route`"* and a `bootstrap.dart` comment called `AppDependencies` *"not a generated service locator (this marketplace's cut list rejects `injectable`)"*. **That conflated "no codegen DI" with "no service locator".** The conflation is what is broken apart here — codegen DI is still out, the container is not. |
| HTTP: `package:http` (flutter-slice's Service template) | **`dio` ADOPTED** | Brings interceptors, which is what makes single-flight 401 refresh and retry possible at all; also deletes the per-Service status-code check, since `validateStatus` throws `badResponse` already. |
| (not previously addressed) | **Local persistence ADOPTED**: `flutter_secure_storage` behind `SecureStore`, `hive_ce` behind `KeyValueStore` | Interfaces first, exactly one implementation each. |
| (not previously addressed) | **A centralized theme / design token system ADOPTED** | Directly fixes a real defect: the pass-1 `app.dart` was a `MaterialApp` with **no `theme:` at all**, rendering stock Material-3 baseline. |
| (not previously addressed) | **l10n ADOPTED and scaffolded** | One `app_en.arb`; near-zero cost single-language, and adding a locale is then a file drop plus `flutter gen-l10n` with **no code change**, because `app.dart` spreads the generated delegate/locale lists rather than a hand-written one. |

State management is **unchanged and still settled: `flutter_bloc` with `Cubit`.**
That was never part of the override.

### Still rejected

- **No Riverpod, GetX, `provider` used as a state-management pattern,
  signals-based state packages, or MobX** — `flutter_bloc` is this stack's
  settled decision (see `flutter-slice`'s SKILL.md for the Cubit-vs-full-Bloc
  selection rule *within* that decision). These are not "also fine"
  alternatives; they were surveyed and rejected, and reintroducing any of them
  when planning a feature would silently reopen a closed decision rather than
  build on it. Note for anyone tempted to cite Google's own `app-architecture`
  guidance in favor of Riverpod: that guidance endorses neither bloc nor
  Riverpod by name, prescribes MVVM + repository + `Command`, and its own
  reference app uses bare `provider` only for dependency injection, not as a
  state-management pattern — "Google recommends Riverpod" is not a claim this
  skill makes or supports.
- **No `injectable` / `injectable_generator` (codegen DI)** — rejected on
  policy **and** on arithmetic, and the arithmetic is worth having because it
  costs nothing: fetched 2026-07-30, `injectable_generator 3.1.1` (published
  2026-07-21) declares `analyzer >=13.0.0 <14.0.0` and `sdk >=3.12.0 <4.0.0`.
  **Two independent hard failures** — the analyzer range has empty intersection
  with freezed's `<11.0.0`, and `sdk >=3.12.0` excludes the installed Dart
  3.11.4. It also depends on `lean_builder ^1.2.0`, a third blocker. `injectable`
  (annotations only) falls by consequence: inert without its generator.
  **`get_it` is NOT covered by this rejection** — see the reversal table above.
- **No `auto_route` / `auto_route_generator` (codegen routing)** — policy plus
  *transitive* arithmetic. **A naive "analyzer conflict" claim would have been
  wrong, and was checked rather than asserted:** `auto_route_generator 10.6.0`
  declares `analyzer >=10.0.0 <14.0.0`, which **does** overlap the ceiling at
  10.x. The real blocker is `lean_builder ^1.2.0`, whose only 1.x release
  (`1.2.0`, published 2026-06-13, fetched 2026-07-30) declares `analyzer ^13.0.0`
  and `sdk >=3.12.0 <4.0.0`. **`go_router` is NOT covered by this rejection.**
- **No `go_router_builder`** (`4.4.0`, fetched 2026-07-21 publish date on
  2026-07-30) — **stated plainly against our own convenience: this is a POLICY
  rejection, not an arithmetic one.** It declares `sdk ^3.10.0`,
  `flutter >=3.38.0`, `analyzer >=8.2.0 <14.0.0`, `build >=3.0.0 <5.0.0`,
  `source_gen >=3.1.0 <5.0.0`, and **no `lean_builder`** — it is the one codegen
  package evaluated anywhere here that **would actually resolve** at analyzer
  10.x. It is out because it is codegen routing (the standing decision), and
  because hand-written path constants plus a per-route typed extractor deliver
  the same compile safety in ~20 lines. Also: go_router 16.0.0 and 17.3.0 both
  shipped `GoRouteData` changes gated on *"Requires go_router_builder >= 3.0.0"*,
  so adopting it couples go_router upgrades to a second package's cadence.
  **This is the package to reach for if the team later wants generated typed
  routes** — dressing a policy call up as a constraint failure would be exactly
  the laundering this plugin's evidence standard forbids.
- **No `retrofit` / `retrofit_generator`** — **and the obvious argument for
  rejecting it is wrong, so it is corrected here rather than repeated.**
  `retrofit_generator 10.2.8`'s `analyzer >=8.4.1 <14.0.0` (fetched 2026-07-30)
  **overlaps** freezed's `<11.0.0` in 8.4.1–10.x. It is rejected on the ground
  the owner actually established — codegen for the networking layer, exactly
  parallel to codegen DI and codegen routing. `ASSUMPTION:` its `build ^4.0.0` /
  `source_gen ^4.0.0` were **not** checked against the pinned `build_runner
  2.15.1`; a conflict is plausible but unproven — **do not assert it** without
  running `flutter pub get`.
- **No `hive` (original) / `hive_flutter` / `hive_generator`** — superseded by
  `hive_ce`, and each for a different reason worth keeping distinct.
  `hive 2.2.3`: last **stable** published **2022-06-30**, most recent
  publication of any kind `4.0.0-dev.2` on 2023-08-25 (the 4.x line died in
  dev), env `sdk >=2.12.0 <3.0.0` (pre-Dart-3). GitHub: `archived=FALSE` — so
  "archived" is *not* the evidence — but `pushed_at 2024-06-28` with **568 open
  issues**. **Honesty point: `flutter pub add --dry-run hive hive_flutter`
  SUCCEEDED on 2026-07-30.** The rejection is purely maintenance evidence, not a
  resolver failure. `hive_flutter 1.1.0`: only release, published **2021-06-20**.
  `hive_generator 2.0.1`: `analyzer >=4.6.0 <7.0.0` — **fully disjoint** from
  freezed's `>=9.0.0` floor, so unlike the other two this one *is* a guaranteed
  `flutter pub get` failure.
- **No `isar`** — the unmaintained twin of `hive`, same publisher, same death
  timeline (last stable 2023-04-25; `4.0.0-dev.14` 2023-08-21; env
  `sdk >=2.17.0 <3.0.0`). Swapping one corpse for its twin is not a migration.
- **No `hive_ce_generator` by default** — this one *does* resolve, at exactly
  one usable version, and is rejected anyway. Walked version by version (all
  fetched 2026-07-30): 1.11.3 `analyzer ^14.0.0` ✗; 1.11.2 `^12.0.0` ✗;
  **1.11.1 `^10.0.0` ✓**; 1.11.0 `^9.0.0` ✓; 1.10.0 `^8.0.0` ✗ *(below freezed's
  floor)*; 1.9.0 and older ✗. **The viable window is exactly `{1.11.0, 1.11.1}`
  out of the entire release history.** Rejected because the project already
  carries one hand-pinned, upgrade-blocked generator (`build_runner 2.15.1`);
  **two is a pattern, and a scaffold should not ship a pattern of upgrade-blocked
  generators.** The default path needs no adapters: `hive_ce` stores
  `null/int/double/bool/String/Map/Uint8List/List<…>/Set<…>` with no adapter,
  plus `DateTime`/`BigInt`/`Duration` via automatically-registered internal
  adapters; anything else throws `HiveError('Cannot write, unknown type: <T>')`.
  Persist domain objects as JSON maps via the `json_serializable` already
  present — one serialization mechanism instead of two. **If ever adopted it
  MUST be pinned exactly (`hive_ce_generator: 1.11.1`, never `^1.11.1`)** with a
  comment naming freezed 3.2.5's window as the cause. **`ASSUMPTION:` its
  co-execution with freezed in one `build_runner` pass was never run** —
  resolution is proven, co-execution is not; those are different failure
  surfaces.
- **No `drift` / `drift_dev` as the default — and it is the strongest rejected
  alternative here, not a weak one.** `drift 2.34.3` (published 2026-07-27,
  three days before the research pass — very active) declares
  `analyzer >=8.0.0 <14.0.0`; `drift_dev 2.34.5` declares `analyzer ^13.0.0`,
  outside the window, but live `flutter pub add --dry-run` resolved
  `drift_dev 2.34.0 (2.34.5 available)` holding analyzer at 10.0.1. So its
  codegen *does* work — **only by pinning the generator back, the same
  upgrade-blocking trap.** Out as a default because it is codegen-mandatory, and
  because it forces every scaffolded app to schematise before it has data.
  **Flagged rather than silently dropped: if freezed relaxes past analyzer 11,
  drift deserves re-evaluation as the default for relational features.**
- **No `sqflite` as the default — and the reason is a tripwire, not a quality
  judgement.** Latest `2.4.3` (published 2026-06-02) declares `sdk ^3.12.0,
  flutter >=3.44.0`; **Dart 3.11.4 does not satisfy that.** Verified by
  consequence: `flutter pub add --dry-run sqflite` resolved `2.4.2+1
  (2.4.3 available)` — a 2025-03-18 release, 16 months stale — **with no error
  message at all.** Same class of failure as the build_runner incident but
  *quieter*. It is also a raw SQL driver (no type safety, no migration story),
  a poor fit for a typed-layers scaffold. Healthy package, wrong default.
- **No `shared_preferences` *alongside* hive_ce** — and this is not a quality
  rejection: `2.5.5` (published 2026-03-25, `flutter/packages`, first-party) is
  **the lowest-risk dependency evaluated anywhere in this revision.** It is out
  because it is redundant with `hive_ce`: shipping both means two `KeyValueStore`
  implementations, two init paths, and a permanent "which one holds this
  setting?" question. **Scaffold the interface plus exactly ONE impl.** If a team
  prefers it over hive_ce, swap the impl — and use `SharedPreferencesAsync`, not
  `SharedPreferences.getInstance()`, which now lives in
  `shared_preferences_legacy.dart` (the filename is the maintainers' own
  verdict).
- **No `pretty_dio_logger`** (`1.4.0`, published 2024-07-21 — the stalest thing
  evaluated) — dio already ships `LogInterceptor`; the third-party dep buys only
  prettier box-drawing.
- **No `dio_smart_retry` by default** (`7.0.1`, published 2024-10-22, ~21 months
  stale) — it predates dio 5.10's `transformTimeout` and 5.11's interceptor
  Future fix, so its `retryEvaluator` has never been exercised against them; a
  ~50-line owned `RetryInterceptor` ships instead. **Whichever is used, the
  idempotent-methods-only restriction is mandatory** — `dio_smart_retry`'s
  default table includes 500/502/503/504 and applies **regardless of method**,
  so a POST that timed out server-side *after committing* can be replayed and
  double-charge, **and its README does not warn about this.** Documented as the
  opt-out for teams who want the broad status table for free.
- **No `connectivity_plus` as a request gate** (`7.3.1`, published 2026-07-23 —
  well maintained, so **not** a quality rejection). Its own README forbids the
  proposed use verbatim: *"You should not rely on the current connectivity status
  to decide whether you can reliably make a network request."* An offline
  pre-check adds a race, a false-negative class, and a second code path, while
  `DioExceptionType.connectionError` reports ground truth. Defensible only as a
  presentation-layer offline banner.
- **No `google_fonts` as a scaffold dependency** (`8.2.0`, published 2026-07-15;
  resolved live with **zero analyzer pressure**, so again not a compatibility
  rejection). Out because its default behaviour is a **runtime HTTP fetch** of
  the font binary — first paint becomes network-dependent and an offline first
  launch renders the fallback face — and because **a scaffold has no business
  choosing the product's brand typeface.** `app_typography.dart` ships one
  identity hook so adopting a font later is a one-file change. If a team does
  adopt it: bundle the `.ttf` under `assets/fonts/` **and** set
  `GoogleFonts.config.allowRuntimeFetching = false` in bootstrap so a missing
  asset fails loudly in dev instead of silently hitting the network in
  production.
- **No `flutter_animate`** (`4.5.2`, published 2024-11-25, 20 months stale; its
  only non-SDK dep `flutter_shaders` is itself 0.x and 22 months stale). **It
  was smoke-tested on 3.41.6 and is not broken** — it is out because the
  framework already covers this scaffold's entire motion vocabulary
  (`AnimatedSwitcher`, `AnimatedSize`, `AnimatedOpacity`, `Durations`, `Easing`),
  proven by a reference implementation at 0 analyzer issues and 14/14 tests.
  Adopting it plants a 0.x, 22-month-stale shader package under every generated
  app.
- **No `flutter_svg` in the default pubspec** (`2.3.0`, published 2026-05-08;
  resolved and smoke-tested live) — **adopt it the moment a real brand mark
  lands**: one asset instead of 1x/2x/3x, and tintable from `ColorScheme` via
  `colorFilter: ColorFilter.mode(scheme.primary, BlendMode.srcIn)` so it
  survives dark mode with no second file. **Still reject it for icons** — the
  Material icon font is already enabled and `Icons.*` are const and tree-shaken.
  Note its transitive `http ^1.0.0`, used only by `SvgPicture.network`, which
  this scaffold must not use.
- **No `path_provider` declared directly** — it arrives transitively via
  `hive_ce_flutter`. `ASSUMPTION:` its own pubspec constraints were **not**
  fetched; it resolved cleanly under Dart 3.11.4, which suffices for the
  transitive verdict but is not a verified reading of its declared range. Fetch
  `pub.dev/api/packages/path_provider` before quoting any constraint.
- **No Mockito** — `mocktail` is the settled mocking choice; same "surveyed
  once, not open for re-litigation per feature" status as the state-management
  cut list.
- **No `custom_lint`/`solid_lints`** — both were independently confirmed broken
  (most pub.dev health checks failing, their own `dart analyze` failing) at
  the time of the design pass that produced this plugin; recommending either
  now would be reintroducing a rejected finding, not a fresh recommendation.
- **No `golden_toolkit`/`dart_code_metrics`** (both discontinued) and no
  `alchemist`+`patrol` stacked together in one bootstrap pass (three testing
  systems before a single test exists is the wrong order of operations) —
  test tooling choices belong to `flutter-verify`, and that skill keeps
  `bloc_test`/`mocktail` as the only required test dependencies here.
