// DESTINATION: src/shared/ui/ErrorView.tsx
//
// Parallel to flutter-bootstrap's shared/widgets/app_error_view.dart +
// app_empty_state.dart. Both live here because the pairing is the point:
//
//   AN EMPTY LIST IS NOT AN ERROR.
//
// Rendering "Something went wrong" for a successful response containing zero
// rows teaches users to distrust the app, and it hides the actual call to
// action ("Add your first product"). They are visually distinct on purpose.
import type { ReactNode } from 'react';
import { ApiError, isRetryable } from '@/shared/api/api-error';
import { Button } from './Button';

export interface ErrorViewProps {
  error: unknown;
  onRetry?: () => void;
  title?: string;
}

export function ErrorView({ error, onRetry, title = 'Something went wrong' }: ErrorViewProps): React.ReactElement {
  const detail = error instanceof ApiError ? error.detail : null;
  const message = detail?.message ?? 'An unexpected error occurred.';
  // Only offer retry where retrying could actually change the outcome —
  // a "Try again" button on a 403 is a lie.
  const canRetry = onRetry !== undefined && (detail === null || isRetryable(detail));

  return (
    <div
      role="alert"
      className="flex flex-col items-center gap-3 rounded-card border border-border bg-danger-soft p-6 text-center"
    >
      <h2 className="text-base font-semibold text-fg">{title}</h2>
      <p className="max-w-sm text-sm text-fg-muted">{message}</p>
      {canRetry && (
        <Button variant="secondary" size="sm" onClick={onRetry}>
          Try again
        </Button>
      )}
    </div>
  );
}

export interface EmptyStateProps {
  title: string;
  description?: string;
  action?: ReactNode;
  icon?: ReactNode;
}

export function EmptyState({ title, description, action, icon }: EmptyStateProps): React.ReactElement {
  return (
    <div className="flex flex-col items-center gap-3 rounded-card border border-dashed border-border p-10 text-center">
      {icon}
      <h2 className="text-base font-medium text-fg">{title}</h2>
      {description !== undefined && <p className="max-w-sm text-sm text-fg-muted">{description}</p>}
      {action}
    </div>
  );
}
