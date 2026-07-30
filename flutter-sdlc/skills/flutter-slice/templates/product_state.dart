// lib/features/product/presentation/bloc/product_state.dart
// (folder named "bloc/" not "cubit/" — see flutter-slice's SKILL.md note on
// why, tied to flutter-verify's coverage-ratchet scope)
//
// freezed@3.2.5 sealed state. Syntax confirmed against freezed's own
// migration guide (rrousselGit/freezed, packages/freezed/migration_guide.md,
// "Migrate from v2 to v3" section): factory-constructor freezed classes now
// require an explicit `sealed`/`abstract` keyword on the class itself, and
// freezed 3.x no longer generates `.when`/`.map` — pattern matching goes
// through Dart's own `switch` (see product_screen.dart for the exhaustive
// switch this enables, with no default case).
//
// This state class is immutable and exhaustively matchable by construction
// (a sealed freezed type): a UI `switch` over it can omit a `default:` arm,
// which means adding a fifth state variant later without updating every
// switch site becomes a compile-time error, not a blank screen discovered in
// production.
//
// If a later feature adds `@Default(...)` or `@JsonKey(...)` to a
// constructor parameter here, flutter-bootstrap's analysis_options.yaml
// already carries the `invalid_annotation_target: ignore` addition that
// combination needs — see that file's comment for the sourced explanation.

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/product_model.dart';

part 'product_state.freezed.dart';

@freezed
sealed class ProductState with _$ProductState {
  const factory ProductState.initial() = ProductInitial;
  const factory ProductState.loading() = ProductLoading;
  const factory ProductState.loaded(ProductModel product) = ProductLoaded;
  const factory ProductState.error(String message) = ProductError;
}
