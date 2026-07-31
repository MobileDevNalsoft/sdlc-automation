// DESTINATION: src/shared/storage/storage-keys.ts
//
// Parallel to flutter-bootstrap's core/storage/storage_keys.dart: every
// storage key string in the app, in one file.
//
// Why centralize something this trivial: a key typed inline in two places is
// two keys, and the bug ("my preference doesn't persist") appears far from
// the typo. The namespace prefix keeps this app's keys from colliding with
// anything else on the same origin.
const NAMESPACE = 'app';

const key = (name: string): string => `${NAMESPACE}:${name}`;

export const StorageKeys = {
  theme: key('theme'),
  locale: key('locale'),
  accessToken: key('auth.access-token'),
  refreshToken: key('auth.refresh-token'),
  sidebarCollapsed: key('ui.sidebar-collapsed'),
} as const;

export type StorageKey = (typeof StorageKeys)[keyof typeof StorageKeys];
