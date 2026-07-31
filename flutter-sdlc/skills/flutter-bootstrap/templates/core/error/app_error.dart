// lib/core/error/app_error.dart
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
// The sealed domain-error hierarchy every `Failure<T>` carries. It is the
// single vocabulary the whole app uses to talk about "something went wrong",
// regardless of whether it started life as a socket error, an HTTP status, a
// timeout, or a decode failure.
//
// WHERE IT CAME FROM — this is a MOVE plus a widening, not a new type.
// `AppError` previously lived at the bottom of flutter-slice's
// `templates/result.dart` as a plain (non-sealed) class with `message` and
// `statusCode?`. It moved here for two reasons:
//   1. `Result<T>`/`Success<T>`/`Failure<T>` stay byte-identical in
//      lib/core/result.dart, which is what makes this change reviewable — the
//      Result type genuinely did not change.
//   2. Eight variants plus the doc comment each one needs would have
//      dominated that file.
// `lib/core/result.dart` therefore now imports THIS file. `Failure<T>` still
// holds an `AppError`, so every existing `switch (result)` keeps compiling.
//
// WHY SEALED — the flat class could not answer a question the UI actually
// asks. A screen showing a failure needs to know "would retrying help?" vs
// "must the user sign in again?" vs "is this a bug in our parsing?". With a
// flat `AppError` the only way to tell was to string-match `message`, which
// silently breaks the first time someone rewords a string. Sealed + Dart 3
// exhaustive switches make that a compile-time question:
//
// ```dart
// final label = switch (error) {
//   NetworkError() || TimeoutError() || ServerError() => 'Try again',
//   UnauthorizedError() => 'Sign in',
//   ValidationError() => 'Fix and resend',
//   CancelledError() || SerializationError() || UnknownError() => 'Dismiss',
// };
// ```
//
// That switch has no `default:` — the vendored `no_default_cases` rule
// forbids one over a sealed type, which is the whole point: adding a ninth
// variant here becomes a compile error at every site that must decide what to
// do about it, instead of silently falling into a catch-all.
//
// WHY EVERY CONSTRUCTOR IS ALL-NAMED
// The base holds `message` (positional in the old flat class) and
// `statusCode` (named). Dart forbids mixing optional-positional and named
// parameters in one signature, AND forbids combining `super.x` parameters
// with an explicit `super(...)` invocation. Keeping `message` positional
// would therefore have forced the three status-carrying variants into
// hand-written `super(message, statusCode: statusCode)` forwarding while the
// other five used `super.message` — two shapes for no benefit. All-named is
// uniform and every variant forwards implicitly. Migration cost: the old
// `AppError('some message')` becomes `UnknownError(message: 'some message')`
// or, better, a variant that actually classifies it.
//
// THE COST, STATED PLAINLY: sealing is a breaking change. Any existing
// `AppError('...')` construction (flutter-slice's `product_repository.dart`
// had three) becomes a compile error and must pick a concrete variant. That
// is contained but it is not free — budget for it when migrating.
//
// WHAT TO CHANGE WHEN YOU COPY THIS
// Adding a variant is expected as the app grows (a `RateLimitedError` is the
// usual first addition). Adding one is a deliberate act: it will break every
// exhaustive switch until each decides how to render it. Resist adding
// per-feature variants — this hierarchy is about TRANSPORT and PROTOCOL
// failures, not domain rules. "Coupon expired" is a successful response
// carrying a domain outcome, not an `AppError`.

/// Base type for every failure a Repository can return inside a `Failure<T>`.
///
/// Sealed, so a `switch` over an [AppError] that misses a variant is a
/// compile-time error rather than a runtime surprise.
///
/// [message] is always safe to show a user: every variant's default is
/// written as user-facing copy, not as a developer diagnostic. Anything a
/// user should not see (a stack trace, a raw server body) belongs in the
/// crash reporter, not in this field.
///
/// Note the defaults are English literals rather than localized strings.
/// Localizing here is impossible — this layer has no `BuildContext`. When the
/// app is multilingual, switch on the variant at the widget layer and pull
/// the copy from `context.l10n`, using [message] only as the fallback for
/// server-supplied detail.
sealed class AppError {
  /// Creates an error carrying a user-safe [message] and an optional
  /// [statusCode].
  const AppError({required this.message, this.statusCode});

