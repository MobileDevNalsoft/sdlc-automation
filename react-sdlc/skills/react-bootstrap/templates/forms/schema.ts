// forms/schema.ts — react-bootstrap template
//
// zod schema for a form, paired with react-hook-form via @hookform/resolvers.
// Worked example against a generic "Customer" contact entity — a stand-in
// for whatever entity a real feature actually needs. react-slice's job is to
// replace this with the slice's own fields, not extend this one.
import { z } from 'zod';

export const entityFormSchema = z.object({
  name: z.string().trim().min(1, 'Name is required'),
  email: z.string().trim().email('Enter a valid email address'),
  company: z.string().trim().min(1, 'Company is required'),
  notes: z.string().trim().optional(),
  subscribed: z.boolean().default(true),
});

// Infer the TS type from the schema instead of hand-maintaining a parallel
// interface — the schema is the single source of truth for both runtime
// validation and the compile-time shape.
export type EntityFormValues = z.infer<typeof entityFormSchema>;
