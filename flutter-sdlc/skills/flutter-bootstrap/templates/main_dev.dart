// lib/main_dev.dart
//
// TEMPLATE — copy to lib/main_dev.dart and replace the placeholder package
// name `my_app` in the three imports below with your own package name (the
// `name:` field of pubspec.yaml).
//
// WHAT THIS IS
// The `dev` flavor entrypoint. It does exactly two things: build the one
// `const FlavorConfig` describing this flavor, and hand it to `bootstrap()`.
// Ordering, storage init, DI registration and crash reporting all live in
// lib/bootstrap.dart — deliberately, so that adding a fourth flavor is a copy
// of this short file and nothing else.
//
// HOW TO RUN AND BUILD IT
//   flutter run \
//     --flavor dev \
//     --target lib/main_dev.dart \
//     --dart-define-from-file=config/dev.json
//
//   flutter build apk \
//     --flavor dev \
//     --target lib/main_dev.dart \
//     --dart-define-from-file=config/dev.json
//
// `--flavor dev` selects the matching Android product flavor (flutter-ship's
// SKILL.md covers the Gradle side); `--target` picks this entrypoint file;
// `--dart-define-from-file` injects the flavor's config values (again see
// flutter-ship for that file's shape).
//
// THE TWO SWITCHES ARE INDEPENDENT, AND THAT IS A TRAP.
// `--flavor prod --target lib/main_dev.dart` is a perfectly valid command
// line: it produces a production-signed, production-named build that talks to
// the dev backend. Nothing in Flutter cross-checks them. Put the pairing in
// CI or in a Makefile rather than in a human's memory.
//
// This project's filenames (`main_dev.dart` / `main_staging.dart` /
// `main_prod.dart`) are a naming choice, not a Flutter requirement — any name
// works as long as `--target` matches it consistently across run, build and
// CI.
//
// WHY `Future<void> main() async` AND NOT `void main()`
// `bootstrap` is async and must be awaited. A bare `bootstrap(...)` inside a
// `void main()` trips `discarded_futures`, and more importantly it leaves an
// error thrown during startup with nowhere to surface — the process carries
// on into `runApp` as if initialisation had succeeded.

import 'package:my_app/app/app.dart';
import 'package:my_app/bootstrap.dart';
import 'package:my_app/core/config/flavor_config.dart';

/// Entrypoint for the `dev` flavor.
Future<void> main() async {
  await bootstrap(
    const FlavorConfig(
      flavor: Flavor.dev,
      // ASSUMPTION: placeholder product name — no real target-project app
      // name was available when this template was written. The "(dev)"
      // suffix is the point: it is what distinguishes this build in the
      // task switcher and on the home screen when a developer has two
      // flavors installed side by side.
      appName: 'My App (dev)',
      // ASSUMPTION: placeholder host — no real target-project API host was
      // available when this template was written. Replace with the actual
      // dev backend origin (scheme + host, no trailing slash; the trailing
      // slash matters because dio joins it with a leading-slash path).
      apiBaseUrl: 'https://dev.api.example.internal',
      // Empty on purpose, and this is a decision rather than a TODO: the dev
      // flavor is developers' own local/debug builds, not a channel real
      // users hit, so there is no field-crash visibility need that justifies
      // a DSN — and no reason to spend quota on crashes whose author is
      // sitting in front of the stack trace. staging and prod each get their
      // own. `SentryFlutter.init` with an empty DSN disables reporting
      // rather than failing, so bootstrap needs no special case for this.
      sentryDsn: '',
    ),
    // A closure rather than the `App.new` tear-off. To be accurate about
    // why, because the obvious reason is wrong: `App.new` DOES type-check
    // here. Its type is `App Function({Key? key})`, and a subtype may add
    // optional named parameters the supertype lacks, so it is assignable to
    // `Widget Function()`. Both forms were compiled on Dart 3.11.4 on
    // 2026-07-31 and `dart analyze` reported no issues for either — in
    // particular `unnecessary_lambdas` does NOT flag this closure, which was
    // the real risk worth checking.
    //
    // The closure is preferred only because it keeps the instance `const`,
    // so the root widget is canonicalized rather than allocated. Use
    // `App.new` if you prefer it; nothing breaks.
    () => const App(),
  );
}
