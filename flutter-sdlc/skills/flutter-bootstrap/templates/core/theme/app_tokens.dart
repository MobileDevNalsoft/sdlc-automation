// lib/core/theme/app_tokens.dart
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
// The design tokens Material's own `ThemeData` does not model: a spacing
// scale, a corner-radius scale, motion (durations + curves + dwell times),
// an elevation scale, and the two semantic colour pairs Material 3 leaves
// out (success and warning). Read at any call site as:
//
//     final tokens = Theme.of(context).tokens;
//     SizedBox(height: tokens.space.lg)
//
// `Theme.of(context).tokens` is the canonical idiom; it is sugar for the raw
// `Theme.of(context).extension<AppTokens>()!`, provided by [AppTokensX] at
// the bottom of this file. A `context.tokens` shorthand lives separately in
// lib/core/extensions/build_context_x.dart so that this file stays free of
// any dependency on the extensions layer — if that file is not present in
// your copy of the scaffold, `Theme.of(context).tokens` works everywhere and
// nothing is missing.
//
// WHY A ThemeExtension AND NOT `class AppSpacing { static const lg = 16.0; }`
// A static-const class is a global. Three concrete consequences:
//   1. It cannot vary by brightness. Semantic colours must (a green that
//      reads on white is invisible on near-black), so they would need a
//      second mechanism anyway, and now the app has two.
//   2. It cannot be overridden per subtree. A white-label build, a "compact
//      density" section, or a golden test that wants a fixed scale all
//      require rebuilding the app, not wrapping a `Theme`.
//   3. It does not animate. `ThemeData` lerps its extensions on every theme
//      transition frame; a static never participates.
// Riding on `ThemeData` gets all three for free, at the cost of one
// `Theme.of(context)` lookup.
//
// VERIFIED API SURFACE (read from the installed SDK, Flutter 3.41.6, on
// 2026-07-30, at packages/flutter/lib/src/material/theme_data.dart):
//
//     abstract class ThemeExtension<T extends ThemeExtension<T>> {
//       const ThemeExtension();
//       Object get type => T;                        // line 136 — key IS the Type
//       ThemeExtension<T> copyWith();                // line 140
//       ThemeExtension<T> lerp(covariant ThemeExtension<T>? other, double t);
//     }
//
// and on `ThemeData` line 993: `T? extension<T>() => extensions[T] as T?;`
// — note it returns NULLABLE, and `_lerpThemeExtensions` (line 1794) calls
// your `lerp` on every theme-animation frame. Both facts drive the design
// below: `lerp` must be cheap and correct, and the accessor must decide what
// to do about null (see [AppTokensX], which throws).
//
// WHY THE SUB-SCALES ARE GETTERS, NOT `static const` FIELDS
// Getters keep `SpaceTokens`/`RadiusTokens`/`MotionTokens`/`ElevationTokens`
// `const`-constructible with no fields, which is what lets `AppTokens.
// standard` be a `const` constructor and keeps `prefer_const_constructors`
// satisfiable at every construction site. A `static const` member on those
// classes would be reachable without an instance and would reintroduce
// exactly the global this design exists to avoid.
//
// WHAT TO CHANGE WHEN YOU COPY THIS
//   - Adding a token is expected; RENAMING or REMOVING one is a breaking
//     change across every screen. Prefer adding.
//   - Keep the names short (`md`, not `medium`). `RoundedRectangleBorder(
//     borderRadius: BorderRadius.all(tokens.radius.md))` in the theme builder
//     already sits within a few characters of the 80-column limit that the
//     vendored very_good_analysis ruleset enforces.
//   - If you add a field to [AppTokens] you MUST extend BOTH [AppTokens
//     .copyWith] and [AppTokens.lerp]. `ThemeExtension` declares both as
//     abstract, so the compiler forces you to have them — but it cannot force
//     you to have handled the NEW field inside them. A field silently dropped
//     from `lerp` reverts to the old value for the duration of every theme
//     animation and then snaps: a genuinely baffling bug to chase.
//   - Do not add a token that Material already models. There is no `AppTokens
//     .primaryColor`; that is `ColorScheme.primary`.

