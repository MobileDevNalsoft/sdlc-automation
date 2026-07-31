// lib/shared/widgets/app_scaffold.dart
//
// WHAT THIS IS
// The screen shell. Every screen in the app returns one of these; `Scaffold`
// is reserved for lib/shared/widgets/**.
//
// NOT SHIPPED BY THE SKILL'S templates/ DIRECTORY. The architecture spec (§7)
// specifies this widget and both lib/core/router/app_router.dart and
// flutter-slice's product_screen.dart import it, but no template file for it
// existed when this app was migrated. It is written here against the spec's
// stated constructor shape:
//   const AppScaffold({required Widget body, String? title,
//     List<Widget>? actions, Widget? bottomAction, bool safeArea = true,
//     Key? key})
//
// FOUR THINGS IT OWNS SO NO SCREEN RE-DECIDES THEM
//   1. THE GUTTER. `tokens.space.lg` (16dp) horizontally, once. A screen that
//      adds its own `Padding` ends up with 16 on one screen and 24 on the
//      next, and nobody can tell which was a decision.
//   2. SafeArea. Forgotten exactly once per project, on the one screen that
//      renders under the notch.
//   3. CHROME-LESS BY DEFAULT. `title == null` builds NO `AppBar` at all —
//      not an empty one. A login screen has no parent to navigate back to and
//      no title worth a 56dp bar, so the brand mark becomes the top of the
//      visual hierarchy instead of the word "Sign in" in a grey bar.
//   4. TAP-OUTSIDE KEYBOARD DISMISSAL, done once here so no feature can
//      forget it.
//
// `excludeFromSemantics: true` ON THAT GestureDetector IS MANDATORY, NOT
// TIDINESS. Verified by running Flutter's own `labeledTapTargetGuideline`
// against this exact shell: without it the full-screen detector publishes an
// unlabelled, screen-sized tappable node and the test fails with
//
//     SemanticsNode#4(Rect.fromLTRB(0.0, 0.0, 800.0, 600.0), actions: [tap]):
//     expected tappable node to have semantic label, but none was found.
//
// Every screen in the app inherits this shell, so the fix has to live here or
// every screen fails the same assertion.
//
// WHY `bottomAction` IS A SEPARATE SLOT AND NOT JUST THE LAST CHILD OF body
// It is laid out below the scrollable body and above the keyboard, so a
// primary action stays reachable with one thumb on a tall form instead of
// requiring the user to scroll to find the button they are looking for.

import 'package:flutter/material.dart';
import 'package:my_app/core/theme/app_tokens.dart';

/// The app's screen shell.
///
/// Standardises the screen gutter, the safe area, whether there is an app bar
/// at all, the bottom action slot, and tap-outside keyboard dismissal.
///
/// Feature code uses this instead of `Scaffold`. Those are reserved for
/// lib/shared/widgets/**.
///
/// ```dart
/// AppScaffold(
///   title: context.l10n.ordersTitle,
///   body: ListView(...),
///   bottomAction: AppButton(label: ..., onPressed: ...),
/// )
/// ```
class AppScaffold extends StatelessWidget {
  /// Creates a screen shell around [body].
  ///
  /// Omit [title] for a chrome-less screen: no `AppBar` is built at all.
  const AppScaffold({
    required this.body,
    this.title,
    this.actions,
    this.bottomAction,
    this.safeArea = true,
    super.key,
  });

  /// The screen's content. Already inside the gutter and the safe area.
  final Widget body;

  /// App-bar title, already localised. Null means NO app bar — see the
  /// header for why that is the interesting case rather than the degenerate
  /// one.
  final String? title;

  /// Trailing app-bar actions. Ignored when [title] is null, because there
  /// is no bar to put them in.
  final List<Widget>? actions;

  /// A pinned action laid out below [body] and above the keyboard.
  ///
  /// Normally a single `AppButton`. Use it for the action that completes the
  /// screen so it stays thumb-reachable on a long form.
  final Widget? bottomAction;

  /// Whether [body] is wrapped in a `SafeArea`. Pass false only for a screen
  /// that deliberately paints under the system bars (a full-bleed image, a
  /// map).
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).tokens;
    final screenTitle = title;
    final action = bottomAction;

    Widget content = Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.space.lg),
      child: body,
    );
    if (safeArea) {
      content = SafeArea(child: content);
    }

    return GestureDetector(
      // Translucent so the detector still receives taps that land on empty
      // space, without stealing them from the widgets underneath.
      behavior: HitTestBehavior.translucent,
      // MANDATORY — see this file's header. Removing it fails
      // labeledTapTargetGuideline on every screen in the app at once.
      excludeFromSemantics: true,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: screenTitle == null
            ? null
            : AppBar(title: Text(screenTitle), actions: actions),
        body: content,
        // bottomNavigationBar rather than persistentFooterButtons: it is the
        // slot Scaffold lifts above the keyboard when
        // resizeToAvoidBottomInset applies, which is the whole point of
        // having a separate action slot on a form screen.
        bottomNavigationBar: action == null
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    tokens.space.lg,
                    tokens.space.sm,
                    tokens.space.lg,
                    tokens.space.lg,
                  ),
                  child: action,
                ),
              ),
      ),
    );
  }
}
