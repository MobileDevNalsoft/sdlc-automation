// lib/features/product/presentation/bloc/product_bloc.dart
//
// TEMPLATE — copy to lib/features/<feature>/presentation/bloc/<feature>
// _bloc.dart, rename every `Product`/`product` identifier, and replace the
// placeholder package name `my_app` in the imports below with your own
// package name (the `name:` field of pubspec.yaml).
//
// ---------------------------------------------------------------------------
// READ THIS BEFORE COPYING: THIS IS THE MINORITY PATH
// ---------------------------------------------------------------------------
// Use product_cubit.dart instead unless this feature needs an event *stream*
// with a transformer applied to it. The rule lives in flutter-slice's
// SKILL.md ("Cubit vs. full Bloc") and is not restated here. A full `Bloc`
// costs you an event class, an `on<Event>` registration per intention, and a
// second sealed type to keep in sync — pay that only for what transformers
// buy you.
//
// If you copy this file you must ALSO copy product_event.dart, and you must
// NOT copy product_cubit.dart — a feature has one emitter, not two.
//
// ---------------------------------------------------------------------------
// ADD THE DEPENDENCY FIRST
// ---------------------------------------------------------------------------
// `package:bloc_concurrency` is NOT in the default scaffold's pubspec.yaml —
// flutter-bootstrap lists it as optional precisely because the Cubit default
// never needs it. Add it before copying this file:
//
//     bloc_concurrency: 0.3.0
//
// Version per flutter-bootstrap's dependency table (fetched pub.dev API,
// latest `0.3.0`, published 2025-01-12). That is genuinely stale relative to
// core `bloc`'s more recent releases — the same staleness flutter-verify
// already flags for `bloc_test` — so treat a future upgrade as its own
// verified change, not a drive-by pin bump. It sorts before `bloc_test` under
// `sort_pub_dependencies`.
//
// ---------------------------------------------------------------------------
// THE FOUR TRANSFORMERS, AND WHAT THE DEFAULT ACTUALLY IS
// ---------------------------------------------------------------------------
// Fetched from bloc_concurrency's README
// (raw.githubusercontent.com/felangel/bloc/master/packages/bloc_concurrency/
// README.md, 2026-07-31) — the package exports exactly four:
//
//   concurrent()  process events concurrently
//   sequential()  process events sequentially
//   droppable()   ignore any events added while an event is processing
//   restartable() process only the latest event and cancel previous handlers
//
// THE DEFAULT IS `concurrent()`, AND THAT IS USUALLY THE WRONG ONE. Verified
// in bloc's own source (raw.githubusercontent.com/felangel/bloc/master/
// packages/bloc/lib/src/bloc.dart, 2026-07-31): `on<E>` resolves
// `(transformer ?? _eventTransformer)`, and the static default is documented
// there as "By default all events are processed concurrently", implemented
// with a flat-map stream transformer.
//
// Concurrent means two taps fire two overlapping requests whose responses can
// land out of order, so the SECOND response can be overwritten by the FIRST.
// That is the classic stale-data bug. If you are writing a `Bloc` at all, you
// are doing it for the transformer — so pass one explicitly on every `on<>`
// below rather than inheriting the default by omission.
//
// Also verified in that same source: registering two handlers for one event
// type throws `StateError('on<$E> was called multiple times. There should
// only be a single event handler per event type.')` — it is a runtime throw,
// not a compile error, so it surfaces on first use of the screen.
//
// ---------------------------------------------------------------------------
// DEBOUNCE: `restartable()` PLUS A LEADING DELAY
// ---------------------------------------------------------------------------
// bloc_concurrency does NOT export a `debounce()`. The usual community answer
// adds `package:stream_transform` for it. This template avoids that extra
// dependency by putting the delay at the TOP of the handler under
// `restartable()`: each keystroke restarts the handler, so an earlier one
// that is still inside its delay never reaches the repository call.
//
// ASSUMPTION: the precise cancellation semantics of `restartable()` — whether
// the superseded handler's `await` is abandoned or merely has its `emit`
// suppressed — were NOT verified against bloc_concurrency's source this
// session. The observable debounce behaviour is the documented purpose of
// `restartable()` ("cancel previous event handlers"), but if your handler has
// SIDE EFFECTS before its first `emit` (writing storage, firing analytics),
// confirm the semantics before relying on them, and guard with `emit.isDone`.

