// lib/core/storage/in_memory_key_value_store.dart
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
// A `KeyValueStore` backed by a plain `Map`. It is a test double, and it is
// the concrete payoff of having an interface at all.
//
// WHY IT LIVES IN lib/ AND NOT test/
// So that any test in any feature can use it without a cross-package or
// relative import, and so a `--profile` build with a `--dart-define` can use
// it for a throwaway demo mode. It costs a few dozen bytes in release.
//
// WHY YOU WANT IT — the concrete problem it solves
// A widget test that pumps a screen touching `KeyValueStore` would otherwise
// need `Hive.initFlutter()`, which needs `path_provider`, which needs a
// platform channel the test binding does not provide. That fails as a
// `MissingPluginException` in a test that has nothing to do with storage.
// Registering this instead means widget tests never initialize Hive at all:
//
// ```dart
// setUp(() async {
//   await getIt.reset();
//   getIt
//     ..registerSingleton<FlavorConfig>(testConfig)
//     ..registerSingleton<KeyValueStore>(InMemoryKeyValueStore());
// });
// ```
//
// Also useful in a NON-test context: `Hive.openBox` throws
// `HiveError('The box "<name>" is already open ...')` if two tests each call
// a bootstrap path that opens the same box. If you genuinely need Hive in an
// integration test, either give each case
// `Hive.init(Directory.systemTemp.createTempSync().path)` or add
// `tearDown(() => Hive.close())`. Most tests should just use this class.
//
// WHAT TO CHANGE WHEN YOU COPY THIS
// Nothing, unless you widen `KeyValueStore` — then this must implement the
// new member too, which is a feature: it is a small tax that discourages
// widening the interface casually.
//
// DELIBERATE NON-FEATURE: this does not simulate failure. If you need a store
// that throws on the third write, write a purpose-built fake in that test
// file. A "fake with knobs" that every test configures differently is harder
// to read than five three-line fakes.

import 'package:my_app/core/storage/key_value_store.dart';

/// In-memory [KeyValueStore] for tests and throwaway demo modes.
///
/// Not persistent: every instance starts empty and its contents vanish with
/// the object. Its futures are already-completed, so awaiting a write never
/// yields to the event loop — which makes tests deterministic, but also means
/// this will not surface a real async ordering bug that the Hive-backed
/// implementation would. That is the standard trade of a fast fake, and it is
/// worth knowing which side of it you are on.
class InMemoryKeyValueStore implements KeyValueStore {
  /// Creates an empty store.
  InMemoryKeyValueStore();

  /// Creates a store pre-populated with [initialValues].
  ///
  /// Handy for "the user has already completed onboarding" style setups
  /// without three `await store.write(...)` lines in every `setUp`.
  InMemoryKeyValueStore.seeded(Map<String, Object> initialValues) {
    _values.addAll(initialValues);
  }

  final Map<String, Object> _values = <String, Object>{};

  /// The current contents, for assertions.
  ///
  /// Unmodifiable on purpose: a test that wants to change the store should go
  /// through [write] so it exercises the same path production code does.
  Map<String, Object> get values => Map<String, Object>.unmodifiable(_values);

  @override
  T? read<T extends Object>(String key) {
    final value = _values[key];
    return value is T ? value : null;
  }

  @override
  Future<void> write<T extends Object>(String key, T value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> clear() async {
    _values.clear();
  }

  @override
  bool containsKey(String key) => _values.containsKey(key);
}
