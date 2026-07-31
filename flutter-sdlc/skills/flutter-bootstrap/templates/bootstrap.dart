// lib/bootstrap.dart
//
// TEMPLATE — copy to lib/bootstrap.dart and replace the placeholder package
// name `my_app` in the two project imports below with your own package name
// (the `name:` field of pubspec.yaml). Nothing else in this file is
// project-specific except the Sentry sample rate.
//
// WHAT THIS IS
// The single async startup sequence. Every `main_<flavor>.dart` is three
// lines: build a `const FlavorConfig`, hand it to [bootstrap], done. This
// file owns the ORDER those steps happen in; it owns no flavor knowledge and
// no dependency knowledge of its own.
//
// ---------------------------------------------------------------------------
// THE ORDER, AND WHY EACH STEP IS WHERE IT IS
// ---------------------------------------------------------------------------
// 1. `WidgetsFlutterBinding.ensureInitialized()` — the binding must exist
//    before any platform channel is touched. `configureDependencies` also
//    calls this (see lib/core/di/injector.dart, phase 0) and the duplication
//    is deliberate, not an oversight: the call is idempotent (it returns the
//    already-created binding), and having it here means this file reads as a
//    complete startup sequence rather than one that silently depends on a
//    callee to initialise the framework.
//
// 2 + 3. `await configureDependencies(config)` — storage init AND DI
//    registration, in that order, inside one awaited call.
//
//    NOTE, because this looks like a missing step: there is no separate
//    "storage init" line in this file. Opening a hive_ce box is phase 1-2 of
//    `configureDependencies`, immediately before the registrations that
//    consume the open box (phase 4). That is not a shortcut — it is the whole
//    reason `configureDependencies` is async and phased. Registering a store
//    before its `await` completes creates a race where the first read beats
//    the open: an intermittent failure that will not reproduce on a warm
//    reload, because by then the box is already open. Keeping the open and
//    the registration adjacent inside one function is what makes that
//    ordering impossible to break by editing this file. It also keeps every
//    `package:hive_ce_flutter` import out of bootstrap, so a team that swaps
//    the KeyValueStore backend for shared_preferences edits ONE file.
//
//    Do NOT add `await Hive.initFlutter()` here as well. Opening the same box
//    twice throws `HiveError('The box "settings" is already open ...')`.
//
//    `configureDependencies` ends with `await getIt.allReady()`, so there is
//    no `allReady` call here either.
//
// 4. `Bloc.observer = const AppBlocObserver()` — the load-bearing half of
//    this step is that it happens BEFORE `runApp`: the observer must be in
//    place before the first widget builds the first Cubit, or the app's
//    opening transitions are invisible to logging and to Sentry.
//
//    KNOWN GAP, stated rather than hidden: it happens AFTER
//    `configureDependencies`, and `configureDependencies` phase 12 awaits
//    `getIt<AuthCubit>().restoreSession()` once the auth slice lands. Those
//    session-restore transitions therefore run unobserved. If you want them
//    observed, move this line above `configureDependencies` — it is a bare
//    assignment with no prerequisites, so that is safe. It is left here to
//    match the documented startup order, and because the transitions in
//    question would be reported to a Sentry that is not initialised until
//    step 5 anyway.
//
// 5. `SentryFlutter.init(..., appRunner: () => runApp(...))` — last, because
//    `appRunner` IS `runApp`. Anything that must happen before the first
//    frame has to be above this call.
//
// ---------------------------------------------------------------------------
// WHY THERE IS NO `runZonedGuarded` HERE — a deliberate decision, kept
// ---------------------------------------------------------------------------
// Checked against getsentry/sentry-dart `packages/flutter/README.md` ("Usage"
// section) on 2026-07-29: on Flutter >= 3.3 the Sentry SDK already hooks
// `PlatformDispatcher.onError` itself. Wrapping `appRunner` in a second,
// manual `runZonedGuarded` is unnecessary and is a known source of
// zone-mismatch bugs (the zone `runApp` runs in stops matching the zone the
// binding was initialised in). This file therefore deliberately does NOT add
// one. Verified toolchain for this template: Flutter 3.41.6 / Dart 3.11.4,
// 2026-07-30 — comfortably past the 3.3 threshold. (An earlier revision of
// this header claimed "this project pins 3.44.8"; that was wrong against the
// installed SDK and is corrected here.)
//
// `SentryOptions.environment` (String?), `tracesSampleRate` (double?) and
// `dsn` were line-checked against getsentry/sentry-dart
// `packages/dart/lib/src/sentry_options.dart` on 2026-07-29, not written from
// memory. sentry_flutter is pinned at 9.25.0 (fetched from the pub.dev API
// 2026-07-29).
//
// ---------------------------------------------------------------------------
// WHAT THIS FILE USED TO CONTAIN, AND WHY IT DOESN'T ANY MORE
// ---------------------------------------------------------------------------
// Three things were deleted. If you are migrating a project scaffolded from
// an older version of this template, all three are breaking:
//
//   - `enum Flavor` and `class FlavorConfig`, which carried
//     `static late FlavorConfig current;`. THAT STATIC WAS A REAL DEFECT:
//     reading it before assignment threw LateInitializationError, every
//     widget test had to assign it before pumping, and because it is ONE
//     mutable slot on ONE class, two differently-flavored tests in the same
//     isolate overwrote each other. Both types now live in
//     lib/core/config/flavor_config.dart WITHOUT the static, and the config
//     is obtained from `getIt<FlavorConfig>()` or passed as a parameter.
//
//   - `class AppDependencies`, the hand-written parameter bag threaded down
//     the widget tree. get_it replaces it (lib/core/di/injector.dart). To be
//     precise about what changed and what did not: CODEGEN DI is still
//     rejected — `injectable`/`injectable_generator` are out on policy and,
//     as of 2026-07-30, on arithmetic too (`injectable_generator 3.1.1`
//     declares `analyzer >=13.0.0` and `sdk >=3.12.0`, both unsatisfiable
//     under freezed 3.2.5's `analyzer <11.0.0` and Dart 3.11.4). What the
//     old comment here got wrong was conflating "no codegen DI" with "no
//     service locator". Registration is hand-written; only the container is
//     a package.
//
//   - `class PlaceholderApp`. Its own doc comment said to replace it once a
//     real app root landed. lib/app/app.dart now ships WITH the scaffold, so
//     the throwaway has no reason to exist. A project scaffolded from the old
//     template very likely has a `test/widget_test.dart` that pumps
//     `PlaceholderApp` — that test must be retargeted at `App` in the same
//     commit, or the migration does not compile.
//
// Consequently `bootstrap`'s signature changed from
// `bootstrap(Widget Function(AppDependencies) builder)` to
// `bootstrap(FlavorConfig config, Widget Function() builder)`. The builder no
// longer receives dependencies because there is nothing to hand it: the root
// widget resolves what it needs from `getIt` itself.

