// lib/core/network/dio_client.dart
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
// NAMING NOTE: some briefs call this file `api_client.dart`. It is named
// `dio_client.dart` here to match the target architecture's `lib/` tree, and
// because what it builds IS a configured `Dio` — not a wrapper type that
// hides one. If you rename it, rename it consistently; nothing else in the
// scaffold depends on the filename.
//
// WHAT THIS IS
// The two factory functions that build this app's HTTP clients:
//   - [buildDio] — the shared, fully-interceptored client every Service uses.
//   - [buildReplayDio] — a bare, INTERCEPTOR-FREE client used only for token
//     refresh and for replaying a request after a refresh.
// Both are registered in lib/core/di/injector.dart; nothing else calls them.
//
// WHY THERE IS DELIBERATELY NO `ApiClient` WRAPPER CLASS
// A `class ApiClient { Future<T> get<T>(...) }` around `Dio` would have to
// re-expose query parameters, headers, cancel tokens, progress callbacks,
// `FormData` and response types one at a time, and would be permanently one
// feature behind dio. Services take a `Dio` directly. The abstraction that
// actually earns its keep is one layer up: the Repository, which converts
// exceptions into `Result<T>` and is the seam tests mock.
//
// ------------------------------------------------------------------
// THE INTERCEPTOR ORDER IS NOT ARBITRARY — TWO FACTS FULLY DETERMINE IT
// ------------------------------------------------------------------
// FACT 1 (fetched 2026-07-30 from
// pub.dev/documentation/dio/latest/dio/Interceptors-class.html, verbatim):
// "A Queue-Model list for Interceptors. Interceptors will be executed with
// FIFO." Confirmed in dio's `dio_mixin.dart`, which loops over the same
// collection in the same direction for the request, response AND error
// phases. Unlike Axios or OkHttp middleware, the error chain is NOT unwound
// in reverse. Therefore THE FIRST-ADDED INTERCEPTOR IS ALSO THE FIRST TO SEE
// AN ERROR.
//
// FACT 2 (from `LogInterceptor`'s own API docs, fetched the same day,
// verbatim): "LogInterceptor is used to print logs during network requests.
// It should be the last interceptor added, otherwise modifications by
// following interceptors will not be logged."
//
// Those two constraints leave exactly one valid order:
//
//   1. AuthInterceptor  — must be FIRST so it gets first refusal on a 401 and
//                         can refresh + replay before anything downstream
//                         treats the failure as terminal. Swap it with retry
//                         and an expired token burns the entire retry budget
//                         (and hammers the server) before anyone refreshes.
//   2. RetryInterceptor — sees only errors auth chose to pass on, so it never
//                         wastes attempts on a merely-expired token. Its
//                         replays re-enter the whole chain and pick up the
//                         refreshed token for free. Swap it with logging and
//                         retried attempts become invisible: you see one
//                         request where three happened.
//   3. LogInterceptor   — last, per FACT 2, so it observes the final headers
//                         and the post-retry outcome. Added first it logs a
//                         request with no `Authorization` header at all,
//                         which is actively misleading when debugging auth.
//
// ------------------------------------------------------------------
// THE kDebugMode GATE ON LOGGING IS A SECURITY CONTROL, NOT A PREFERENCE
// ------------------------------------------------------------------
// Because `LogInterceptor` is last, it sees the injected `Authorization`
// header. Unguarded, a release build writes bearer tokens to the device log,
// where any other process with log access can read them. The `if (kDebugMode)`
// below is what prevents that. `logPrint: debugPrint` is also required, not
// cosmetic: `print` trips `avoid_print`, and dio's docs say "When used in
// Flutter, make sure to use `debugPrint`" because plain `print` gets
// throttled and truncated by the platform log.
//
// Consider redacting the token even in debug — a screenshot of a debug
// console in a bug report is a credential leak too.
//
// ------------------------------------------------------------------
// ERROR MAPPING IS NOT IN THIS CHAIN — ON PURPOSE
// ------------------------------------------------------------------
// See dio_error_mapper.dart's header. Short version:
// `ErrorInterceptorHandler.reject` accepts a `DioException` and nothing else,
// so an interceptor physically cannot emit an `AppError`; and the last slot
// is already taken by logging. Repositories call `mapDioException` instead.
//
// WHAT TO CHANGE WHEN YOU COPY THIS
//   - Timeouts: the values below are scaffold defaults, not measurements —
//     see the ASSUMPTION on each constant.
//   - Add a `CurlInterceptor`, tracing, or a correlation-ID interceptor
//     BETWEEN retry and logging, so logging still runs last.
//   - If you need a second `baseUrl` (a separate media or auth host), build a
//     second `Dio` here with its own factory and register it under a named
//     instance — do NOT mutate `dio.options.baseUrl` at call time; it is
//     shared mutable state on a singleton.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:my_app/core/config/flavor_config.dart';
import 'package:my_app/core/network/auth_interceptor.dart';
import 'package:my_app/core/network/retry_interceptor.dart';

