// DESTINATION: src/app/router/RequireAuth.tsx
//
// Parallel to flutter-bootstrap's go_router auth redirect guard.
//
// THE DEFECT THIS SHAPE AVOIDS: the common implementation puts the check in a
// `useEffect` inside the protected page. That runs AFTER the first render, so
// the user sees a frame of protected content — real names, real numbers —
// before the redirect fires. Screenshots and screen recordings capture it.
// Returning <Navigate/> during render means the protected component never
// mounts at all.
//
// The 'unknown' status is the other half: on a cold reload the session has not
// been restored yet, and treating that as "anonymous" would bounce an
// authenticated user to /login on every refresh.
import type { ReactNode } from 'react';
import { Navigate, useLocation } from 'react-router';
import { useAuthStatus } from '@/shared/store/auth-store';
import { AppRoutes, loginWithRedirect } from '@/shared/navigation/routes';

interface RequireAuthProps {
  children: ReactNode;
  /** Rendered while the session is still being restored. */
  fallback?: ReactNode;
}

export function RequireAuth({ children, fallback = null }: RequireAuthProps): ReactNode {
  const status = useAuthStatus();
  const location = useLocation();

  if (status === 'unknown') return fallback;

  if (status === 'anonymous') {
    const from = `${location.pathname}${location.search}`;
    return <Navigate to={loginWithRedirect(from)} replace />;
  }

  return children;
}

/** The mirror guard: keeps an authenticated user off /login. */
export function RequireAnonymous({ children }: { children: ReactNode }): ReactNode {
  const status = useAuthStatus();
  if (status === 'authenticated') return <Navigate to={AppRoutes.root} replace />;
  return children;
}