import 'dart:async';

import 'package:bloc/bloc.dart'; // bloc@9.2.1
import 'package:flutter/widgets.dart';
import 'package:my_app/core/config/flavor_config.dart';
import 'package:my_app/core/di/injector.dart';
import 'package:sentry_flutter/sentry_flutter.dart'; // sentry_flutter@9.25.0

/// Logs every bloc/cubit state transition and forwards uncaught bloc/cubit
/// errors to Sentry.
///
/// Installed once by [bootstrap] via `Bloc.observer = const
/// AppBlocObserver();`, before `appRunner` runs, so no transition is missed.
class AppBlocObserver extends BlocObserver {
  /// Creates the observer. `const` so installing it allocates nothing.
  const AppBlocObserver();

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    // debugPrint, not `print` (which trips `avoid_print`) and not a logging
    // package — bootstrap stays free of dependencies the app has not chosen.
    // Swap for a real structured logger once the target project picks one;
    // that choice is out of scope for this scaffold.
    //
    // This fires on EVERY state change, including in release builds. If a
    // Cubit's state is large or holds anything sensitive, gate this on
    // `kDebugMode` (from package:flutter/foundation.dart) before shipping.
    debugPrint('${bloc.runtimeType} $change');
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    // `unawaited` rather than a bare call: `captureException` returns a
    // Future, this override is synchronous, and a discarded future is exactly
    // what `discarded_futures` flags. Fire-and-forget is the intended
    // behaviour — an observer must never block a state transition on a
    // network round-trip to Sentry — so the intent is stated rather than the
    // lint suppressed.
    unawaited(Sentry.captureException(error, stackTrace: stackTrace));
    super.onError(bloc, error, stackTrace);
  }
}

/// Starts the app. Call exactly once, from a flavor entrypoint's `main()`.
///
/// [config] is the `const FlavorConfig` that entrypoint built; it is passed
/// to `configureDependencies` and registered as an immutable singleton, which
/// is what replaced the old mutable `FlavorConfig.current` static.
///
/// [builder] returns the root widget and takes no arguments — the root
/// resolves its own dependencies from `getIt`. In the shipped scaffold this
/// is `() => const App()`.
///
/// Awaiting the returned future is required in `main()`; `void main()` with a
/// bare call trips `discarded_futures` and, worse, means an unhandled error
/// during startup has nowhere to surface.
Future<void> bootstrap(
  FlavorConfig config,
  Widget Function() builder,
) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Storage init happens inside this call, before the registrations that
  // depend on it. See the ORDER section in this file's header before adding
  // anything between these two lines.
  await configureDependencies(config);

  Bloc.observer = const AppBlocObserver();

  await SentryFlutter.init(
    (options) {
      // A cascade, not three `options.x = y` statements: repeated method or
      // setter access on the same target is what `cascade_invocations` flags,
      // and it was one of the pre-existing analyze findings in this file.
      options
        ..dsn = config.sentryDsn
        ..environment = config.flavor.name
        // ASSUMPTION: 0.2 is a placeholder trace-sampling rate, not sized
        // against any real traffic or cost figures — no target project's
        // traffic volume was available when this template was written.
        // Revisit once real usage data exists. Sampling at 1.0 in production
        // is usually cost-prohibitive at scale, and this scaffold would
        // rather under-sample by default than surprise a team with a bill.
        ..tracesSampleRate = 0.2;
    },
    // `appRunner` is where `runApp` goes. Sentry installs its error handling
    // around it, which is the whole reason this is the last step.
    appRunner: () => runApp(builder()),
  );
}