/// Time allowed to open the connection.
///
/// ASSUMPTION: 10 seconds is a conventional mobile default, not a value
/// measured against any real backend. dio's `BaseOptions` declares all four
/// timeouts as `Duration?` with no documented default (verified from
/// pub.dev/documentation/dio/latest/dio/BaseOptions-class.html on
/// 2026-07-30), and — a second ASSUMPTION — a null timeout is taken to mean
/// "no timeout"; the API docs state the nullable type but never state the
/// null semantics. Either way, setting them explicitly is required: a request
/// that hangs forever is indistinguishable from a frozen app.
const Duration kConnectTimeout = Duration(seconds: 10);

/// Time allowed to receive the response after the request is sent.
///
/// ASSUMPTION: 20 seconds, same basis as [kConnectTimeout]. Raise it for
/// endpoints that stream or generate reports; do not raise it globally to
/// accommodate one slow endpoint — pass a per-request `Options` instead.
const Duration kReceiveTimeout = Duration(seconds: 20);

/// Time allowed to send the request body.
///
/// ASSUMPTION: 20 seconds, same basis as [kConnectTimeout]. This is the one
/// to raise for file uploads over a poor connection.
const Duration kSendTimeout = Duration(seconds: 20);

/// get_it instance name for the interceptor-free replay client.
///
/// Lives here rather than in the injector so that the one thing that must
/// never drift — the string identifying "the Dio with no interceptors" — is
/// declared next to the factory that builds it.
const String kReplayClientName = 'replayClient';

/// Builds the shared, fully-configured HTTP client.
///
/// Register it as a LAZY SINGLETON: one instance means one connection pool
/// and, more importantly, exactly one installed interceptor chain. Building a
/// second one silently doubles the auth logic and gives it a second
/// `AuthInterceptor` queue, defeating the single-flight refresh guarantee.
///
/// [authInterceptor] is injected rather than constructed here so that the
/// same lazy-singleton instance is shared, and so a test can install a fake.
Dio buildDio({
  required FlavorConfig config,
  required AuthInterceptor authInterceptor,
}) {
  final dio = Dio(_baseOptions(config));

  dio.interceptors.addAll(<Interceptor>[
    // 1. Auth first: first-added is first to see a 401 (FACT 1 above).
    authInterceptor,
    // 2. Retry second: only errors auth passed on, replayed through `dio`
    //    itself so the whole chain (including a refreshed token) applies.
    RetryInterceptor(dio: dio),
    // 3. Logging last, and only in debug — see the security note above.
    //    `logPrint: debugPrint` DOES NOT COMPILE (verified 2026-07-30 on
    //    Flutter 3.41.6 / dio 5.11.0): `LogInterceptor.logPrint` is
    //    `void Function(Object)`, while `debugPrint` is a
    //    `DebugPrintCallback`, i.e. `void Function(String?, {int? wrapWidth})`
    //    — the two are not assignable. The adapter closure below is required.
    if (kDebugMode)
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (object) => debugPrint('$object'),
      ),
  ]);

  return dio;
}

/// Builds the bare, INTERCEPTOR-FREE client used for token refresh and for
/// replaying a request after a refresh.
///
/// This client's emptiness is a hard requirement, not an optimisation.
/// `AuthInterceptor` extends `QueuedInterceptor`, whose error queue is
/// serialized: a refresh issued on the main client would, if it FAILED, put
/// its own `DioException` into an error queue that is already processing and
/// awaiting the refresh. There is no timeout on that queue — the app hangs
/// rather than erroring. See auth_interceptor.dart's NOTE 2.
///
/// Register it under [kReplayClientName]:
///
/// ```dart
/// getIt.registerLazySingleton<Dio>(
///   () => buildReplayDio(getIt<FlavorConfig>()),
///   instanceName: kReplayClientName,
/// );
/// ```
///
/// Whatever implements the refresh call must use THIS client. Anything you
/// add to it — a logger, a tracing hook, "just one" retry — reintroduces the
/// hang, so it takes no interceptor parameters at all by design.
Dio buildReplayDio(FlavorConfig config) => Dio(_baseOptions(config));

/// Shared `BaseOptions` so the two clients cannot drift apart on timeouts or
/// base URL.
///
/// `baseUrl` comes from the injected [FlavorConfig] and is read in exactly
/// this one place in the whole app. That is what lets every Service issue
/// relative paths (`/products/$id`) and stay ignorant of flavors entirely.
BaseOptions _baseOptions(FlavorConfig config) => BaseOptions(
  baseUrl: config.apiBaseUrl,
  connectTimeout: kConnectTimeout,
  receiveTimeout: kReceiveTimeout,
  sendTimeout: kSendTimeout,
  // Content-Type is deliberately absent: dio sets it per request from the
  // body type, and pinning it here breaks multipart uploads.
  headers: const <String, String>{'Accept': 'application/json'},
);
