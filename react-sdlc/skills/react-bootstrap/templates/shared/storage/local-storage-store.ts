// DESTINATION: src/shared/storage/local-storage-store.ts
//
// The one production KeyValueStore implementation.
//
// Every method swallows-and-reports rather than throwing, because all three
// realistic failure modes are environmental rather than programmer error:
//   - Safari Private Browsing historically throws QuotaExceededError on the
//     very first setItem.
//   - A user with cookies/site-data blocked makes `localStorage` itself throw
//     on property access.
//   - Storage full, from this app or any other on the same origin.
// A crashed app is a far worse outcome than an unsaved sidebar preference, so
// persistence is treated as best-effort. NOTHING that must not be lost may
// live here — see token-store.ts.
import type { KeyValueStore } from './key-value-store';

function backingStore(): Storage | null {
  try {
    // Property access itself can throw when site data is blocked.
    return typeof window === 'undefined' ? null : window.localStorage;
  } catch {
    return null;
  }
}

export function createLocalStorageStore(): KeyValueStore {
  return {
    get<T>(key: string): T | null {
      const store = backingStore();
      if (!store) return null;
      try {
        const raw = store.getItem(key);
        return raw === null ? null : (JSON.parse(raw) as T);
      } catch {
        // Corrupt/hand-edited value. Drop it rather than crashing every
        // subsequent read on the same key.
        try {
          store.removeItem(key);
        } catch {
          /* nothing further to do */
        }
        return null;
      }
    },

    set<T>(key: string, value: T): void {
      const store = backingStore();
      if (!store) return;
      try {
        store.setItem(key, JSON.stringify(value));
      } catch {
        /* quota or private mode — best-effort by design */
      }
    },

    remove(key: string): void {
      const store = backingStore();
      if (!store) return;
      try {
        store.removeItem(key);
      } catch {
        /* best-effort */
      }
    },

    clear(): void {
      const store = backingStore();
      if (!store) return;
      try {
        store.clear();
      } catch {
        /* best-effort */
      }
    },
  };
}

export const localStorageStore: KeyValueStore = createLocalStorageStore();
