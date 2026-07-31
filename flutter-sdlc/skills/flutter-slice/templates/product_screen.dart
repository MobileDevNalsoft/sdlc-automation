// lib/features/product/presentation/screens/product_screen.dart
//
// TEMPLATE — copy to lib/features/<feature>/presentation/screens/<feature>
// _screen.dart, rename every `Product`/`product` identifier, and replace the
// placeholder package name `my_app` in the imports below with your own
// package name (the `name:` field of pubspec.yaml).
//
// WHAT THIS IS
// The Screen: an exhaustive `switch` over the sealed `ProductState` with
// deliberately NO `default:` arm, rendering each state through the shared
// design system. Two jobs, and only two:
//
//   1. Map each state variant to a widget subtree.
//   2. Turn user intent back into a Cubit method call.
//
// Everything else — what a loader looks like, what an error screen says, how
// wide the gutter is, how long a transition takes — is decided once, in
// lib/core/theme/ and lib/shared/widgets/, and consumed here.
//
// ---------------------------------------------------------------------------
// THE EXHAUSTIVE SWITCH IS STILL THE POINT
// ---------------------------------------------------------------------------
// `ProductState` is `sealed` (freezed@3.2.5), so Dart's own exhaustiveness
// checking makes forgetting a variant a COMPILE-TIME error rather than a
// silent blank screen. The vendored `no_default_cases` rule (see
// flutter-bootstrap's analysis_options.yaml) is the second line of defence,
// in case somebody reintroduces a `default:` during a later refactor. Adding
// a fifth variant to ProductState must break this file. That is the feature.
//
// ---------------------------------------------------------------------------
// WHAT CHANGED, AND THE STANCE THAT WAS RETIRED
// ---------------------------------------------------------------------------
// A previous revision of this template said it "makes no visual-design
// decisions" and handed typography, spacing, colour and motion to a separate
// UI/UX skill. That is no longer true, and the change is deliberate: this
// template now makes exactly ONE design decision — USE THE DESIGN SYSTEM —
// and then has none left to make, because tokens and shared widgets have
// already made the rest.
//
// Concretely, versus the old version:
//   - `Scaffold` + `AppBar(title: Text('Product'))` -> `AppScaffold(title:
//     l10n.productTitle, ...)`. AppScaffold owns the gutter, the SafeArea,
//     and tap-outside keyboard dismissal (with `excludeFromSemantics: true`,
//     without which every screen fails `labeledTapTargetGuideline`).
//   - `Center(child: CircularProgressIndicator())` -> `AppLoader()`. One
//     spinner size and colour app-wide.
//   - A hand-rolled `_ErrorView` printing 'Error: $message' -> `AppErrorView`,
//     which switches exhaustively on the sealed `AppError` and offers "Try
//     again" / "Sign in" / "Dismiss" according to what the user can actually
//     do about it.
//   - `SizedBox(height: 16)` -> `AppGap(AppGapSize.lg)`.
//   - `Text('Product')` and `'${product.name} — \$${product.price}'` ->
//     `context.l10n.*`, including the currency and date formatting, which are
//     ICU-formatted in the ARB rather than interpolated in Dart.
//   - `_InitialView` returning `SizedBox.shrink()` -> `AppEmptyState` with an
//     action. A screen that renders nothing on its first frame reads as
//     broken; an empty state with a button reads as ready.
//
// The `sdlc-core:ui-ux-mobile` / `sdlc-core:ui-ux-review` handoff still
// exists, but it now happens THROUGH the design system rather than around it:
// those skills change tokens and shared widgets, and every screen inherits
// the change. A screen that hardcodes its own padding is a screen those
// skills cannot fix centrally.
//
// ---------------------------------------------------------------------------
// WHY `unawaited(...)` INSTEAD OF A BARE CALL
// ---------------------------------------------------------------------------
// `ProductCubit.load` returns `Future<void>`, and both call sites here are
// synchronous callbacks. A bare `cubit.load(id)` trips `discarded_futures`.
// `unawaited()` states the intent — fire and forget, the state stream is how
// the result arrives — rather than suppressing the lint. It needs
// `import 'dart:async'`.
//
// ---------------------------------------------------------------------------
// WHAT TO CHANGE WHEN YOU COPY THIS
// ---------------------------------------------------------------------------
//   - Names, the state variants, and the contents of `_LoadedView`.
//   - Add every user-visible string to lib/l10n/arb/app_en.arb with a `@key`
//     description, then run `flutter gen-l10n`. Nothing runs it for you —
//     `flutter test` in particular does not.
//   - Do NOT add a `Color(0x...)`, an `EdgeInsets.all(16)`, a
//     `SizedBox(height: 24)`, a `Duration(milliseconds: 300)`, a
//     `BorderRadius.circular(8)`, or a bare `Text('Save')` to this file or
//     any file under lib/features/. See flutter-slice's SKILL.md, "The UI/UX
//     rule". If a token you need does not exist, ADD IT TO THE TOKEN SET —
//     that is the correct move, and it takes one line.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; // flutter_bloc@9.1.1
import 'package:my_app/core/di/injector.dart';
import 'package:my_app/core/theme/app_tokens.dart';
import 'package:my_app/features/product/domain/product_model.dart';
import 'package:my_app/features/product/presentation/bloc/product_cubit.dart';
import 'package:my_app/features/product/presentation/bloc/product_state.dart';
import 'package:my_app/l10n/l10n.dart';
import 'package:my_app/shared/widgets/app_button.dart';
import 'package:my_app/shared/widgets/app_empty_state.dart';
import 'package:my_app/shared/widgets/app_error_view.dart';
import 'package:my_app/shared/widgets/app_gap.dart';
import 'package:my_app/shared/widgets/app_loader.dart';
import 'package:my_app/shared/widgets/app_scaffold.dart';

