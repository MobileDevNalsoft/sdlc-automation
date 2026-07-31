// DESTINATION: src/shared/ui/Button.tsx
//
// Parallel to flutter-bootstrap's shared/widgets/app_button.dart: features use
// THIS, never a raw <button>, so focus rings, disabled semantics, tap-target
// size and the loading state are decided once.
//
// Variants are a plain lookup object rather than class-variance-authority:
// cva's latest release (0.7.1) is from 2024-11-26 — ~20 months stale — and
// this is fifteen lines. Taking a stale dependency to avoid fifteen lines is a
// bad trade. Reach for cva only if variant logic outgrows this shape.
import type { ButtonHTMLAttributes, ReactNode } from 'react';
import { cn } from './cn';
import { Spinner } from './Spinner';

type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger';
type ButtonSize = 'sm' | 'md' | 'lg';

const VARIANTS: Record<ButtonVariant, string> = {
  primary: 'bg-brand-600 text-fg-onbrand hover:bg-brand-700 focus-visible:outline-brand-600',
  secondary:
    'bg-surface text-fg border border-border hover:bg-surface-raised focus-visible:outline-brand-600',
  ghost: 'bg-transparent text-fg hover:bg-surface-raised focus-visible:outline-brand-600',
  danger: 'bg-danger text-fg-onbrand hover:opacity-90 focus-visible:outline-danger',
};

// min-h values keep every size at or above the 44px pointer-target floor
// (WCAG 2.2 AA, 2.5.8) — the same class of guarantee flutter's 48dp tap-target
// test enforces.
const SIZES: Record<ButtonSize, string> = {
  sm: 'min-h-11 px-3 text-sm gap-1.5',
  md: 'min-h-11 px-4 text-sm gap-2',
  lg: 'min-h-12 px-5 text-base gap-2',
};

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  isLoading?: boolean;
  leadingIcon?: ReactNode;
}

export function Button({
  variant = 'primary',
  size = 'md',
  isLoading = false,
  leadingIcon,
  className,
  children,
  disabled,
  type = 'button',
  ...rest
}: ButtonProps): React.ReactElement {
  return (
    <button
      // Explicit type: a <button> inside a <form> defaults to type="submit",
      // so an unrelated icon button silently submits the form.
      type={type}
      // `disabled` while loading is what stops the double-submit that creates
      // two orders. aria-busy tells a screen reader why it went inert.
      disabled={disabled === true || isLoading}
      aria-busy={isLoading}
      className={cn(
        'inline-flex items-center justify-center rounded-control font-medium',
        'transition-colors duration-200 ease-standard',
        'focus-visible:outline-2 focus-visible:outline-offset-2',
        'disabled:cursor-not-allowed disabled:opacity-60',
        VARIANTS[variant],
        SIZES[size],
        className
      )}
      {...rest}
    >
      {isLoading ? <Spinner size="sm" /> : leadingIcon}
      {children}
    </button>
  );
}
