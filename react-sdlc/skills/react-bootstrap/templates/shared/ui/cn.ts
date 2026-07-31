// DESTINATION: src/shared/ui/cn.ts
//
// clsx handles conditional class lists; tailwind-merge resolves CONFLICTS
// within them. Both are needed and they do different jobs:
//
//   clsx('px-2', cond && 'px-4')        -> "px-2 px-4"   (both survive)
//   cn('px-2', cond && 'px-4')          -> "px-4"        (later wins)
//
// Without the merge step, a caller passing `className="px-4"` to a component
// whose default is `px-2` gets whichever CSS rule happens to come later in the
// stylesheet — i.e. the override silently does nothing, or works by accident.
import { clsx } from 'clsx';
import type { ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]): string {
  return twMerge(clsx(inputs));
}
