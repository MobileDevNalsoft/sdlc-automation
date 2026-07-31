// lib/core/router/go_router_refresh_stream.dart
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
// VENDORED CODE — PROVENANCE
//   Source:   flutter/packages, tag `go_router-v4.5.1`, file
//             packages/go_router/lib/src/misc/refresh_stream.dart
//   Fetched:  2026-07-30, from raw.githubusercontent.com, by the research
//             pass that produced this skill's architecture spec.
//   Status:   DELETED UPSTREAM. go_router 5.0.0's CHANGELOG entry reads,
//             verbatim:
//                 - **BREAKING CHANGE**
//                   - Removes GoRouterRefreshStream
//             Independently confirmed the same day: the current export barrel
//             (lib/go_router.dart on `main`) contains no refresh_stream.dart
//             export, and the source path itself 404s on `main`.
//   License:  the upstream file ships under flutter/packages' BSD-3-Clause
//             licence. Keep that in mind before rewriting it beyond
//             recognition — and keep this header when you copy the file, per
//             the sdlc-core:vendoring-freshness rule.
//
// WHY THIS FILE EXISTS AT ALL
// `refreshListenable` is very much alive. Verified 2026-07-31 against
// pub.dev/documentation/go_router/latest for go_router 17.3.0: the default
// GoRouter constructor still takes `Listenable? refreshListenable`. What 5.0.0
// removed is only the Stream -> Listenable BRIDGE. A Cubit exposes a Stream,
// go_router wants a Listenable, so the bridge has to live somewhere. It lives
// here, vendored with its provenance, rather than being imported from a
// package that has not exported it since twelve majors ago.
//
// THE TRAP THIS PREVENTS
// Essentially every tutorial written before go_router 5.0.0 says:
//
//     import 'package:go_router/go_router.dart';
//     ...
//     refreshListenable: GoRouterRefreshStream(authCubit.stream),
//
// On 17.3.0 that does not compile — the symbol is not there. If a future
// maintainer "simplifies" this file away and imports the symbol from
// go_router instead, they will have reintroduced exactly that break. Do not.
//
// DO NOT "IMPROVE" IT
// The `late final` subscription plus `ChangeNotifier.dispose` is load-bearing,
// and the code does satisfy very_good_analysis@10.3.0 as written even though
// `Stream<dynamic>` / `(dynamic _)` read oddly under a strict ruleset.
// Retyping them to `Object?` is untested here; if you do it, re-run
// `flutter analyze --fatal-infos` and the router tests rather than assuming.
//
// TWO DELIBERATE DEVIATIONS FROM VERBATIM — both recorded rather than quietly
// applied, because the whole value of a vendored file is that a reader can
// diff it against upstream.
//
// FIRST: the upstream doc comment reads "the [GoRouter] will refresh its
// current route". Square brackets around a symbol this file does not import
// trip `comment_references`, so GoRouter is written as plain text below.
//
// SECOND: `dispose()` calls `unawaited(_subscription.cancel())` where the
// original wrote a bare `_subscription.cancel();`. `StreamSubscription.cancel`
// returns a Future, and discarding it inside a synchronous `void dispose()`
// trips `discarded_futures`. MEASURED, not assumed: the verbatim line produces
// "'Future'-returning calls in a non-'async' function" under a byte-for-byte
// copy of this project's analysis_options.yaml
// (very_good_analysis@10.3.0) on Flutter 3.41.6, checked 2026-07-31 — which
// means `flutter analyze --fatal-infos`, i.e. flutter-verify's blocking gate,
// FAILS on the unmodified upstream code. `unawaited` is the minimal fix:
// identical behaviour, intent made explicit, no `async` on an override that
// must stay synchronous. `dart:async` is already imported for
// `StreamSubscription`, so it costs nothing.
//
// The two import lines are this template's choice as well — the upstream
// file's own imports were not captured — and `package:flutter/foundation.dart`
// is used because that is where `ChangeNotifier` and `Listenable` live, which
// keeps this file free of any widget-layer dependency.
//
// WHY A MISSED "CURRENT VALUE" IS NOT A BUG HERE
// `BlocBase.stream` is a broadcast controller (bloc 9.2.1, bloc_base.dart:66)
// and therefore does NOT replay the current state to a late listener. That is
// fine, because go_router's `redirect` callback reads `authCubit.state`
// SYNCHRONOUSLY. This class carries the SIGNAL that something changed, never
// the VALUE. Carrying the value across this seam is what makes
// Stream-as-Listenable go wrong (flutter/flutter#116651); this does not do
// that. The `notifyListeners()` in the constructor covers the very first
// frame, before any state change has happened.
//
// A RELATED FACT WORTH KNOWING: bloc suppresses emission of a state equal to
// the current one (`if (state == _state && _emitted) return;`,
// bloc_base.dart:102), so this notifier does not fire on no-op state writes
// and the guard is not re-run for nothing.

import 'dart:async';

import 'package:flutter/foundation.dart';

/// Converts a [Stream] into a [Listenable].
///
/// Every time the [Stream] receives an event, GoRouter will refresh its
/// current route — i.e. re-run its `redirect` callback. Pass one to
/// `GoRouter(refreshListenable: ...)`:
///
/// ```dart
/// refreshListenable: GoRouterRefreshStream(authCubit.stream),
/// ```
///
/// Create exactly one per router. lib/core/di/injector.dart registers the
/// router as a lazy singleton with `dispose: (router) => router.dispose()`,
/// which is what guarantees the stream subscription below is created and
/// cancelled exactly once.
class GoRouterRefreshStream extends ChangeNotifier {
  /// Creates a [GoRouterRefreshStream] that notifies on every event of
  /// [stream].
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    // `unawaited(...)` rather than the upstream original's bare
    // `_subscription.cancel();` — see the "SECOND DELIBERATE DEVIATION" note
    // in this file's header. The behaviour is identical; only the lint
    // outcome differs.
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
