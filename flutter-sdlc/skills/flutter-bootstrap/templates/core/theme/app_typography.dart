// lib/core/theme/app_typography.dart
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
// The single seam through which the app's type scale passes. The theme
// builder calls `AppTypography.apply(base.textTheme)` exactly once per
// brightness; nothing else in the app constructs a `TextStyle` from scratch.
//
// WHY IT SHIPS AS THE IDENTITY FUNCTION
// This is the deliberate part, and it is worth stating plainly because an
// empty-looking file reads like an oversight:
//
//   A scaffold has no business choosing the product's typeface.
//
// The Material 3 `TextTheme` that `ThemeData` already builds is a complete,
// professionally-tuned 15-style scale (display/headline/title/body/label ×
// large/medium/small) with sizes, weights, line heights and letter spacing
// generated from Material's own token database. It is not a placeholder. An
// app that uses it unmodified looks *neutral*, not *unfinished* — what makes
// an app look unfinished is inconsistent type, which is exactly what this
// seam prevents.
//
// So the default is: change nothing, and make changing it a one-file edit.
//
// WHY NOT `google_fonts`
// The `google_fonts` package's default behaviour is to fetch the font binary
// over HTTP at runtime. That makes first paint network-dependent, renders the
// fallback face on a cold offline launch, and drags a `LicenseRegistry`
// obligation into a scaffold that cannot know the product's font. If a team
// adopts it, bundle the `.ttf` under `assets/fonts/` AND set
// `GoogleFonts.config.allowRuntimeFetching = false` in bootstrap, so a
// missing asset fails loudly in development instead of silently hitting the
// network in production.
//
// WHAT TO CHANGE WHEN YOU COPY THIS
// Adopting a brand typeface is a change to THIS FILE AND NOTHING ELSE.
// Declare the font in pubspec.yaml:
//
// ```yaml
// flutter:
//   fonts:
//     - family: Inter
//       fonts:
//         - asset: assets/fonts/Inter-Regular.ttf
//         - asset: assets/fonts/Inter-SemiBold.ttf
//           weight: 600
// ```
//
// then return `base.apply(fontFamily: 'Inter')` from [AppTypography.apply].
// `TextTheme.apply` rewrites every one of the 15 styles at once, which is why
// it is the right tool here: it is impossible to change 14 styles and forget
// the fifteenth.
//
// Per-style overrides belong here too, and should stay rare:
//
// ```dart
// static TextTheme apply(TextTheme base) {
//   final withFont = base.apply(fontFamily: 'Inter');
//   return withFont.copyWith(
//     // Tighten only the largest sizes: Material's default tracking is
//     // tuned for Roboto and reads loose on a geometric sans at display
//     // sizes. Body copy is left alone on purpose.
//     displayLarge: withFont.displayLarge?.copyWith(letterSpacing: -0.5),
//   );
// }
// ```
//
// WHAT NOT TO DO HERE
//   - Do not hardcode a `color:`. Colours come from `ColorScheme` roles, and
//     `ThemeData` has already applied the correct `bodyColor`/`displayColor`
//     for the brightness by the time [AppTypography.apply] is called.
//     Baking a colour in here is how a text style survives into dark mode
//     unreadable.
//   - Do not add sizes outside the 15-style scale. "One more size, just for
//     this screen" is how the scale stops meaning anything. If a screen needs
//     emphasis, it needs a different EXISTING style or a different colour
//     role, not a new number.

import 'package:flutter/material.dart';

/// The app's one type-scale hook.
///
/// `abstract final` so it can be neither instantiated nor subclassed: this is
/// a namespace for a single pure function, not a type.
abstract final class AppTypography {
  /// Returns the app's text theme, given the Material 3 [base] that
  /// `ThemeData` derived for the current brightness.
  ///
  /// Ships as the identity function: the scaffold makes no typeface claim.
  /// Adopt a brand font by editing this one method — see the header comment
  /// of this file for the pubspec declaration and the `TextTheme.apply`
  /// idiom.
  ///
  /// [base] already carries the correct foreground colours for its
  /// brightness, so implementations must preserve them (use `apply` and
  /// `copyWith`, never build a fresh `TextTheme`).
  static TextTheme apply(TextTheme base) => base;
}

// ASSUMPTION: the specific default typeface Flutter resolves for the Material
// 3 text theme (commonly stated as Roboto on Android) was NOT read out of the
// installed SDK this session. What WAS verified is the shape of the seam —
// `ThemeData.textTheme` is a `TextTheme` of 15 named styles and
// `TextTheme.apply(fontFamily: …)` rewrites all of them — which is the only
// claim this file actually depends on. Do not repeat a face name as fact in
// downstream docs without checking the SDK's typography.dart.
