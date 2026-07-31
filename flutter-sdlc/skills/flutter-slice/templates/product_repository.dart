// lib/features/product/data/repositories/product_repository.dart
//
// TEMPLATE — copy to lib/features/<feature>/data/repositories/<feature>
// _repository.dart, rename every `Product`/`product` identifier, and replace
// the placeholder package name `my_app` in the imports below with your own
// package name (the `name:` field of pubspec.yaml).
//
// WHAT THIS IS
// The mandatory seam between Service (raw API calls, throws) and Cubit
// (`Result<T>`, never exceptions). It catches everything the Service and DTO
// layers can throw and normalises it into `Failure(AppError)`, so no
// `try`/`catch` ever needs to appear in a Cubit or a Screen.
//
// This layer is mandatory for NEW features only. Do NOT retrofit a
// Repository/`Result<T>` wrapper onto an existing feature that already calls
// a Service directly, just because a new feature nearby now has one — that is
// a separate, deliberately-scoped migration a plan should call out on its
// own, not a drive-by refactor this template forces on adopted code.
//
// ---------------------------------------------------------------------------
// THE IMPORTS ARE `package:` IMPORTS, AND THAT IS A FIX
// ---------------------------------------------------------------------------
// A previous revision of this template used relative imports
// ('../../../../core/result.dart' and friends). That VIOLATED
// `always_use_package_imports` — a rule in the very_good_analysis@10.3.0
// ruleset this same plugin vendors. The template was failing the gate it
// ships. Corrected here; use `package:` imports everywhere, including for
// files inside the same feature.
//
// ---------------------------------------------------------------------------
// THE CATCH CLAUSES, AND THE ONE THAT WAS DELETED
// ---------------------------------------------------------------------------
// Every `catch` has an explicit `on` type. `avoid_catches_without_on_clauses`
// (vendored in flutter-bootstrap's analysis_options.yaml) fails a bare
// `catch (e)`, and the rule is right: a bare catch swallows programming
// errors alongside expected failures.
//
//   - `on DioException` -> `mapDioException(e)`. ONE call site per
//     Repository method, mapping dio's nine `DioExceptionType` values plus
//     the HTTP status onto the sealed `AppError` hierarchy. The mapping lives
//     in lib/core/network/dio_error_mapper.dart, not in an interceptor, and
//     not here: `ErrorInterceptorHandler.reject()` accepts a `DioException`
//     and nothing else, so an interceptor is physically incapable of emitting
//     a domain `AppError`.
//
//   - `on FormatException` -> `SerializationError`. Still needed: dio
//     succeeded, the bytes arrived, and `fromJson` could not read them.
//
//   - `on Exception catch (e)` -> DELETED. It used to be the third arm. With
//     a sealed `AppError` that catch-all is actively harmful: every
//     unclassified failure lands in one generic message, so the UI can never
//     do better than "something went wrong" and nobody ever learns which case
//     the mapper is missing. Let an unexpected `Exception` propagate; it will
//     show up in the crash reporter as the bug it is.
//
// RESIDUAL GAP, FLAGGED RATHER THAN HIDDEN: a bad cast inside a generated
// `fromJson` throws `TypeError`, which is an `Error`, not an `Exception` — so
// neither `on DioException` nor `on FormatException` catches it and it
// escapes this method uncaught. The recommended fix is DEFENSIVE DTO PARSING
// (see product_dto.dart), NOT adding `on TypeError`: `avoid_catching_errors`
// forbids that, and catching `Error` hides real programming bugs.
//
// ---------------------------------------------------------------------------
// REGISTERING IT — this step is part of the slice, not an afterthought
// ---------------------------------------------------------------------------
// Add to `configureDependencies` in lib/core/di/injector.dart, in the
// per-feature block, INSIDE the existing cascade (`cascade_invocations` flags
// repeated `getIt.registerX(...)` statements):
//
//     getIt
//       ..registerLazySingleton<ProductService>(
//         () => ProductService(getIt<Dio>()),
//       )
//       ..registerLazySingleton<ProductRepository>(
//         () => ProductRepositoryImpl(getIt<ProductService>()),
//       )
//       ..registerFactory<ProductCubit>(
//         () => ProductCubit(getIt<ProductRepository>()),
//       );
//
// Two details that matter:
//
//   - Register against the ABSTRACT type `ProductRepository`, never against
//     `ProductRepositoryImpl`. That single choice is what makes a test
//     override a one-liner:
//         getIt.registerLazySingleton<ProductRepository>(
//           MockProductRepository.new,
//         );
//     Registering the impl type means every consumer names the impl and the
//     interface buys nothing.
//   - `registerLazySingleton`, not `registerFactory`, for both the Service
//     and the Repository: they are stateless request-shapers and caches, so
//     one shared instance is free, and lazy means a feature nobody visits
//     costs nothing at startup. The Cubit is the opposite — see
//     product_cubit.dart for why it MUST be a factory.

import 'package:dio/dio.dart'; // dio@5.11.0
import 'package:my_app/core/error/app_error.dart';
import 'package:my_app/core/network/dio_error_mapper.dart';
import 'package:my_app/core/result.dart';
import 'package:my_app/features/product/data/dto/product_dto.dart';
import 'package:my_app/features/product/data/services/product_service.dart';
import 'package:my_app/features/product/domain/product_model.dart';

/// Read/write access to products, as the rest of the app sees it.
///
/// Declared as an `abstract interface class` because it is only ever
/// implemented, never extended — and because that is the type the DI
/// container registers, so a fake in a test is a class that `implements` this
/// and nothing more.
abstract interface class ProductRepository {
  /// Loads the product with [id].
  ///
  /// Never throws: every failure comes back as `Failure(AppError)`.
  Future<Result<ProductModel>> getProduct(String id);
}

/// The live [ProductRepository], backed by [ProductService].
final class ProductRepositoryImpl implements ProductRepository {
  /// Creates the repository over an injected [ProductService].
  const ProductRepositoryImpl(this._service);

  final ProductService _service;

  @override
  Future<Result<ProductModel>> getProduct(String id) async {
    try {
      final json = await _service.fetchProduct(id);
      return Success(ProductDto.fromJson(json).toDomain());
    } on DioException catch (e) {
      return Failure(mapDioException(e));
    } on FormatException catch (e) {
      return Failure(
        SerializationError(message: 'Malformed product: ${e.message}'),
      );
    }
  }
}
