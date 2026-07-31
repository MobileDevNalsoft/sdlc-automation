// DESTINATION: src/app/router/RouteErrorBoundary.tsx
//
// Per-route error boundary, wired as each route's `errorElement`.
//
// Why per-route rather than one boundary at the top: a single top-level
// boundary means any thrown error anywhere blanks the ENTIRE app — nav, shell
// and all — and the user's only recovery is a full reload. Scoped to a route,
// the chrome survives and the user can navigate somewhere else.
import { isRouteErrorResponse, useNavigate, useRouteError } from 'react-router';
import { ApiError } from '@/shared/api/api-error';
import { Button } from '@/shared/ui/Button';

function describe(error: unknown): { title: string; detail: string; canRetry: boolean } {
  if (error instanceof ApiError) {
    // The exhaustive union pays off here: the message is already
    // user-facing and mapped, so this layer does not re-derive one.
    return {
      title: 'Something went wrong',
      detail: error.detail.message,
      canRetry: error.detail.kind !== 'forbidden' && error.detail.kind !== 'notFound',
    };
  }
  if (isRouteErrorResponse(error)) {
    return {
      title: `${String(error.status)} ${error.statusText}`,
      detail: 'This page could not be loaded.',
      canRetry: error.status >= 500,
    };
  }
  return { title: 'Something went wrong', detail: 'An unexpected error occurred.', canRetry: true };
}

export function RouteErrorBoundary(): React.ReactElement {
  const error = useRouteError();
  const navigate = useNavigate();
  const { title, detail, canRetry } = describe(error);

  return (
    <div role="alert" className="mx-auto flex max-w-md flex-col items-center gap-4 p-8 text-center">
      <h1 className="text-lg font-semibold text-fg">{title}</h1>
      <p className="text-sm text-fg-muted">{detail}</p>
      <div className="flex gap-2">
        {canRetry && (
          <Button
            onClick={() => {
              navigate(0);
            }}
          >
            Try again
          </Button>
        )}
        <Button
          variant="secondary"
          onClick={() => {
            void navigate(-1);
          }}
        >
          Go back
        </Button>
      </div>
    </div>
  );
}
