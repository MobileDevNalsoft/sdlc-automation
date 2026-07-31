// lib/core/result.dart
//
// TEMPLATE — copy to lib/core/result.dart and replace the placeholder package
// name `my_app` in the one import below with your own package name (the
// `name:` field of pubspec.yaml).
//
// COPY THIS ONCE PER PROJECT, NOT ONCE PER FEATURE. It is the one file in
// this skill's template set that is shared rather than sliced. Every
// feature's Repository returns this type, so a second copy under
// lib/features/<x>/ would be a second, drifting definition of the same sealed
// type — and a `Success<T>` from one copy would not be a `Success<T>` from
// the other.
//
// WHAT THIS IS
// The sealed success/failure return type every Repository method returns
// instead of throwing exceptions as control flow. Dart 3 sealed classes make
// handling exhaustive at the ANALYZER level: a `switch` over a Result<T> that
// does not cover both Success and Failure is a compile-time error, not a
// runtime surprise discovered later.
//
// It lives in lib/core/ (not lib/features/<x>/) on purpose — every feature's
// Repository returns it, so it is exactly the kind of shared type
// flutter-bootstrap's tools/check_boundaries.dart expects features to route
// through instead of importing each other directly.
//
// WHERE `AppError` WENT — read this before looking for it here
// An earlier revision of this file also declared a flat
// `class AppError { final String message; final int? statusCode; }` at the
// bottom. It is gone from here. `AppError` is now a SEALED hierarchy of eight
// variants living in lib/core/error/app_error.dart, which flutter-bootstrap
// ships. Two consequences worth stating plainly:
//
//   1. `Result<T>`, `Success<T>` and `Failure<T>` below are otherwise
//      UNCHANGED in shape. `Failure<T>` still holds an `AppError`, so every
//      existing `switch (result)` keeps compiling. That is deliberate: the
//      error hierarchy changed, the result type did not, and keeping them in
//      separate files is what makes that reviewable.
//   2. `const AppError('boom')` no longer compiles anywhere. A sealed base
//      class cannot be instantiated. Every construction site must pick a
//      concrete variant — `NetworkError()`, `ServerError(statusCode: 503)`,
//      `SerializationError(message: '...')`. That is a breaking change and it
//      is not free; budget for it when migrating an existing project. This
//      skill's own product_repository.dart had three such sites.
//
// OWNERSHIP, so two skills never ship the same type:
//   - lib/core/result.dart          — THIS file, shipped by flutter-slice.
//   - lib/core/error/app_error.dart — shipped by flutter-bootstrap.
// Neither skill ships the other's file. If a project ends up with two copies
// of either, delete one before they drift.
//
// VERIFIED TOOLCHAIN: Flutter 3.41.6 / Dart 3.11.4, 2026-07-30. An earlier
// revision of this header claimed "this marketplace pins Dart 3.12.2"; that
// was wrong against the installed SDK and is corrected here. Nothing in this
// file needs 3.11 specifically — sealed classes and exhaustive switches are
// Dart 3.0 features — but the toolchain is recorded because the rest of the
// stack is pinned against it.
//
// WHAT TO CHANGE WHEN YOU COPY THIS
// Nothing but the package name in the import. Resist adding helpers here
// (`fold`, `mapSuccess`, `getOrElse`) until a second caller actually wants
// one: the pattern-matching `switch` in product_cubit.dart is already the
// ergonomic path, and every helper added here is one more thing a reader must
// learn before they can read a Repository. When you do add them, put them in
// lib/core/extensions/ as an extension on `Result<T>` rather than growing
// this file, so this file stays a type declaration and nothing else.

import 'package:my_app/core/error/app_error.dart';

/// The outcome of a Repository operation: either a [Success] carrying a value
/// or a [Failure] carrying an error.
///
/// Sealed, so a `switch` over a `Result<T>` that misses a case is a
/// compile-time error. That is the whole reason a Repository returns
/// `Future<Result<T>>` and never `Future<T>` with a thrown exception: the
/// Cubit above it cannot forget to handle the failure path.
///
/// ```dart
/// switch (await repository.getProduct(id)) {
///   case Success(:final value):
///     emit(ProductState.loaded(value));
///   case Failure(:final error):
///     emit(ProductState.error(error));
/// }
/// ```
sealed class Result<T> {
  /// Creates a result.
  ///
  /// Construct [Success] or [Failure] instead — this exists only so both
  /// subtypes can have `const` constructors.
  const Result();
}

/// A successful outcome carrying [value].
final class Success<T> extends Result<T> {
  /// Creates a successful result carrying [value].
  const Success(this.value);

  /// The value the operation produced.
  final T value;
}

/// A failed outcome carrying [error].
///
/// Note the type parameter: a `Failure<ProductModel>` is a
/// `Result<ProductModel>` even though it holds no product. That is what lets
/// a Repository report failure without inventing a null or a sentinel value.
final class Failure<T> extends Result<T> {
  /// Creates a failed result carrying [error].
  const Failure(this.error);

  /// What went wrong, as one of the sealed variants declared in
  /// lib/core/error/app_error.dart.
  ///
  /// Always a domain error, never a `DioException`: the Repository maps
  /// transport exceptions through `mapDioException` before wrapping them
  /// here, which is what keeps every layer above the data layer free of any
  /// dio import.
  final AppError error;
}
