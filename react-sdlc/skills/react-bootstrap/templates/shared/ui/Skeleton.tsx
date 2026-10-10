import { cn } from './cn';

export interface SkeletonProps extends React.HTMLAttributes<HTMLDivElement> {
  className?: string;
}

export function Skeleton({ className, ...props }: SkeletonProps): React.ReactElement {
  return (
    <div
      aria-hidden="true"
      className={cn(
        'animate-pulse rounded-control bg-fg-subtle/10',
        className
      )}
      {...props}
    />
  );
}
