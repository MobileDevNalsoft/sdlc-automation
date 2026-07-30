// lib/core/result.dart
//
// Sealed success/failure return type every Repository method returns instead
// of throwing exceptions as control flow. Dart 3 sealed classes (this
// marketplace pins Dart 3.12.2) make handling exhaustive at the *analyzer*
// level: a `switch` over a Result<T> that doesn't cover both Success and
// Failure is a compile-time error, not a runtime surprise discovered later.
//
// Lives in lib/core/ (not lib/features/<x>/) on purpose — every feature's
// Repository layer returns this, so it's exactly the kind of shared type
// flutter-bootstrap's tools/check_boundaries.dart expects features to route
// through rather than importing each other directly.

sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error);

  final AppError error;
}

/// Minimal error shape every Repository failure normalizes to, regardless of
/// whether it originated as an HTTP status, a timeout, or a decode failure.
/// Kept intentionally small — add fields as real error-handling needs
/// surface, rather than speculatively.
class AppError {
  const AppError(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'AppError($statusCode: $message)';
}
