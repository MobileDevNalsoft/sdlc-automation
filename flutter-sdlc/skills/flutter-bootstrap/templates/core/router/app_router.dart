// lib/core/router/app_router.dart
//
// WHAT THIS IS
// The ONE place that assembles the app's route tree, and the ONE place
// allowed to import every feature's routes file. `createRouter()` is called
// exactly once, from `configureDependencies()` in lib/core/di/injector.dart,
// and the resulting GoRouter is handed to `MaterialApp.router` by
// lib/app/app.dart. Nothing else constructs a router.
//
// PINNED VERSION AND EVIDENCE
// go_router 17.3.0 — fetched from pub.dev/api/packages/go_router on
// 2026-07-31: latest 17.3.0, published 2026-06-02T22:38:52Z, environment
// `sdk: ^3.10.0, flutter: >=3.38.0`. First-party (flutter/packages). It
// raises the project's effective Flutter floor to 3.38.0, which is why
// pubspec.yaml declares an explicit `flutter:` key in `environment:`.
// Constructor parameters used below (`redirectLimit = 5`,
// `debugLogDiagnostics = false`, `Listenable? refreshListenable`) verified
// against the same source. Toolchain: Flutter 3.41.6 / Dart 3.11.4.
//
// WHY THE ROUTER LIVES IN core/ AND NOT IN lib/app/
// Because DI owns its lifetime and features contribute to it. lib/app/ is the
// widget layer; a file there importing every feature would invert the
// dependency direction the rest of this scaffold uses. lib/app/router.dart
// exists as a thin re-export for anyone who expects that path.
//
// WHY A CENTRAL AGGREGATOR DOES NOT BREAK tools/check_boundaries.dart
// Read off the checker itself, not assumed:
//   1. It walks `Directory('lib/features')` and nothing else. Files outside
//      lib/features/ are never opened, so THIS file importing every feature
//      is invisible to it. That is not a loophole — the script's own header
//      names lib/core and lib/shared as the two allowed shared layers.
//   2. Its regex is `import\s+['"]package:$pkg/features/([^/'"]+)/` and it
//      records a violation only when the captured feature name differs from
//      the feature directory the importing file lives in. An import of
//      `package:<pkg>/core/...` cannot match that pattern at all.
//
// THIS FILE IS ALSO THE SEAM BETWEEN THE TWO FEATURES. `home` needs the
// signed-in email and a sign-out action, both of which live in `auth`. It may
// not import `auth` (the checker would fail the build, correctly). So this
// file — which is outside lib/features/ and already holds the app-scoped
// AuthCubit — reads them out of auth state and passes them to `homeRoutes` as
// a getter and a callback. Neither feature knows the other exists.
//
// HOW A NEW FEATURE ADDS ITS ROUTES: declare `List<RouteBase> get <f>Routes`
// in lib/features/<f>/presentation/<f>_routes.dart, add one import here and
// one `...<f>Routes` spread below. This file gains two lines per feature.
// Anything another feature must navigate to gets its path in
// lib/core/router/routes.dart as an `AppRoutes` constant; feature A then
// calls `context.go(AppRoutes.b)` — a String from core, never a symbol from
// feature B.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:my_app/core/router/go_router_refresh_stream.dart';
import 'package:my_app/core/router/routes.dart';
import 'package:my_app/features/auth/presentation/auth_routes.dart';
import 'package:my_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:my_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:my_app/features/home/presentation/home_routes.dart';

/// Builds the app's [GoRouter].
///
/// [authCubit] MUST be the app-scoped instance from DI — the guard reads its
/// state on every navigation, so a second instance would guard against state
/// the UI never changes.
///
/// Call this exactly once, from `configureDependencies()`, and register the
/// result so the whole app shares one router:
///
/// ```dart
/// getIt.registerLazySingleton<GoRouter>(
///   () => createRouter(getIt<AuthCubit>()),
///   dispose: (router) => router.dispose(),
/// );
/// ```
///
/// The `dispose` callback is not optional bookkeeping: the router owns a
/// `GoRouterRefreshStream`, which owns a stream subscription. One router means
/// one subscription, created and cancelled exactly once.
GoRouter createRouter(AuthCubit authCubit) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    // Logs route resolution and every redirect decision. Gated on kDebugMode
    // so the diagnostics — which include matched locations, i.e. potentially
    // user identifiers in path parameters — never reach a release build's log.
    debugLogDiagnostics: kDebugMode,
    // The Stream -> Listenable bridge go_router DELETED in 5.0.0 and this
    // project vendors back (lib/core/router/go_router_refresh_stream.dart).
    // Any tutorial importing GoRouterRefreshStream from package:go_router is
    // twelve majors stale and does not compile.
    refreshListenable: GoRouterRefreshStream(authCubit.stream),
    redirect: (context, state) {
      // EXHAUSTIVE switch over the sealed AuthState, not
      // `is AuthAuthenticated`. `no_default_cases` plus sealed exhaustiveness
      // means adding a fifth state variant becomes a compile error RIGHT
      // HERE, which forces someone to decide whether it counts as signed in.
      // The `is` shorthand would silently treat every future variant as
      // signed out.
      final signedIn = switch (authCubit.state) {
        AuthAuthenticated() => true,
        AuthInitial() || AuthLoading() || AuthError() => false,
      };
      final atLogin = state.matchedLocation == AppRoutes.login;

      // `atLogin ? null : AppRoutes.login` — NOT a bare `AppRoutes.login`.
      // Returning null means "no redirect". go_router's own upstream example
      // computes a `loggingIn` flag and then does not use it on this branch,
      // so a signed-out user already at /login is redirected to /login again.
      // `redirectLimit` defaults to 5 and exceeding it renders an error
      // screen instead of the app.
      if (!signedIn) {
        return atLogin ? null : AppRoutes.login;
      }
      return atLogin ? AppRoutes.home : null;
    },
    routes: <RouteBase>[
      ...authRoutes,
      // The cross-feature seam. See this file's header: home may not import
      // auth, so the two values it needs are resolved here and handed over as
      // plain Dart.
      ...homeRoutes(
        // A getter, not a value: this list is built ONCE at startup, when
        // nobody is signed in. Evaluating it inside `builder:` is what makes
        // it current.
        currentEmail: () => switch (authCubit.state) {
          AuthAuthenticated(:final user) => user.email,
          // Unreachable in practice — the guard above sends a signed-out user
          // to /login before this route ever builds. It is still written out
          // rather than defaulted, because `no_default_cases` forbids the
          // catch-all and because "unreachable" is a claim that stops being
          // true the day someone adds a route outside the guard.
          AuthInitial() || AuthLoading() || AuthError() => '',
        },
        // Changes state only. The guard turns that emission into the
        // navigation; a `context.go` here would race it.
        onSignOut: () => unawaited(authCubit.signOut()),
      ),
    ],
  );
}