import 'package:flutter/material.dart';

/// The design tokens Material's [ThemeData] does not model.
///
/// Installed once per brightness by the app theme builder via
/// `ThemeData(extensions: [tokens])`, and read anywhere as
/// `Theme.of(context).tokens` (see [AppTokensX]).
///
/// Feature code reads tokens instead of writing numbers. A screen containing
/// `SizedBox(height: 16)` has silently opted out of the design system: the
/// next spacing change will miss it, and nothing will report that it did.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  /// Creates a token set from explicit parts.
  ///
  /// Prefer [AppTokens.standard], which fixes the four structural scales and
  /// asks only for the brightness-dependent colours. This unnamed
  /// constructor exists mainly so [copyWith] and [lerp] can rebuild the
  /// object; a white-label build that genuinely needs a different radius
  /// scale is its other legitimate user.
  const AppTokens({
    required this.space,
    required this.radius,
    required this.motion,
    required this.elevation,
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
  });

  /// The single token set every theme in this app uses.
  ///
  /// The four structural scales are identical in light and dark — a 16dp
  /// gutter is 16dp regardless of brightness, and pretending otherwise is a
  /// well-known way to make a dark theme feel like a different app.
  /// [success] and [warning] and their foregrounds are the only
  /// brightness-dependent members, so they are the only parameters.
  const AppTokens.standard({
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
  }) : space = const SpaceTokens(),
       radius = const RadiusTokens(),
       motion = const MotionTokens(),
       elevation = const ElevationTokens();

  /// The 4dp-based spacing scale.
  final SpaceTokens space;

  /// The corner-radius scale.
  final RadiusTokens radius;

  /// Durations, curves, and dwell times.
  final MotionTokens motion;

  /// The elevation scale.
  final ElevationTokens elevation;

  /// Container colour for a success state.
  ///
  /// Material 3 models `error` but has no success role at all, which is why
  /// this lives on a token set rather than on `ColorScheme`.
  final Color success;

  /// Foreground colour drawn on [success].
  final Color onSuccess;

  /// Container colour for a non-fatal warning state.
  final Color warning;

  /// Foreground colour drawn on [warning].
  final Color onWarning;

  @override
  AppTokens copyWith({
    SpaceTokens? space,
    RadiusTokens? radius,
    MotionTokens? motion,
    ElevationTokens? elevation,
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
  }) {
    return AppTokens(
      space: space ?? this.space,
      radius: radius ?? this.radius,
      motion: motion ?? this.motion,
      elevation: elevation ?? this.elevation,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
    );
  }

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens(
      // The four scales are DISCRETE, so they snap at the midpoint rather
      // than interpolating. This is a deliberate, load-bearing choice:
      // smoothly interpolating a spacing scale means every gap in the app is
      // a fractional, non-repeating number for the whole duration of a theme
      // transition, which produces sub-pixel layout jitter across the entire
      // screen. Snapping produces one reflow instead of sixty.
      space: t < 0.5 ? space : other.space,
      radius: t < 0.5 ? radius : other.radius,
      motion: t < 0.5 ? motion : other.motion,
      elevation: t < 0.5 ? elevation : other.elevation,
      // Colours DO interpolate — this is precisely what makes a light/dark
      // switch read as a crossfade instead of a flash. `Color.lerp` returns
      // null only when both inputs are null, which cannot happen here
      // because both fields are non-nullable, so the `!` is safe.
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
    );
  }
}

/// A 4dp-based spacing scale. Every gap in the app is one of these.
///
/// Seven steps, not a continuous range: the constraint is the point. A
/// designer asking for 18dp is asking for either 16 or 24, and answering
/// that question once here is cheaper than answering it per screen forever.
@immutable
class SpaceTokens {
  /// Creates the spacing scale.
  const SpaceTokens();

