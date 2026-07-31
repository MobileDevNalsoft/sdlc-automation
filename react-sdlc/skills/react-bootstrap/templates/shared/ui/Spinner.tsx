// DESTINATION: src/shared/ui/Spinner.tsx
//
// Parallel to flutter-bootstrap's shared/widgets/app_loader.dart.
//
// `aria-hidden` is deliberate: a spinner is decorative, and the STATUS is
// announced by whatever region wraps it (see ErrorView / the busy button).
// A spinner that announces itself produces "loading loading loading" as a
// screen reader re-reads the animation's container.
import { cn } from './cn';

const SIZES = { sm: 'size-4 border-2', md: 'size-6 border-2', lg: 'size-8 border-[3px]' } as const;

export interface SpinnerProps {
  size?: keyof typeof SIZES;
  className?: string;
}

export function Spinner({ size = 'md', className }: SpinnerProps): React.ReactElement {
  return (
    <span
      aria-hidden="true"
      className={cn(
        'inline-block animate-spin rounded-full border-current border-t-transparent',
        SIZES[size],
        className
      )}
    />
  );
}

/** Full-region loading state, for a route or panel that has nothing to show yet. */
export function LoadingState({ label = 'Loading' }: { label?: string }): React.ReactElement {
  return (
    <div role="status" aria-live="polite" className="flex items-center justify-center gap-3 p-8">
      <Spinner />
      <span className="text-sm text-fg-muted">{label}</span>
    </div>
  );
}
