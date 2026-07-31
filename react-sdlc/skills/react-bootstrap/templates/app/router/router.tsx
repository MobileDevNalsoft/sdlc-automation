// DESTINATION: src/app/router/router.tsx
//
// Parallel to flutter-bootstrap's core/router/app_router.dart: THE ONE
// aggregator that knows about every feature's routes. Features never import
// each other; they meet here.
//
// Every route is `lazy`, so a route's component and its whole dependency
// subtree land in a separate chunk. Route boundaries are the natural
// code-split point — a full page transition is already happening, so a
// loading state there is expected rather than jarring.
import { createBrowserRouter } from 'react-router';
import type { RouteObject } from 'react-router';
import { AppLayout } from '@/app/AppLayout';
import { RequireAnonymous, RequireAuth } from './RequireAuth';
import { RouteErrorBoundary } from './RouteErrorBoundary';
import { AppRoutes } from '@/shared/navigation/routes';
import { LoadingState } from '@/shared/ui/Spinner';

const routes: RouteObject[] = [
  {
    path: AppRoutes.root,
    element: <AppLayout />,
    // errorElement at the LAYOUT level means a thrown error keeps the app
    // chrome and replaces only the outlet.
    errorElement: <RouteErrorBoundary />,
    children: [
      {
        index: true,
        // Every leaf below is `lazy`, so its dynamic import is always at
        // least one tick from resolving — even in a client-only SPA with no
        // loaders. Without a fallback for that tick, react-router warns "No
        // HydrateFallback element provided to render during initial
        // hydration" on every single page load.
        hydrateFallbackElement: <LoadingState />,
        lazy: async () => {
          const { ProductsPage } = await import('@/features/products/components/ProductsPage');
          return {
            element: (
              <RequireAuth fallback={<LoadingState />}>
                <ProductsPage />
              </RequireAuth>
            ),
          };
        },
      },
      {
        path: AppRoutes.login,
        hydrateFallbackElement: <LoadingState />,
        lazy: async () => {
          const { LoginPage } = await import('@/features/auth/components/LoginPage');
          return {
            element: (
              <RequireAnonymous>
                <LoginPage />
              </RequireAnonymous>
            ),
          };
        },
      },
      {
        path: AppRoutes.notFound,
        hydrateFallbackElement: <LoadingState />,
        lazy: async () => {
          const { NotFoundPage } = await import('@/features/errors/components/NotFoundPage');
          return { Component: NotFoundPage };
        },
      },
    ],
  },
];

export function createAppRouter(): ReturnType<typeof createBrowserRouter> {
  // basename keeps subpath deployments working: the same build served from
  // https://host/some-app/ needs the router to strip that prefix. It is fed by
  // Vite's BASE_URL, which comes from the BASE_PATH build arg — so this is
  // never hardcoded per environment.
  return createBrowserRouter(routes, { basename: import.meta.env.BASE_URL });
}
