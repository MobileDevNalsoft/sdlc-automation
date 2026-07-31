// lib/core/theme/app_colors.dart
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
// The ONLY file in the whole app that is allowed to write a colour literal.
// Everything else — every widget, every theme sub-component, every feature —
// reads a role off `ColorScheme` (`scheme.primary`, `scheme.errorContainer`,
// …) or a semantic token off `AppTokens` (`tokens.success`). Grep the repo for
// `Color(0x` and this file should be the only hit outside generated code.
//
// WHY IT IS A SEPARATE FILE FROM app_theme.dart
// The architecture spec put `static const Color seed` on `AppTheme` itself.
// Splitting it out costs nothing and buys one thing that matters: the rule
// "no file may name a colour" becomes checkable with a one-line grep and a
// single-path exemption, instead of "no file except the 120-line theme
// builder may name a colour, and reviewers must eyeball which of its lines
// are legitimate". `AppTheme.seed` is kept as an alias so code written
// against the spec's shape still compiles.
//
// WHY THERE ARE SO FEW COLOURS HERE
// `ColorScheme.fromSeed` derives roughly 45 colour roles from `seed` using
// Material 3's tonal-palette maths — primary, secondary, tertiary, every
// surface tier, error, and each matching `on-` foreground, for BOTH
// brightnesses. Adding a hand-picked colour for something the scheme already
// models is how an app ends up with three slightly different blues. Only add
// a constant here when Material genuinely does not model the concept.
//
// It models exactly two things that Material does not: SUCCESS and WARNING.
// `ColorScheme` has `error`/`onError`/`errorContainer`/`onErrorContainer` and
// nothing for "that worked" or "careful". Those four pairs live here, are
// carried on `AppTokens`, and exist precisely so a feature cannot invent its
// own green.
//
// WHAT TO CHANGE WHEN YOU COPY THIS
//   1. Replace [AppColors.seed] with the product's real brand colour. That is
//      normally the ONLY edit this file ever needs.
//   2. After changing the seed, RE-RUN test/a11y_test.dart. The seeded
//      schemes shipped with this scaffold were verified to pass Flutter's
//      `textContrastGuideline` (WCAG 2.0 AA) in both brightnesses for THIS
//      seed. That is a property of this seed, not a guarantee of
//      `ColorScheme.fromSeed` — a light or very desaturated brand colour can
//      and does produce failing `on-` pairs.
//   3. Do NOT add a `Color` here to "just tweak one screen". A one-screen
//      colour is a design-system bug; either the scheme role is wrong for the
//      whole app, or the screen is wrong.

import 'package:flutter/material.dart';

/// Every colour literal in the app, in one place.
///
/// `abstract final` so it can be neither instantiated nor subclassed: this is
/// a namespace for constants, not a type anything should hold a value of.
///
/// The light/dark pairs below are hand-picked rather than seed-derived
/// because Material 3 does not model success or warning as colour roles.
/// Each pair is stated as a container colour plus the foreground drawn on it,
/// mirroring how `ColorScheme` names `error`/`onError`, so switching between
/// a scheme role and a token at a call site never changes the idiom.
abstract final class AppColors {
  /// The single brand colour every `ColorScheme` in the app is derived from.
  ///
  /// Passed to `ColorScheme.fromSeed(seedColor: …)` once per brightness in
  /// the app theme. Changing this one value re-derives the entire palette,
  /// light and dark, which is the whole reason a seed exists.
  ///
  /// This particular blue is the scaffold's placeholder brand colour, chosen
  /// because its seeded light and dark schemes were verified to pass
  /// Flutter's WCAG AA contrast guideline. Replace it with the real brand
  /// colour and re-run test/a11y_test.dart.
  static const Color seed = Color(0xFF2F5BEA);

  /// Container colour for a success state, light theme.
  ///
  /// A deep green so white foreground text clears AA on it.
  static const Color successLight = Color(0xFF1B6B3A);

  /// Foreground drawn on [successLight].
  static const Color onSuccessLight = Color(0xFFFFFFFF);

  /// Container colour for a success state, dark theme.
  ///
  /// Light and desaturated, following the same inversion Material applies to
  /// its own error roles: a dark surface needs a light accent, not the same
  /// accent at the same luminance.
  static const Color successDark = Color(0xFF7BDCA0);

  /// Foreground drawn on [successDark].
  static const Color onSuccessDark = Color(0xFF00391A);

  /// Container colour for a non-fatal warning state, light theme.
  ///
  /// Deliberately an amber/brown rather than a bright yellow — bright yellow
  /// cannot carry legible dark text OR legible light text, which is why
  /// "yellow warning" banners are so often unreadable.
  static const Color warningLight = Color(0xFF8A5300);

  /// Foreground drawn on [warningLight].
  static const Color onWarningLight = Color(0xFFFFFFFF);

  /// Container colour for a non-fatal warning state, dark theme.
  static const Color warningDark = Color(0xFFFFC46B);

  /// Foreground drawn on [warningDark].
  static const Color onWarningDark = Color(0xFF452B00);
}

// ASSUMPTION: the four success/warning pairs above have NOT been measured
// against WCAG 2.0 AA (4.5:1 for normal text) this session. The scaffold's
// a11y test verified the SEEDED scheme roles and the error-container pair
// that the login exemplar actually renders; no shipped screen renders a
// success or warning surface yet, so no guideline assertion has touched
// these. They are chosen to be high-contrast by construction (near-black or
// near-white foreground on a mid-dark or light container) but that is design
// judgement, not a measurement. The first screen that uses `tokens.success`
// should be added to test/a11y_test.dart in the same commit, which converts
// this assumption into a verified fact for free.
