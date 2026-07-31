// lib/shared/widgets/app_text_field.dart
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
// The ONLY text input feature code is allowed to use. `TextField` and
// `TextFormField` are banned under lib/features/**
// (tools/check_boundaries.dart enforces it); this widget is the sanctioned
// way to get one.
//
// WHY BAN THE FRAMEWORK FIELDS — four things every screen otherwise
// re-decides, and gets wrong in the same four ways:
//
//   1. THE LAYOUT JOLT. A `TextFormField` with a validator has no error line
//      until validation fails, at which point one appears and shoves
//      everything below it down ~20dp — under the user's thumb, mid-typing.
//      This widget reserves that line from the start (`helperText: ' '`), so
//      the error fades in without moving anything. This is the single most
//      dated-feeling defect in hand-built Flutter forms.
//   2. AUTOFILL. `autofillHints` is a REQUIRED parameter here, not an
//      optional one. A password field with no hint is a field iOS Keychain
//      and Google Password Manager cannot fill or offer to save, and the
//      omission is invisible in a demo and infuriating in a real app.
//      Passing `const []` is legal and explicit — you had to decide.
//   3. THE OBSCURE TOGGLE. Everyone builds one; almost nobody gives it a
//      tooltip, so screen-reader users hear "button" and switch-control
//      users get an unlabelled target. Here the tooltip doubles as the
//      accessibility label and cannot be forgotten.
//   4. KEYBOARD FLOW. `textInputAction` defaults to `.next` so a multi-field
//      form is completable from the keyboard alone; the last field passes
//      `.done` plus `onSubmitted`.
//
// WHERE THE LOOK COMES FROM — NOT FROM HERE.
// The fill colour, the 12dp radius on all five border states, the 2dp focus
// ring and the content padding all come from `inputDecorationTheme` in
// lib/core/theme/app_theme.dart. This file contains no colours and no
// dimensions at all. That is deliberate: a raw `TextField` used inside
// lib/shared/widgets/** still looks correct, so the wrapper is about
// BEHAVIOUR and never about paint.
//
// WHAT TO CHANGE WHEN YOU COPY THIS
//   - `label`, and the two tooltips, must already be localised by the
//     caller. The tooltips carry English defaults so the widget is usable
//     from day one in a single-language app; pass `context.l10n.…` the
//     moment a second locale exists.
//   - Wrap the fields of one credential pair in a single `AutofillGroup` at
//     the SCREEN level, and call `TextInput.finishAutofillContext()` on
//     submit. That call is what prompts the OS to offer to SAVE the
//     credential; without it, autofill reads but never writes.
//   - Resist adding a `style:` parameter. If one field needs different type,
//     the type scale is wrong.

import 'package:flutter/material.dart';

/// The only text input feature code is allowed to use.
///
/// Standardises the reserved error line, required autofill hints, the
/// labelled obscure-text toggle, and keyboard flow. All paint (fill,
/// radius, focus ring, padding) is inherited from `inputDecorationTheme`, so
/// this widget declares no colours or dimensions of its own.
///
/// The caller owns the [controller] and, for a password field, owns the
/// [obscureText] flag as well — this widget is stateless on purpose so that
/// a parent Cubit rebuild can never reset what the user has typed.
class AppTextField extends StatelessWidget {
  /// Creates a standardised text field.
  ///
  /// [autofillHints] is required rather than optional: a field the platform
  /// password manager cannot recognise is a defect, and making the parameter
  /// required forces the decision to be made once per field. Pass
  /// `const []` for a field that genuinely has no autofill meaning (a search
  /// box, a one-off numeric quantity).
  const AppTextField({
    required this.controller,
    required this.label,
    required this.autofillHints,
    this.validator,
    this.obscureText = false,
    this.onToggleObscure,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.enabled = true,
    this.autocorrect = true,
    this.revealTooltip = 'Show text',
    this.hideTooltip = 'Hide text',
    super.key,
  });

  /// Holds the field's text. Owned by the calling `StatefulWidget`.
  ///
  /// Form input must never live in Cubit state: a state transition would
  /// rebuild the field and discard whatever the user was mid-way through
  /// typing.
  final TextEditingController controller;

  /// The floating label. Always localised by the caller.
  final String label;

  /// Platform autofill hints, e.g. `[AutofillHints.username]`.
  ///
  /// Use `AutofillHints.username` rather than `.email` for a sign-in
  /// identifier even when it is an email address — `username` is the hint
  /// password managers key a saved credential on.
  final List<String> autofillHints;

  /// Synchronous validation, run on user interaction and on form submit.
  ///
  /// Returning a non-null string renders it in the line already reserved
  /// below the field, so the layout does not move.
  final String? Function(String?)? validator;

  /// Whether the text is hidden. The caller owns this flag.
  final bool obscureText;

  /// Called when the user taps the reveal/hide affordance.
  ///
  /// When null, no toggle button is shown at all — so a plain field does not
  /// grow a mystery icon.
  final VoidCallback? onToggleObscure;

  /// Which soft keyboard to request.
  final TextInputType? keyboardType;

  /// What the keyboard's action key does. Defaults to
  /// [TextInputAction.next]; the last field of a form should pass
  /// [TextInputAction.done] together with [onSubmitted].
  final TextInputAction textInputAction;

  /// Called when the user presses the keyboard's action key.
  final ValueChanged<String>? onSubmitted;

  /// Whether the field accepts input.
  final bool enabled;

  /// Whether the platform may autocorrect the text.
  ///
  /// Pass `false` for email addresses, usernames and codes. Autocorrecting
  /// an email address into a real word is a classic "why won't it let me
  /// sign in" bug.
  final bool autocorrect;

  /// Tooltip and accessibility label for the reveal affordance, shown while
  /// the text is hidden. Localise via `context.l10n` when multilingual.
  final String revealTooltip;

  /// Tooltip and accessibility label for the hide affordance, shown while
  /// the text is visible. Localise via `context.l10n` when multilingual.
  final String hideTooltip;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: obscureText,
      enabled: enabled,
      autocorrect: autocorrect,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      autofillHints: autofillHints,
      // Validate as the user interacts, not on every keystroke from the
      // first character: `onUserInteraction` waits until the field has been
      // touched, so an empty form does not greet the user with errors.
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        // THE RESERVED ERROR LINE. A single space, not an empty string:
        // `helperText: ''` collapses, `helperText: ' '` lays out one line of
        // helper-sized text that stays empty until the validator has
        // something to say. Removing this reintroduces the layout jolt this
        // widget exists to prevent.
        helperText: ' ',
        suffixIcon: onToggleObscure == null
            ? null
            : IconButton(
                onPressed: onToggleObscure,
                // The tooltip IS the accessibility label — an icon-only
                // button without one fails Flutter's own
                // `labeledTapTargetGuideline`. IconButton already lays out
                // at 48x48 (kMinInteractiveDimension), so no size override
                // is needed here.
                tooltip: obscureText ? revealTooltip : hideTooltip,
                icon: Icon(
                  obscureText ? Icons.visibility_off : Icons.visibility,
                ),
              ),
      ),
    );
  }
}
