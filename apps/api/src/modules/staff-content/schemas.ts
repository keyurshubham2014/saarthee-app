import { z } from 'zod';
import { SERVICE_CATEGORIES } from '../../../prisma/seed-data/services';

/** Staff content schemas (V2 TASK-12 §5.2/§5.3). Bounds mirror the column sizes and CHECKs. */
const text = (max: number) => z.string().trim().min(1).max(max);
const httpsUrl = z.string().trim().max(500).regex(/^https:\/\/[^\s]+$/, 'Use a full https:// link.');
/** Numbered Markdown list only: every non-empty line is "N. step". */
const numbered = z
  .string()
  .trim()
  .min(1)
  .max(4000)
  .refine((v) => v.split('\n').every((l) => /^\d{1,2}\. \S/.test(l.trim())), 'Write each step on its own line as "1. …".');

export const serviceFields = {
  slug: z.string().regex(/^[a-z0-9-]{3,60}$/, 'Use 3–60 lowercase letters, numbers or dashes.'),
  category: z.enum(SERVICE_CATEGORIES),
  nameEn: text(80),
  nameGu: text(80),
  department: text(100),
  departmentGu: text(100),
  summaryEn: text(300),
  summaryGu: text(300),
  howToEn: numbered,
  howToGu: numbered,
  url: httpsUrl,
  online: z.boolean(),
  visitWardOffice: z.boolean(),
  sortOrder: z.number().int().min(0).max(10_000),
  isActive: z.boolean(),
};

/** Optional versions of fields (no defaults, so a PATCH never resets an omitted field). */
const partial = (fields: Record<string, z.ZodType>) => Object.fromEntries(Object.entries(fields).map(([k, v]) => [k, v.optional()]));

export const serviceCreate = z.strictObject({
  ...serviceFields,
  visitWardOffice: serviceFields.visitWardOffice.default(false),
  sortOrder: serviceFields.sortOrder.default(100),
  isActive: serviceFields.isActive.default(true),
});
export const servicePatch = z.strictObject({ ...partial(serviceFields), markVerified: z.literal(true).optional() }) as unknown as z.ZodType<
  Partial<z.output<typeof serviceCreate>> & { markVerified?: true }
>;

export const staffServicesQuery = z.object({
  linkOk: z.enum(['true', 'false']).optional(),
  active: z.enum(['true', 'false']).optional(),
});

export const INITIATIVE_TYPES = ['tree_drive', 'cleanup', 'health_camp', 'other'] as const;
export const ORGANISERS = ['AMC', 'RWA', 'NGO', 'Saarthee'] as const;
export const INITIATIVE_STATUSES = ['draft', 'published', 'cancelled', 'completed'] as const;

const initiativeBase = {
  titleEn: text(100),
  titleGu: text(100),
  descriptionEn: text(1000),
  descriptionGu: text(1000),
  type: z.enum(INITIATIVE_TYPES),
  organiser: z.enum(ORGANISERS),
  organiserName: text(100),
  sourceUrl: httpsUrl.nullable().optional(),
  wardId: z.uuid().nullable().optional(),
  locationTextEn: text(200),
  locationTextGu: text(200),
  lat: z.number().min(-90).max(90).nullable().optional(),
  lng: z.number().min(-180).max(180).nullable().optional(),
  startsAt: z.iso.datetime({ offset: true }).transform((v) => new Date(v)),
  endsAt: z.iso.datetime({ offset: true }).transform((v) => new Date(v)),
  capacity: z.number().int().min(1).max(100_000).nullable().optional(),
};

export const initiativeCreate = z
  .strictObject({ ...initiativeBase, status: z.enum(['draft', 'published']).default('draft') })
  .refine((v) => v.endsAt > v.startsAt, { path: ['endsAt'], message: 'End must be after the start.' })
  .refine((v) => v.organiser !== 'AMC' || !!v.sourceUrl, { path: ['sourceUrl'], message: 'Add the AMC source link.' })
  .refine((v) => (v.lat == null) === (v.lng == null), { path: ['lng'], message: 'Give both latitude and longitude.' });

export const initiativePatch = z.strictObject({
  ...partial(initiativeBase),
  status: z.enum(INITIATIVE_STATUSES).optional(),
}) as unknown as z.ZodType<Partial<Omit<z.output<typeof initiativeCreate>, 'status'>> & { status?: (typeof INITIATIVE_STATUSES)[number] }>;

export const attendanceBody = z.strictObject({
  userIds: z.array(z.uuid()).min(1).max(500),
  attended: z.boolean(),
});

const isoDate = z.iso.date().transform((v) => new Date(`${v}T00:00:00Z`));

const tipBase = {
  titleEn: text(80),
  titleGu: text(80),
  bodyEn: text(240),
  bodyGu: text(240),
  serviceSlug: z.string().regex(/^[a-z0-9-]{3,60}$/).nullable().optional(),
  wardId: z.uuid().nullable().optional(),
  activeFrom: isoDate,
  activeTo: isoDate,
  isActive: z.boolean(),
};

export const tipCreate = z
  .strictObject({ ...tipBase, isActive: tipBase.isActive.default(true) })
  .refine((v) => v.activeTo >= v.activeFrom, { path: ['activeTo'], message: 'End date must be on or after the start date.' });

export const tipPatch = z.strictObject(partial(tipBase)) as unknown as z.ZodType<Partial<z.output<typeof tipCreate>>>;

export const idParams = z.object({ id: z.uuid() });
