// lib/core/storage/key_value_store.dart
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
// The abstraction over ordinary, non-secret local persistence: user
// preferences, cached payloads, "has the user seen onboarding", the last
// selected locale. NOT credentials — those go in `SecureStore`.
//
// WHY THE INTERFACE IS IN ITS OWN FILE
// Same reason as `SecureStore`: this file imports nothing, so depending on
// the abstraction never drags `package:hive_ce` into a feature. Boundary rule
// R1 denies storage-package imports under `lib/features/**`, and that rule is
// only enforceable if the interface is import-free.
//
// WHY [read] IS SYNCHRONOUS WHILE EVERY WRITE IS ASYNC
// This mirrors hive_ce's actual `Box` API, verified live from
// pub.dev/documentation/hive_ce/latest/hive_ce/Box-class.html on 2026-07-30
// (page reports hive_ce 2.19.3):
//     get(dynamic key, {E? defaultValue}) -> E?          // synchronous
//     put(dynamic key, E value)           -> Future<void>
//     delete(dynamic key)                 -> Future<void>
//     clear()                             -> Future<int>
//     containsKey(dynamic key)            -> bool         // synchronous
// The page states "Write operations are asynchronous but the new values are
// immediately available", because a non-lazy box holds its entries in memory.
//
// That synchronous read is not a cosmetic detail — it is the ONE storage
// call a `go_router` `redirect` guard could legally make, because `redirect`
// is synchronous. (Auth state still must not come from here; see
// `SecureStore`'s doc. But "which locale did the user pick" legitimately
// can.) If you swap the implementation for one whose reads are genuinely
// async, you cannot keep this signature — and that is a real, breaking
// property of the interface, not an implementation detail.
//
// WHY ONE IMPLEMENTATION AND NOT TWO
// `hive_ce` and `shared_preferences` are both credible and both resolve
// cleanly against this project's analyzer ceiling. This scaffold ships the
// interface plus EXACTLY ONE implementation (hive_ce), because shipping both
// means two init paths, two places to look, and a permanent "which one holds
// this setting?" question. `shared_preferences` is the documented drop-in
// alternate — see hive_key_value_store.dart's header for how to switch.
//
// WHAT TO CHANGE WHEN YOU COPY THIS
// Add domain-shaped helpers to a small class ON TOP of this interface rather
// than widening the interface itself (e.g. an `AppSettings` class that owns
// `ThemeMode get themeMode` and delegates to a `KeyValueStore`). Every method
// added here has to be implemented by the in-memory test double too.

/// Non-secret local key/value persistence.
///
/// Obtain it from DI; never construct an implementation inside a feature:
///
/// ```dart
/// final store = getIt<KeyValueStore>();
/// final seen = store.read<bool>(StorageKeys.onboardingComplete) ?? false;
/// await store.write<bool>(StorageKeys.onboardingComplete, true);
/// ```
///
/// Keys come from lib/core/storage/storage_keys.dart, never from a string
/// literal at the call site.
///
/// Values must be types the backing store can persist without a code-
/// generated adapter. For hive_ce that is: null, int, double, bool, String,
/// Map, Uint8List, List, Set, plus DateTime, BigInt and Duration (which
/// hive_ce registers internal adapters for). Anything else — including your
/// own domain models — must be encoded to a JSON `Map<String, dynamic>`
/// first, reusing the json_serializable this project already has. That is a
/// deliberate choice to avoid adding a SECOND code generator pinned to a
/// specific analyzer version; one such generator (freezed) is already pinning
/// build_runner, and a scaffold should not ship a pattern of upgrade-blocked
/// generators.
abstract interface class KeyValueStore {
  /// Returns the value stored under [key] as a [T], or null.
  ///
  /// Returns null both when the key is absent and when the stored value is
  /// not a [T]. Reading back the wrong type is a programming error, but it is
  /// one that typically happens after a schema change on a device that still
  /// holds old data, where throwing would be a crash on launch. Absence is
  /// the safer reading, and callers already have to handle it.
  T? read<T extends Object>(String key);

  /// Stores [value] under [key], replacing any previous value.
  ///
  /// Awaiting this is optional for correctness — a non-lazy box makes the new
  /// value readable immediately — but the returned future completes when the
  /// value has actually reached disk, so await it before anything that
  /// depends on durability (for example, before backgrounding the app).
  Future<void> write<T extends Object>(String key, T value);

  /// Removes the value stored under [key]. A no-op if there is none.
  Future<void> delete(String key);

  /// Removes every value in this store.
  ///
  /// Note this clears app settings too, so it is usually the wrong thing to
  /// call on sign-out — delete the specific user-scoped keys instead.
  Future<void> clear();

  /// Whether a value is currently stored under [key].
  ///
  /// Prefer `read<T>(key) != null` when you are about to read the value
  /// anyway; this exists for the case where presence itself is the signal.
  bool containsKey(String key);
}
