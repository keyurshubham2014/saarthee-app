/** Request schemas for the issues module (V2 TASK-05 §5.3). */
import { z } from 'zod';

const round6 = (v: number) => Math.round(v * 1e6) / 1e6;

/** Structured reasons for sensitive categories (TASK-05 §5.4); stored as the English label. */
export const STRUCTURED_REASONS: Record<string, Record<string, string>> = {
  encroachment: {
    footpath: 'Blocking the footpath',
    road: 'Blocking the road',
    hawkers: 'Hawkers or stalls',
    other_obstruction: 'Other obstruction',
  },
  building: {
    no_permission: 'Construction without permission',
    unsafe: 'Unsafe building',
    debris: 'Debris on the road',
    other: 'Other',
  },
};

/** Gujarati labels for [STRUCTURED_REASONS], worded as the app's `reportReason*` ARB strings. */
export const STRUCTURED_REASONS_GU: Record<string, Record<string, string>> = {
  encroachment: { footpath: 'ફૂટપાથ રોકે છે', road: 'રસ્તો રોકે છે', hawkers: 'ફેરિયા કે સ્ટોલ', other_obstruction: 'અન્ય અવરોધ' },
  building: { no_permission: 'મંજૂરી વગરનું બાંધકામ', unsafe: 'અસુરક્ષિત મકાન', debris: 'રસ્તા પર કાટમાળ', other: 'અન્ય' },
};

/** A sensitive category's stored English label in the reader's language; free text is returned unchanged. */
export function localDescription(categorySlug: string, description: string | null, lang: 'en' | 'gu'): string | null {
  if (lang !== 'gu' || !description) return description;
  const en = STRUCTURED_REASONS[categorySlug];
  const key = en && Object.keys(en).find((k) => en[k] === description);
  return (key && STRUCTURED_REASONS_GU[categorySlug]?.[key]) || description;
}

export const createIssueBody = z.object({
  clientSubmissionId: z.uuid({ version: 'v4', error: 'Must be a UUID v4.' }),
  categorySlug: z.string().trim().min(1).max(32),
  photoIds: z.array(z.uuid()).min(1, 'Add at least one photo.'),
  latitude: z.number().min(-90).max(90).transform(round6),
  longitude: z.number().min(-180).max(180).transform(round6),
  gpsAccuracyM: z.number().min(0).max(100_000).optional(),
  pinAdjusted: z.boolean(),
  /** Device fix (before the pin was moved); used only for the pinDistanceFromFixM note. */
  fixLatitude: z.number().min(-90).max(90).optional(),
  fixLongitude: z.number().min(-180).max(180).optional(),
  deviceCapturedAt: z.iso.datetime({ offset: true }),
  description: z
    .string()
    .max(2000)
    .optional()
    .nullable()
    .transform((v) => (v ?? '').trim())
    .refine((v) => v.length <= 1000, 'Keep the description under 1,000 characters.')
    .transform((v) => (v === '' ? null : v)),
  structuredReason: z.string().max(40).optional().nullable(),
  confirmedWardId: z.uuid().optional().nullable(),
  platform: z.enum(['android', 'ios']),
  appVersion: z.string().min(1).max(20),
});
export type CreateIssueBody = z.infer<typeof createIssueBody>;

export const nearbyQuery = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lng: z.coerce.number().min(-180).max(180),
  category: z.string().trim().min(1).max(32),
});

export const issueIdParams = z.object({ id: z.uuid() });

export const linkCcrsBody = z.object({
  ccrsNumber: z.string().max(80),
  filedVia: z.enum(['web', 'whatsapp', 'phone']),
});
