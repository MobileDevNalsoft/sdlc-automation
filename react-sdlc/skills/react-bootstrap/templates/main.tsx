// DESTINATION: src/main.tsx
//
// Parallel to flutter-bootstrap's main_<flavor>.dart entrypoints — except
// React needs only ONE, because the flavor arrives at runtime through
// window.__ENV__ rather than at build time. That is the whole reason one built
// image can serve dev, staging and prod without a rebuild.
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { App } from '@/app/App';
import { useAuthStore, wireAuthToHttpClient } from '@/shared/store/auth-store';
import '@/styles/tokens.css';

// Wire the HTTP layer's token port before the first render, so a query firing
// on mount already has auth attached.
//
// The refresh callback is project-specific — this default marks the session
// anonymous rather than pretending a refresh endpoint exists. Replace it with
// the real call; leaving it means a 401 logs the user out instead of
// recovering, which is at least honest.
wireAuthToHttpClient(() => Promise.resolve(null));

// `status` starts 'unknown' so RequireAuth doesn't bounce an authenticated
// user to /login before a real session-restore attempt has answered. But
// nothing else resolves that question on its own: the refresh callback above
// only runs REACTIVELY, when some request 401s — and until a feature exists
// that actually calls a protected endpoint, that never happens (see trap 11).
// Left as-is, `status` stays 'unknown' forever and RequireAuth's fallback
// renders indefinitely instead of ever reaching 'anonymous' and redirecting to
// /login. Mark anonymous immediately: with no real refresh endpoint wired yet,
// "no endpoint" and "no session" are the same fact. Replace this call with a
// real restore-session attempt (call the real refresh endpoint, then
// signIn(...) on success) once one exists.
useAuthStore.getState().markAnonymous();

const container = document.getElementById('root');
if (!container) throw new Error('Root element #root not found in index.html');

createRoot(container).render(
  <StrictMode>
    <App />
  </StrictMode>
);
