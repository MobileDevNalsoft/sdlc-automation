// The single-flight refresh is the highest-risk logic in the scaffold: it is
// concurrent, security-adjacent, and its failure mode (a user randomly logged
// out) is intermittent and nearly impossible to reproduce by hand. So it is
// tested directly rather than trusted.
//
// No mocking library. axios lets you replace the ADAPTER — the bottom of its
// own stack — so the real interceptor chain runs unmodified and only the
// network is faked. That avoids taking axios-mock-adapter, whose latest
// release (2.1.0) is from 2024-10-09.
import axios, { AxiosError, AxiosHeaders } from 'axios';
import type { AxiosAdapter, AxiosInstance, AxiosResponse, InternalAxiosRequestConfig } from 'axios';
import { describe, expect, it, vi } from 'vitest';
import { installAuthInterceptor } from './auth-interceptor';
import type { AuthTokenPort } from './auth-interceptor';

type Handler = (config: InternalAxiosRequestConfig) => [status: number, data?: unknown];

function withAdapter(handler: Handler): { client: AxiosInstance; calls: InternalAxiosRequestConfig[] } {
  const calls: InternalAxiosRequestConfig[] = [];

  const adapter: AxiosAdapter = async (config) => {
    calls.push(config);
    const [status, data] = handler(config);
    const response: AxiosResponse = {
      data: data ?? {},
      status,
      statusText: String(status),
      headers: new AxiosHeaders(),
      config,
    };
    if (status >= 200 && status < 300) return response;
    throw new AxiosError('Request failed', String(status), config, null, response);
  };

  const client = axios.create({ baseURL: '/api', adapter });
  return { client, calls };
}

function port(overrides: Partial<AuthTokenPort> = {}): AuthTokenPort {
  return {
    getAccessToken: () => 'stale-token',
    refresh: () => Promise.resolve('fresh-token'),
    onRefreshFailed: () => undefined,
    ...overrides,
  };
}

const authHeader = (config: InternalAxiosRequestConfig): unknown =>
  config.headers.get('Authorization');

describe('installAuthInterceptor', () => {
  it('stamps the access token on outgoing requests', async () => {
    const { client, calls } = withAdapter(() => [200]);
    installAuthInterceptor(client, port());

    await client.get('/thing');

    expect(authHeader(calls[0]!)).toBe('Bearer stale-token');
  });

  it('refreshes ONCE for concurrent 401s, then retries each request', async () => {
    let currentToken = 'stale-token';
    const refresh = vi.fn(
      () =>
        new Promise<string>((resolve) => {
          setTimeout(() => {
            resolve('fresh-token');
          }, 10);
        })
    );

    const { client, calls } = withAdapter((config) =>
      authHeader(config) === 'Bearer fresh-token' ? [200, { ok: true }] : [401]
    );

    installAuthInterceptor(
      client,
      port({
        getAccessToken: () => currentToken,
        refresh: async () => {
          const next = await refresh();
          currentToken = next;
          return next;
        },
      })
    );

    const responses = await Promise.all([
      client.get('/resource/1'),
      client.get('/resource/2'),
      client.get('/resource/3'),
    ]);

    // THE ASSERTION THAT MATTERS: three concurrent 401s produce exactly ONE
    // refresh. Without single-flight this is 3, and on a backend that rotates
    // refresh tokens, two of those three replay a consumed token, fail, and
    // log the user out by a race rather than an actual auth problem.
    expect(refresh).toHaveBeenCalledTimes(1);
    expect(responses.map((r) => r.status)).toEqual([200, 200, 200]);
    // 3 initial 401s + 3 retries.
    expect(calls).toHaveLength(6);
  });

  it('gives up after one retry instead of looping forever', async () => {
    const onRefreshFailed = vi.fn();
    const { client, calls } = withAdapter(() => [401]);
    installAuthInterceptor(client, port({ refresh: () => Promise.resolve(null), onRefreshFailed }));

    await expect(client.get('/thing')).rejects.toThrow();

    expect(onRefreshFailed).toHaveBeenCalledTimes(1);
    expect(calls).toHaveLength(1);
  });

  it('surfaces the original 401 when the refresh call itself throws', async () => {
    const onRefreshFailed = vi.fn();
    const { client } = withAdapter(() => [401]);
    installAuthInterceptor(
      client,
      port({
        refresh: () => Promise.reject(new Error('refresh endpoint down')),
        onRefreshFailed,
      })
    );

    // The caller asked for a resource; it must not receive an error about a
    // refresh mechanism it never invoked.
    await expect(client.get('/thing')).rejects.toMatchObject({ code: '401' });
    expect(onRefreshFailed).toHaveBeenCalledTimes(1);
  });

  it('does not attempt a refresh for non-401 failures', async () => {
    const refresh = vi.fn(() => Promise.resolve('fresh-token'));
    const { client } = withAdapter(() => [500]);
    installAuthInterceptor(client, port({ refresh }));

    await expect(client.get('/thing')).rejects.toThrow();
    expect(refresh).not.toHaveBeenCalled();
  });
});
