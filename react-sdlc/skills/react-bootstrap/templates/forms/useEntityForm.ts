// forms/useEntityForm.ts — react-bootstrap template
//
// react-hook-form + zod wiring. Named `useEntityForm` deliberately as a
// placeholder — react-slice's job is to rename this to the real feature
// (e.g. `useCustomerForm`) and swap `entityFormSchema`/`EntityFormValues` for
// the slice's own schema.
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { entityFormSchema, type EntityFormValues } from './schema';

const DEFAULT_VALUES: EntityFormValues = {
  name: '',
  email: '',
  company: '',
  notes: undefined,
  subscribed: true,
};

export function useEntityForm(initialValues?: Partial<EntityFormValues>) {
  return useForm<EntityFormValues>({
    resolver: zodResolver(entityFormSchema),
    defaultValues: { ...DEFAULT_VALUES, ...initialValues },
    // Validate on blur, re-validate on change once a field has been touched —
    // a common, low-friction default: errors don't appear before the user has
    // interacted with a field, but clear promptly once they fix it. Adjust to
    // your project's existing form UX convention if it already has one.
    mode: 'onBlur',
    reValidateMode: 'onChange',
  });
}
