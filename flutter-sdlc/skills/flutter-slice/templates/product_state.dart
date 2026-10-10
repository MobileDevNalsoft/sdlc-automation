// lib/features/product/presentation/bloc/product_state.dart
// (folder named "bloc/" not "cubit/" — see flutter-slice's SKILL.md note on
// why, tied to flutter-verify's coverage-ratchet scope)
//
// TEMPLATE — copy to lib/features/<feature>/presentation/bloc/<feature>
// _state.dart, rename every `Product`/`product` identifier, and replace the
// placeholder package name `my_app` in the imports below with your own
// package name (the `name:` field of pubspec.yaml). Run
// `dart run build_runner build --delete-conflicting-outputs` afterwards —
// the `.freezed.dart` part file is generated, not hand-written.
//
// WHAT THIS IS
// freezed@3.2.5 sealed state. Syntax confirmed against freezed's own
// migration guide (rrousselGit/freezed, packages/freezed/migration_guide.md,
// "Migrate from v2 to v3"): factory-constructor freezed classes now require
// an explicit `sealed`/`abstract` keyword on the class itself, and freezed
// 3.x no longer generates `.when`/`.map` — pattern matching goes through
// Dart's own `switch`. See product_screen.dart for the exhaustive switch this
// enables, with no `default:` arm.
//
// This state class is immutable and exhaustively matchable BY CONSTRUCTION.
// A UI `switch` over it can omit `default:`, which means adding a fifth state
// variant later without updating every switch site is a compile-time error
// rather than a blank screen discovered in production. That property is the
// entire reason freezed is in this stack; it is not used for `copyWith`
// convenience.
//
// ---------------------------------------------------------------------------
// THE `error` VARIANT CARRIES `AppError`, NOT `String`
// ---------------------------------------------------------------------------
// It used to be `const factory ProductState.error(String message)`. Carrying
// the sealed `AppError` instead is what lets the screen hand the error
// straight to `AppErrorView`, which switches on the variant to decide whether
// the affordance is "Try again", "Sign in", or "Dismiss". With a String the
// only way to make that decision was to match on message text, which breaks
// silently the first time somebody rewords a sentence.
//
// It also means this file imports lib/core/error/app_error.dart. That is a
// core import, not a cross-feature one, so tools/check_boundaries.dart is
// unaffected — its regex only matches `package:<pkg>/features/<other>/`.
//
// If a later feature adds `@Default(...)` or `@JsonKey(...)` to a constructor
// parameter here, flutter-bootstrap's analysis_options.yaml already carries
// the `invalid_annotation_target: ignore` addition that combination needs —
// see that file's comment for the sourced explanation.
//
// ---------------------------------------------------------------------------
// WHAT TO CHANGE WHEN YOU COPY THIS
// ---------------------------------------------------------------------------
//   - Names, and the payload each variant carries.
//   - Add variants only for states the UI RENDERS DIFFERENTLY. A variant that
//     produces the same subtree as another is a variant that should not
//     exist; it only costs a branch at every switch site.
//   - For a list-shaped feature, add `const factory ProductState.empty()` so
//     "loaded, but there is nothing here" is its own branch and renders
//     `AppEmptyState` rather than an empty `ListView`. Empty is NOT a
//     failure and must never render `AppErrorView`.
//   - Do NOT add a variant that carries a `TextEditingController` or raw form
//     text. Form input belongs to the `StatefulWidget`, not to Cubit state.

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:my_app/core/error/app_error.dart';
import 'package:my_app/features/product/domain/product_model.dart';

part 'product_state.freezed.dart';

/// Everything the product screen can be showing, as a sealed set.
///
/// Sealed and immutable, so `switch (state)` in product_screen.dart is
/// exhaustive with no `default:` arm.
@freezed
sealed class ProductState with _$ProductState {
  /// Nothing has been requested yet. Renders the idle state.
  const factory ProductState.initial() = ProductInitial;

  /// A request is in flight. Renders `AppLoader` / skeleton.
  const factory ProductState.loading() = ProductLoading;

  /// The request succeeded but collection contains zero records. Renders `AppEmptyState`.
  const factory ProductState.empty() = ProductEmpty;

  /// User lacks entitlement or access is view-only on write screen. Renders `AppGateState`.
  const factory ProductState.gated(String reason) = ProductGated;

  /// The product loaded successfully.
  const factory ProductState.loaded(ProductModel product) = ProductLoaded;

  /// The request failed. Carries typed error for AppErrorView.
  const factory ProductState.error(AppError error) = ProductError;
}
