// DESTINATION: src/app/App.tsx
//
// Parallel to flutter-bootstrap's app/app.dart: the root widget, and nothing
// more. It composes providers around the router and stops there — no data
// fetching, no business logic, no layout.
import { RouterProvider } from 'react-router';
import { useState } from 'react';
import { AppProviders } from './providers';
import { createAppRouter } from './router/router';

export function App(): React.ReactElement {
  // One router instance for the app's lifetime. Recreating it on every render
  // would remount every route and drop all component state on each keystroke.
  const [router] = useState(createAppRouter);

  return (
    <AppProviders>
      <RouterProvider router={router} />
    </AppProviders>
  );
}
