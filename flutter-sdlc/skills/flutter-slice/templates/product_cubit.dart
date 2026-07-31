// lib/features/product/presentation/bloc/product_cubit.dart
// (folder named "bloc/" not "cubit/" — see flutter-slice's SKILL.md note on
// why, tied to flutter-verify's coverage-ratchet scope)
//
// TEMPLATE — copy to lib/features/<feature>/presentation/bloc/<feature>
// _cubit.dart, rename every `Product`/`product` identifier, and replace the
// placeholder package name `my_app` in the imports below with your own
// package name (the `name:` field of pubspec.yaml).
//
// WHAT THIS IS
// The Cubit: the only layer allowed to call the Repository and the only layer
// allowed to `switch` on a `Result<T>`. A Screen switches on `ProductState`
// (see product_screen.dart), never on a `Result` directly. bloc@9.2.1 via
// flutter_bloc@9.1.1.
//
// This layer is UNCHANGED in shape by the move to dio, get_it and go_router,
// and that is the point of the layering: it still calls one Repository
// method, still destructures `Success`/`Failure` with object patterns, still
// maps to a `ProductState` before emitting. It imports neither dio nor
// get_it nor go_router — a Cubit that imported an HTTP client would mean the
// Repository seam had stopped doing its job.
//
// This feature uses `Cubit`, not a full event-driven `Bloc`, because `load()`
// is a plain, directly-invoked request/response operation with nothing to
// debounce, throttle, or race against a newer call — see flutter-slice's
// SKILL.md "Cubit vs. full Bloc" section for the rule that decides which one
// a given feature needs. That rule is unchanged and still settled.
//
// `Success(:final value)` / `Failure(:final error)` below are Dart 3 object
// patterns destructuring lib/core/result.dart's fields — no `.value`/`.error`
// getter call, and no `if (result is Success)` cast. That is the whole point
// of `Result<T>` being sealed: the switch below is exhaustive over
// `Result<ProductModel>` the same way product_screen.dart's switch is
// exhaustive over `ProductState`.
//
// ---------------------------------------------------------------------------
// THE STATE CARRIES THE TYPED `AppError`, NOT `error.message`
// ---------------------------------------------------------------------------
// A previous revision emitted `ProductState.error(error.message)` — a String.
// It now emits the `AppError` itself. That one change is what lets
// `AppErrorView` switch exhaustively on the variant and show "Try again" for
// a `ServerError` but "Sign in" for an `UnauthorizedError`, instead of
// string-matching a message that someone will eventually reword.
//
// Flattening to a String is still a legitimate per-feature choice when a
// feature genuinely has one failure rendering — but it is a choice to make
// deliberately, not the default. The default here is to keep the type.
//
// ---------------------------------------------------------------------------
// DI LIFETIME: `registerFactory`. NOT a singleton. This is provable.
// ---------------------------------------------------------------------------
// Register it in lib/core/di/injector.dart as:
//
//     ..registerFactory<ProductCubit>(
//       () => ProductCubit(getIt<ProductRepository>()),
//     )
//
// and provide it with `BlocProvider(create: (_) => getIt<ProductCubit>())`.
//
// WHY a factory, from bloc's own source (fetched
// raw.githubusercontent.com/felangel/bloc/master/packages/bloc/lib/src/
// bloc_base.dart on 2026-07-30):
//
//     // bloc_base.dart:97-101
//     void emit(State state) {
//       try {
//         if (_stateController.isClosed) {
//           throw StateError('Cannot emit new states after calling close');
//     // bloc_base.dart:173-177
//     Future<void> close() async {
//       _blocObserver.onClose(this);
//       await _stateController.close();
//     }
//
// `BlocProvider(create: ...)` OWNS the bloc it creates and closes it when its
// subtree is disposed. So a feature Cubit registered as a lazy singleton gets
// `close()`d the first time the user pops that screen, and every later
// navigation receives the SAME CLOSED INSTANCE — whose first `emit` throws
// `StateError('Cannot emit new states after calling close')`.
// `registerFactory` hands out a fresh, open Cubit per mount, which is exactly
// the ownership contract `create:` assumes.
//
// THE ONE EXCEPTION, and the highest-likelihood mistake in this whole stack:
// `AuthCubit` is app-scoped, because the router's redirect guard closes over
// it for the app's lifetime. It is `registerLazySingleton(..., dispose: (c) =>
// c.close())` AND it is provided with `BlocProvider.value(value:
// getIt<AuthCubit>())` — NEVER `create:`. `.value` does not take ownership
// and does not close on dispose. Getting that pair backwards reintroduces
// exactly the `StateError` above. Every FEATURE Cubit — including this one —
// stays factory + `create:`.
//
// ASSUMPTION: that `BlocProvider(create:)` closes the bloc it creates while
// `BlocProvider.value` does not. The CONSEQUENCE was verified directly in
// bloc's source (quoted above); flutter_bloc 9.1.1's own `bloc_provider.dart`
// was NOT fetched to confirm the ownership asymmetry itself. It is
// long-standing documented behaviour, but confirm it before relying on the
// app-scoped AuthCubit design in a new project.
//
// ---------------------------------------------------------------------------
// WHAT TO CHANGE WHEN YOU COPY THIS
// ---------------------------------------------------------------------------
//   - Names, and one method per user-triggered operation.
//   - Keep `emit(const ...loading())` as the FIRST line of every async
//     method. A method that awaits before emitting a loading state produces a
//     screen that looks frozen for the duration of the request.
//   - Do NOT put a `try`/`catch` here. If you feel you need one, the
//     Repository is not returning `Result<T>` properly.
//   - Do NOT hold `TextEditingController`s or raw form text in Cubit state.
//     Form input belongs to a `StatefulWidget`; state that round-trips
//     through a rebuild loses the user's cursor position.

import 'package:bloc/bloc.dart'; // bloc@9.2.1
import 'package:my_app/core/result.dart';
import 'package:my_app/features/product/data/repositories/product_repository.dart';
import 'package:my_app/features/product/presentation/bloc/product_state.dart';

/// Loads a single product and exposes it as a [ProductState].
///
/// Registered as a FACTORY in lib/core/di/injector.dart and provided with
/// `BlocProvider(create: (_) => getIt<ProductCubit>())`, which owns and
/// closes it. See this file's header for why a singleton would break.
class ProductCubit extends Cubit<ProductState> {
  /// Creates the cubit over an injected [ProductRepository].
  ProductCubit(this._repository) : super(const ProductState.initial());

  final ProductRepository _repository;

  /// Loads the product with [id], emitting loading, then loaded or error.
  ///
  /// Never throws: the Repository returns a `Result<ProductModel>`, and both
  /// arms of the switch below emit a state.
  Future<void> load(String id) async {
    emit(const ProductState.loading());
    final result = await _repository.getProduct(id);
    switch (result) {
      case Success(:final value):
        emit(ProductState.loaded(value));
      case Failure(:final error):
        emit(ProductState.error(error));
    }
  }
}