  /// 4dp — tightest adjacency, e.g. a caption under its value.
  double get xs => 4;

  /// 8dp — icon to its label.
  double get sm => 8;

  /// 12dp — internal padding of a chip or banner.
  double get md => 12;

  /// 16dp — the default screen gutter, and the default gap between fields.
  double get lg => 16;

  /// 24dp — separates logical groups within a screen.
  double get xl => 24;

  /// 32dp — a heavier group separation.
  double get xxl => 32;

  /// 48dp — separates major page sections; also the breathing room above and
  /// below an optically centred block.
  double get xxxl => 48;
}

/// The corner-radius scale.
///
/// Typed as [Radius] rather than `double` so call sites read
/// `BorderRadius.all(tokens.radius.md)` and cannot accidentally pass a
/// spacing token where a radius belongs.
@immutable
class RadiusTokens {
  /// Creates the radius scale.
  const RadiusTokens();

  /// 8dp — chips and other small surfaces.
  Radius get sm => const Radius.circular(8);

  /// 12dp — buttons and text fields.
  Radius get md => const Radius.circular(12);

  /// 20dp — cards and sheets.
  Radius get lg => const Radius.circular(20);

  /// 28dp — dialogs and bottom sheets.
  ///
  /// Matches Material 3's own dialog shape, read from the installed SDK at
  /// packages/flutter/lib/src/material/dialog.dart:1797, where
  /// `_DialogDefaultsM3` (generated from the Material token database)
  /// specifies `BorderRadius.all(Radius.circular(28.0))`.
  Radius get xl => const Radius.circular(28);
}

/// Motion tokens: durations, curves, and on-screen dwell times.
///
/// The duration and curve members ALIAS Flutter's own generated Material 3
/// token classes rather than restating milliseconds. Two reasons: an SDK
/// token-table update propagates for free, and a reviewer reading
/// `tokens.motion.enter` sees the intent instead of a number they would have
/// to look up. Values read from the installed SDK at
/// packages/flutter/lib/src/material/motion.dart on 2026-07-30, whose own
/// header states it is generated from the Material Design token database:
/// `abstract final class Durations` at lines 21-148 (`short2` = 100ms line
/// 36, `short4` = 200ms line 52, `medium2` = 300ms line 68, `long2` = 500ms
/// line 100) and `abstract final class Easing` at lines 161-232.
@immutable
class MotionTokens {
  /// Creates the motion scale.
  const MotionTokens();

  /// 100ms — ripples, hover, colour swaps, in-place icon changes.
  Duration get instant => Durations.short2;

  /// 200ms — the default for in-place state changes.
  Duration get fast => Durations.short4;

  /// 300ms — elements entering or leaving, surfaces expanding.
  Duration get medium => Durations.medium2;

  /// 500ms — full-screen transitions.
  Duration get slow => Durations.long2;

  /// The default curve for anything already on screen.
  Curve get standard => Easing.standard;

  /// For elements ARRIVING on screen.
  ///
  /// Decelerating: fast at first, settling softly. Paired with [exit] below,
  /// this asymmetry is the actual Material 3 guidance and the single thing
  /// hand-rolled Flutter motion most often gets wrong. A user waiting for
  /// something to appear tolerates a soft landing; a user who just dismissed
  /// something wants it gone. Using `Curves.easeInOut` for both directions
  /// is the tell that nobody made a decision.
  Curve get enter => Easing.emphasizedDecelerate;

  /// For elements LEAVING the screen. Accelerating — see [enter].
  Curve get exit => Easing.emphasizedAccelerate;

  /// How long a brief confirmation stays on screen: 2s.
  ///
  /// Dwell times are not motion curves, but they live here for the same
  /// reason the curves do — so that "how long does a snackbar stay up?" is
  /// answered once, in one place, instead of as a `Duration(seconds: 3)`
  /// literal at each call site that nobody ever reconciles.
  ///
  /// Used for success messages, where the user already knows what happened
  /// and the snackbar is a confirmation rather than information.
  Duration get dwellBrief => const Duration(seconds: 2);

