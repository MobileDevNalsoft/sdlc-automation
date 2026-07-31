// lib/shared/widgets/app_gap.dart
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
// The spacing widget. Every gap between two widgets in this app is an
// `AppGap`, never a `SizedBox` with a number in it.
//
// WHY A WHOLE WIDGET FOR A SizedBox
// Because `SizedBox(height: 16)` is the single most common way a design
// system leaks. It is one line, it looks harmless, and it is invisible to
// review. Ten screens later the app contains 16, 16, 15, 18, 16, 20, and
// nobody can tell which were decisions.
//
// `const AppGap(AppGapSize.lg)` costs the same keystrokes and buys three
// things:
//   1. It resolves through `Theme.of(context).tokens.space`, so changing the
//      scale changes every gap in the app at once.
//   2. It is greppable. `grep -r "SizedBox(height:" lib/features` should
//      return nothing, and that is a check a script can run — see the
//      raw-design-literal rule in tools/check_boundaries.dart.
//   3. It names an INTENT (`lg` = "the standard gap between fields") rather
//      than a magnitude, so a reviewer can tell a deliberate tight gap from
//      a typo.
//
// WHY IT IS NOT `const Gap(16)`
// Because that is the same magic number with extra steps. The size argument
// is an enum precisely so the set of legal gaps is closed.
//
// WHAT TO CHANGE WHEN YOU COPY THIS
// Nothing, normally. If you find yourself wanting a size that is not on the
// scale, the fix is in lib/core/theme/app_tokens.dart (and applies to the
// whole app), not here.

import 'package:flutter/material.dart';
import 'package:my_app/core/theme/app_tokens.dart';

/// The size of an [AppGap], named for the spacing token it resolves to.
///
/// The set is closed on purpose: these are the only gaps this app has.
enum AppGapSize {
  /// 4dp — tightest adjacency.
  xs,

  /// 8dp — icon to its label.
  sm,

  /// 12dp — internal padding of a chip or banner.
  md,

  /// 16dp — the default gap between two fields or two paragraphs.
  lg,

  /// 24dp — separates logical groups within a screen.
  xl,

  /// 32dp — a heavier group separation.
  xxl,

  /// 48dp — separates major page sections.
  xxxl,
}

/// A token-driven gap between two widgets.
///
/// Standardises spacing: feature code writes `const AppGap(AppGapSize.lg)`
/// instead of `SizedBox(height: 16)`, so no screen can contain a spacing
/// value that the design system does not know about.
///
/// Defaults to a VERTICAL gap because most gaps live in a `Column`. Inside a
/// `Row`, use [AppGap.horizontal].
///
/// ```dart
/// Column(
///   children: [
///     const AppTextField(...),
///     const AppGap(AppGapSize.lg),
///     const AppTextField(...),
///   ],
/// )
/// ```
class AppGap extends StatelessWidget {
  /// Creates a vertical gap of [size].
  const AppGap(this.size, {super.key}) : axis = Axis.vertical;

  /// Creates a horizontal gap of [size], for use inside a `Row`.
  const AppGap.horizontal(this.size, {super.key}) : axis = Axis.horizontal;

  /// Which step of the spacing scale this gap occupies.
  final AppGapSize size;

  /// The direction the gap occupies space in.
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final space = Theme.of(context).tokens.space;
    final extent = switch (size) {
      AppGapSize.xs => space.xs,
      AppGapSize.sm => space.sm,
      AppGapSize.md => space.md,
      AppGapSize.lg => space.lg,
      AppGapSize.xl => space.xl,
      AppGapSize.xxl => space.xxl,
      AppGapSize.xxxl => space.xxxl,
    };
    // Switch EXPRESSIONS over both enums, with no `default:` arm — the
    // vendored ruleset forbids `default:` over an exhaustive type, which is
    // the point: adding a step to AppGapSize becomes a compile error here
    // rather than a silent fall-through to the wrong size.
    return switch (axis) {
      Axis.vertical => SizedBox(height: extent),
      Axis.horizontal => SizedBox(width: extent),
    };
  }
}