import 'package:bloc/bloc.dart'; // bloc@9.2.1
import 'package:bloc_concurrency/bloc_concurrency.dart'; // 0.3.0
import 'package:my_app/core/result.dart';
import 'package:my_app/features/product/data/repositories/product_repository.dart';
import 'package:my_app/features/product/domain/product_model.dart';
import 'package:my_app/features/product/presentation/bloc/product_event.dart';
import 'package:my_app/features/product/presentation/bloc/product_state.dart';

/// How long to wait after the last keystroke before searching.
const _searchDebounce = Duration(milliseconds: 300);

/// Event-driven emitter for the product screen.
///
/// Registered as a FACTORY in lib/core/di/injector.dart and provided with
/// `BlocProvider(create: (_) => getIt<ProductBloc>())`. The factory-vs-
/// singleton reasoning is identical to product_cubit.dart's — read that
/// file's header; `BlocProvider(create:)` closes what it creates, so a
/// singleton feature bloc hands out a closed instance on the second mount.
class ProductBloc extends Bloc<ProductEvent, ProductState> {
  /// Creates the bloc over an injected [ProductRepository].
  ///
  /// Every `on<>` below passes an explicit transformer; none inherits the
  /// concurrent default (see this file's header for why that matters).
  ProductBloc(this._repository) : super(const ProductState.initial()) {
    on<ProductRequested>(_onRequested, transformer: droppable());
    on<ProductSearchChanged>(_onSearchChanged, transformer: restartable());
    on<ProductRefreshRequested>(_onRefreshRequested, transformer: sequential());
  }

  final ProductRepository _repository;

  /// Loads [ProductRequested.id]. `droppable()` — a second tap while a load
  /// is already running is a double-tap, not a new intention.
  Future<void> _onRequested(
    ProductRequested event,
    Emitter<ProductState> emit,
  ) async {
    emit(const ProductState.loading());
    await _emitResult(await _repository.getProduct(event.id), emit);
  }

  /// Searches for [ProductSearchChanged.query]. `restartable()` plus the
  /// leading delay gives debounce: a keystroke during the wait restarts this
  /// handler, so only the final query reaches the repository.
  Future<void> _onSearchChanged(
    ProductSearchChanged event,
    Emitter<ProductState> emit,
  ) async {
    if (event.query.isEmpty) {
      emit(const ProductState.initial());
      return;
    }
    await Future<void>.delayed(_searchDebounce);
    emit(const ProductState.loading());
    await _emitResult(await _repository.getProduct(event.query), emit);
  }

  /// Pull-to-refresh. `sequential()` so two overlapping refreshes cannot
  /// interleave their emissions and leave the newer result overwritten.
  ///
  /// Deliberately does NOT emit a loading state: the refresh indicator is
  /// already on screen, and blanking the list under it is a visible flicker.
  Future<void> _onRefreshRequested(
    ProductRefreshRequested event,
    Emitter<ProductState> emit,
  ) async {
    final current = state;
    final id = current is ProductLoaded ? current.product.id : null;
    if (id == null) return;
    await _emitResult(await _repository.getProduct(id), emit);
  }

  /// Maps a `Result<ProductModel>` onto the two terminal states.
  ///
  /// Shared by all three handlers so the `Success`/`Failure` switch — and the
  /// decision to carry the typed `AppError` rather than a `String` — lives in
  /// exactly one place. See product_state.dart for why the type is kept.
  Future<void> _emitResult(
    Result<ProductModel> result,
    Emitter<ProductState> emit,
  ) async {
    switch (result) {
      case Success(:final value):
        emit(ProductState.loaded(value));
      case Failure(:final error):
        emit(ProductState.error(error));
    }
  }
}
