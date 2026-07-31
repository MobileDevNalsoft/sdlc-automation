// lib/core/storage/secure_store.dart
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
// The abstraction over platform-secure storage (Keychain on iOS/macOS,
// EncryptedSharedPreferences-successor ciphers on Android, libsecret on
// Linux, DPAPI/credential store on Windows). Tokens and nothing else.
//
// WHY THE INTERFACE IS IN ITS OWN FILE, SEPARATE FROM THE IMPLEMENTATION
// This file imports NOTHING. That is deliberate and load-bearing:
//   - `lib/core/network/auth_interceptor.dart` depends on this type, and the
//     recommended boundary rule R1 (see flutter-bootstrap's
//     tools/check_boundaries.dart) denies `package:flutter_secure_storage`
//     imports under `lib/features/**` AND under `lib/core/network/**`. If
//     the interface and the impl shared a file, importing the interface
//     would drag the package in and defeat that rule.
//   - A unit test can implement this with a plain `Map` and never touch a
//     platform channel.
//
// WHY ONE GENERAL `read(key)` INTERFACE AND NOT A `TokenStore`
// An earlier draft of the network layer wanted a narrow
// `TokenStore { readAccessToken(); clear(); }`. That was rejected: two
// near-identical storage interfaces is exactly the drift this scaffold
// exists to prevent. `AuthInterceptor` takes a [SecureStore] and reads
// `StorageKeys.accessToken`. If you find yourself adding a second storage
// abstraction, add a key to lib/core/storage/storage_keys.dart instead.
//
// WHAT TO CHANGE WHEN YOU COPY THIS
// Almost nothing. Resist adding `readAll()` — enumerate-everything is a
// capability a token store does not need, and on some backends it is far
// slower than a keyed read.
//
// WHAT DOES *NOT* BELONG IN HERE
// Anything that is not a credential. Secure storage is slow (it crosses a
// platform channel and does real crypto per call) and, on Android, has a
// history of being wiped by backup/restore and OEM keystore quirks. User
// preferences, cached payloads and feature flags go in `KeyValueStore`.
//
// PLATFORM CAVEAT THE GENERATED PROJECT'S README MUST CARRY (web):
// flutter_secure_storage's own README says its web implementation "only
// works on HTTPS or localhost environments" and warns that without HSTS and
// correct headers "you could be subject to a javascript hijack". Plainly:
// **on web this is NOT equivalent to Keychain/Keystore** — the key material
// lives where page JavaScript can reach it, so an XSS is a token compromise.
// If you target web, the real mitigation is short-lived access tokens plus
// an httpOnly refresh cookie, not this package.

/// Platform-secure key/value storage for credentials.
///
/// Backed by the OS credential store. Every method crosses a platform
/// channel, so all of them are asynchronous — which is precisely why the
/// router's auth guard must never call this. `go_router`'s `redirect` is
/// synchronous; a guard that awaited a token read would race the store on
/// cold start and bounce an already-authenticated user to `/login`
/// intermittently. The guard reads in-memory `AuthCubit` state instead, and
/// `configureDependencies` hydrates that Cubit with an awaited
/// `restoreSession()` before `runApp`.
///
/// Implementations must treat a platform failure on [read] as absence
/// (return null) rather than throwing: a missing keychain entry, a locked
/// keystore and a wiped credential store are all "no token" from a caller's
/// point of view, and the auth flow already models absence.
abstract interface class SecureStore {
  /// Returns the value stored under [key], or null if there is none.
  ///
  /// Returns null rather than throwing when the platform store is
  /// unavailable — see the class doc.
  Future<String?> read(String key);

  /// Stores [value] under [key], replacing any previous value.
  Future<void> write(String key, String value);

  /// Removes the value stored under [key]. A no-op if there is none.
  Future<void> delete(String key);

  /// Removes every value this app has written.
  ///
  /// Called on sign-out and when a token refresh fails unrecoverably. Note
  /// that on some platforms this clears the whole app's namespace, so do not
  /// use secure storage for anything you would not want deleted at sign-out.
  Future<void> clear();
}
