import { cloneElement, isValidElement, type ReactElement, type ReactNode } from 'react';
import { cn } from './cn';

export interface PermissionGateProps {
  /** The permission token or group required for access */
  permission?: string | string[];
  /** Mode: 'write' disables with reason if read-only; 'read' hides completely */
  mode?: 'read' | 'write';
  /** User's current access type: 'F' (Full), 'V' (View only), or null */
  accessType?: 'F' | 'V' | null;
  /** Child interactive element to gate (e.g. Button) */
  children: ReactElement<{ disabled?: boolean; title?: string }>;
  /** Optional fallback component when permission is absent */
  fallback?: ReactNode;
  /** Optional visible refusal reason text */
  showReason?: boolean;
  className?: string;
}

export function PermissionGate({
  accessType = 'F',
  mode = 'write',
  children,
  fallback = null,
  showReason = false,
  className,
}: PermissionGateProps): React.ReactElement | null {
  // If no access granted at all -> render nothing
  if (!accessType) {
    return <>{fallback}</>;
  }

  // View-only access on a write affordance -> render child disabled with reason
  if (mode === 'write' && accessType === 'V') {
    const refusalReason = 'View-only access: you do not have permission to modify this record.';
    const disabledChild = isValidElement(children)
      ? cloneElement(children, {
          disabled: true,
          title: refusalReason,
        })
      : children;

    if (showReason) {
      return (
        <span className={cn('inline-flex items-center gap-2', className)}>
          {disabledChild}
          <span className="text-xs text-fg-muted italic">{refusalReason}</span>
        </span>
      );
    }

    return disabledChild;
  }

  // Full access -> render normal child
  return children;
}
