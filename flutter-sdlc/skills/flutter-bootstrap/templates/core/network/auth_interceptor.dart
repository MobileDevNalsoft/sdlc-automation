// lib/core/network/auth_interceptor.dart
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
// Two jobs in one interceptor: stamp `Authorization` on every outgoing
// request, and, on a 401, refresh the token exactly once and replay the
// requests that failed — without the caller ever learning a 401 happened.
//
// This is the subtlest file in the network layer. Read the next three notes
// before changing anything in it.
//
// ------------------------------------------------------------------
// NOTE 1 — WHY IT EXTENDS QueuedInterceptor, NOT Interceptor
// ------------------------------------------------------------------
// `QueuedInterceptor` is what provides single-flight refresh. There is no
// mutex, `Completer`, or `bool _isRefreshing` flag in this file, and there
// must not be one.
//
// From dio's `interceptor.dart` (read 2026-07-30 from
// raw.githubusercontent.com/cfug/dio/main/dio/lib/src/interceptor.dart), a
// `QueuedInterceptor` holds THREE separate per-instance task queues:
//
//     final _requestQueue  = _TaskQueue<RequestOptions,  ...>();
//     final _responseQueue = _TaskQueue<Response,        ...>();
//     final _errorQueue    = _TaskQueue<DioException,    ...>();
//
// Each `_TaskQueue` is a `Queue` plus a `bool processing`; a task starts only
// when `!processing`, and the queue advances ONLY when you call
// `handler.next` / `resolve` / `reject`. That serialization of `_errorQueue`
// IS the entire single-flight guarantee: N concurrent 401s enter the error
// queue, the first one refreshes, and requests 2..N are handled one at a time
// afterwards — by which point the stale-token check in [onError] short-
// circuits them straight to a replay.
//
// Use a plain `Interceptor` here and N concurrent 401s each fire their own
// refresh; on any backend with refresh-token rotation, N-1 of those
// invalidate the winner and the user is signed out. That failure only appears
// under concurrency, which is why the fake-adapter test described in NOTE 3
// ships with this scaffold.
//
// TWO CONSEQUENCES OF "per-instance" THAT ARE EASY TO BREAK:
//   - Register this as a LAZY SINGLETON. A second instance has its own
//     queues and defeats the guarantee outright.
//   - Install it on exactly one `Dio`. Two Dios sharing one instance is fine
//     (the queues are shared, which is what you want); one Dio with two
//     instances is not.
//
// ------------------------------------------------------------------
// NOTE 2 — WHY THE REPLAY GOES THROUGH A SEPARATE, INTERCEPTOR-FREE Dio
// ------------------------------------------------------------------
// THIS IS A DEADLOCK, NOT A STYLE PREFERENCE. Do not "simplify" it away.
//
// The queues are per instance AND per phase. A refresh call issued on the
// SAME Dio enters `_requestQueue` — a different queue, so that part is fine.
// But if the refresh FAILS, its `DioException` enters `_errorQueue`, which is
// at that moment `processing == true` and is awaiting *you*. The awaited call
// can never complete.
//
// There is no timeout on the queue. The app HANGS. It does not error, it does
// not report to Sentry, and it does not surface in any test that does not use
// a failing refresh. dio's own upstream example
// (example_dart/lib/queued_interceptor_crsftoken.dart, read 2026-07-30) uses
// a fresh `Dio` for exactly this reason.
//
// So: `replayClient` must be the interceptor-free `Dio` registered under
// `instanceName: 'replayClient'`, and whatever object implements
// [RefreshToken] must ALSO use that client for its refresh request.
//
// ------------------------------------------------------------------
// NOTE 3 — HOW TO ACTUALLY TEST THIS
// ------------------------------------------------------------------
// `class MockDio extends Mock implements Dio {}` proves NOTHING here — it
// bypasses the interceptor chain entirely. Swap the adapter instead:
// `dio.httpClientAdapter` is a settable `HttpClientAdapter` and the interface
// is two methods. Have a fake adapter return 401 for the first N calls and
// 200 afterwards, fire five concurrent requests, and assert the refresh
// callback ran EXACTLY ONCE while all five futures completed successfully.
//
// That is the test that catches a plain `Interceptor` being used where a
// `QueuedInterceptor` was needed, and it is the only kind that can.
//
// ------------------------------------------------------------------
// WHAT TO CHANGE WHEN YOU COPY THIS
// ------------------------------------------------------------------
//   - Supply a real [RefreshToken]. The scaffold's `configureDependencies`
//     wires a stub that returns null (= "cannot refresh, sign out"), which is
//     the correct behaviour until a refresh endpoint exists.
//   - If your API uses a header other than `Authorization` or a scheme other
//     than `Bearer`, change the two constants below — and nothing else.
//   - If some endpoints must NOT carry a token (a public config endpoint, the
//     refresh endpoint itself), do NOT add a URL allowlist here. Issue those
//     through the interceptor-free replay client instead; a growing list of
//     path patterns inside an interceptor is a well-known source of
//     "why is my token being sent to a third party" incidents.
//
// ASSUMPTION: this template has not been exercised against a real refreshing
// backend. The mechanism (QueuedInterceptor's `_errorQueue`, `Dio.fetch`,
// handler semantics) was verified from dio's source and API docs on
// 2026-07-30, but no end-to-end 401-refresh round trip against a live server
// was performed. Test it with the fake adapter above before trusting it.

