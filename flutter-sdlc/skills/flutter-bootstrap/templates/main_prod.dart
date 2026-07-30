// lib/main_prod.dart
//
// Entrypoint for the `prod` flavor. Run/build with:
//   flutter run    --flavor prod    --target lib/main_prod.dart --dart-define-from-file=config/prod.json
//   flutter build apk --flavor prod --target lib/main_prod.dart --dart-define-from-file=config/prod.json --obfuscate --split-debug-info=build/symbols
//
// See main_dev.dart's header comment for the general --flavor/--target/
// --dart-define-from-file pattern. Production builds additionally pass
// --obfuscate --split-debug-info (see flutter-ship's SKILL.md) — the SYMBOLS
// directory that produces must be uploaded to Sentry so obfuscated stack
// traces from real users can be de-obfuscated later.

import 'bootstrap.dart';

void main() {
  FlavorConfig.current = const FlavorConfig(
    flavor: Flavor.prod,
    // ASSUMPTION: placeholder host — replace with the real production origin.
    apiBaseUrl: 'https://api.example.com',
    // ASSUMPTION: placeholder DSN — must be a distinct Sentry project (or at
    // minimum a distinct DSN/environment tag) from staging's, so production
    // alerting isn't diluted by pre-release noise.
    sentryDsn: 'https://REPLACE-WITH-PROD-DSN@o0.ingest.sentry.io/0',
  );

  bootstrap((dependencies) => PlaceholderApp(dependencies: dependencies));
}
