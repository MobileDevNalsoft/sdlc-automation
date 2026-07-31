// DESTINATION: src/shared/store/auth-store.ts
//
// Client state only. The user's PROFILE is server state and belongs to a
// TanStack Query hook; what lives here is the session status the router needs
// synchronously to decide whether to render a protected route at all.
//
// The access token is deliberately NOT part of the store's state object: it
// is held by a TokenStore so that no middleware, devtools panel, or future
// `persist` call can serialize it to disk by accident. That is a structural
// guarantee rather than a rule someone has to remember.
import { create } from 'zustand';
import { registerAuthTokenPort } from '@/shared/api/http-client';
import { createMemoryTokenStore } from '@/shared/storage/token-store';
import type { TokenStore } from '@/shared/storage/token-store';

export type AuthStatus = 'unknown' | 'authenticated' | 'anonymous';

export interface AuthUser {
  id: string;
  email: string;
  displayName: string;
}

interface AuthState {
  status: AuthStatus;
  user: AuthUser | null;
  signIn: (user: AuthUser, accessToken: string) => void;
  signOut: () => void;
  markAnonymous: () => void;
}

const tokenStore: TokenStore = createMemoryTokenStore();

export const useAuthStore = create<AuthState>()((set) => ({
  // 'unknown' rather than 'anonymous' is what stops a protected route from
  // redirecting to /login during the first tick, before the refresh call that
  // restores a session has had a chance to answer.
  status: 'unknown',
  user: null,

  signIn: (user, accessToken) => {
    tokenStore.setAccessToken(accessToken);
    set({ status: 'authenticated', user });
  },

  signOut: () => {
    tokenStore.clear();
    set({ status: 'anonymous', user: null });
  },

  markAnonymous: () => {
    set({ status: 'anonymous', user: null });
  },
}));

// --- Selectors -------------------------------------------------------------
// Each selector returns ONE field. A selector returning a fresh object
// (`(s) => ({ user: s.user })`) allocates a new reference every call, defeats
// the store's reference-equality check, and re-renders the component on every
// unrelated state change.
export const useAuthStatus = (): AuthStatus => useAuthStore((s) => s.status);
export const useAuthUser = (): AuthUser | null => useAuthStore((s) => s.user);
export const useSignIn = (): AuthState['signIn'] => useAuthStore((s) => s.signIn);
export const useSignOut = (): AuthState['signOut'] => useAuthStore((s) => s.signOut);

/**
 * Connects the HTTP layer's AuthTokenPort to this store. Called once at
 * bootstrap.
 *
 * This direction matters: the store imports the api module, never the
 * reverse. If `shared/api` imported this store, the client would drag the
 * whole state layer into every test that touches an api service, and an
 * import cycle would form the moment the store needed to call an endpoint.
 *
 * `refresh` is left as a project-supplied callback because the refresh
 * endpoint's shape is backend-specific — there is no honest default.
 */
export function wireAuthToHttpClient(refresh: () => Promise<string | null>): void {
  registerAuthTokenPort({
    getAccessToken: () => tokenStore.getAccessToken(),
    refresh: async () => {
      const token = await refresh();
      tokenStore.setAccessToken(token);
      return token;
    },
    onRefreshFailed: () => {
      useAuthStore.getState().signOut();
    },
  });
}
