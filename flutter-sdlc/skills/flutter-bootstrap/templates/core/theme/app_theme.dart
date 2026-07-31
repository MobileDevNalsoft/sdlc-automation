// lib/core/theme/app_theme.dart
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
// The app's single source of visual truth. It builds the two `ThemeData`
// objects the root widget hands to `MaterialApp` and nothing else in the app
// ever constructs one:
//
//     MaterialApp.router(
//       theme: AppTheme.light(),
//       darkTheme: AppTheme.dark(),
//       themeMode: ThemeMode.system,
//       …
//     )
//
// WHY THIS FILE EXISTS AT ALL — it fixes a specific, observed defect.
// The previous scaffold's root widget was `MaterialApp(...)` with NO `theme:`
// parameter. Everything therefore rendered in Flutter's stock Material 3
// baseline: the default purple-ish seeded palette, default component shapes,
// default everything. That is the root cause of "the UI doesn't look like a
// modern app" — not the individual screens. A screen built carefully on top
// of no theme still looks like a demo.
//
// TWO THINGS TO NOTICE ABOUT THE SHAPE OF THIS FILE
//
// 1. Both themes come from ONE seed via `ColorScheme.fromSeed`, which derives
//    ~45 colour roles (primary, secondary, tertiary, every surface tier,
//    error, and every matching `on-` foreground) using Material 3's
//    tonal-palette maths. Light and dark are the SAME function called with a
//    different `Brightness`. There is no second palette to keep in sync, and
//    "we'll do dark mode later" is not a project that exists.
//
// 2. Every component sub-theme is set HERE, once, so features inherit them
//    without opting in. This is the whole enforcement idea: a feature that
//    writes `FilledButton(onPressed: …, child: Text('Save'))` — or, better,
//    the `AppButton` wrapper — gets the 52dp height, the 12dp radius and the
//    `labelLarge` type automatically, because the theme already said so. A
//    design system that requires every screen to remember something has
//    already failed.
//
// `themeMode: ThemeMode.system` FROM DAY ONE IS NOT OPTIONAL.
// If dark mode is added after the first few features ship, those features
// will already contain `Colors.white`, `Colors.black87`, and a handful of
// hardcoded greys, and retrofitting is then a rewrite. Shipping both from the
// start means the dark scheme is exercised continuously and breakage is
// caught the day it lands.
//
// API-NAME GOTCHAS — verified by compiling against Flutter 3.41.6 on
// 2026-07-30. These are the exact names that trip up code written against
// older Flutter releases or from memory:
//   - `InputDecorationThemeData`, `CardThemeData`, `DialogThemeData` all take
//     the `…ThemeData` suffix,
//   - but it is still `AppBarTheme` (NO `Data` suffix) and
//     `SnackBarThemeData` (WITH one).
//   - `Color.withValues(alpha: …)`, NOT the deprecated `withOpacity`.
// A template written against the older names does not compile.
//
// WHAT TO CHANGE WHEN YOU COPY THIS
//   - The brand colour is NOT here. It is `AppColors.seed` in
//     lib/core/theme/app_colors.dart, which is the only file in the app
//     allowed to name a colour literal.
//   - Add a component sub-theme here the moment the second screen needs the
//     same look. The rule of thumb: if you are about to copy a `style:` or a
//     `shape:` from one widget to another, that is a sub-theme, not a copy.
//   - After ANY change here, re-run test/a11y_test.dart (contrast + tap
//     targets, both brightnesses) and test/theme_scale_test.dart (text
//     scaling at 1.0/1.3/2.0). Both are cheap and both have caught real
//     regressions in this exact code.

import 'package:flutter/material.dart';
import 'package:my_app/core/theme/app_colors.dart';
import 'package:my_app/core/theme/app_tokens.dart';
import 'package:my_app/core/theme/app_typography.dart';

/// The app's single source of visual truth.
///
/// `abstract final` so it can be neither instantiated nor subclassed — there
/// is exactly one theme, and a subclass would be a second one.
///
/// Features never construct a [ThemeData]. They read `Theme.of(context)`,
/// `Theme.of(context).colorScheme` and `Theme.of(context).tokens`.
abstract final class AppTheme {
  /// The one brand colour every scheme is derived from.
  ///
  /// An alias for [AppColors.seed], kept so call sites and documentation
  /// that reach for `AppTheme.seed` keep working. The value itself lives in
  /// lib/core/theme/app_colors.dart, which is the single file permitted to
  /// write a colour literal.
  static const Color seed = AppColors.seed;

