// DESTINATION: src/shared/api/retry-interceptor.ts
//
// Parallel to flutter-bootstrap's core/network/retry_interceptor.dart, and
// adopted for the same reason: hand-written and ~90 lines, rather than taking
// a third-party retry package whose default status table applies REGARDLESS
// OF METHOD.
//
// THE SAFETY RULE, and it is not stylistic: a POST that timed out client-side
// may well have COMMITTED server-side. Replaying it double-charges the card,
// double-creates the record, double-sends the email. Only methods that are
// idempotent by definition are retried here.
import { isAxiosError } from 'axios';
import type { AxiosInstance, InternalAxiosRequestConfig } from 'axios';

export interface RetryOptions {
  maxAttempts?: number;
  baseDelayMs?: number;
  maxDelayMs?: number;
  /**
   * PUT and DELETE are idempotent per RFC 9110 — but only if the SERVER
   * implements them that way. Left off by default: a DELETE that decrements a
   * counter is a real thing that exists in real codebases. Opt in per project
   * once you have checked, not because the RFC says you may.
   */
  retryPutAndDelete?: boolean;
}

interface RetryConfig extends InternalAxiosRequestConfig {
  __retryAttempt?: number;
}

const RETRYABLE_STATUS = new Set([408, 425, 429, 500, 502, 503, 504]);

function isRetryableMethod(method: string | undefined, allowPutDelete: boolean): boolean {
  const verb = (method ?? 'get').toLowerCase();
  if (verb === 'get' || verb === 'head' || verb === 'options') return true;
  return allowPutDelete && (verb === 'put' || verb === 'delete');
}

function backoffMs(attempt: number, base: number, max: number): number {
  const exponential = Math.min(base * 2 ** attempt, max);
  // Full jitter. Without it, N clients that failed on the same server blip all
  // retry at the same instant and reproduce the blip they are recovering from.
  return Math.random() * exponential;
}

function retryAfterMs(headers: unknown): number | null {
  if (typeof headers !== 'object' || headers === null) return null;
  const raw = (headers as Record<string, unknown>)['retry-after'];
  const seconds = Number(raw);
  return Number.isFinite(seconds) && seconds >= 0 ? seconds * 1000 : null;
}

const sleep = (ms: number): Promise<void> =>
  new Promise((resolve) => {
    setTimeout(resolve, ms);
  });

export function installRetryInterceptor(client: AxiosInstance, options: RetryOptions = {}): void {
  const {
    maxAttempts = 3,
    baseDelayMs = 300,
    maxDelayMs = 5_000,
    retryPutAndDelete = false,
  } = options;

  client.interceptors.response.use(undefined, async (error: unknown) => {
    if (!isAxiosError(error)) throw error;

    const config = error.config as RetryConfig | undefined;
    if (!config) throw error;

    // Never retry a caller-cancelled request: the caller is gone, and a retry
    // would resolve into a cache nobody is watching.
    if (error.code === 'ERR_CANCELED') throw error;

    if (!isRetryableMethod(config.method, retryPutAndDelete)) throw error;

    const status = error.response?.status;
    const isTransport = error.response === undefined; // network failure / timeout
    if (!isTransport && (status === undefined || !RETRYABLE_STATUS.has(status))) {
      throw error;
    }

    const attempt = config.__retryAttempt ?? 0;
    if (attempt >= maxAttempts - 1) throw error;
    config.__retryAttempt = attempt + 1;

    // A server that told us when to come back outranks our own backoff curve.
    const serverDelay = status === 429 ? retryAfterMs(error.response?.headers) : null;
    await sleep(serverDelay ?? backoffMs(attempt, baseDelayMs, maxDelayMs));

    return client.request(config);
  });
}
