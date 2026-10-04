import { z } from 'zod';

const round6 = (n: number) => Math.round(n * 1e6) / 1e6;

/** Decimal coordinate string → number in [min, max], rounded to 6 dp. Rejects '', 'abc', '1e3'. */
const coord = (min: number, max: number) =>
  z
    .string({ error: 'required' })
    .trim()
    .regex(/^[+-]?\d{1,3}(\.\d+)?$/, 'must be a decimal number')
    .transform(Number)
    .pipe(z.number().min(min, `must be between ${min} and ${max}`).max(max, `must be between ${min} and ${max}`))
    .transform(round6);

export const locateQuery = z.object({ lat: coord(-90, 90), lng: coord(-180, 180) });

export const wardsQuery = z.object({
  q: z.string().max(40, 'must be at most 40 characters').optional(),
  zone: z
    .string()
    .regex(/^[a-z_]{3,20}$/, 'must be a zone code')
    .optional(),
});

/** `{id}` is a ward uuid or a ward number (ASCII or Gujarati digits). */
export const wardParams = z.object({
  id: z
    .string()
    .regex(
      /^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|[0-9૦-૯]{1,4})$/i,
      'must be a ward id or ward number',
    ),
});

export const wardDetailQuery = z.object({
  include: z.enum(['geometry']).optional(),
});