  /// The light theme.
  static ThemeData light() => _build(Brightness.light);

  /// The dark theme.
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final isLight = brightness == Brightness.light;

    // The only brightness-dependent tokens. Everything structural (spacing,
    // radius, motion, elevation) is identical across brightnesses on
    // purpose — see AppTokens.standard.
    final tokens = AppTokens.standard(
      success: isLight ? AppColors.successLight : AppColors.successDark,
      onSuccess: isLight ? AppColors.onSuccessLight : AppColors.onSuccessDark,
      warning: isLight ? AppColors.warningLight : AppColors.warningDark,
      onWarning: isLight ? AppColors.onWarningLight : AppColors.onWarningDark,
    );

    // Built first so `base.textTheme` is the fully-resolved M3 scale with the
    // correct foreground colours already applied for this brightness. The
    // typography seam then runs on top of it, and the RESULT is what every
    // sub-theme below reads — so adopting a brand font also restyles the app
    // bar title and the button labels, with no second edit.
    final base = ThemeData(colorScheme: scheme, extensions: [tokens]);
    final textTheme = AppTypography.apply(base.textTheme);

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      // Material 3's ink ripple. The default splash differs by platform,
      // which makes an Android and an iOS build feel like two apps.
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        // Chrome-less by default: a flat bar the same colour as the surface,
        // with no tint on scroll. Features OPT IN to elevation; they never
        // inherit a grey bar they did not ask for. This single choice is
        // most of the difference between "stock Flutter demo" and
        // "considered app".
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: tokens.elevation.level0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // 52dp, not 48dp. `kMinInteractiveDimension` is 48.0
          // (material/constants.dart:27) and Android's accessibility minimum
          // is the same 48dp — so 48 is the FLOOR, not a target. The extra
          // 4dp is headroom for the 1.3x text-scale case, which is common
          // enough on real devices that designing exactly to the floor means
          // shipping under it.
          minimumSize: const Size.fromHeight(52),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(tokens.radius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(tokens.radius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          // Text buttons are not full-width, so they get the 48dp square
          // minimum rather than a stretched height.
          minimumSize: const Size(48, 48),
          textStyle: textTheme.labelLarge,
        ),
      ),
      // Note there is deliberately no `iconButtonTheme` here: Material's
      // IconButton already lays out at 48x48 (kMinInteractiveDimension), so
      // adding one would restate a default and invite drift.
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        // A soft fill instead of a hard outline is the current idiom and,
        // more usefully, it makes the field's tap target visible at rest.
        // Alpha rather than a fixed grey so it composites correctly over
        // both surfaces.
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(tokens.radius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(tokens.radius.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(tokens.radius.md),
          // A 2dp ring, not 1dp. This is the visible focus state that
          // keyboard, switch-control and external-keyboard users navigate
          // by; at 1dp it is easy to lose against the fill.
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(tokens.radius.md),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(tokens.radius.md),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: tokens.space.lg,
          vertical: tokens.space.lg,
        ),
      ),
      cardTheme: CardThemeData(
        // Flat, tonal cards. Material 3 separates surfaces with colour tiers
        // rather than shadows; a shadowed card on a tinted surface reads as
        // Material 2.
        elevation: tokens.elevation.level0,
        color: scheme.surfaceContainerLow,
        // Zero margin because the SCREEN owns spacing, via tokens. A card
        // that carries its own margin fights every layout it is placed in.
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(tokens.radius.lg),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        // Floating, not fixed: a fixed snackbar is pinned to the bottom edge
        // and collides with gesture navigation on modern Android.
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
        elevation: tokens.elevation.level3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(tokens.radius.md),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: tokens.elevation.level3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(tokens.radius.xl),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          // PredictiveBackPageTransitionsBuilder is what makes the Android
          // back GESTURE animate the outgoing route under the user's thumb,
          // the way native apps do. Without it the gesture works but the
          // screen only redraws once the gesture completes, which is the
          // single most recognisable "this is a Flutter app" tell.
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
