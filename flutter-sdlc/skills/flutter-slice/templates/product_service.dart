// lib/features/product/data/services/product_service.dart
//
// TEMPLATE — copy to lib/features/<feature>/data/services/<feature>_service
// .dart, rename every `Product`/`product` identifier to the real feature's
// name, and replace the endpoint path with the real one. There is no package
// name to substitute in this file: it imports only dio.
//
// WHAT THIS IS
// The Service layer: the ONLY layer allowed to know about HTTP. It talks to
// the backend's raw JSON shape and hands back a decoded map. It does NOT
// decide success/failure semantics and does NOT map to a domain model —
// that is the Repository's job (see product_repository.dart). A Service
// throwing on a network or HTTP-status failure is EXPECTED; the Repository is
// what turns that exception into a `Result<T>`, so no exception ever leaks
// past that boundary into a Cubit.
//
// ---------------------------------------------------------------------------
// WHAT CHANGED FROM THE PREVIOUS VERSION OF THIS TEMPLATE, AND WHY
// ---------------------------------------------------------------------------
// This file used to be built on `package:http` with this constructor:
//
//     ProductService({required this.baseUrl, http.Client? client})
//       : _client = client ?? http.Client();
//
// Four things went away with the move to dio. Each removal is load-bearing,
// so do not reintroduce them out of habit:
//
// 1. `http.Client? client` WITH A `?? http.Client()` FALLBACK — deleted.
//    That fallback is the anti-pattern this template most wants to kill: a
//    test that forgets to pass a client does not fail, it SILENTLY OPENS REAL
//    SOCKETS against whatever `baseUrl` happens to hold. `const
//    ProductService(this._dio)` has no such escape: a caller that does not
//    supply a client does not compile. The `Dio` it receives is the one
//    registered in lib/core/di/injector.dart, which already carries the
//    ordered interceptor chain (auth -> retry -> logging).
//
// 2. `baseUrl` — deleted. It lives once, in the `BaseOptions` that
//    lib/core/network/dio_client.dart builds from `FlavorConfig.apiBaseUrl`.
//    Keeping it here meant every Service re-read flavor config, and every one
//    of them was a place a dev-vs-prod mix-up could hide. Paths below are
//    therefore RELATIVE ('/products/$id'), which is what makes them
//    flavor-agnostic.
//
// 3. The manual `if (statusCode < 200 || statusCode >= 300) throw ...` check
//    — deleted. dio's `validateStatus` already throws a `DioException` with
//    `type == DioExceptionType.badResponse` for a non-2xx. Hand-checking it
//    added roughly ten lines PER ENDPOINT and made status handling
//    per-Service instead of uniform.
//
// 4. `class ProductServiceException` — deleted entirely. It existed only to
//    carry `message` + `statusCode` across the Service/Repository boundary,
//    which is exactly what `DioException` already does, with more detail
//    (the failing `RequestOptions`, the `Response`, the typed
//    `DioExceptionType`). One exception type per feature meant N Repositories
//    each catching a different name for the same event. The Repository now
//    catches `on DioException` and calls `mapDioException` — see
//    lib/core/network/dio_error_mapper.dart.
//
// dio is pinned at 5.11.0 (fetched from pub.dev's package API 2026-07-30,
// published 2026-07-25). Do not pin below 5.11.0: its changelog entry "Fix
// concurrent requests hanging when interceptors share failing Futures"
// describes a hang in exactly the concurrent-interceptor scenario the 401
// refresh queue in lib/core/network/auth_interceptor.dart creates.
//
// ---------------------------------------------------------------------------
// WHAT TO CHANGE WHEN YOU COPY THIS
// ---------------------------------------------------------------------------
//   - The class name, the file name, and the endpoint paths.
//   - One method per endpoint. Keep them thin: a path, a payload, a return.
//     The moment a method starts deciding what a response MEANS, that logic
//     belongs one layer up.
//   - Do NOT add a `try`/`catch` here. This layer throws; the Repository
//     catches. A `catch` in a Service is how error handling ends up smeared
//     across two layers instead of living in one.
//   - Do NOT add `Options(headers: {'Authorization': ...})`. The token is
//     stamped by `AuthInterceptor` on the shared `Dio`. A Service that sets
//     its own auth header bypasses the refresh-and-replay logic and will 401
//     forever once the token expires.
//   - Register it in lib/core/di/injector.dart as
//
//         ..registerLazySingleton<ProductService>(
//           () => ProductService(getIt<Dio>()),
//         )
//
//     — a Service is a stateless request-shaper, so one shared instance is
//     free. Note `getIt<Dio>()` UNNAMED: the named 'replayClient' instance is
//     interceptor-free and exists only for the auth refresh.

import 'package:dio/dio.dart'; // dio@5.11.0

/// Raw HTTP access to the product endpoints.
///
/// Every method returns the decoded JSON body and throws `DioException` on
/// any transport or status failure. Nothing here interprets a failure; see
/// lib/features/product/data/repositories/product_repository.dart for the
/// layer that does.
class ProductService {
  /// Creates a service over an injected [Dio].
  ///
  /// The `Dio` is REQUIRED and has no default. That is deliberate — a
  /// defaulted client is how a test quietly makes real network calls.
  const ProductService(this._dio);

  final Dio _dio;

  /// Fetches the raw JSON body for the product with [id].
  ///
  /// Throws `DioException` on any transport failure, timeout, cancellation,
  /// or non-2xx status — dio's `validateStatus` handles the status case, so
  /// there is no manual check here. The Repository catches it and maps it
  /// with `mapDioException`.
  ///
  /// Returns an empty map rather than null when the body is absent: the
  /// generated `fromJson` needs a `Map<String, dynamic>`, and a 204 with no
  /// body is a contract question for the Repository to notice as a
  /// `SerializationError`, not something to paper over with a null check at
  /// every call site.
  Future<Map<String, dynamic>> fetchProduct(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/products/$id');
    return response.data ?? const <String, dynamic>{};
  }
}
