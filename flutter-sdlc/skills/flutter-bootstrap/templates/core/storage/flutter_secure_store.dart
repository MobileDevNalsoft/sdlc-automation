// lib/core/storage/flutter_secure_store.dart
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
// The one and only implementation of `SecureStore`, over
// flutter_secure_storage. It is the only file in the app allowed to import
// `package:flutter_secure_storage` (boundary rule R1).
//
// VERSION EVIDENCE
// flutter_secure_storage 10.3.1 — the constructor and method signatures used
// below were fetched live from
// pub.dev/documentation/flutter_secure_storage/latest/flutter_secure_storage/
// FlutterSecureStorage-class.html on 2026-07-30, which reports package
// version 10.3.1 and:
//   FlutterSecureStorage({IOSOptions iOptions, AndroidOptions aOptions,
//     LinuxOptions lOptions, WindowsOptions wOptions, WebOptions webOptions,
//     AppleOptions mOptions})
//   read({required String key, ...}) -> Future<String?>
//   write({required String key, required String? value, ...}) -> Future<void>
//   delete({required String key, ...}) -> Future<void>
//   deleteAll({...}) -> Future<void>
// Note every parameter is NAMED — `_storage.read(key)` does not compile.
//
// WHY THE CONSTRUCTOR TAKES THE PLUGIN RATHER THAN CONSTRUCTING IT
// `configureDependencies` writes
// `const FlutterSecureStore(FlutterSecureStorage())`. Injecting the plugin
// keeps this class const-constructible (which is what makes
// `prefer_const_constructors` satisfiable at the registration site) and lets
// a test pass a fake plugin without any platform-channel mocking. There is
// deliberately no `FlutterSecureStorage? storage` fallback parameter — a
// `storage ?? FlutterSecureStorage()` default is the anti-pattern where a
// forgotten test argument silently talks to the real keystore.
//
// WHAT TO CHANGE WHEN YOU COPY THIS
//   - Android: pass `aOptions:` to `FlutterSecureStorage(...)` at the
//     registration site if you need a non-default preference name.
//   - iOS/macOS: pass `iOptions:`/`mOptions:` to set an access group or
//     `KeychainAccessibility` (relevant if a background isolate or an app
//     extension must read the token while the device is locked).
//   - ANDROID minSdk: flutter_secure_storage 10.x requires minSdkVersion 23.
//     Set it in `android/app/build.gradle` — this fails at build time, not
//     at runtime, so it is a README item for the generated project.
//   - MIGRATING FROM 9.x: 10.0.0 moved off Jetpack Security's deprecated
//     `encryptedSharedPreferences` to custom ciphers, so tokens written by a
//     9.x build are unreadable by a 10.x build. For a TOKEN store the correct
//     handling is to treat the failed read as "logged out" — which the null
//     return below already does — not to write a migration.

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:my_app/core/storage/secure_store.dart';

/// [SecureStore] backed by the operating system's credential store.
///
/// Register it once, eagerly, because the instance is free to build and
/// everything auth-related needs it:
///
/// ```dart
/// getIt.registerSingleton<SecureStore>(
///   const FlutterSecureStore(FlutterSecureStorage()),
/// );
/// ```
class FlutterSecureStore implements SecureStore {
  /// Wraps an existing [FlutterSecureStorage] instance.
  ///
  /// Take the plugin as a parameter rather than constructing it internally so
  /// that platform options stay configurable at the composition root and a
  /// test can substitute a fake.
  const FlutterSecureStore(this._storage);

  final FlutterSecureStorage _storage;

  /// Returns the value for [key], or null if absent OR if the platform store
  /// could not be reached.
  ///
  /// The swallowed [PlatformException] is deliberate and is the asymmetry
  /// worth understanding in this class: a missing keychain entry, a locked
  /// keystore, a credential store wiped by a backup/restore, and a 9.x→10.x
  /// cipher change are ALL "no token" from the caller's point of view. The
  /// auth flow already has a branch for "no token" — sign in — and turning
  /// this into an error would add a second, worse branch that most callers
  /// would handle identically anyway.
  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } on PlatformException {
      return null;
    }
  }

  /// Stores [value] under [key].
  ///
  /// Unlike [read] this does NOT swallow platform failures, and the
  /// difference is intentional. Silently dropping a write leaves the app
  /// believing it saved a token it did not, which presents to a user as being
  /// signed out again on every cold start — a far worse and much harder-to-
  /// diagnose failure than an error at the moment of writing. The calling
  /// Repository should catch `on PlatformException` and return a
  /// `Failure(UnknownError(...))` so the failure travels through the normal
  /// `Result<T>` seam.
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  /// Removes the value for [key].
  ///
  /// Also propagates platform failures, for the same reason as [write]: a
  /// silently-failed delete at sign-out means a credential the user believes
  /// is gone is still on the device.
  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  /// Removes every value this app has written to secure storage.
  @override
  Future<void> clear() => _storage.deleteAll();
}
