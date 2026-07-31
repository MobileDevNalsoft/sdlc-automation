// forms/EntityForm.tsx — react-bootstrap template
//
// Minimal form component wiring useEntityForm's register/handleSubmit/errors
// to inputs. react-slice's job is to replace the field list with the slice's
// real fields and wire onSubmit to the slice's mutation hook instead of the
// placeholder below. Markup here is intentionally plain — visual design is
// owned by sdlc-core:ui-ux-web / reviewed by sdlc-core:ui-ux-review, not by
// this skill.
import { useEntityForm } from './useEntityForm';
import type { EntityFormInput, EntityFormValues } from './schema';

interface EntityFormProps {
  // Initial values are the INPUT shape (a defaulted field may be absent);
  // onSubmit receives the OUTPUT shape (every default is resolved). Collapsing
  // these two into one type is what broke this template originally — see
  // schema.ts.
  initialValues?: Partial<EntityFormInput>;
  onSubmit: (values: EntityFormValues) => void | Promise<void>;
  isSubmitting?: boolean;
}

export function EntityForm({
  initialValues,
  onSubmit,
  isSubmitting,
}: EntityFormProps): React.ReactElement {
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useEntityForm(initialValues);

  return (
    <form onSubmit={handleSubmit(onSubmit)} noValidate>
      <div>
        <label htmlFor="name">Name</label>
        <input id="name" {...register('name')} aria-invalid={!!errors.name} />
        {errors.name && <p role="alert">{errors.name.message}</p>}
      </div>

      <div>
        <label htmlFor="email">Email</label>
        <input id="email" type="email" {...register('email')} aria-invalid={!!errors.email} />
        {errors.email && <p role="alert">{errors.email.message}</p>}
      </div>

      <div>
        <label htmlFor="company">Company</label>
        <input id="company" {...register('company')} aria-invalid={!!errors.company} />
        {errors.company && <p role="alert">{errors.company.message}</p>}
      </div>

      <div>
        <label htmlFor="notes">Notes</label>
        <textarea id="notes" {...register('notes')} aria-invalid={!!errors.notes} />
        {errors.notes && <p role="alert">{errors.notes.message}</p>}
      </div>

      <button type="submit" disabled={isSubmitting}>
        {isSubmitting ? 'Saving…' : 'Save'}
      </button>
    </form>
  );
}
