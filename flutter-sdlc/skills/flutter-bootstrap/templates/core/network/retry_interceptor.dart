// lib/core/network/retry_interceptor.dart
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
// A small, owned retry policy for transient network failures. It sits SECOND
// in the interceptor chain, after `AuthInterceptor` and before
// `LogInterceptor`.
//
// WHY HAND-WRITTEN INSTEAD OF dio_smart_retry
// Two reasons, and the second is the one that matters.
//
//   1. Freshness: `dio_smart_retry 7.0.1` was published 2024-10-22 (~21
//      months before this template was written, checked on pub.dev
//      2026-07-30). It predates dio 5.10's `transformTimeout` and 5.11's fix
//      for concurrent requests hanging when interceptors share failing
//      futures, so its `retryEvaluator` has never been exercised against
//      either.
//
//   2. SAFETY — the thing its README does not warn you about. Its default
//      retryable-status table includes 500/502/503/504 and applies
//      REGARDLESS OF HTTP METHOD. A POST that timed out client-side AFTER the
//      server committed it will be replayed. On a payments or order endpoint
//      that is a double charge. This implementation therefore retries only
//      idempotent methods, and that restriction is mandatory in any
//      replacement you write or adopt.
//
// dio ships no built-in retry — verified from
// pub.dev/documentation/dio/latest/dio/ on 2026-07-30, where the only
// exported interceptors are `Interceptor`, `Interceptors`,
// `InterceptorsWrapper`, `QueuedInterceptor`, `QueuedInterceptorsWrapper` and
// `LogInterceptor`. Unlike logging, retry genuinely needs code.
//
// WHY IT IS A PLAIN Interceptor AND NOT A QueuedInterceptor
// It re-issues the request on the SAME `Dio` it is installed on, so the
// replay re-enters the whole chain and picks up a refreshed `Authorization`
// header for free. That is safe here precisely because this is NOT a
// `QueuedInterceptor`: there is no serialized error queue to deadlock
// against. Change this class to extend `QueuedInterceptor` and the re-entry
// in [RetryInterceptor.onError] becomes the hang described in
// auth_interceptor.dart's NOTE 2.
//
// WHY IT MUST NOT BE FIRST IN THE CHAIN
// Placed before `AuthInterceptor`, a merely-expired token (a 401) would be
// seen as a failure worth retrying — burning the whole budget and hammering
// the server — before anything tried to refresh it. As written, 401 is not
// in the retryable set at all, so even a misordering is survivable; but the
// ordering is still the design, not a coincidence.
//
// WHAT TO CHANGE WHEN YOU COPY THIS
//   - `maxAttempts` counts TOTAL attempts, not extra ones. 3 means the
//     original plus two retries.
//   - If your API returns 429 with a `Retry-After` header, add a branch that
//     honours it. Retrying a 429 on a fixed backoff is how a client turns
//     rate limiting into an outage.
//   - If you must retry a POST, give it an `Idempotency-Key` header, have the
//     server deduplicate on it, and add `POST` to [idempotentMethods] with a
//     comment naming the endpoints that honour the key. Do not simply widen
//     the set.
//
// ASSUMPTION: the backoff values below (300 ms, then 900 ms) are a
// conservative placeholder, not a figure derived from any measured API. No
// real backend latency distribution was available when this template was
// written. Revisit them against your own p99 before treating them as tuned.

import 'dart:math';

import 'package:dio/dio.dart';

/// Retries transient failures on idempotent requests, with backoff.
///
/// Install SECOND, after the auth interceptor:
///
/// ```dart
/// dio.interceptors.addAll(<Interceptor>[
///   authInterceptor,
///   RetryInterceptor(dio: dio),
///   if (kDebugMode) LogInterceptor(logPrint: debugPrint),
/// ]);
/// ```
///
/// Note the `dio: dio` self-reference: the interceptor replays through the
/// very client it is installed on, which is what lets a retried attempt pick
/// up a token the auth interceptor refreshed in the meantime.
class RetryInterceptor extends Interceptor {
  /// Creates a retry policy for [dio].
  ///
  /// [maxAttempts] is the total number of attempts including the first.
  RetryInterceptor({required Dio dio, this.maxAttempts = 3}) : _dio = dio;

  /// HTTP methods safe to replay.
  ///
  /// Per RFC 9110 these are idempotent: repeating one has the same effect as
  /// issuing it once. POST and PATCH are absent deliberately — see this
  /// file's header for the double-charge scenario that omission prevents.
  static const Set<String> idempotentMethods = <String>{
    'GET',
    'HEAD',
    'PUT',
    'DELETE',
    'OPTIONS',
  };

  /// Key under which the attempt counter is carried in
  /// `RequestOptions.extra`.
  ///
  /// The counter rides on the request rather than living in a field on this
  /// interceptor, because one instance serves every concurrent request; a
  /// field would be a shared counter and two unrelated requests would
  /// exhaust each other's budget.
  static const String attemptExtraKey = 'retry.attempt';

  /// Base unit for the exponential backoff.
  static const Duration baseBackoff = Duration(milliseconds: 300);

  /// Total attempts allowed, including the original request.
  final int maxAttempts;

  final Dio _dio;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final previousAttempts = _attemptsSoFar(err.requestOptions);
    final nextAttempt = previousAttempts + 1;

    if (nextAttempt >= maxAttempts || !_isRetryable(err)) {
      handler.next(err);
      return;
    }

    await Future<void>.delayed(_backoffFor(nextAttempt));

    final options = err.requestOptions
      ..extra[attemptExtraKey] = nextAttempt;

    try {
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (e) {
      // Budget exhausted or a different failure. Pass the LATEST error on so
      // the Repository maps what actually happened last, not a stale first
      // attempt.
      handler.next(e);
    }
  }

  /// How many times this request has already been retried.
  int _attemptsSoFar(RequestOptions options) {
    final raw = options.extra[attemptExtraKey];
    return raw is int ? raw : 0;
  }

  /// Exponential backoff: 300 ms, 900 ms, 2.7 s, ...
  ///
  /// No jitter, deliberately: this is a mobile client where the realistic
  /// concurrency is a handful of requests from one device, not a fleet
  /// stampeding a service. Add jitter if you ever retry from a server.
  Duration _backoffFor(int attempt) {
    final multiplier = pow(3, attempt - 1).toInt();
    return baseBackoff * multiplier;
  }

  /// Whether [err] is a transient failure on a replayable request.
  ///
  /// Both halves must hold. The method check comes first because it is the
  /// safety property; the failure-kind check is only the optimisation.
  bool _isRetryable(DioException err) {
    if (!idempotentMethods.contains(err.requestOptions.method.toUpperCase())) {
      return false;
    }
    return switch (err.type) {
      // The network was reachable but slow, or not reachable at all. A second
      // attempt a moment later is exactly what a human would do.
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError =>
        true,
      // A response arrived; only server faults are worth repeating. 4xx will
      // fail identically every time, and retrying them is how a client turns
      // its own bug into load on someone else's service.
      DioExceptionType.badResponse => _isServerFault(
        err.response?.statusCode,
      ),
      // transformTimeout is OUR decoder being slow, not the network.
      // badCertificate will not fix itself. cancel was deliberate. unknown is
      // unclassified and must not be replayed blindly.
      DioExceptionType.transformTimeout ||
      DioExceptionType.badCertificate ||
      DioExceptionType.cancel ||
      DioExceptionType.unknown =>
        false,
    };
  }

  /// Whether [statusCode] is a 5xx.
  bool _isServerFault(int? statusCode) =>
      statusCode != null && statusCode >= 500;
}
