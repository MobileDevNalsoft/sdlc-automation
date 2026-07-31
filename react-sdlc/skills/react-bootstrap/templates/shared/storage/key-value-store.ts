// DESTINATION: src/shared/storage/key-value-store.ts
//
// Parallel to flutter-bootstrap's core/storage/key_value_store.dart: the
// interface comes first, and exactly ONE production implementation ships
// against it (plus an in-memory double for tests).
//
// Everything above this file depends on the interface, never on
// `window.localStorage` directly — which is what makes a test not need a DOM,
// and what makes swapping to IndexedDB later a one-file change.
export interface KeyValueStore {
  get: <T>(key: string) => T | null;
  set: <T>(key: string, value: T) => void;
  remove: (key: string) => void;
  clear: () => void;
}
