// lib/l10n/l10n.dart
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
// PATH MATTERS HERE: this template's destination is lib/l10n/l10n.dart,
// NOT lib/core/extensions/. Every screen and every routes file in the
// scaffold imports 'package:my_app/l10n/l10n.dart'. An earlier revision
// of this template shipped at core/extensions/build_context_l10n.dart;
// copying it there leaves every one of those imports unresolved. The
// file also sits beside lib/l10n/gen/ so the whole localization story
// lives in one directory.
//
// WHAT THIS IS
// The `context.l10n` accessor. Every user-visible string in the app is read
// through it:
//
//     Text(context.l10n.loginHeadline)
//
// WHY IT LOOKS LIKE THIS
//   - It returns a NON-NULLABLE AppL10n. That is `nullable-getter: false` in
//     l10n.yaml doing its job. Without it, the generated `AppL10n.of(context)`
//     returns `AppL10n?` and every one of hundreds of call sites needs a `!`
//     — and under very_good_analysis a bare `!` is a smell someone will
//     eventually "fix" into a `??` with a hard-coded English fallback, which
//     is how a localized app quietly stops being localized.
//   - It is an extension rather than a helper function so the call site reads
//     as a property of the context, and so the import is the only thing a
//     screen needs to know about localization.
//   - It is hand-written, not generated. It never needs regenerating, and it
//     is the one stable symbol screens depend on even if the generated class
//     name changes.
//
// WHERE THE STRINGS COME FROM
// lib/l10n/arb/app_en.arb -> `flutter gen-l10n` -> lib/l10n/gen/. The
// generated files are COMMITTED, deliberately: `flutter test` does not run
// gen-l10n, so a gitignored lib/l10n/gen/ means a fresh clone fails to
// compile until somebody runs the generator by hand, and flutter-verify would
// need a new pre-step ahead of both `analyze` and `test`. They carry
// `ignore_for_file: type=lint` and `// coverage:ignore-file` in their headers,
// so they pollute neither the analyze gate nor the coverage ratchet.
//
// WHAT TO CHANGE WHEN YOU COPY THIS
//   - The package name in the import. Nothing else. If you renamed
//     `output-class` in l10n.yaml, rename `AppL10n` here to match.

import 'package:flutter/widgets.dart';
import 'package:my_app/l10n/gen/app_localizations.dart';

/// Terse access to the app's localized strings.
extension L10nX on BuildContext {
  /// The nearest [AppL10n] instance.
  ///
  /// Non-nullable because l10n.yaml sets `nullable-getter: false`. It throws
  /// if there is no [AppL10n] above this context, which in practice means the
  /// delegates were not wired into `MaterialApp.router` — see
  /// `localizationsDelegates` in lib/app/app.dart. A widget test that pumps a
  /// bare widget without those delegates will hit this; give it
  /// `AppL10n.localizationsDelegates` and `AppL10n.supportedLocales` in the
  /// `MaterialApp` it pumps rather than avoiding `context.l10n` in tests.
  AppL10n get l10n => AppL10n.of(this);
}
