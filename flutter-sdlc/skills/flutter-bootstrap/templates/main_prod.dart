// lib/main_prod.dart
//
// TEMPLATE — copy to lib/main_prod.dart and replace the placeholder package
// name `my_app` in the three imports below with your own package name.
//
// WHAT THIS IS
// The `prod` flavor entrypoint. See main_dev.dart's header for the general
// --flavor / --target / --dart-define-from-file pattern, the warning that
// those two switches are independent and unchecked, and why `main` is
// `Future<void> ... async`. This file differs from main_dev.dart in nothing
// but the four values it passes to FlavorConfig.
//
// HOW TO RUN AND BUILD IT
//   flutter run \
//     --flavor prod \
//     --target lib/main_prod.dart \
//     --dart-define-from-file=config/prod.json
//
//   flutter build apk \
//     --flavor prod \
//     --target lib/main_prod.dart \
//     --dart-define-from-file=config/prod.json \
//     --obfuscate \
//     --split-debug-info=build/symbols
//
// PRODUCTION BUILDS ADD --obfuscate --split-debug-info (flutter-ship's
// SKILL.md owns the full release procedure). The symbols directory that
// produces MUST be uploaded to Sentry, or every stack trace from a real user
// arrives as unreadable mangled names — and the symbols only exist on the
// machine that ran the build, so a CI job that does not upload them has
// destroyed them by the time anyone notices. Obfuscation without symbol
// upload is strictly worse than no obfuscation.

import 'package:my_app/app/app.dart';
import 'package:my_app/bootstrap.dart';
import 'package:my_app/core/config/flavor_config.dart';

/// Entrypoint for the `prod` flavor.
Future<void> main() async {
  await bootstrap(
    const FlavorConfig(
      flavor: Flavor.prod,
      // ASSUMPTION: placeholder product name — this is the only flavor whose
      // appName carries no environment suffix, because it is the one users
      // see. Note that `MaterialApp.title` is not the launcher label: the
      // home-screen name comes from android/app/src/main/AndroidManifest.xml
      // (and the per-flavor manifests / Gradle `resValue` entries), so both
      // have to be set.
      appName: 'My App',
      // ASSUMPTION: placeholder host — replace with the real production
      // origin (scheme + host, no trailing slash).
      apiBaseUrl: 'https://api.example.com',
      // ASSUMPTION: placeholder DSN — must be a distinct Sentry project from
      // staging's (or at minimum a distinct DSN), so production alerting is
      // not diluted by pre-release noise. `flavor.name` is already sent as
      // the `environment` tag by bootstrap, so events are distinguishable
      // either way; separate projects additionally keep the quota separate.
      sentryDsn: 'https://REPLACE-WITH-PROD-DSN@o0.ingest.sentry.io/0',
    ),
    // See main_dev.dart for why this is a closure rather than `App.new`.
    () => const App(),
  );
}
