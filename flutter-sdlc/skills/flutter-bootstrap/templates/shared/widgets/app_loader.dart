// lib/shared/widgets/app_loader.dart
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
// The app's one loading indicator, in its two legitimate forms:
//   - `const AppLoader()` — the inline/centred spinner a screen shows while
//     it has nothing else to show.
//   - `const AppLoader.overlay()` — a scrim over content that already
//     exists, for an action that must block interaction while it runs.
//
// WHY IT IS A WRAPPER AND NOT JUST `CircularProgressIndicator()`
// Because a bare `CircularProgressIndicator()` in a feature is a decision
// nobody made: its size is whatever the parent allows (so it is a different
// size on every screen), its stroke is the framework default, and it carries
// no semantics, so a screen reader announces a busy screen as an empty one.
// Standardising it costs one widget and removes three inconsistencies.
//
// WHICH FORM TO USE — the distinction is about what is already on screen:
//   - Nothing meaningful on screen yet (first load of a route): the inline
//     form, centred.
//   - Content on screen that the user could otherwise touch (submitting a
//     form from a populated screen): the overlay, so a second tap cannot
//     land somewhere that is about to change.
//   - A button's own work: NEITHER. Use `AppButton(isLoading: true)`, which
//     keeps the feedback attached to the thing that was pressed and keeps
//     the button's size stable.
//
// WHAT TO CHANGE WHEN YOU COPY THIS
//   - `semanticsLabel` carries an English default so the widget works in a
//     single-language app. Pass `context.l10n.…` once a second locale
//     exists.
//   - Do not add a "spinner with a message underneath" variant. If there is
//     a message worth reading, the screen is in an EMPTY or ERROR state, not
//     a loading one — see AppEmptyState and AppErrorView.

import 'package:flutter/material.dart';
import 'package:my_app/core/theme/app_tokens.dart';

/// The app's one loading indicator.
///
/// Standardises the spinner's size, stroke and accessibility announcement so
/// that no feature ships a bare `CircularProgressIndicator()`.
///
/// The overlay form is designed to be laid over existing content:
///
/// ```dart
/// Stack(
///   children: [
///     content,
///     if (state.isSubmitting) const Positioned.fill(
///       child: AppLoader.overlay(),
///     ),
///   ],
/// )
/// ```
class AppLoader extends StatelessWidget {
  /// Creates a centred inline spinner.
  ///
  /// [size] defaults to the 24dp spacing token, which is the size the rest
  /// of the app's iconography is tuned around.
  const AppLoader({this.size, this.semanticsLabel = 'Loading', super.key})
    : _isOverlay = false;

  /// Creates a full-bleed scrim with a centred spinner that also BLOCKS
  /// pointer input to whatever is beneath it.
  ///
  /// Blocking is the point: an action that is already in flight must not be
  /// startable a second time, and the surrounding content is about to
  /// change. Place it inside a `Positioned.fill` so it has bounds.
  const AppLoader.overlay({this.semanticsLabel = 'Loading', super.key})
    : size = null,
      _isOverlay = true;

  /// Diameter of the spinner. Defaults to the 24dp spacing token.
  final double? size;

  /// What a screen reader announces while this is on screen.
  ///
  /// Localise via `context.l10n` when the app is multilingual.
  final String semanticsLabel;

  final bool _isOverlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.tokens;

    final indicator = Semantics(
      label: semanticsLabel,
      // liveRegion so the transition into a loading state is announced
      // without the user having to go looking for it.
      liveRegion: true,
      child: SizedBox.square(
        dimension: size ?? tokens.space.xl,
        // strokeWidth 2 is a deliberate raw literal: it is a hairline
        // weight matched to the glyph, not a layout dimension, so
        // expressing it as a spacing token would be a category error. It is
        // the same value AppButton's inline spinner uses, which is why the
        // two read as the same component.
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
    );

    if (!_isOverlay) {
      return Center(child: indicator);
    }

    return Stack(
      children: [
        // ModalBarrier rather than a Container with a colour: it is the
        // framework's own "absorb every pointer event in this area"
        // primitive, so blocking is not something this widget re-implements
        // and gets subtly wrong.
        ModalBarrier(
          dismissible: false,
          // 0.32 alpha is a design judgement, not a framework constant:
          // enough to push the content behind into the background, light
          // enough that the user can still see the state they are waiting
          // on. Material's own default barrier (black54) is heavier than a
          // transient loading scrim needs.
          color: theme.colorScheme.scrim.withValues(alpha: 0.32),
        ),
        Center(child: indicator),
      ],
    );
  }
}
