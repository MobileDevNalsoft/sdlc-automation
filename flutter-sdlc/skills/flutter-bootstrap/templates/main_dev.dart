// lib/main_dev.dart
//
// Entrypoint for the `dev` flavor. Run/build with:
//   flutter run    --flavor dev    --target lib/main_dev.dart --dart-define-from-file=config/dev.json
//   flutter build apk --flavor dev --target lib/main_dev.dart --dart-define-from-file=config/dev.json
//
// `--flavor dev` selects the matching Android product flavor (see
// flutter-ship's SKILL.md for the Gradle side of this); `--target` picks this
// entrypoint; `--dart-define-from-file` injects the flavor's config values
// (see flutter-ship for that file's shape). This project's own filenames
// (`main_dev.dart` / `main_staging.dart` / `main_prod.dart`) are a naming
// choice, not a Flutter requirement — any name works as long as `--target`
// matches it consistently across `run`/`build` and CI.

import 'bootstrap.dart';

void main() {
  FlavorConfig.current = const FlavorConfig(
    flavor: Flavor.dev,
    // ASSUMPTION: placeholder host — no real target-project API host was
    // available this session. Replace with the actual dev backend origin.
    apiBaseUrl: 'https://dev.api.example.internal',
    // Empty on purpose: the dev flavor is developers' own local/debug builds,
    // not a channel real users hit, so there is no field-crash visibility
    // need that justifies a DSN here. staging/prod each get their own.
    sentryDsn: '',
  );

  bootstrap((dependencies) => PlaceholderApp(dependencies: dependencies));
}
