// lib/features/product/presentation/bloc/product_cubit.dart
// (folder named "bloc/" not "cubit/" — see flutter-slice's SKILL.md note on
// why, tied to flutter-verify's coverage-ratchet scope)
//
// Cubit: the only layer allowed to call the Repository and the only layer
// allowed to `switch` on a Result<T> — a Screen switches on ProductState
// (see product_screen.dart), never on Result directly. bloc@9.2.1 (via
// flutter_bloc@9.1.1).
//
// This feature uses `Cubit`, not a full event-driven `Bloc`, because `load()`
// is a plain, directly-invoked request/response operation with nothing to
// debounce, throttle, or race against a newer call — see flutter-slice's
// SKILL.md "Cubit vs. full Bloc" section for the rule that decides which one
// a given feature needs.
//
// `Success(:final value)` / `Failure(:final error)` below are Dart 3 object
// patterns destructuring core/result.dart's Success/Failure fields — no
// `.value`/`.error` getter call needed, and no `if (result is Success)`
// cast, which is the point of Result<T> being a sealed type in the first
// place: the switch below is exhaustive over Result<ProductModel> the same
// way product_screen.dart's switch is exhaustive over ProductState.

import 'package:bloc/bloc.dart';

import '../../../../core/result.dart';
import '../../data/repositories/product_repository.dart';
import 'product_state.dart';

class ProductCubit extends Cubit<ProductState> {
  ProductCubit(this._repository) : super(const ProductState.initial());

  final ProductRepository _repository;

  Future<void> load(String id) async {
    emit(const ProductState.loading());
    final result = await _repository.getProduct(id);
    switch (result) {
      case Success(:final value):
        emit(ProductState.loaded(value));
      case Failure(:final error):
        emit(ProductState.error(error.message));
    }
  }
}
