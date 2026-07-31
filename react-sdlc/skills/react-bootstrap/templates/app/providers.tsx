// DESTINATION: src/app/providers.tsx
//
// Parallel to flutter-bootstrap's bootstrap.dart + core/di/injector.dart: the
// composition root. Every cross-cutting dependency is mounted here, in one
// place, in a deliberate order.
//
// ORDER, outermost first, and each one is outside the next for a reason:
//   ErrorBoundary   — must wrap everything, or a provider that throws during
//                     init takes the whole app down with a blank screen.
//   QueryClient     — anything below may use hooks.
//   I18n            — the error UI itself wants translated strings.
//   Suspense        — innermost, so a lazy route suspends without unmounting
//                     the providers above it (which would drop the cache).
import type { ReactNode } from 'react';
import { Suspense, useState } from 'react';
import { QueryClientProvider } from '@tanstack/react-query';
import { ErrorBoundary } from 'react-error-boundary';
import { I18nextProvider } from 'react-i18next';
import { createQueryClient } from './query-client';
import { i18n } from '@/shared/i18n/i18n';
import { ErrorView } from '@/shared/ui/ErrorView';
import { LoadingState } from '@/shared/ui/Spinner';

export function AppProviders({ children }: { children: ReactNode }): React.ReactElement {
  // useState, not a module-level `new QueryClient()`: a module singleton is
  // created once per PROCESS, so in tests every case would share one cache and
  // leak state between them. This gives one client per mounted app.
  const [queryClient] = useState(createQueryClient);

  return (
    <ErrorBoundary
      fallbackRender={({ error, resetErrorBoundary }) => (
        <ErrorView error={error} onRetry={resetErrorBoundary} />
      )}
    >
      <QueryClientProvider client={queryClient}>
        <I18nextProvider i18n={i18n}>
          <Suspense fallback={<LoadingState />}>{children}</Suspense>
        </I18nextProvider>
      </QueryClientProvider>
    </ErrorBoundary>
  );
}
