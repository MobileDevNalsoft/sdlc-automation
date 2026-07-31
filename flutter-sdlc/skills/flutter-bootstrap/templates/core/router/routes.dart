// lib/core/router/routes.dart
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
// Every route path that more than one part of the app needs to name, in one
// core-owned place. It is the mechanism that lets feature A navigate to
// feature B WITHOUT importing feature B.
//
// WHY IT LOOKS LIKE THIS
// tools/check_boundaries.dart fails the build when a file under
// lib/features/<a>/ imports lib/features/<b>/. Navigation is the single most
// common reason someone reaches for that import — "I need ProfileScreen so I
// can push it". You do not need it:
//
//   context.go(AppRoutes.profile);
//
// That is a String owned by core, not a symbol owned by feature B. The
// boundary holds, navigation still works, and the two features stay
// independently deletable. If you catch yourself adding
// `import 'package:my_app/features/b/...'` to feature A purely to reach a
// screen, add the destination here instead.
//
// WHICH PATHS BELONG HERE, AND WHICH DO NOT
//   - HERE: anything another feature, the auth guard, a deep link, or a push
//     notification payload needs to name.
//   - NOT HERE: a feature's internal sub-paths — a detail route reached only
//     from that feature's own list screen, for instance. Those live beside
//     the routes that build them, in
//     lib/features/<f>/presentation/<f>_routes.dart, so a feature's private
//     URL structure stays private and this file does not become a dumping
//     ground that every slice edits.
//
// WHAT TO CHANGE WHEN YOU COPY THIS
//   - Add one `static const String` per shared destination, with a doc
//     comment (`public_member_api_docs` is on).
//   - Keep the entries sorted. Nothing lints this for you; an unsorted
//     registry stops being skimmable at about a dozen routes.
//   - Keep values absolute (leading slash) and lower-case. go_router 15.0.0's
//     CHANGELOG (fetched 2026-07-30) says verbatim: "**BREAKING CHANGE** URLs
//     are now case sensitive." — so `/Profile` and `/profile` are two
//     different routes on the pinned 17.3.0, and only one of them exists.
//
// WHY THERE ARE NO ROUTE *NAMES* HERE
// go_router also supports named routes (`GoRoute(name: 'profile')` plus
// `context.goNamed('profile')`). This scaffold uses paths only, on purpose: a
// name is a second parallel namespace that must be kept in sync with the path
// by hand, and it buys nothing here because these constants are already
// compile-checked identifiers — a typo in `AppRoutes.profil` does not
// compile, whereas a typo in `goNamed('profil')` throws at runtime. Adopt
// names only if you specifically want `namedLocation()` for building URLs
// with parameters, and then declare them in this same class so there is still
// exactly one registry rather than two.

/// Every shared route path in the app, owned by `core` so that no feature has
/// to import another feature in order to navigate to it.
///
/// Declared `abstract final` so it can be neither instantiated nor extended:
/// it is a namespace for constants, not a type.
///
/// ```dart
/// context.go(AppRoutes.login);
/// ```
abstract final class AppRoutes {
  /// The signed-in landing destination, and the app's initial location.
  ///
  /// Kept at the root so a cold start with no deep link resolves here and the
  /// auth guard — not the route table — decides whether the user is allowed
  /// to stay.
  static const String home = '/';

  /// The unauthenticated entry point.
  ///
  /// The auth guard in lib/core/router/app_router.dart redirects here from
  /// anywhere else whenever the in-memory auth state is not authenticated,
  /// and redirects away from here once it is. Nothing else should hard-code
  /// the string '/login'.
  static const String login = '/login';
}
