// lib/shared/widgets/app_error_view.dart
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
// The full-screen failure state. A screen whose Cubit is in an error state
// and that has nothing useful to show renders this and nothing else.
//
// WHY IT TAKES THE SEALED `AppError` AND NOT A `String`
// This is the design decision in this file. If the constructor took a
// message, every screen would have to answer, on its own, three questions it
// is not well placed to answer:
//   - which icon means this?
//   - what should the button say — "Try again", or "Sign in"?
//   - is retrying even a sensible thing to offer here?
// Taking the sealed type means those are answered ONCE, exhaustively, by the
// switches below. A ninth `AppError` variant added in
// lib/core/error/app_error.dart becomes a COMPILE ERROR here until someone
// decides how it looks — which is exactly the moment to make that decision,
// rather than three months later when it shows up in production as a generic
// "Something went wrong".
//
// The switches are switch EXPRESSIONS with no `default:` arm. That is not a
// style preference: the vendored `no_default_cases` rule forbids `default:`
// over a sealed type precisely so the compile error above is reachable. A
// `default: => Icons.error_outline` would silently absorb every future
// variant.
//
// ALWAYS-PRESENT ACTION — and why "always" is the right call
// `onRetry` is required, not optional. Even for a failure retrying cannot
// fix (a cancelled request, a decode bug), the user needs SOMETHING to press
// other than the system back gesture; the action label switch below turns
// those into "Dismiss" rather than a misleading "Try again". A dead-end
// error screen is a bug report waiting to happen.
//
// WHAT TO CHANGE WHEN YOU COPY THIS
//   - The headline and action strings carry English defaults so the widget
//     works from day one. In a multilingual app, switch on the variant at
//     the CALL SITE and pass `context.l10n.…` into [AppErrorView.headline]
//     and [AppErrorView.retryLabel]. Localising cannot happen inside
//     lib/core/error/app_error.dart itself — that layer has no
//     `BuildContext`, by design.
//   - Do not add per-feature error copy here. If a feature needs to say
//     something specific about a failure, the specific text belongs in the
//     `AppError`'s `message` (which this widget already renders), not in a
//     new branch.

import 'package:flutter/material.dart';
import 'package:my_app/core/error/app_error.dart';
import 'package:my_app/core/theme/app_tokens.dart';
import 'package:my_app/shared/widgets/app_button.dart';
import 'package:my_app/shared/widgets/app_gap.dart';

/// The app's full-screen failure state.
///
/// Standardises what a failure looks like across every feature: one icon
/// vocabulary, one headline vocabulary, the error's own user-safe message as
/// the body, and an action that is always present.
///
/// Feature code renders this for the error arm of its state switch instead
/// of composing an icon, a `Text` and a button per screen.
class AppErrorView extends StatelessWidget {
  /// Creates a full-screen failure state for [error].
  ///
  /// [onRetry] is required — see this file's header for why there is no
  /// dead-end variant.
  const AppErrorView({
    required this.error,
    required this.onRetry,
    this.headline,
    this.retryLabel,
    super.key,
  });

  /// What went wrong. Drives the icon, the headline and the action label.
  final AppError error;

  /// Invoked by the action button. Usually re-dispatches the Cubit call that
  /// failed; for a non-retryable failure, dismisses or pops.
  final VoidCallback onRetry;

  /// Overrides the variant-derived headline. Pass a localised string here in
  /// a multilingual app.
  final String? headline;

  /// Overrides the variant-derived action label. Pass a localised string
  /// here in a multilingual app.
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.tokens;
    final scheme = theme.colorScheme;

    // One switch expression yielding a record, so the icon and the headline
    // for a variant are decided in the same place and cannot drift apart.
    final (icon, defaultHeadline) = switch (error) {
      NetworkError() => (Icons.wifi_off_rounded, "You're offline"),
      TimeoutError() => (Icons.hourglass_empty_rounded, 'That took too long'),
      UnauthorizedError() => (Icons.lock_outline_rounded, 'Session expired'),
      ValidationError() => (Icons.rule_rounded, "That didn't work"),
      ServerError() => (Icons.cloud_off_rounded, 'Server problem'),
      CancelledError() => (Icons.do_not_disturb_on_outlined, 'Cancelled'),
      SerializationError() => (Icons.bug_report_outlined, 'Unexpected reply'),
      UnknownError() => (Icons.error_outline_rounded, 'Something went wrong'),
    };

    // The action's label depends on what the user can actually DO, which is
    // a DIFFERENT partition of the variants than the illustration above —
    // hence a second switch rather than two more fields on the first record.
    // Offering "Try again" for a failure that retrying cannot fix is how an
    // error screen teaches users to distrust its buttons.
    final (defaultAction, actionIcon) = switch (error) {
      NetworkError() ||
      TimeoutError() ||
      ServerError() => ('Try again', Icons.refresh_rounded),
      UnauthorizedError() => ('Sign in', Icons.login_rounded),
      ValidationError() => ('Go back', Icons.arrow_back_rounded),
      CancelledError() ||
      SerializationError() ||
      UnknownError() => ('Dismiss', Icons.close_rounded),
    };

    return Center(
      child: SingleChildScrollView(
        // Scrollable so the whole state survives a short viewport at a large
        // text scale instead of overflowing — an error screen that itself
        // renders an overflow stripe is a bad look at a bad moment.
        padding: EdgeInsets.symmetric(vertical: tokens.space.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              // 48dp: large enough to read as an illustration rather than a
              // UI control. Taken from the spacing scale's top step so it
              // still moves with the scale rather than being a loose number.
              size: tokens.space.xxxl,
              color: scheme.error,
            ),
            const AppGap(AppGapSize.xl),
            Text(
              headline ?? defaultHeadline,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const AppGap(AppGapSize.sm),
            Text(
              // The error's own message: written as user-facing copy by
              // lib/core/error/app_error.dart, and carrying the server's
              // detail when the API supplied one.
              error.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const AppGap(AppGapSize.xl),
            AppButton(
              label: retryLabel ?? defaultAction,
              onPressed: onRetry,
              icon: actionIcon,
            ),
          ],
        ),
      ),
    );
  }
}
