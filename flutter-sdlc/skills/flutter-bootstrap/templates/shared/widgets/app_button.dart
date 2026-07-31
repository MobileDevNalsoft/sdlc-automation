// lib/shared/widgets/app_button.dart
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
// The ONLY button feature code is allowed to use. `FilledButton`,
// `OutlinedButton`, `ElevatedButton` and `TextButton` are banned under
// lib/features/** (tools/check_boundaries.dart enforces it); this widget is
// the sanctioned way to get one.
//
// WHY BAN THE FRAMEWORK BUTTONS
// Not because they are bad — this widget is a thin wrapper over them. It is
// because a button has FIVE states (idle, pressed, disabled, busy, and
// busy-and-disabled) and every screen that reaches for a raw `FilledButton`
// re-decides four of them, differently. The two that get improvised worst:
//
//   - LOADING. The usual improvisation replaces the button with a spinner,
//     which changes the widget's size, which reflows the layout under the
//     user's thumb at the exact moment they are watching it. This widget
//     swaps the CHILD inside a button whose height is pinned by the theme's
//     52dp `minimumSize`, so the button does not move at all.
//   - DOUBLE SUBMIT. A screen that shows a spinner but leaves `onPressed`
//     live sends the request twice. Here, `isLoading` forces `onPressed` to
//     null; it is not possible to get one without the other.
//
// THE TEXT-SCALE DEFECT THIS WIDGET EXISTS TO NOT HAVE
// An earlier version composed icon + label as
// `Row(mainAxisSize: MainAxisSize.min, children: [Icon, SizedBox, Text])`.
// At `TextScaler.linear(2.0)` on a 360x640 viewport that produced, verified
// by running it:
//
//     FlutterError: A RenderFlex overflowed by 136 pixels on the right.
//
// Cause: a bare `Text` inside a `mainAxisSize.min` `Row` has unbounded
// width. The `Flexible` + `maxLines: 2` + ellipsis below is the fix, and it
// was verified to make text scales 1.0, 1.3 and 2.0 all pass. Do not
// "simplify" it back to a bare `Text` — the scaffold ships
// test/theme_scale_test.dart specifically to catch that.
//
// WHAT TO CHANGE WHEN YOU COPY THIS
//   - Heights, radii and label type are NOT here. They come from the
//     `filledButtonTheme` / `outlinedButtonTheme` / `textButtonTheme`
//     sub-themes in lib/core/theme/app_theme.dart, so a raw framework button
//     used inside lib/shared/widgets/** still looks right.
//   - Adding a fourth variant means adding an `AppButtonVariant` value; the
//     two exhaustive switches below will then fail to compile until you have
//     decided what it looks like AND what colour its spinner is. That is
//     working as intended.
//   - `label` must already be localised by the caller (`context.l10n.…`).
//     This widget never sees a string it is allowed to invent.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/core/theme/app_tokens.dart';

/// Visual weight of an [AppButton].
enum AppButtonVariant {
  /// The single most important action on a screen. There should be one.
  primary,

  /// An action of equal validity but lower emphasis.
  secondary,

  /// A low-emphasis, chrome-less action — links, "Cancel", "Skip".
  text,
}

/// How firmly an [AppButton] reports its press to the hand.
///
/// Two weights, because distinguishing "I tapped something" from "something
/// committed" is a real, felt affordance and costs one enum value.
enum AppButtonHaptic {
  /// The default: a light tick on any press.
  light,

  /// For the action that actually commits — submitting a form, confirming a
  /// destructive change, completing a purchase.
  medium,
}

/// The only button feature code is allowed to use.
///
/// Standardises, in one place: the >=52dp height (Android's 48dp minimum
/// plus text-scale headroom), the token corner radius, `labelLarge` type, a
/// built-in loading state that swaps the label for a spinner WITHOUT
/// changing the button's size, haptic feedback on press, disabling while
/// busy, and semantics that do not announce a busy button as tappable.
///
/// Feature code uses this instead of `FilledButton`/`OutlinedButton`/
/// `TextButton` directly. Those are reserved for lib/shared/widgets/**.
class AppButton extends StatelessWidget {
  /// Creates a button.
  ///
  /// [onPressed] may be null to disable it. [label] must already be
  /// localised.
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.haptic = AppButtonHaptic.light,
    super.key,
  });

  /// The button's text. Always localised by the caller.
  final String label;

  /// Tapped callback. Null disables the button.
  final VoidCallback? onPressed;

  /// Visual emphasis.
  final AppButtonVariant variant;

  /// When true the label is replaced by a spinner and taps are ignored.
  ///
  /// Drive this from the feature's Cubit state (for example
  /// `isLoading: state is AuthLoading`) so the press, the spinner and the
  /// resulting navigation read as one continuous response.
  final bool isLoading;

  /// Optional leading icon, hidden while [isLoading].
  final IconData? icon;

  /// Press feedback weight. Use [AppButtonHaptic.medium] on the button that
  /// commits the screen's work.
  final AppButtonHaptic haptic;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).tokens;
    final enabled = onPressed != null && !isLoading;

    void handlePress() {
      // `.ignore()` rather than `await` or `unawaited()`: this is a
      // fire-and-forget platform call whose result nobody can act on, and
      // `.ignore()` satisfies the `discarded_futures` lint without needing a
      // `dart:async` import.
      switch (haptic) {
        case AppButtonHaptic.light:
          HapticFeedback.lightImpact().ignore();
        case AppButtonHaptic.medium:
          HapticFeedback.mediumImpact().ignore();
      }
      onPressed?.call();
    }

    final child = AnimatedSwitcher(
      // `instant` (100ms), not a longer duration: this crossfade happens at
      // the moment of the tap, and anything slower reads as lag rather than
      // as feedback.
      duration: tokens.motion.instant,
      child: isLoading
          ? SizedBox.square(
              // Keys are what let AnimatedSwitcher tell the two children
              // apart; without them it treats the swap as an update and
              // does not animate at all.
              key: const ValueKey('loading'),
              // 20dp: a deliberate raw literal, and the only one in this
              // file. It is an OPTICAL size for a glyph inside a fixed
              // 52dp button, not a layout gap — expressing it as a spacing
              // token would imply it participates in the spacing rhythm,
              // which it does not.
              dimension: 20,
              child: CircularProgressIndicator(
                // Likewise a hairline weight, not a spacing value.
                strokeWidth: 2,
                color: _spinnerColour(context),
              ),
            )
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  // 18dp: optical match to `labelLarge`, same reasoning as
                  // the spinner dimension above.
                  Icon(icon, size: 18),
                  SizedBox(width: tokens.space.sm),
                ],
                // Flexible, not a bare Text — see the overflow note in this
                // file's header. Removing this reintroduces a verified
                // RenderFlex overflow at text scale 2.0.
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
    );

    // A busy button must not read as "tap to activate" to a screen reader.
    // `excludeSemantics` while loading suppresses the child's own semantics
    // so the announcement comes from this node alone.
    final semanticChild = Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: isLoading,
      child: child,
    );

    // Switch EXPRESSION, so there is no `default:` arm to hide a new variant
    // in. Shape, height and text style all come from the theme's button
    // sub-themes; nothing is restated here.
    return switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: enabled ? handlePress : null,
        child: semanticChild,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: enabled ? handlePress : null,
        child: semanticChild,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: enabled ? handlePress : null,
        child: semanticChild,
      ),
    };
  }

  Color _spinnerColour(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (variant) {
      AppButtonVariant.primary => scheme.onPrimary,
      AppButtonVariant.secondary || AppButtonVariant.text => scheme.primary,
    };
  }
}
