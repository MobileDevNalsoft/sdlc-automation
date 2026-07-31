// lib/shared/widgets/app_snack.dart
//
// WHAT THIS IS
// The three transient messages the app is allowed to show, as three named
// static methods. A raw
// `ScaffoldMessenger.of(context).showSnackBar(SnackBar(...))` at a call site
// is what this replaces.
//
// NOT SHIPPED BY THE SKILL'S templates/ DIRECTORY. Specified in the
// architecture spec (§7) but absent from the template set; written here
// against the spec's stated shape, `abstract final class AppSnack` with
// `static void success/error/info(BuildContext, String)`.
//
// WHY THREE METHODS AND NOT ONE WITH A SEVERITY PARAMETER
// Because the call site then reads `AppSnack.error(context, msg)` — the
// severity is the verb, and it is impossible to pass the wrong one by
// accident the way a positional enum argument can be. It also means the DWELL
// TIME is decided per severity, once, here:
//   - success  2s  the user already knows what happened; this is a receipt.
//   - info     4s  matches Flutter's own `_snackBarDisplayDuration`.
//   - error    6s  unexpected, has to be read, may need acting on.
// Those are `tokens.motion.dwell*`, not literals — see
// lib/core/theme/app_tokens.dart.
//
// WHAT A SNACKBAR IS NOT FOR
// Anything the user MUST act on. A snackbar leaves on a timer, so a message
// that matters after it is gone belongs in an `AppErrorBanner` (inline, stays
// put) or an `AppErrorView` (full screen, has a button). Reaching for a
// snackbar to report a failed save is how a user loses work silently.
//
// `clearSnackBars()` FIRST, DELIBERATELY: without it a screen that reports
// two things in quick succession queues them, and the second message appears
// seconds after the action that caused it — by which point the user has moved
// on and is being told about something they no longer remember doing.
//
// The floating behaviour, corner radius and close icon are NOT set here. They
// come from `snackBarTheme` in lib/core/theme/app_theme.dart, so the ones the
// framework shows by itself look the same as these.

import 'package:flutter/material.dart';
import 'package:my_app/core/theme/app_tokens.dart';

/// The app's transient messages.
///
/// `abstract final` so it can be neither instantiated nor extended: this is a
/// namespace for three functions, not a type.
///
/// ```dart
/// AppSnack.success(context, context.l10n.loginWelcome(user.name));
/// ```
abstract final class AppSnack {
  /// Confirms something the user just did. Short dwell — it is a receipt.
  ///
  /// [message] must already be localised by the caller.
  static void success(BuildContext context, String message) {
    final theme = Theme.of(context);
    final tokens = theme.tokens;
    _show(
      context,
      message: message,
      icon: Icons.check_circle_outline_rounded,
      background: tokens.success,
      foreground: tokens.onSuccess,
      duration: tokens.motion.dwellBrief,
    );
  }

  /// Reports a failure the user does not have to act on immediately.
  ///
  /// For anything they DO have to act on, use an inline `AppErrorBanner` or a
  /// full-screen `AppErrorView` instead — see this file's header.
  ///
  /// [message] must already be localised by the caller.
  static void error(BuildContext context, String message) {
    final theme = Theme.of(context);
    _show(
      context,
      message: message,
      icon: Icons.error_outline_rounded,
      background: theme.colorScheme.errorContainer,
      foreground: theme.colorScheme.onErrorContainer,
      duration: theme.tokens.motion.dwellLong,
    );
  }

  /// States a neutral fact. Standard dwell.
  ///
  /// [message] must already be localised by the caller.
  static void info(BuildContext context, String message) {
    final theme = Theme.of(context);
    _show(
      context,
      message: message,
      icon: Icons.info_outline_rounded,
      background: theme.colorScheme.inverseSurface,
      foreground: theme.colorScheme.onInverseSurface,
      duration: theme.tokens.motion.dwellStandard,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color background,
    required Color foreground,
    required Duration duration,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    final tokens = Theme.of(context).tokens;
    messenger
      // See the header: queuing rather than replacing means the second
      // message arrives long after the action that caused it.
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          backgroundColor: background,
          closeIconColor: foreground,
          content: Row(
            children: [
              Icon(icon, color: foreground),
              SizedBox(width: tokens.space.sm),
              // Expanded, not a bare Text: a long message inside a Row has
              // unbounded width and overflows rather than wrapping.
              Expanded(
                child: Text(message, style: TextStyle(color: foreground)),
              ),
            ],
          ),
        ),
      );
  }
}
