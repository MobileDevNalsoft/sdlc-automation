// lib/core/network/dio_error_mapper.dart
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
// The single function that turns dio's transport exception into this app's
// domain error: `DioException` -> `AppError`. Repositories call it; nothing
// else does.
//
// WHY THIS IS A FUNCTION AND NOT AN INTERCEPTOR
// This is the file people most expect to be an `ErrorInterceptor`, so the
// reason it is not is worth stating precisely. It is structural, not taste:
//
//   1. `ErrorInterceptorHandler.reject(...)` accepts a `DioException` and
//      nothing else. An interceptor is PHYSICALLY INCAPABLE of emitting a
//      domain `AppError`. The best it could do is stuff one into
//      `DioException.error` as an `Object?`, and then every Repository would
//      have to blind-cast it back out — strictly worse than calling a
//      function.
//   2. dio runs its error chain in the SAME FIFO order as its request chain
//      (verified below). An error-mapping interceptor placed anywhere but
//      last would pre-empt `AuthInterceptor`'s 401 refresh and
//      `RetryInterceptor`'s replay — both of which need to see the raw
//      `DioException` first.
//   3. The last slot is already spoken for by `LogInterceptor`, which dio's
//      own documentation says "should be the last interceptor added,
//      otherwise modifications by following interceptors will not be logged".
//
// So the chain is simply the wrong venue. The Repository is the right one:
// it is already the `Result<T>` seam, it is already where `FormatException`
// is caught, and it is the layer that knows which failures are meaningful to
// its own feature.
//
// FIFO EVIDENCE (fetched 2026-07-30)
// pub.dev/documentation/dio/latest/dio/Interceptors-class.html states
// verbatim: "A Queue-Model list for Interceptors. Interceptors will be
// executed with FIFO." Confirmed in dio's `dio_mixin.dart`, which loops over
// the same collection in the same direction for request, response AND error
// phases — errors are NOT unwound in reverse like Axios/OkHttp middleware.
//
// HOW A REPOSITORY USES IT
//
// ```dart
// @override
// Future<Result<Product>> getProduct(String id) async {
//   try {
//     final json = await _service.fetchProduct(id);
//     return Success(ProductDto.fromJson(json).toDomain());
//   } on DioException catch (e) {
//     return Failure(mapDioException(e));
//   } on FormatException catch (e) {
//     return Failure(SerializationError(message: 'Malformed: ${e.message}'));
//   }
// }
// ```
//
// Note there is no `on Exception catch (e)` catch-all. With a sealed
// `AppError` that arm hides classification failures: everything lands in
// `UnknownError` and the UI can never do better than a generic message.
//
// RESIDUAL GAP, FLAGGED RATHER THAN HIDDEN
// A bad cast inside a generated `fromJson` throws `TypeError`, which is an
// `Error`, not an `Exception` — so neither `on DioException` nor
// `on FormatException` catches it, and it escapes the Repository uncaught.
// The fix is defensive DTO parsing, NOT adding `on TypeError`
// (`avoid_catching_errors` forbids that, and catching `Error` hides real
// programming bugs).
//
// WHAT TO CHANGE WHEN YOU COPY THIS
//   - Adjust the copy in each variant's default to your product's voice; the
//     messages here are deliberately plain and blameless.
//   - If your API returns a machine-readable error envelope, parse it in
//     `_mapStatus` and put the server's own message in the `AppError` rather
//     than the generic default. Do that only for statuses where the envelope
//     is contractually guaranteed — a 502 from a load balancer is HTML.
//   - Add a `429` branch the moment your API rate-limits.

import 'package:dio/dio.dart';
import 'package:my_app/core/error/app_error.dart';

/// Maps a dio transport failure onto this app's sealed [AppError].
///
/// Call this from a Repository's `on DioException` clause and wrap the result
/// in a `Failure<T>`. It never throws and never returns null.
///
/// The `switch` is exhaustive over `DioExceptionType` with no `default:` —
/// `no_default_cases` forbids one, and that is the point: `transformTimeout`
/// only landed in dio 5.10.0, so a mapper written against an older dio stops
/// compiling on upgrade instead of silently routing a new failure kind into
/// [UnknownError]. Every enum value below was read from
/// pub.dev/documentation/dio/latest/dio/DioExceptionType.html on 2026-07-30;
/// there are exactly nine.
AppError mapDioException(DioException exception) {
  return switch (exception.type) {
    // All four dio timeouts collapse to one variant. The distinction between
    // "connect" and "receive" is diagnostic, not something a user can act
    // on differently — it belongs in the crash report, not the UI.
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.transformTimeout =>
      const TimeoutError(),

    // "Caused by an incorrect certificate as configured by
    // ValidateCertificate". Deliberately NOT UnknownError: on a corporate
    // or captive-portal network this is common and specific, and telling the
    // user "could not establish a secure connection" is actionable where
    // "something went wrong" is not.
    DioExceptionType.badCertificate => const NetworkError(
      message: 'Could not establish a secure connection.',
    ),

    // "Caused for example by a xhr.onError or SocketExceptions" — the
    // authoritative offline signal. This is why the app does not consult a
    // connectivity plugin before sending: this reports what actually
    // happened, with no race and no captive-portal false negative.
    DioExceptionType.connectionError => const NetworkError(),

    // The caller cancelled (navigated away, retyped a search). Its own
    // variant so "render nothing" is an explicit branch at the UI.
    DioExceptionType.cancel => const CancelledError(),

    // "caused by an incorrect status code as configured by ValidateStatus" —
    // a real response arrived, so the status decides.
    DioExceptionType.badResponse => _mapStatus(exception.response?.statusCode),

    // Keep the underlying message: an UnknownError with no detail is a
    // support ticket nobody can act on.
    DioExceptionType.unknown => UnknownError(
      message: 'Unexpected network error: ${exception.message}',
    ),
  };
}

/// Maps an HTTP status code onto an [AppError].
///
/// Deliberately if/else rather than a `switch`: the domain is `int?`, so a
/// switch would need a `default:`/`_` arm, which `no_default_cases` rejects.
/// Ranges also express "any 5xx" far better than enumerating codes.
AppError _mapStatus(int? code) {
  // 403 is grouped with 401 on purpose. Strictly it means "authenticated but
  // not permitted", but for a mobile client whose only credential is the
  // token, both end in the same place: re-authenticate. Split them if and
  // when your API has real per-resource permissions that a re-login cannot
  // fix — at which point 403 deserves its own AppError variant, not a
  // reinterpretation of this one.
  if (code == 401 || code == 403) {
    return UnauthorizedError(statusCode: code);
  }
  if (code != null && code >= 500) {
    return ServerError(statusCode: code);
  }
  if (code != null && code >= 400) {
    return ValidationError(statusCode: code);
  }
  // Reached when `validateStatus` was customised to reject a 2xx/3xx, or when
  // dio reported badResponse with no status at all. Rare and genuinely
  // unclassifiable, so it names the code it saw.
  return UnknownError(message: 'Unexpected response status: $code');
}
