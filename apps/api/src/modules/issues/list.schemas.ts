/** Query schemas for discovery reads (V2 TASK-07 §5.3): GET /issues, /issues/{id}, /feed, /map/issues. */
import { z } from 'zod';
import { config } from '../../config';

export const STATUS_FILTERS = [
  'reported', 'sent', 'acknowledged', 'in_progress', 'marked_fixed', 'verified', 'reopened', 'rejected', 'merged', 'overdue', 'fixed_unverified',
] as const;
export type StatusFilter = (typeof STATUS_FILTERS)[number];

const MAX_SPAN_DEG = 0.5;

const csv = <T extends z.ZodType<unknown, string>>(item: T) =>
  z
    .string()
    .trim()
    .min(1)
    .max(400)
    .transform((v) => v.split(',').map((s) => s.trim()).filter(Boolean))
    .pipe(z.array(item).min(1).max(20));

export interface Bbox {
  minLng: number;
  minLat: number;
  maxLng: number;
  maxLat: number;
}

/** `minLng,minLat,maxLng,maxLat`, each axis span ≤ 0.5°. */
export const bboxParam = z
  .string()
  .trim()
  .transform((v, ctx): Bbox => {
    const n = v.split(',').map(Number);
    const [minLng, minLat, maxLng, maxLat] = n;
    const ok =
      n.length === 4 && n.every(Number.isFinite) && minLng! < maxLng! && minLat! < maxLat! &&
      minLng! >= -180 && maxLng! <= 180 && minLat! >= -90 && maxLat! <= 90 &&
      maxLng! - minLng! <= MAX_SPAN_DEG && maxLat! - minLat! <= MAX_SPAN_DEG;
    if (!ok) {
      ctx.addIssue({ code: 'custom', message: `Use minLng,minLat,maxLng,maxLat spanning at most ${MAX_SPAN_DEG}°.` });
      return z.NEVER;
    }
    return { minLng: minLng!, minLat: minLat!, maxLng: maxLng!, maxLat: maxLat! };
  });

const bool = z.enum(['true', 'false']).transform((v) => v === 'true');
export const langParam = z.enum(['en', 'gu']).default('en');

export const listQuery = z.object({
  ward: z.uuid().optional(),
  category: csv(z.string().max(32)).optional(),
  status: csv(z.enum(STATUS_FILTERS)).optional(),
  bbox: bboxParam.optional(),
  mine: bool.optional(),
  following: bool.optional(),
  sort: z.enum(['newest', 'most_affected', 'overdue']).default('newest'),
  cursor: z.string().max(400).optional(),
  limit: z.coerce.number().int().min(1).max(config.ISSUES_PAGE_MAX).default(20),
  lang: langParam,
});
export type ListQuery = z.infer<typeof listQuery>;

export const detailQuery = z.object({ lang: langParam });

export const feedQuery = z.object({ ward: z.uuid().optional(), lang: langParam });

export const mapQuery = z.object({
  bbox: bboxParam,
  zoom: z.coerce.number().int().min(0).max(20),
  category: csv(z.string().max(32)).optional(),
  status: csv(z.enum(STATUS_FILTERS)).optional(),
  mine: bool.optional(),
});
export type MapQuery = z.infer<typeof mapQuery>;
