// DESTINATION: src/main.tsx
//
// Parallel to flutter-bootstrap's main_<flavor>.dart entrypoints — except
// React needs only ONE, because the flavor arrives at runtime through
// window.__ENV__ rather than at build time. That is the whole reason one built
// image can serve dev, staging and prod without a rebuild.
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { App } from '@/app/App';
import { wireAuthToHttpClient } from '@/shared/store/auth-store';
import '@/styles/tokens.css';

// Wire the HTTP layer's token port before the first render, so a query firing
// on mount already has auth attached.
//
// The refresh callback is project-specific — this default marks the session
// anonymous rather than pretending a refresh endpoint exists. Replace it with
// the real call; leaving it means a 401 logs the user out instead of
// recovering, which is at least honest.
wireAuthToHttpClient(() => Promise.resolve(null));

const container = document.getElementById('root');
if (!container) throw new Error('Root element #root not found in index.html');

createRoot(container).render(
  <StrictMode>
    <App />
  </StrictMode>
);
