// DESTINATION: src/shared/storage/memory-store.ts
//
// Parallel to flutter-bootstrap's core/storage/in_memory_key_value_store.dart:
// the test double, shipped alongside the interface rather than re-invented in
// each test file.
//
// A test that uses this needs no DOM, no storage permission, and no cleanup
// between cases beyond constructing a new one — which is exactly why the
// interface exists.
import type { KeyValueStore } from './key-value-store';

export function createMemoryStore(seed?: Record<string, unknown>): KeyValueStore {
  const map = new Map<string, unknown>(Object.entries(seed ?? {}));

  return {
    get<T>(key: string): T | null {
      return map.has(key) ? (map.get(key) as T) : null;
    },
    set<T>(key: string, value: T): void {
      map.set(key, value);
    },
    remove(key: string): void {
      map.delete(key);
    },
    clear(): void {
      map.clear();
    },
  };
}
