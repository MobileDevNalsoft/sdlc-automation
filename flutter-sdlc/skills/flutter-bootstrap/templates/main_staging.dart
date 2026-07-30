// lib/main_staging.dart
//
// Entrypoint for the `staging` flavor. Run/build with:
//   flutter run    --flavor staging    --target lib/main_staging.dart --dart-define-from-file=config/staging.json
//   flutter build apk --flavor staging --target lib/main_staging.dart --dart-define-from-file=config/staging.json
//
// See main_dev.dart's header comment for the general --flavor/--target/
// --dart-define-from-file pattern; this file only differs in the values it
// passes to FlavorConfig.

import 'bootstrap.dart';

void main() {
  FlavorConfig.current = const FlavorConfig(
    flavor: Flavor.staging,
    // ASSUMPTION: placeholder host — replace with the real staging origin.
    apiBaseUrl: 'https://staging.api.example.internal',
    // ASSUMPTION: placeholder DSN. Staging is the first flavor that should
    // actually report to Sentry (it's where crashes get caught before prod),
    // so this must be a real per-flavor Sentry project DSN before shipping —
    // not the same DSN as prod, so staging noise doesn't pollute prod alerts.
    sentryDsn: 'https://REPLACE-WITH-STAGING-DSN@o0.ingest.sentry.io/0',
  );

  bootstrap((dependencies) => PlaceholderApp(dependencies: dependencies));
}
