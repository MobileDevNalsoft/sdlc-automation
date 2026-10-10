import type { ReactNode } from 'react';
import { cn } from './cn';

export interface EmptyStateProps {
  illustration?: ReactNode;
  title: string;
  description?: string;
  action?: ReactNode;
  size?: 'compact' | 'inline' | 'page';
  className?: string;
}

const SIZES: Record<'compact' | 'inline' | 'page', { frame: string; mark: string; title: string }> = {
  compact: { frame: 'gap-2 px-3 py-4', mark: 'w-14', title: 'text-sm font-semibold' },
  inline: { frame: 'gap-3 px-4 py-10', mark: 'w-28', title: 'text-base font-semibold' },
  page: { frame: 'gap-4 px-6 py-16', mark: 'w-40', title: 'text-lg font-semibold' },
};

export function EmptyState({
  illustration,
  title,
  description,
  action,
  size = 'inline',
  className,
}: EmptyStateProps): React.ReactElement {
  return (
    <div className={cn('flex flex-col items-center justify-center text-center', SIZES[size].frame, className)}>
      {illustration !== undefined && (
        <div className={cn('text-fg-subtle mb-2', SIZES[size].mark)}>{illustration}</div>
      )}
      <div className="space-y-1.5 max-w-sm">
        <p className={cn('text-fg', SIZES[size].title)}>{title}</p>
        {description !== undefined && (
          <p className="text-sm text-fg-muted leading-relaxed">{description}</p>
        )}
      </div>
      {action !== undefined && <div className="mt-4">{action}</div>}
    </div>
  );
}
