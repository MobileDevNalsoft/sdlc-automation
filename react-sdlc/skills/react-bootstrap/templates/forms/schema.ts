// forms/schema.ts — react-bootstrap template
//
// zod schema for a form, paired with react-hook-form via @hookform/resolvers.
// Worked example against a generic "Customer" contact entity — a stand-in for
// whatever entity a real feature needs. react-slice's job is to replace this
// with the slice's own fields, not to extend this one.
import { z } from 'zod';

export const entityFormSchema = z.object({
  name: z.string().trim().min(1, 'Name is required'),
  // zod 4 moved email validation to the TOP-LEVEL `z.email()`; the older
  // `z.string().email()` still compiles but is deprecated. Piping through a
  // trimmed string first matters in practice — autofill and paste routinely
  // add a trailing space, and validating before trimming rejects an address
  // the user considers obviously correct.
  email: z.string().trim().pipe(z.email('Enter a valid email address')),
  company: z.string().trim().min(1, 'Company is required'),
  notes: z.string().trim().optional(),
  subscribed: z.boolean().default(true),
});

// TWO types, and the distinction is load-bearing — see useEntityForm.ts.
//
// `.default()` (and `.optional()`, `.catch()`, any transform) makes a field
// OPTIONAL on the way in and GUARANTEED on the way out. One `z.infer` alias
// cannot describe both, and using it for both is what produced this template's
// original type error:
//
//   Type 'boolean | undefined' is not assignable to type 'boolean'.
//
// Input: what the form holds while the user is typing (subscribed may be absent).
export type EntityFormInput = z.input<typeof entityFormSchema>;
// Output: what a successful submit hands you (subscribed is definitely a boolean).
export type EntityFormValues = z.output<typeof entityFormSchema>;
