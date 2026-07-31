// lib/shared/widgets/app_empty_state.dart
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
// The "nothing here (yet)" state: a successful load that returned no rows,
// a search with no matches, an inbox that is genuinely empty.
//
// WHY IT IS A SEPARATE WIDGET FROM AppErrorView — this is the whole point.
// EMPTY IS NOT A FAILURE. Nothing went wrong; there is simply nothing to
// show, and very often that is the normal state of a brand-new account. The
// two states are therefore deliberately different in every dimension that
// carries meaning:
//
//                     AppEmptyState              AppErrorView
//   icon colour       onSurfaceVariant           scheme.error
//   icon treatment    inside a soft surface      bare, alarming
//   headline          neutral, sometimes warm    names the fault
//   action            OPTIONAL and generative    REQUIRED and corrective
//                     ("Add your first item")    ("Try again")
//
// An empty list rendered in error red teaches users that the app is broken
// when it is working exactly as designed. That is the single most common
// place a competent Flutter app still feels amateur, and it is a
// three-minute fix that nobody makes because the two states get written by
// the same `else` branch.
//
// THE ACTION IS OPTIONAL, AND THAT ASYMMETRY IS DELIBERATE
// A failure always needs a way out (see AppErrorView, where `onRetry` is
// required). An empty state frequently has no action at all — an empty
// "archived" tab needs no button. When there IS one it should be
// GENERATIVE: create the first thing, clear the filter, invite someone.
//
// WHAT TO CHANGE WHEN YOU COPY THIS
//   - `headline` and `supporting` are passed in, already localised, by the
//     feature. This widget invents no copy of its own — unlike AppErrorView,
//     which can derive sensible defaults from a sealed type, there is no
//     closed set of "empty" reasons to switch over.
//   - Keep `supporting` to one short sentence. If it needs a paragraph, the
//     screen needs onboarding, not an empty state.

import 'package:flutter/material.dart';
import 'package:my_app/core/theme/app_tokens.dart';
import 'package:my_app/shared/widgets/app_gap.dart';

/// The app's "nothing here yet" state.
///
/// Standardises the empty state so it is visually distinct from a failure:
/// neutral colours, a soft container behind the icon, and an optional
/// generative action rather than a mandatory corrective one.
///
/// Feature code renders this for the empty arm of its state switch instead
/// of composing centred text per screen.
///
/// ```dart
/// AppEmptyState(
///   icon: Icons.inbox_outlined,
///   headline: context.l10n.ordersEmptyHeadline,
///   supporting: context.l10n.ordersEmptySupporting,
///   action: AppButton(
///     label: context.l10n.ordersEmptyAction,
///     onPressed: _startOrder,
///     variant: AppButtonVariant.secondary,
///   ),
/// )
/// ```
class AppEmptyState extends StatelessWidget {
  /// Creates an empty state.
  const AppEmptyState({
    required this.icon,
    required this.headline,
    this.supporting,
    this.action,
    super.key,
  });

  /// A calm, outline-style icon describing what is missing.
  ///
  /// Prefer the `_outlined` variants: a filled icon at this size reads as
  /// heavier than an empty state should.
  final IconData icon;

  /// One short line naming what is empty. Localised by the caller.
  final String headline;

  /// Optional single sentence explaining why, or what to do next.
  /// Localised by the caller.
  final String? supporting;

  /// Optional generative action, normally an `AppButton` with
  /// `AppButtonVariant.secondary` — an empty state is an invitation, not the
  /// screen's primary call to action.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.tokens;
    final scheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        // Scrollable so a large text scale on a short viewport cannot
        // overflow this state.
        padding: EdgeInsets.symmetric(vertical: tokens.space.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The soft container is what makes this read as "considered
            // blank" rather than "failed to load": the icon sits ON
            // something, instead of floating alone in the middle of a void.
            Container(
              padding: EdgeInsets.all(tokens.space.xl),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                // 32dp from the spacing scale: smaller than AppErrorView's
                // 48dp bare icon, because this one is already framed by the
                // circle above and does not need to carry the state alone.
                size: tokens.space.xxl,
                // onSurfaceVariant, never scheme.error — see the header.
                color: scheme.onSurfaceVariant,
              ),
            ),
            const AppGap(AppGapSize.xl),
            Text(
              headline,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (supporting != null) ...[
              const AppGap(AppGapSize.sm),
              Text(
                supporting!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const AppGap(AppGapSize.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
