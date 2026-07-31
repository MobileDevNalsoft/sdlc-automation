// lib/core/storage/storage_keys.dart
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
// Every persistence key the app uses, in one file, as `static const String`.
// Both `SecureStore` and `KeyValueStore` draw from this list.
//
// WHY A FILE INSTEAD OF LITERALS AT THE CALL SITE
// Storage keys are the one kind of string where a typo does not fail — it
// silently reads absent and writes to a key nobody will ever read again. That
// failure mode is invisible in code review and in tests that write then read
// through the same typo. Naming them here also makes "what does this app
// persist?" answerable by opening one file, which matters for a privacy
// review and for writing a correct sign-out.
//
// THE NAMESPACE CONVENTION
// `<area>.<name>`, dot-separated. The prefix is not decorative: it is what
// makes a targeted sign-out possible ("delete every `auth.` key, keep every
// `settings.` key") without clearing storage wholesale. Keep the prefix in
// sync with the directory the feature lives in.
//
// WHAT TO CHANGE WHEN YOU COPY THIS
// Add a constant per persisted value, with a doc comment naming WHICH store
// it belongs to and WHAT type is stored. Two rules worth enforcing in review:
//   - Never reuse a key for a different type after a release ships. Old
//     devices still hold the old value; `KeyValueStore.read` will return null
//     for the mismatch (which is safe), but that is a silent data loss you
//     should choose deliberately rather than discover. Retire the key and add
//     a new one instead.
//   - Never put a key here that you do not intend to persist across app
//     restarts. Transient state belongs in a Cubit.

/// Namespaced keys for every value this app persists.
///
/// `abstract final class` so it can be neither instantiated nor extended —
/// this is a namespace, not a type.
abstract final class StorageKeys {
  /// SECURE STORE. The bearer token sent as `Authorization: Bearer <token>`.
  ///
  /// Read by `AuthInterceptor` on every request and again when deciding
  /// whether another in-flight request already refreshed it.
  static const String accessToken = 'auth.accessToken';

  /// SECURE STORE. The long-lived token exchanged for a new [accessToken].
  ///
  /// Never sent on ordinary requests — only to the refresh endpoint, and only
  /// through the interceptor-free replay client.
  static const String refreshToken = 'auth.refreshToken';

  /// SECURE STORE. Identifier of the signed-in user, as a String.
  ///
  /// Kept beside the tokens rather than in the key/value store so that a
  /// single `SecureStore.clear()` at sign-out removes the whole identity.
  static const String userId = 'auth.userId';

  /// KEY/VALUE STORE. The user's theme preference, stored as the `name` of a
  /// `ThemeMode` value (`'system'`, `'light'`, `'dark'`).
  ///
  /// Stored as a String rather than an index because enum indices renumber
  /// when someone reorders the enum, and old devices keep the old number.
  static const String themeMode = 'settings.themeMode';

  /// KEY/VALUE STORE. The user's chosen locale as a BCP-47 tag (`'en'`,
  /// `'pt-BR'`), or absent to follow the device locale.
  static const String locale = 'settings.locale';

  /// KEY/VALUE STORE. Whether the onboarding flow has been completed, as a
  /// bool.
  ///
  /// Read synchronously, which is why it can legally participate in a
  /// `go_router` redirect decision — unlike anything in the secure store.
  static const String onboardingComplete = 'settings.onboardingComplete';
}
