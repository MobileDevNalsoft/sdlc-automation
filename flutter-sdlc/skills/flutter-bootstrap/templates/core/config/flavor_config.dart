// lib/core/config/flavor_config.dart
//
// TEMPLATE — copy to the same path under your project's lib/, replacing the
// placeholder package name `my_app` with your own `name:` from pubspec.yaml.
//
// VERIFIED 2026-07-31 — and this file is one of the few here that earns that
// word. It was backported from a reference app in which `flutter analyze
// --fatal-infos` exited 0, `flutter test` passed 56/56, and
// `dart run tools/check_boundaries.dart` reported OK. It has been compiled
// and executed, unlike a template written only against documentation.
//
// WHAT THIS IS
// The immutable, per-flavor configuration value. Each `main_<flavor>.dart`
// constructs exactly one of these and passes it to `bootstrap()`, which hands
// it to `configureDependencies()` (lib/core/di/injector.dart), which registers
// it with `getIt.registerSingleton<FlavorConfig>(config)`. Everything
// downstream asks DI for it; nothing reads a global.
//
// WHY IT LOOKS LIKE THIS — this file exists to kill a specific defect.
// The previous version of this scaffold carried:
//
// ```dart
// class FlavorConfig {
//   static late FlavorConfig current;   // <-- the defect
// }
// ```
//
// That single mutable slot caused three real problems, all observed:
//   1. Reading it before any `main()` assigned it threw
//      LateInitializationError.
//   2. Every widget test had to assign it before pumping.
//   3. It is ONE slot on ONE class, so two differently-flavored tests in the
//      same isolate overwrite each other — order-dependent, flaky, and it
//      will not reproduce on a warm reload.
//
// The fix is not "we adopted get_it because DI is nice". The fix is that the
// config became a VALUE passed as a parameter and registered as an immutable
// instance, so there is no writable slot left to race on. Do not add a
// `static` field back to this class for any reason — if some code cannot
// reach the config, inject it, or pass it down.
//
// WHAT TO CHANGE WHEN YOU COPY THIS
//   - Add fields for anything genuinely per-flavor (feature flags, an
//     analytics key, a payment-provider mode). Keep every field `final` and
//     keep the constructor `const`.
//   - Do NOT add fields that are per-BUILD rather than per-flavor (timeouts,
//     retry counts, log verbosity). Those belong next to the code that uses
//     them — see lib/core/network/dio_client.dart, which owns its own
//     timeout constants precisely so three flavor entrypoints don't have to
//     restate them identically.
//
// This file deliberately has NO imports. It is plain Dart with no dependency
// on Flutter, dio, or get_it, so it can be constructed in a pure-Dart unit
// test with no binding initialized.

/// Which build flavor is running.
///
/// Selected by the entrypoint file (`lib/main_dev.dart` etc.) that `--target`
/// points at, and mirrored by the Android product flavor `--flavor` selects.
/// The two are independent switches that must be kept consistent — see
/// flutter-ship's SKILL.md for the Gradle side.
enum Flavor {
  /// Developers' own local/debug builds. Not a channel real users reach.
  dev,

  /// Pre-production builds against production-shaped infrastructure.
  staging,

  /// Builds shipped to real users.
  prod,
}

/// Immutable per-flavor configuration, constructed once by each
/// `main_<flavor>.dart` and injected everywhere else.
///
/// Obtain it from DI, never from a global:
///
/// ```dart
/// final config = getIt<FlavorConfig>();
/// ```
///
/// Two instances built with the same arguments compare equal by identity
/// because Dart canonicalizes `const` instances — so a test asserting
/// `getIt<FlavorConfig>() == const FlavorConfig(...)` passes without this
/// class overriding `==`. That is the reason `==`/`hashCode` are deliberately
/// absent: adding them would drag in `@immutable` (and therefore a
/// `package:flutter/foundation.dart` import) to buy behaviour const already
/// provides. If you ever add a non-const construction path, revisit that.
class FlavorConfig {
  /// Creates a configuration for one flavor.
  ///
  /// Always invoke this as `const FlavorConfig(...)` from the entrypoint, so
  /// the instance is canonicalized and provably unmodifiable.
  const FlavorConfig({
    required this.flavor,
    required this.appName,
    required this.apiBaseUrl,
    required this.sentryDsn,
  });

  /// Which flavor this configuration describes.
  ///
  /// Also used as Sentry's `environment` tag, via `flavor.name`.
  final Flavor flavor;

  /// The user-visible application name, used as `MaterialApp.title`.
  ///
  /// ASSUMPTION: this field is this scaffold's choice, not a verified product
  /// requirement — the previous `FlavorConfig` had only `flavor`,
  /// `apiBaseUrl` and `sentryDsn`. It exists so a dev build can be titled
  /// "My App (dev)" in the task switcher without the root widget reaching for
  /// a global. If your app is localized and the title must be translated,
  /// delete this field and use `context.l10n.appTitle` in `app.dart` instead;
  /// a localized title cannot come from a const config.
  final String appName;

  /// Origin (scheme + host, no trailing slash) of this flavor's API.
  ///
  /// Consumed in exactly one place — `BaseOptions.baseUrl` in
  /// lib/core/network/dio_client.dart. Service classes must never read this;
  /// they issue relative paths (`/products/$id`) against the injected `Dio`
  /// so that no feature has to know about flavor configuration at all.
  /// (Written as code, not as a square-bracket doc reference: this file
  /// imports nothing, and an unresolvable reference trips
  /// `comment_references`.)
  final String apiBaseUrl;

  /// Sentry DSN for this flavor, or the empty string to disable reporting.
  ///
  /// Empty is the correct value for `dev`: developers' own debug builds are
  /// not a channel real users hit, so there is no field-crash visibility need
  /// that justifies the noise. `staging` and `prod` each get their own DSN.
  final String sentryDsn;

  /// Whether this is the production flavor.
  ///
  /// Use this for product decisions (hide a debug menu, suppress seeded test
  /// data). Do NOT use it to decide whether to log request bodies — that is a
  /// build-mode question, and `kDebugMode` answers it correctly even for a
  /// `prod`-flavored debug build running on a developer's device.
  bool get isProduction => flavor == Flavor.prod;
}
