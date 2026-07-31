// DESTINATION: src/shared/store/ui-store.ts
//
// The second store slice, split by CONCERN rather than merged into one global
// object — so a theme change does not notify subscribers watching auth, and
// each slice is independently testable and independently persistable.
//
// Everything here is genuinely client state: it has no server origin and
// nothing else can invalidate it. Persisting it is therefore correct, whereas
// persisting a server-fetched value would be reintroducing the stale-cache
// problem TanStack Query exists to solve.
import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export type ThemeMode = 'light' | 'dark' | 'system';

interface UIState {
  theme: ThemeMode;
  sidebarCollapsed: boolean;
  setTheme: (theme: ThemeMode) => void;
  toggleSidebar: () => void;
}

export const useUIStore = create<UIState>()(
  persist(
    (set) => ({
      theme: 'system',
      sidebarCollapsed: false,
      setTheme: (theme) => {
        set({ theme });
      },
      toggleSidebar: () => {
        set((state) => ({ sidebarCollapsed: !state.sidebarCollapsed }));
      },
    }),
    {
      name: 'app:ui',
      // Persist only the data, never the action functions — without this,
      // a rehydrate can overwrite an updated action with a stale serialized
      // one, which fails in ways that look like "the button stopped working".
      partialize: (state) => ({ theme: state.theme, sidebarCollapsed: state.sidebarCollapsed }),
    }
  )
);

export const useTheme = (): ThemeMode => useUIStore((s) => s.theme);
export const useSetTheme = (): UIState['setTheme'] => useUIStore((s) => s.setTheme);
export const useSidebarCollapsed = (): boolean => useUIStore((s) => s.sidebarCollapsed);