  /// User-facing description of what went wrong.
  final String message;

  /// HTTP status code, when the failure originated from a response.
  ///
  /// Null for transport-level failures (no response ever arrived), for
  /// cancellation, and for decode failures.
  final int? statusCode;

  @override
  String toString() => 'AppError($statusCode: $message)';
}

/// The transport failed outright — no usable response arrived.
///
/// Socket errors, DNS failures, TLS handshake failures. Mapped from dio's
/// `connectionError` and `badCertificate`.
///
/// Deliberately NOT produced by consulting a connectivity plugin before
/// sending. `connectivity_plus`'s own README says a connection type "does not
/// guarantee that there is an Internet access" (captive portals, hotel
/// Wi-Fi), so a pre-flight check adds a race and a false-negative class,
/// while this error already reports ground truth after the fact.
final class NetworkError extends AppError {
  /// Creates a transport failure.
  const NetworkError({super.message = 'No internet connection.'});
}

/// A request exceeded one of the configured dio timeouts.
///
/// Covers `connectionTimeout`, `sendTimeout`, `receiveTimeout` and
/// `transformTimeout`. Distinguished from [NetworkError] because a timeout
/// means the network is reachable but slow — retrying is much more likely to
/// help, and the copy must not claim the user is offline when they are not.
final class TimeoutError extends AppError {
  /// Creates a timeout failure.
  const TimeoutError({
    super.message = 'The request timed out. Please try again.',
  });
}

/// Credentials were absent, rejected, or unrecoverable after a token refresh.
///
/// This is what the router's auth guard ultimately reacts to. Reaching it
/// means `AuthInterceptor` already tried to refresh and gave up — a bare 401
/// that a refresh fixed never surfaces to a Repository at all.
final class UnauthorizedError extends AppError {
  /// Creates an authentication failure, usually for status 401 or 403.
  const UnauthorizedError({
    super.message = 'Please sign in again.',
    super.statusCode,
  });
}

/// The server understood the request and rejected its contents (4xx).
///
/// Typically something the user can correct. Carry the server's own
/// field-level detail in [AppError.message] when the API provides it — the
/// generic default is only the fallback.
final class ValidationError extends AppError {
  /// Creates a client-side request-rejection failure.
  const ValidationError({
    super.message = 'That request was rejected.',
    super.statusCode,
  });
}

/// A server-side fault (5xx). Retrying may succeed.
///
/// The only [AppError] whose default affordance should be "Try again" with no
/// qualification — the user did nothing wrong and nothing about their input
/// needs to change.
final class ServerError extends AppError {
  /// Creates a server-fault failure.
  const ServerError({
    super.message = 'The server had a problem.',
    super.statusCode,
  });
}

/// The caller cancelled the request.
///
/// Usually rendered as nothing at all: the user navigated away, or typed
/// another character into a search field and the previous query was dropped.
/// Showing an error for this is a common and jarring bug, so it gets its own
/// variant specifically to make "render nothing" an explicit, exhaustively
/// checked branch rather than an omission.
final class CancelledError extends AppError {
  /// Creates a cancellation failure.
  const CancelledError({super.message = 'Request was cancelled.'});
}

/// A response arrived but did not match the expected shape.
///
/// Almost always our bug or a backend contract change, not the user's
/// problem — worth reporting to the crash reporter even though it is a
/// handled failure.
///
/// Caveat worth knowing: this covers `FormatException`, but a bad cast inside
/// a generated `fromJson` throws `TypeError`, which is an `Error`, not an
/// `Exception`, so it escapes a Repository's `on` clauses entirely. The
/// recommended fix is defensive DTO parsing, not catching `Error`
/// (`avoid_catching_errors` forbids the latter, for good reason).
final class SerializationError extends AppError {
  /// Creates a response-decoding failure.
  const SerializationError({
    super.message = 'The server sent something unexpected.',
  });
}

/// Anything that could not be classified.
///
/// Keep this rare. A steady trickle of [UnknownError] in your crash reporter
/// means the mapper in lib/core/network/dio_error_mapper.dart is missing a
/// case, and every one of those is a UI decision made blind.
final class UnknownError extends AppError {
  /// Creates an unclassified failure.
  const UnknownError({super.message = 'Something went wrong.'});
}
