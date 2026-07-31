// lib/shared/widgets/app_error_banner.dart
//
// WHAT THIS IS
// The INLINE failure state: a message shown in place, above the fields it
// concerns, while the rest of the screen stays usable. Distinct from
// `AppErrorView`, which replaces the whole screen when there is nothing left
// to show.
//
// NOT SHIPPED BY THE SKILL'S templates/ DIRECTORY. Specified in the
// architecture spec (§7) but absent from the template set; written here
// against the spec's stated shape, `const AppErrorBanner({required String?
// message, Key? key})`.
//
// WHY THE MESSAGE IS NULLABLE — this is the design decision in the file.
// The banner is ALWAYS in the tree and collapses to zero height when there is
// nothing to say. Callers write
//
//     AppErrorBanner(message: state is AuthError ? state.error.message : null)
//
// and never `if (error != null) AppErrorBanner(...)`. The conditional-child
// version is what produces the defect this widget exists to avoid: the fields
// below jump ~60px down the instant an error appears — under the user's thumb,
// mid-typing, at the exact moment they are looking at them. Keeping the widget
// mounted and animating its HEIGHT means the error grows into reserved space
// instead of shoving the layout.
//
// `AnimatedSize(alignment: Alignment.topCenter)` is what makes it grow
// downward from its top edge rather than expanding from its centre.
//
// `Semantics(liveRegion: true, container: true)` is what makes TalkBack and
// VoiceOver announce the message WITHOUT moving focus — a screen reader user
// mid-way through the password field is told what went wrong and stays where
// they are. Without `container: true` the announcement merges into the
// surrounding node and is easy to miss.
//
// ICON PLUS COLOUR, NEVER COLOUR ALONE: roughly 1 in 12 men has a red/green
// colour vision deficiency, and an error conveyed only by a red tint is
// invisible to them. The icon is not decoration.

import 'package:flutter/material.dart';
import 'package:my_app/core/theme/app_tokens.dart';
import 'package:my_app/shared/widgets/app_gap.dart';

/// An inline, collapsible failure message.
///
/// Keep it mounted at all times and pass a null [message] when there is
/// nothing to report — see this file's header for why the conditional-child
/// alternative is a layout defect rather than a simplification.
class AppErrorBanner extends StatelessWidget {
  /// Creates a banner showing [message], or nothing at all when it is null.
  const AppErrorBanner({required this.message, super.key});

  /// The failure to show, already localised, or null to collapse the banner.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.tokens;
    final scheme = theme.colorScheme;
    final text = message;

    return Semantics(
      liveRegion: true,
      container: true,
      child: AnimatedSize(
        duration: tokens.motion.fast,
        curve: tokens.motion.standard,
        // Grows downward from its top edge. The default (centre) makes the
        // banner expand in both directions, which moves the content above it
        // as well as below.
        alignment: Alignment.topCenter,
        child: text == null
            // Full-width but zero-height, so only the HEIGHT animates. A
            // `SizedBox.shrink()` here would animate the width too and the
            // banner would appear to unroll sideways.
            ? const SizedBox(width: double.infinity)
            : Container(
                width: double.infinity,
                padding: EdgeInsets.all(tokens.space.md),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.all(tokens.radius.md),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: scheme.onErrorContainer,
                    ),
                    const AppGap.horizontal(AppGapSize.sm),
                    Expanded(
                      child: Text(
                        text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