/// Shows one product, identified by [productId].
///
/// Owns the `BlocProvider` for its own [ProductCubit] so the widget is
/// self-contained: a route builder, a test, or another screen can drop it in
/// without also knowing how to construct its Cubit.
class ProductScreen extends StatelessWidget {
  /// Creates the screen for the product with [productId].
  const ProductScreen({required this.productId, super.key});

  /// Which product to load. Comes from the route's path parameter — see
  /// lib/features/product/presentation/product_routes.dart.
  final String productId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProductCubit>(
      // `create:` — NOT `BlocProvider.value`. This provider OWNS the Cubit
      // and closes it when the route pops, which is exactly why the Cubit is
      // registered with `registerFactory` (a fresh, open instance per mount).
      // The app-scoped AuthCubit is the one deliberate exception; it is a
      // lazy singleton provided with `.value`. See product_cubit.dart.
      create: (_) {
        final cubit = getIt<ProductCubit>();
        unawaited(cubit.load(productId));
        return cubit;
      },
      child: _ProductView(productId: productId),
    );
  }
}

/// The part of the screen that is BELOW the provider, so `context.read` can
/// find the Cubit. Splitting it out is not ceremony: reading a Cubit from the
/// same `context` that created it is the most common cause of a
/// `ProviderNotFoundException` in a flutter_bloc app.
class _ProductView extends StatelessWidget {
  const _ProductView({required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final motion = Theme.of(context).tokens.motion;

    return AppScaffold(
      title: l10n.productTitle,
      body: BlocBuilder<ProductCubit, ProductState>(
        builder: (context, state) {
          // The state change itself is animated, with token durations and the
          // asymmetric M3 curves: things ENTER decelerating (a soft landing
          // for something the user is waiting for) and LEAVE accelerating
          // (get gone). Using one symmetric curve for both is the tell that
          // nobody thought about it.
          return AnimatedSwitcher(
            duration: motion.fast,
            switchInCurve: motion.enter,
            switchOutCurve: motion.exit,
            // Exhaustive switch over the sealed ProductState. No `default:`.
            // Every branch carries a distinct key so AnimatedSwitcher can
            // tell the subtrees apart — without one it treats a rebuild as
            // the same child and never animates.
            child: switch (state) {
              ProductInitial() => _IdleView(
                key: const ValueKey<String>('product-idle'),
                onLoad: () => _load(context),
              ),
              ProductLoading() => const AppLoader(
                key: ValueKey<String>('product-loading'),
              ),
              ProductLoaded(:final product) => _LoadedView(
                key: const ValueKey<String>('product-loaded'),
                product: product,
              ),
              // AppErrorView derives its icon, headline and action label from
              // the AppError variant, so this screen does not choose error
              // copy at all. Override `headline:`/`retryLabel:` only when a
              // feature genuinely needs different wording.
              ProductError(:final error) => AppErrorView(
                key: const ValueKey<String>('product-error'),
                error: error,
                onRetry: () => _load(context),
              ),
            },
          );
        },
      ),
    );
  }

  void _load(BuildContext context) =>
      unawaited(context.read<ProductCubit>().load(productId));
}

/// Nothing requested yet. An empty state with an action, not a blank frame.
///
/// `AppEmptyState`, not `AppErrorView`: nothing has failed. Rendering a
/// failure for an empty condition is one of the most common and most
/// corrosive UI bugs — it teaches users that the app is broken when it is
/// merely idle.
class _IdleView extends StatelessWidget {
  const _IdleView({required this.onLoad, super.key});

  final VoidCallback onLoad;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppEmptyState(
      icon: Icons.inventory_2_outlined,
      headline: l10n.productEmptyHeadline,
      supporting: l10n.productEmptyBody,
      action: AppButton(label: l10n.productLoad, onPressed: onLoad),
    );
  }
}

/// The loaded product.
///
/// Note what is NOT here: no `Padding`, because `AppScaffold` owns the
/// gutter; no `SizedBox`, because `AppGap` owns spacing; no colour literal,
/// because roles come from `ColorScheme`; no string literal and no `$` sign,
/// because the ARB owns copy, currency and date formatting.
class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.product, super.key});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(product.name, style: theme.textTheme.headlineSmall),
        const AppGap(AppGapSize.sm),
        Text(
          // ICU currency formatting in the ARB, not '\$${product.price}' in
          // Dart. The currency symbol, its position, the decimal separator
          // and the digit grouping are all locale-dependent; hardcoding '$'
          // in front of a `double` gets all four wrong outside en_US.
          l10n.productPrice(product.price),
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const AppGap(AppGapSize.lg),
        Text(
          l10n.productAddedOn(product.createdAt),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
