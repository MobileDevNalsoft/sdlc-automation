// DESTINATION: src/shared/api/api-error.ts
//
// Parallel to flutter-bootstrap's core/error/app_error.dart +
// core/network/dio_error_mapper.dart: ONE discriminated union every layer
// above the HTTP client speaks, and ONE function that produces it.
//
// The rule this file exists to enforce: no component, hook, or transformer
// ever inspects an AxiosError. If a `.tsx` file imports from 'axios', the
// mapping is missing, not the component taking a shortcut.
import { isAxiosError } from 'axios';

export type AppError =
  | { kind: 'canceled'; message: string }
  | { kind: 'timeout'; message: string }
  | { kind: 'network'; message: string }
  | { kind: 'unauthorized'; message: string; status: number }
  | { kind: 'forbidden'; message: string; status: number }
  | { kind: 'notFound'; message: string; status: number }
  | { kind: 'conflict'; message: string; status: number }
  | { kind: 'validation'; message: string; status: number; fields: Record<string, string[]> }
  | { kind: 'rateLimited'; message: string; status: number; retryAfterSeconds?: number }
  | { kind: 'server'; message: string; status: number }
  | { kind: 'unknown'; message: string };

/** The error envelope react-slice's api-contract.md specifies. */
interface ErrorEnvelope {
  error?: { code?: string; message?: string; fields?: Record<string, string[]> };
  message?: string;
}

function messageFrom(data: unknown, fallback: string): string {
  if (typeof data !== 'object' || data === null) return fallback;
  const envelope = data as ErrorEnvelope;
  return envelope.error?.message ?? envelope.message ?? fallback;
}

function fieldsFrom(data: unknown): Record<string, string[]> {
  if (typeof data !== 'object' || data === null) return {};
  return (data as ErrorEnvelope).error?.fields ?? {};
}

function parseRetryAfter(value: unknown): number | undefined {
  const seconds = Number(value);
  return Number.isFinite(seconds) && seconds >= 0 ? seconds : undefined;
}

/**
 * Maps anything thrown by the HTTP layer into an AppError.
 *
 * Ordering matters: cancellation is checked before timeout, and timeout
 * before the generic no-response case, because axios reports all three
 * through the same "no response" shape and only the codes tell them apart.
 */
export function toAppError(error: unknown): AppError {
  if (isAxiosError(error)) {
    if (error.code === 'ERR_CANCELED') {
      return { kind: 'canceled', message: 'Request was canceled.' };
    }
    if (error.code === 'ECONNABORTED' || error.code === 'ETIMEDOUT') {
      return { kind: 'timeout', message: 'The request timed out.' };
    }

    const response = error.response;
    if (!response) {
      return { kind: 'network', message: 'Could not reach the server.' };
    }

    const { status, data } = response;
    switch (true) {
      case status === 401:
        return { kind: 'unauthorized', status, message: messageFrom(data, 'Your session has expired.') };
      case status === 403:
        return { kind: 'forbidden', status, message: messageFrom(data, 'You do not have access to this.') };
      case status === 404:
        return { kind: 'notFound', status, message: messageFrom(data, 'Not found.') };
      case status === 409:
        return { kind: 'conflict', status, message: messageFrom(data, 'This conflicts with existing data.') };
      case status === 422 || status === 400:
        return {
          kind: 'validation',
          status,
          message: messageFrom(data, 'Some fields need attention.'),
          fields: fieldsFrom(data),
        };
      case status === 429:
        return {
          kind: 'rateLimited',
          status,
          message: messageFrom(data, 'Too many requests. Try again shortly.'),
          retryAfterSeconds: parseRetryAfter(response.headers?.['retry-after']),
        };
      case status >= 500:
        return { kind: 'server', status, message: messageFrom(data, 'The server had a problem.') };
      default:
        return { kind: 'unknown', message: messageFrom(data, `Unexpected response (${String(status)}).`) };
    }
  }

  if (error instanceof Error) {
    return { kind: 'unknown', message: error.message };
  }
  return { kind: 'unknown', message: 'An unexpected error occurred.' };
}

/** True for errors where showing the user a "Retry" button is honest. */
export function isRetryable(error: AppError): boolean {
  return error.kind === 'network' || error.kind === 'timeout' || error.kind === 'server';
}

/**
 * What the API layer actually THROWS.
 *
 * The union above is the data; this is the carrier. Throwing a bare object
 * would lose stack traces, break `instanceof Error` checks in error
 * boundaries, and confuse every logger — but a plain `Error` subclass with a
 * `message` string would lose the exhaustive `switch` that makes the union
 * worth having. Carrying the union on `.detail` keeps both.
 *
 *   catch (e) {
 *     const detail = asApiError(e).detail;
 *     switch (detail.kind) { case 'validation': ... }
 *   }
 */
export class ApiError extends Error {
  readonly detail: AppError;

  constructor(detail: AppError) {
    super(detail.message);
    this.name = 'ApiError';
    this.detail = detail;
  }

  get kind(): AppError['kind'] {
    return this.detail.kind;
  }
}

/** Normalizes anything caught into an ApiError, mapping only when needed. */
export function asApiError(error: unknown): ApiError {
  return error instanceof ApiError ? error : new ApiError(toAppError(error));
}
