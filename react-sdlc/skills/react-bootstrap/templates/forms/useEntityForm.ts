// forms/useEntityForm.ts — react-bootstrap template
//
// react-hook-form + zod wiring. Named `useEntityForm` deliberately as a
// placeholder — react-slice renames it to the real feature (`useCustomerForm`)
// and swaps in that slice's schema.
//
// THE THREE-GENERIC FORM IS REQUIRED, NOT STYLISTIC. `useForm<Values>` with a
// schema containing `.default()` fails to compile against zodResolver:
//
//   Type 'Resolver<{ ...subscribed?: boolean | undefined }, any, { ...subscribed: boolean }>'
//   is not assignable to type 'Resolver<{ ...subscribed: boolean }, ...>'
//
// because the resolver's input and output types genuinely differ. RHF's three
// generics <TFieldValues, TContext, TTransformedValues> exist for exactly this:
// the form is typed by the INPUT shape, and `handleSubmit` hands the callback
// the OUTPUT shape. Verified against react-hook-form 7.83.0 + zod 4.4.3 +
// @hookform/resolvers 5.5.7 on 2026-07-31.
import { useForm } from 'react-hook-form';
import type { UseFormReturn } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { entityFormSchema } from './schema';
import type { EntityFormInput, EntityFormValues } from './schema';

const DEFAULT_VALUES: EntityFormInput = {
  name: '',
  email: '',
  company: '',
  notes: undefined,
  subscribed: true,
};

export function useEntityForm(
  initialValues?: Partial<EntityFormInput>
): UseFormReturn<EntityFormInput, unknown, EntityFormValues> {
  return useForm<EntityFormInput, unknown, EntityFormValues>({
    resolver: zodResolver(entityFormSchema),
    defaultValues: { ...DEFAULT_VALUES, ...initialValues },
    // Validate on blur, re-validate on change once a field has been touched:
    // errors don't appear before the user has interacted with a field, but
    // clear promptly once fixed. Adjust to your project's existing form UX
    // convention if it already has one.
    mode: 'onBlur',
    reValidateMode: 'onChange',
  });
}
