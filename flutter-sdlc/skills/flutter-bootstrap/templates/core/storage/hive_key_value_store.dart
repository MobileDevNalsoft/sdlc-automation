// lib/core/storage/hive_key_value_store.dart
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
// The default `KeyValueStore` implementation, over an ALREADY-OPEN hive_ce
// `Box`. Together with flutter_secure_store.dart it is one of only two files
// allowed to import a storage package (boundary rule R1).
//
// VERSION EVIDENCE
// hive_ce 2.19.3 / hive_ce_flutter 2.3.4. The `Box<E>` API used below was
// fetched live from pub.dev/documentation/hive_ce/latest/hive_ce/
// Box-class.html on 2026-07-30 (page reports 2.19.3):
//   get(dynamic key, {E? defaultValue}) -> E?
//   put(dynamic key, E value)           -> Future<void>
//   delete(dynamic key)                 -> Future<void>
//   clear()                             -> Future<int>      // note: int
//   containsKey(dynamic key)            -> bool
//   watch({dynamic key})                -> Stream<BoxEvent>
// `hive_ce_flutter` re-exports `Hive`, `Box` and `BoxEvent`, confirmed from
// pub.dev/documentation/hive_ce_flutter/latest/hive_flutter/ the same day, so
// one import covers both.
//
// WHY hive_ce AND NOT hive
// The original `hive` package's last stable release (2.2.3) was published
// 2022-06-30 and its 4.x line died in dev in 2023; `hive_flutter 1.1.0` is
// from 2021 and still pins Dart-2-era lints. Both still RESOLVE — this is a
// maintenance rejection, not a resolver failure, and it is worth being
// precise about that. `hive_ce` is the community continuation: 2.19.3 was
// published 2026-02-03 and its repository was pushed to 2026-07-29.
//
// WHY THE BOX IS INJECTED RATHER THAN OPENED IN HERE
// This class never calls `Hive.box('settings')`. If it did, this file would
// reintroduce — under a new name — exactly the defect this whole refactor
// exists to kill: reading a mutable global that some earlier line was
// supposed to have initialized. `Hive.box()` on an unopened box throws
// `HiveError('Box not found. Did you forget to call Hive.openBox()?')` at
// runtime. Taking the open `Box` as a constructor argument turns that runtime
// error into an unsatisfiable constructor, and confines the Hive global to
// the single `await Hive.openBox(...)` in `configureDependencies`.
//
// NO CODE GENERATION, DELIBERATELY
// There is no `hive_ce_generator` in this project's dev_dependencies and no
// `TypeAdapter` registered anywhere. Persist domain objects as JSON maps
// using the json_serializable this project already has. Reason: as of
// 2026-07-30, with freezed 3.2.5 constraining analyzer to `>=9.0.0 <11.0.0`,
// only hive_ce_generator 1.11.0 and 1.11.1 are compatible out of its entire
// release history — every later release requires analyzer 12+ and every
// earlier one is below freezed's floor. Adopting it means hand-pinning a
// second generator that blocks upgrades, on top of the build_runner 2.15.1
// pin freezed already forces. If you decide the tradeoff is worth it, pin it
// EXACTLY (`hive_ce_generator: 1.11.1`, never `^1.11.1`) with a comment
// naming freezed as the cause.
//
// SWITCHING TO shared_preferences INSTEAD
// Write a `SharedPreferencesKeyValueStore` in this directory, delete this
// file, and change one line in `configureDependencies`. Two notes if you do:
// (1) use `SharedPreferencesAsync`, not the legacy
// `SharedPreferences.getInstance()` — the maintainers moved the latter into a
// file literally named `shared_preferences_legacy.dart`; (2) its reads are
// asynchronous, so `KeyValueStore.read` can no longer be synchronous and the
// interface changes with it. That is the real cost of the swap.
//
// WEB CAVEAT: with `kIsWeb`, `Hive.initFlutter()` skips path_provider and the
// IndexedDB backend is used. That storage is origin-scoped and clearable by
// the user at any moment — treat web key/value data as a cache, never as a
// source of truth. It also means the native-only "You need to initialize
// Hive" error CANNOT fire on web, so a web-first dev loop will not surface a
// missing `initFlutter()` call that will crash on device.

import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:my_app/core/storage/key_value_store.dart';

/// [KeyValueStore] backed by a hive_ce [Box].
///
/// The box must already be open. Register it once, eagerly, right after the
/// `await Hive.openBox(...)` that produced it:
///
/// ```dart
/// final settingsBox = await Hive.openBox<Object?>('settings');
/// getIt.registerSingleton<KeyValueStore>(HiveKeyValueStore(settingsBox));
/// ```
///
/// The box is typed `Box<Object?>` rather than a per-value generic because
/// one box holds heterogeneous settings. The type safety callers actually
/// want is restored at [read], which is generic and returns null on a type
/// mismatch.
class HiveKeyValueStore implements KeyValueStore {
  /// Wraps an already-open box.
  ///
  /// (No square-bracket reference to the parameter: it is `this._box`, so the
  /// only name in scope is the private field, and `comment_references` fails
  /// on `[box]`.)
  const HiveKeyValueStore(this._box);

  final Box<Object?> _box;

  /// Returns the value for [key] if it is present AND is a [T], else null.
  ///
  /// The `is T` test rather than an `as T` cast is what makes a stale value
  /// of the wrong type behave as absence instead of throwing `TypeError` on
  /// launch — see [KeyValueStore.read].
  @override
  T? read<T extends Object>(String key) {
    final value = _box.get(key);
    return value is T ? value : null;
  }

  @override
  Future<void> write<T extends Object>(String key, T value) =>
      _box.put(key, value);

  @override
  Future<void> delete(String key) => _box.delete(key);

  /// Removes every entry in the box.
  ///
  /// hive_ce's own `Box.clear()` returns the number of entries removed; that
  /// count is dropped here so the interface stays backend-agnostic.
  @override
  Future<void> clear() async {
    await _box.clear();
  }

  @override
  bool containsKey(String key) => _box.containsKey(key);

  /// Emits an event whenever [key] changes, or whenever anything in the box
  /// changes if [key] is omitted.
  ///
  /// This is NOT part of [KeyValueStore] on purpose: exposing a
  /// `Stream<BoxEvent>` on the interface would leak a hive_ce type through
  /// the abstraction and into whatever imported it, which is what boundary
  /// rule R1 exists to prevent. It is available here for wiring done at the
  /// composition root — for instance, a Cubit that rebuilds the app's theme
  /// when the stored `ThemeMode` changes. If you need it behind the
  /// interface, expose a `Stream<void>` (no hive type) rather than this.
  Stream<BoxEvent> watch({String? key}) => _box.watch(key: key);
}
