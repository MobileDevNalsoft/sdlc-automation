// DESTINATION: src/shared/api/auth-interceptor.ts
//
// Parallel to flutter-bootstrap's core/network/auth_interceptor.dart
// (a dio QueuedInterceptor): stamp the access token on every request, and on
// a 401 refresh ONCE while every other 401 in flight waits on that same
// refresh instead of firing its own.
//
// Why single-flight is the whole point: without it, a page that fires six
// queries on mount against an expired token produces six concurrent refresh
// calls. On a backend that rotates refresh tokens, five of those six are
// replaying an already-consumed token — so five fail, and the user is logged
// out by a race rather than by an actual auth problem.
import { isAxiosError } from 'axios';
import type { AxiosInstance, InternalAxiosRequestConfig } from 'axios';

/**
 * The seam between the HTTP layer and wherever tokens actually live.
 *
 * Deliberately an interface, not a direct import of the auth store: this file
 * must not know whether tokens sit in memory, in a Zustand slice, or behind a
 * cookie. Mirrors flutter's rule that core/network depends on the SecureStore
 * interface, never on a concrete storage package.
 */
export interface AuthTokenPort {
  getAccessToken: () => string | null;
  /** Resolve to a fresh access token, or null when refresh is not possible. */
  refresh: () => Promise<string | null>;
  /** Called once when refresh definitively fails — clear session, redirect. */
  onRefreshFailed: () => void;
}

interface RetriableConfig extends InternalAxiosRequestConfig {
  __retriedAfterRefresh?: boolean;
}

export function installAuthInterceptor(client: AxiosInstance, tokens: AuthTokenPort): void {
  // Module-scoped per client instance, NOT global: two clients (e.g. a public
  // one and an authenticated one) must not share a refresh flight.
  let refreshInFlight: Promise<string | null> | null = null;

  function refreshOnce(): Promise<string | null> {
    refreshInFlight ??= tokens.refresh().finally(() => {
      // Cleared only after settling, so every caller that arrived during the
      // flight awaited the same promise. Assignment above is synchronous, so
      // this callback cannot run before it.
      refreshInFlight = null;
    });
    return refreshInFlight;
  }

  client.interceptors.request.use((config) => {
    const token = tokens.getAccessToken();
    if (token !== null && token !== '') {
      config.headers.set('Authorization', `Bearer ${token}`);
    }
    return config;
  });

  client.interceptors.response.use(undefined, async (error: unknown) => {
    if (!isAxiosError(error)) throw error;

    const original = error.config as RetriableConfig | undefined;
    const isAuthFailure = error.response?.status === 401;

    // `__retriedAfterRefresh` is what stops an infinite loop when the refreshed
    // token is itself rejected — the retry gets exactly one chance.
    if (!isAuthFailure || !original || original.__retriedAfterRefresh === true) {
      throw error;
    }
    original.__retriedAfterRefresh = true;

    let fresh: string | null;
    try {
      fresh = await refreshOnce();
    } catch {
      // A thrown refresh is a failed refresh. Surface the ORIGINAL 401 rather
      // than the refresh's own error — the caller asked for a resource, and
      // the refresh mechanism is an implementation detail it never invoked.
      fresh = null;
    }

    if (fresh === null || fresh === '') {
      tokens.onRefreshFailed();
      throw error;
    }

    original.headers.set('Authorization', `Bearer ${fresh}`);
    return client.request(original);
  });
}
