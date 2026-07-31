// DESTINATION: src/shared/api/http-client.ts
//
// Parallel to flutter-bootstrap's core/network/dio_client.dart: the ONE
// configured client instance, with an explicitly ORDERED interceptor chain.
//
// ORDER IS LOAD-BEARING. Axios runs response interceptors in registration
// order, so auth is installed first and retry second. A 401 is therefore
// resolved by a token refresh before the retry interceptor ever sees it — and
// because 401 is not in retry's status table, the two never contend for the
// same failure. Swapping these two lines produces a client that retries an
// expired-token request three times before refreshing it once.
//
// baseURL is a RELATIVE path by default ('/api'), which is what makes the
// nginx credential-proxy work: the browser talks only to its own origin, and
// the credential is attached server-side where the browser cannot read it.
import axios from 'axios';
import type { AxiosInstance } from 'axios';
import { env } from '@/shared/config/env';
import { installAuthInterceptor } from './auth-interceptor';
import type { AuthTokenPort } from './auth-interceptor';
import { installRetryInterceptor } from './retry-interceptor';

/**
 * A no-op token port, replaced at bootstrap via `registerAuthTokenPort`.
 *
 * Late registration exists because feature api services are constructed at
 * module scope (`export const productTagsApi = new ProductTagsApiService()`),
 * so the client must be importable before the auth store has been created.
 *
 * Honest limit, stated the way flutter-bootstrap states get_it's: this is one
 * mutable module-level slot, i.e. process-global state. What it buys over
 * reaching into the auth store directly is that `shared/api` depends on an
 * interface rather than on a concrete store — so the client is testable with
 * a fake port, and no import cycle forms between api and store.
 */
let tokenPort: AuthTokenPort = {
  getAccessToken: () => null,
  refresh: () => Promise.resolve(null),
  onRefreshFailed: () => undefined,
};

export function registerAuthTokenPort(port: AuthTokenPort): void {
  tokenPort = port;
}

export function createHttpClient(): AxiosInstance {
  const client = axios.create({
    baseURL: env.apiBaseUrl,
    timeout: env.requestTimeoutMs,
    headers: { Accept: 'application/json' },
    // Send cookies for same-origin calls, which is what the nginx proxy
    // pattern relies on when the backend uses a session cookie.
    withCredentials: true,
  });

  // 1. Auth: stamps the token, and owns single-flight 401 refresh.
  installAuthInterceptor(client, {
    getAccessToken: () => tokenPort.getAccessToken(),
    refresh: () => tokenPort.refresh(),
    onRefreshFailed: () => {
      tokenPort.onRefreshFailed();
    },
  });

  // 2. Retry: transport failures and a narrow status table, idempotent only.
  installRetryInterceptor(client, { maxAttempts: 3, baseDelayMs: 300 });

  return client;
}

export const httpClient: AxiosInstance = createHttpClient();