import 'package:dio/dio.dart';
import 'package:my_app/core/storage/secure_store.dart';
import 'package:my_app/core/storage/storage_keys.dart';

/// Obtains a fresh access token, or null if the session cannot be recovered.
///
/// The implementation is responsible for BOTH calling the refresh endpoint
/// (through the interceptor-free replay client — see NOTE 2 in this file's
/// header) AND persisting the new token to [SecureStore] before returning it.
/// [AuthInterceptor] does not write the token itself, because the refresh
/// response usually also carries a new refresh token and an expiry that only
/// the auth Repository knows how to store.
///
/// Returning null means "this session is unrecoverable": the interceptor
/// clears secure storage and lets the original 401 through, which becomes an
/// `UnauthorizedError` and, via `AuthCubit`, a redirect to the login route.
typedef RefreshToken = Future<String?> Function();

/// Attaches the access token to every request and performs a single-flight
/// token refresh with replay on 401.
///
/// Must be registered as a lazy singleton and installed FIRST in the
/// interceptor chain — dio runs its error chain in the same FIFO order as its
/// request chain, so first-added is first to see a 401. Placed after
/// `RetryInterceptor`, a merely-expired token would burn the whole retry
/// budget (and hammer the server) before anyone tried to refresh it.
class AuthInterceptor extends QueuedInterceptor {
  /// Creates the interceptor.
  ///
  /// [replayClient] MUST be a `Dio` with no interceptors installed — see
  /// NOTE 2 in this file's header for the deadlock this avoids.
  AuthInterceptor({
    required SecureStore secureStore,
    required Dio replayClient,
    required RefreshToken refreshToken,
  }) : _secureStore = secureStore,
       _replayClient = replayClient,
       _refreshToken = refreshToken;

  static const String _authorizationHeader = 'Authorization';
  static const String _bearerPrefix = 'Bearer ';
  static const int _unauthorizedStatus = 401;

  final SecureStore _secureStore;
  final Dio _replayClient;
  final RefreshToken _refreshToken;

  /// Stamps `Authorization: Bearer <token>` when a token is stored.
  ///
  /// Absence is not an error: unauthenticated calls (sign-in, sign-up, a
  /// public catalogue) go out unstamped and the server decides. Sending
  /// `Bearer null` would be worse than sending nothing.
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _secureStore.read(StorageKeys.accessToken);
    if (token != null && token.isNotEmpty) {
      options.headers[_authorizationHeader] = '$_bearerPrefix$token';
    }
    handler.next(options);
  }

  /// Refreshes and replays on 401; passes everything else along untouched.
  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != _unauthorizedStatus) {
      // `next`, NOT `resolve`. dio's own CSRF example calls
      // `handler.resolve(error.response!)` for non-matching errors, which
      // FABRICATES A SUCCESS out of an error response — copy that and every
      // 500 looks like a successful response to every Repository. This
      // template deliberately diverges from upstream here.
      handler.next(err);
      return;
    }

    // The stale-token guard. This is what makes requests 2..N of a
    // concurrent burst cheap: while this one sat in `_errorQueue`, an
    // earlier task may already have refreshed. Comparing what WAS sent
    // against what is stored NOW detects that without any shared flag.
    //
    // Left as `dynamic` from `headers` (a `Map<String, dynamic>`) on
    // purpose — `==`/`!=` are declared on `Object`, so this is not a dynamic
    // invocation and `avoid_dynamic_calls` does not apply. A cast here would
    // add a throw path for a header some proxy rewrote.
    final sentHeader = err.requestOptions.headers[_authorizationHeader];
    final storedToken = await _secureStore.read(StorageKeys.accessToken);

    if (storedToken != null && sentHeader != '$_bearerPrefix$storedToken') {
      await _replay(err, storedToken, handler);
      return;
    }

    final freshToken = await _refreshToken();
    if (freshToken == null) {
      // Unrecoverable. Clearing here (rather than leaving it to the UI) means
      // the next request cannot re-send a token the server has rejected.
      await _secureStore.clear();
      handler.next(err);
      return;
    }

    await _replay(err, freshToken, handler);
  }

  /// Re-issues the failed request with [token] and resolves the ORIGINAL
  /// caller's future with the result.
  ///
  /// `handler.resolve(response)` completes the future the Repository is
  /// awaiting, so the caller never learns that a 401 and a refresh happened
  /// in between. That is the whole user-visible point of this class.
  Future<void> _replay(
    DioException err,
    String token,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions
      ..headers[_authorizationHeader] = '$_bearerPrefix$token';
    try {
      // `fetch` is dio's documented single entry point: "The eventual method
      // to submit requests. All callers for requests should eventually go
      // through this method." Using it (rather than re-deriving
      // get/post/put) preserves body, query, cancel token and extras.
      final response = await _replayClient.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (e) {
      // The replay itself failed. Pass the REPLAY's error on rather than the
      // original 401 — it describes what actually stopped the request now,
      // and the original is no longer the interesting failure.
      handler.next(e);
    }
  }
}
