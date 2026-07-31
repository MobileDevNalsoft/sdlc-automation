// DESTINATION: src/app/query-client.ts
//
// The server-state cache's configuration. There is no flutter parallel for
// this file — it is the piece a React app needs that a bloc app does not.
//
// THE COMPOUNDING-RETRY TRAP, and it is the reason this file has opinions:
// the axios retry interceptor ALREADY retries transport failures up to 3
// times. TanStack Query's own default is ALSO 3 retries. Left at defaults,
// those multiply — one failing GET becomes up to NINE requests, with the
// user watching a spinner through all of them, and a "flaky endpoint" turns
// into a self-inflicted load test. Transport retry is owned at exactly one
// layer (axios); this layer retries only sparingly, and never for errors that
// cannot possibly succeed on a second attempt.
import { QueryClient } from '@tanstack/react-query';
import { ApiError, isRetryable } from '@/shared/api/api-error';

function shouldRetry(failureCount: number, error: unknown): boolean {
  // A 404/403/422 will be a 404/403/422 again. Retrying it only delays the
  // error state the user needs to see.
  if (error instanceof ApiError && !isRetryable(error.detail)) return false;
  // One extra attempt on top of axios's own — covers the case where a token
  // refresh happened between attempts.
  return failureCount < 1;
}

export function createQueryClient(): QueryClient {
  return new QueryClient({
    defaultOptions: {
      queries: {
        retry: shouldRetry,
        // 30s: long enough that tab-switching and route changes don't re-fetch
        // constantly, short enough that data does not feel frozen. Override
        // per-query for genuinely static reference data.
        staleTime: 30_000,
        gcTime: 5 * 60_000,
        // Default true is a common source of "why did it refetch when I
        // alt-tabbed" — off here, and turned on per-query for live dashboards.
        refetchOnWindowFocus: false,
        refetchOnReconnect: true,
      },
      mutations: {
        // NEVER retry mutations by default. A POST that timed out may have
        // committed server-side; the same double-charge reasoning as the retry
        // interceptor's idempotency rule.
        retry: false,
      },
    },
  });
}
