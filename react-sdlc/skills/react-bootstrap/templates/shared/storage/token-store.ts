// DESTINATION: src/shared/storage/token-store.ts
//
// Parallel to flutter-bootstrap's core/storage/secure_store.dart — and the
// parallel is where the honesty is required, because THE BROWSER HAS NO
// KEYCHAIN. flutter_secure_storage maps to Keystore/Keychain on device; there
// is no equivalent primitive on the web. Anything reachable from JavaScript
// is reachable from injected JavaScript.
//
// So the ranking, strongest first:
//
//   1. BEST — refresh token in an httpOnly + Secure + SameSite cookie the JS
//      never touches, access token held in MEMORY ONLY (this file's default).
//      An XSS can still CALL the API as the user while it runs, but it cannot
//      read the refresh token and cannot persist access past page unload.
//   2. WEAKER — access token in sessionStorage: survives reload, readable by
//      any injected script, gone when the tab closes.
//   3. WEAKEST — anything in localStorage: readable by any injected script and
//      persists indefinitely, so one XSS is a durable account compromise.
//
// The default below is (1). `createPersistentTokenStore` implements (2)/(3)
// and exists because some backends genuinely cannot issue cookies — it is
// labelled, not hidden, so choosing it is a decision someone made on purpose.
import type { KeyValueStore } from './key-value-store';
import { StorageKeys } from './storage-keys';

export interface TokenStore {
  getAccessToken: () => string | null;
  setAccessToken: (token: string | null) => void;
  clear: () => void;
}

/**
 * (1) The default. Access token lives in a module closure — never written to
 * any Storage, so it does not survive a reload. That is the intended
 * behaviour: on reload the app calls the refresh endpoint, which authenticates
 * via the httpOnly cookie the JS cannot read.
 */
export function createMemoryTokenStore(): TokenStore {
  let accessToken: string | null = null;
  return {
    getAccessToken: () => accessToken,
    setAccessToken: (token) => {
      accessToken = token;
    },
    clear: () => {
      accessToken = null;
    },
  };
}

/**
 * (2)/(3) Persistent fallback. Pass a sessionStorage-backed KeyValueStore for
 * (2); passing a localStorage-backed one is (3) and should be a recorded
 * decision, not a default someone drifted into.
 */
export function createPersistentTokenStore(store: KeyValueStore): TokenStore {
  return {
    getAccessToken: () => store.get<string>(StorageKeys.accessToken),
    setAccessToken: (token) => {
      if (token === null) {
        store.remove(StorageKeys.accessToken);
      } else {
        store.set(StorageKeys.accessToken, token);
      }
    },
    clear: () => {
      store.remove(StorageKeys.accessToken);
      store.remove(StorageKeys.refreshToken);
    },
  };
}
