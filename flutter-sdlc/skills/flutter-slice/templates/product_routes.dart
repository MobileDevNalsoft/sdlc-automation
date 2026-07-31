// lib/features/product/presentation/product_routes.dart
//
// TEMPLATE — copy to lib/features/<feature>/presentation/<feature>_routes
// .dart, rename every `Product`/`product` identifier, and replace the
// placeholder package name `my_app` in the imports below with your own
// package name (the `name:` field of pubspec.yaml).
//
// WHAT THIS IS
// The feature's own slice of the route table. Each feature owns its routes;
// lib/core/router/app_router.dart is the ONE aggregator that imports every
// feature's routes file and spreads them into a single `GoRouter`.
//
// This file did not exist in the previous version of this skill, which said
// go_router was "its own separate, recommended-not-required decision" and
// that "nothing here assumes it's present". That is reversed: go_router
// 17.3.0 is now part of the stack, and a route is part of a slice. A feature
// with no route is a feature nobody can reach.
//
// ---------------------------------------------------------------------------
// WHY THE ROUTES LIVE IN THE FEATURE AND THE AGGREGATOR LIVES IN core/
// ---------------------------------------------------------------------------
// Read straight off tools/check_boundaries.dart, not guessed:
//
//   1. It only walks `Directory('lib/features')`. Files outside
//      lib/features/ are NEVER SCANNED. So lib/core/router/app_router.dart
//      importing all N features is invisible to it — legal by construction,
//      needing no exemption.
//   2. Its regex matches `import\s+['"]package:$pkg/features/([^/'"]+)/` and
//      flags a match only when the captured feature name differs from the
//      feature the importing file lives in.
//
// Therefore this file may import its OWN feature's screens freely (the
// capture equals the owning feature), and the aggregator in core/ may import
// every feature's routes file. What must NOT happen is feature A importing
// feature B's screen in order to navigate to it.
//
// CROSS-FEATURE NAVIGATION CARRIES NO IMPORT. Feature A calls
// `context.go(AppRoutes.profile)` — a String owned by lib/core/router/
// routes.dart, not a symbol owned by feature B. The boundary holds and
// navigation still works. If you catch yourself importing another feature
// just to reach a screen, add the destination to `AppRoutes` instead.
//
// ---------------------------------------------------------------------------
// WHICH PATHS GO WHERE
// ---------------------------------------------------------------------------
//   - lib/core/router/routes.dart (`AppRoutes`) — any destination another
//     feature, the auth guard, a deep link, or a push payload must name.
//   - THIS FILE (`ProductPaths`) — the feature's internal sub-paths: a detail
//     route reached only from this feature's own list screen, an edit route
//     reached only from the detail screen. Keeping them private is what stops
//     `AppRoutes` becoming a dumping ground that every slice edits (and
//     therefore every slice conflicts in).
//
// Keep values absolute (leading slash) and lower-case. go_router 15.0.0's
// CHANGELOG says verbatim (fetched 2026-07-30): "**BREAKING CHANGE** URLs are
// now case sensitive." On the pinned 17.3.0, `/Product/7` and `/product/7`
// are two different routes and only one of them exists.
//
// ---------------------------------------------------------------------------
// TYPED PARAMETERS WITHOUT CODEGEN
// ---------------------------------------------------------------------------
// `state.pathParameters` is a `Map<String, String>`. Every route that takes a
// parameter parses it HERE, colocated with the route, and FAILS CLOSED — a
// missing or unparseable parameter renders a real screen, never a null
// dereference and never a blank frame. One extractor per route gives the
// compile-time safety that motivates `go_router_builder` without adopting a
// second codegen chain (which is rejected on policy — see flutter-bootstrap's
// cut list, where it is stated honestly that go_router_builder WOULD resolve
// against this project's analyzer ceiling; it is a policy rejection, not an
// arithmetic one).
//
// This feature's id is a `String`, so "fail closed" means checking for
// missing/empty. When the id is numeric the shape is:
//
//     final id = int.tryParse(state.pathParameters['id'] ?? '');
//     if (id == null) {
//       return const _InvalidProductScreen();
//     }
//     return ProductScreen(productId: id);
//
// ---------------------------------------------------------------------------
// WHAT TO CHANGE WHEN YOU COPY THIS
// ---------------------------------------------------------------------------
//   - Names, paths, and one `GoRoute` per screen.
//   - Add `...productRoutes` to the `routes:` list in
//     lib/core/router/app_router.dart, and one import for this file. That is
//     the ONLY edit a slice makes to a core file's route table.
//   - Nest sub-routes as `routes:` children of their parent `GoRoute` when
//     the child is genuinely a sub-location of the parent, so the back stack
//     is correct on a deep link. Do not nest them merely because they belong
//     to the same feature.
//   - If a route must be reachable from another feature, put its path in
//     `AppRoutes` and reference it from here — do not duplicate the string.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // go_router@17.3.0
import 'package:my_app/features/product/presentation/screens/product_screen.dart';
import 'package:my_app/l10n/l10n.dart';
import 'package:my_app/shared/widgets/app_empty_state.dart';
import 'package:my_app/shared/widgets/app_scaffold.dart';

/// Route paths owned by the product feature.
///
/// Declared `abstract final` so it can be neither instantiated nor extended:
/// it is a namespace for constants, not a type. Paths that another feature
/// needs to name belong in `AppRoutes` (lib/core/router/routes.dart), not
/// here.
abstract final class ProductPaths {
  /// The product detail route, with its `:id` path parameter.
  ///
  /// This is the PATTERN, not a location — pass it to `GoRoute(path:)`. To
  /// navigate, use [detailFor], which fills the parameter in.
  static const String detail = '/product/:id';

  /// Builds the concrete detail location for the product with [id].
  ///
  /// Exists so no caller ever writes `'/product/$id'` by hand. A hand-built
  /// location is a string that silently stops matching the moment [detail]
  /// changes; this one stops COMPILING, which is the difference.
  static String detailFor(String id) => '/product/$id';
}

/// Routes owned by the product feature.
///
/// Spread into the root route table by lib/core/router/app_router.dart:
/// `routes: <RouteBase>[...authRoutes, ...productRoutes]`.
List<RouteBase> get productRoutes => <RouteBase>[
  GoRoute(
    path: ProductPaths.detail,
    builder: (context, state) {
      // Fail closed. A deep link, a push notification payload, or a typo can
      // all deliver a route with no usable id; none of them should produce a
      // crash or a blank screen.
      final id = state.pathParameters['id'];
      if (id == null || id.isEmpty) {
        return const _InvalidProductScreen();
      }
      return ProductScreen(productId: id);
    },
  ),
];

/// Rendered when the route's `:id` parameter is missing or empty.
///
/// Private, and a real screen rather than a `SizedBox.shrink()`: an
/// unreachable-looking blank page is indistinguishable from a hang. It uses
/// `AppEmptyState` rather than `AppErrorView` because nothing failed — the
/// address was simply not a product.
class _InvalidProductScreen extends StatelessWidget {
  const _InvalidProductScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppScaffold(
      title: l10n.productTitle,
      body: AppEmptyState(
        icon: Icons.link_off_rounded,
        headline: l10n.productNotFoundHeadline,
        supporting: l10n.productNotFoundBody,
      ),
    );
  }
}
