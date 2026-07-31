// lib/main_staging.dart
//
// TEMPLATE — copy to lib/main_staging.dart and replace the placeholder
// package name `my_app` in the three imports below with your own package
// name.
//
// WHAT THIS IS
// The `staging` flavor entrypoint. See main_dev.dart's header for the general
// --flavor / --target / --dart-define-from-file pattern, the warning that
// those two switches are independent and unchecked, and why `main` is
// `Future<void> ... async`. This file differs from main_dev.dart in nothing
// but the four values it passes to FlavorConfig.
//
// HOW TO RUN AND BUILD IT
//   flutter run \
//     --flavor staging \
//     --target lib/main_staging.dart \
//     --dart-define-from-file=config/staging.json
//
//   flutter build apk \
//     --flavor staging \
//     --target lib/main_staging.dart \
//     --dart-define-from-file=config/staging.json

import 'package:my_app/app/app.dart';
import 'package:my_app/bootstrap.dart';
import 'package:my_app/core/config/flavor_config.dart';

/// Entrypoint for the `staging` flavor.
Future<void> main() async {
  await bootstrap(
    const FlavorConfig(
      flavor: Flavor.staging,
      // ASSUMPTION: placeholder product name. Keep a visible suffix: a
      // staging build that is indistinguishable from prod on the home screen
      // is how bug reports get filed against the wrong environment.
      appName: 'My App (staging)',
      // ASSUMPTION: placeholder host — replace with the real staging origin
      // (scheme + host, no trailing slash).
      apiBaseUrl: 'https://staging.api.example.internal',
      // ASSUMPTION: placeholder DSN. Staging is the first flavor that should
      // actually report to Sentry — it is where crashes get caught before
      // prod — so this must be a real per-flavor Sentry DSN before shipping.
      // Deliberately NOT the same DSN as prod: staging noise would otherwise
      // pollute production alerting, which is the fastest way to teach a team
      // to ignore the alerts. bootstrap already tags every event with
      // `environment: 'staging'` from `flavor.name`, so even a shared DSN is
      // filterable — but separate projects keep the quota separate too.
      sentryDsn: 'https://REPLACE-WITH-STAGING-DSN@o0.ingest.sentry.io/0',
    ),
    // See main_dev.dart for why this is a closure rather than `App.new`.
    () => const App(),
  );
}