  /// How long an informational message stays on screen: 4s.
  ///
  /// Matches Flutter's own `_snackBarDisplayDuration`, read from the
  /// installed SDK at packages/flutter/lib/src/material/snack_bar.dart:29
  /// (`const Duration _snackBarDisplayDuration = Duration(milliseconds:
  /// 4000);`). Aliasing the framework default rather than picking a number
  /// keeps unstyled snackbars consistent with styled ones.
  Duration get dwellStandard => const Duration(seconds: 4);

  /// How long a failure message stays on screen: 6s.
  ///
  /// Longer because the user did not expect it, has to read it, and may need
  /// to act on it. Anything the user MUST act on should be a dialog or an
  /// inline banner, not a snackbar that leaves on a timer.
  Duration get dwellLong => const Duration(seconds: 6);
}

/// The elevation scale, in logical pixels.
///
/// Four levels only. The app theme sets app bars, cards and snackbars flat by
/// default, so most screens never touch this — elevation is something a
/// surface OPTS IN to when it genuinely floats above another, not ambient
/// decoration sprinkled on every card.
///
/// The values mirror Material 3's own generated defaults, read from the
/// installed SDK on 2026-07-30: `_CardDefaultsM3` uses `elevation: 1.0`
/// (material/card.dart:305), `_NavigationBarDefaultsM3` uses `3.0`
/// (material/navigation_bar.dart:1431), and `_DialogDefaultsM3` uses `6.0`
/// (material/dialog.dart:1797). Each of those files carries the "generated
/// from data in the Material Design token database" header.
///
/// ASSUMPTION: Material 3 defines two further elevation levels above these
/// (commonly cited as 8dp and 12dp). No occurrence of either was found in
/// the SDK's generated M3 defaults this session, so they are NOT shipped
/// here rather than being asserted from memory. If a surface needs more
/// separation than [level3], the surface is probably wrong.
@immutable
class ElevationTokens {
  /// Creates the elevation scale.
  const ElevationTokens();

  /// 0dp — flat. The default for nearly everything in this scaffold.
  double get level0 => 0;

  /// 1dp — a card that must read as separate from the surface behind it.
  double get level1 => 1;

  /// 3dp — persistent chrome that floats over scrolling content, such as a
  /// bottom navigation bar.
  double get level2 => 3;

  /// 6dp — transient surfaces that sit above everything: dialogs, menus,
  /// floating snackbars.
  double get level3 => 6;
}

/// Ergonomic token access: `Theme.of(context).tokens.space.lg`.
extension AppTokensX on ThemeData {
  /// The app's [AppTokens].
  ///
  /// THROWS a [StateError] when the extension is missing, and deliberately
  /// does not fall back to a default token set. `ThemeData.extension<T>()`
  /// returns null when the theme was not built by this app's theme builder,
  /// which is always a WIRING BUG — a `MaterialApp` with no `theme:`, a test
  /// pumping a bare `MaterialApp`, or a `Theme` widget that dropped
  /// `extensions` while copying. A silent `?? const AppTokens.standard(…)`
  /// fallback would let such an app render "almost right" forever, which is
  /// how a design system quietly stops being applied. Failing loudly at the
  /// first read makes the miswiring a one-minute fix instead of a slow
  /// visual drift.
  ///
  /// In a widget test, wrap the widget under test in a `MaterialApp` built
  /// with the app's own light/dark theme rather than a bare `MaterialApp()`.
  AppTokens get tokens {
    final tokens = extension<AppTokens>();
    if (tokens == null) {
      throw StateError(
        'AppTokens missing from ThemeData.extensions. '
        'Build the theme with AppTheme.light()/AppTheme.dark().',
      );
    }
    return tokens;
  }
}
