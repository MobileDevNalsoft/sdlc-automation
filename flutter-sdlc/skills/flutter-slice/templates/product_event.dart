// lib/features/product/presentation/bloc/product_event.dart
//
// TEMPLATE — copy to lib/features/<feature>/presentation/bloc/<feature>
// _event.dart, rename every `Product`/`product` identifier, and replace the
// placeholder package name `my_app` in the imports below with your own
// package name (the `name:` field of pubspec.yaml). Run
// `dart run build_runner build --delete-conflicting-outputs` afterwards —
// the `.freezed.dart` part file is generated, not hand-written.
//
// ---------------------------------------------------------------------------
// READ THIS BEFORE COPYING: MOST FEATURES MUST NOT HAVE THIS FILE
// ---------------------------------------------------------------------------
// This file exists ONLY for the minority of features that need a full,
// event-driven `Bloc`. The default in this stack is a `Cubit`, which has no
// event class at all — see product_cubit.dart and flutter-slice's SKILL.md
// "Cubit vs. full Bloc" section.
//
// Copy this file (and product_bloc.dart) ONLY if the feature needs an event
// *stream* with a transformer applied to it: debouncing a search-as-you-type
// field, throttling scroll-triggered pagination, or cancelling in-flight work
// when a newer event supersedes it. If the feature is a set of directly
// invoked request/response methods — `load()`, `submit()`, `refresh()` — it is
// a Cubit, and adding events here buys ceremony and nothing else.
//
// The state file is IDENTICAL either way. `product_state.dart` is unchanged
// whether the emitter is a Cubit or a Bloc, and so is product_screen.dart's
// exhaustive switch. That is deliberate: the Cubit-vs-Bloc choice is confined
// to the emitter, and swapping one for the other later touches this file and
// product_bloc.dart only.
//
// ---------------------------------------------------------------------------
// WHY EVENTS ARE SEALED TOO
// ---------------------------------------------------------------------------
// Sealing the event type is what makes `on<ProductRequested>` /
// `on<ProductSearchChanged>` registrations checkable: every variant below is a
// distinct Dart type, so a handler registered for a variant that no longer
// exists is a compile error rather than an event that is silently never
// handled at runtime. Bloc does NOT warn about an unhandled event type.
//
// ---------------------------------------------------------------------------
// WHAT TO CHANGE WHEN YOU COPY THIS
// ---------------------------------------------------------------------------
//   - Names, and one variant per user intention (not per state change).
//   - Name variants for what the USER DID, in the past tense
//     (`ProductSearchChanged`, `ProductRefreshRequested`), not for what the
//     bloc should do about it (`FetchProduct`, `SetLoading`). An event is a
//     fact that already happened; the handler decides the consequence.
//   - Do NOT add a variant carrying a `TextEditingController` or a
//     `BuildContext`. Events are values; they cross an async boundary and
//     outlive the widget that added them.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'product_event.freezed.dart';

/// Everything the user can do on the product screen, as a sealed set.
///
/// Each variant is registered with its own `on<...>` handler and its own
/// event transformer in product_bloc.dart.
@freezed
sealed class ProductEvent with _$ProductEvent {
  /// The screen mounted, or the user explicitly asked for [id] again.
  ///
  /// Handled with `droppable()` in product_bloc.dart — a second request for
  /// the same thing while one is already in flight is a double-tap, not a
  /// new intention.
  const factory ProductEvent.requested(String id) = ProductRequested;

  /// The user typed in the search field; [query] is the full current text.
  ///
  /// This is the variant that justifies using a `Bloc` at all: it arrives
  /// once per keystroke and is handled with `restartable()` so only the
  /// latest query survives. See product_bloc.dart.
  const factory ProductEvent.searchChanged(String query) = ProductSearchChanged;

  /// Pull-to-refresh. Handled sequentially so two overlapping refreshes
  /// cannot interleave their emissions.
  const factory ProductEvent.refreshRequested() = ProductRefreshRequested;
}
