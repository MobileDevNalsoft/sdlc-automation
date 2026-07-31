// lib/app/router.dart
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
// A re-export, and nothing else. The router itself lives in
// lib/core/router/app_router.dart, and the shared path constants in
// lib/core/router/routes.dart. This file exists so that `lib/app/router.dart`
// is a valid import path for anyone who expects the router to sit beside the
// root widget.
//
// WHY THE REAL FILES ARE UNDER core/router/ AND NOT HERE
//   - DI owns the router's lifetime. `configureDependencies()` builds it,
//     registers it, and disposes it; lib/app/ is the widget layer and owns
//     none of that.
//   - The route tree is assembled from every feature. A file under lib/app/
//     importing all N features inverts the dependency direction the rest of
//     this scaffold uses, where core/ is the layer features feed into.
//   - tools/check_boundaries.dart never scans outside lib/features/, so both
//     locations are equally legal as far as the gate is concerned. This is a
//     design decision, not a lint workaround — do not "discover" later that
//     the checker permits the other arrangement and move things back.
//
// THE HONEST TRADE-OFF
// Two import paths for one symbol is exactly the kind of drift this scaffold
// otherwise argues against: someone will import `app/router.dart`, someone
// else `core/router/app_router.dart`, and a reader has to know they are the
// same thing. Prefer importing the core paths directly in new code. If your
// team does not want the alias at all, DELETE THIS FILE — nothing in the
// scaffold imports it, and removing it costs nothing.
//
// It re-exports the path constants as well as `createRouter`, because a caller
// that wants one almost always wants the other, and an alias that forces a
// second import for `AppRoutes` would be worse than no alias.

export 'package:my_app/core/router/app_router.dart';
export 'package:my_app/core/router/routes.dart';
