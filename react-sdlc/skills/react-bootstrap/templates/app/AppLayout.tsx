// DESTINATION: src/app/AppLayout.tsx
//
// The persistent shell every route renders inside. Parallel to flutter's
// AppScaffold, and it owns the same things: the outer gutter, the skip link,
// and the theme class that the token stylesheet keys off.
import { useEffect } from 'react';
import { Link, Outlet } from 'react-router';
import { AppRoutes } from '@/shared/navigation/routes';
import { useTheme } from '@/shared/store/ui-store';

function applyTheme(theme: 'light' | 'dark' | 'system'): void {
  const root = document.documentElement;
  const prefersDark =
    theme === 'dark' ||
    (theme === 'system' && window.matchMedia('(prefers-color-scheme: dark)').matches);
  root.classList.toggle('dark', prefersDark);
}

export function AppLayout(): React.ReactElement {
  const theme = useTheme();

  useEffect(() => {
    applyTheme(theme);
    if (theme !== 'system') return;
    // Follow the OS while (and only while) the user has chosen 'system'.
    const media = window.matchMedia('(prefers-color-scheme: dark)');
    const onChange = (): void => {
      applyTheme('system');
    };
    media.addEventListener('change', onChange);
    return () => {
      media.removeEventListener('change', onChange);
    };
  }, [theme]);

  return (
    <div className="min-h-dvh bg-bg text-fg">
      {/* Keyboard users land here first and can jump past the nav. Visible
          only on focus, which is why it is not `hidden`. */}
      <a
        href="#main"
        className="sr-only focus:not-sr-only focus:absolute focus:m-2 focus:rounded-control focus:bg-surface focus:p-2"
      >
        Skip to content
      </a>
      <header className="border-b border-border">
        <nav className="mx-auto flex max-w-5xl items-center gap-4 p-4" aria-label="Main">
          <Link to={AppRoutes.root} className="font-semibold">
            App
          </Link>
          <Link to={AppRoutes.products} className="text-sm text-fg-muted hover:text-fg">
            Products
          </Link>
        </nav>
      </header>
      <main id="main" className="mx-auto max-w-5xl p-4">
        <Outlet />
      </main>
    </div>
  );
}
