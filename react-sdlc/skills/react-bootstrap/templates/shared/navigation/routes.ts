// DESTINATION: src/app/router/routes.ts
//
// Parallel to flutter-bootstrap's core/router/routes.dart, and it carries the
// same load-bearing consequence:
//
//   CROSS-FEATURE NAVIGATION CARRIES NO IMPORT.
//
// Feature A navigating to feature B uses a STRING owned here, not a symbol
// imported from feature B. That is what keeps the import-boundary rule
// enforceable — otherwise every navigation would be a boundary violation, and
// the rule would have to be abandoned or exempted into meaninglessness.
export const AppRoutes = {
  root: '/',
  login: '/login',
  products: '/products',
  productDetail: (id: string): string => `/products/${id}`,
  settings: '/settings',
  notFound: '*',
} as const;

/** Where an unauthenticated user is sent, and where they return to. */
export const REDIRECT_PARAM = 'redirectTo';

export function loginWithRedirect(from: string): string {
  return `${AppRoutes.login}?${REDIRECT_PARAM}=${encodeURIComponent(from)}`;
}
