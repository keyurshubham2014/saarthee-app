/**
 * Moderation queues (TASK-10 §5.2): sensitive, flagged, out_of_area. Out-of-area is computed from geometry
 * (no ward polygon covers the point). Items never carry reporter identity.
 */
import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';

export type QueueName = 'sensitive' | 'flagged' | 'out_of_area';

const OPEN = Prisma.sql`i.status NOT IN ('rejected', 'merged')`;
const OUTSIDE = Prisma.sql`NOT EXISTS (SELECT 1 FROM wards w WHERE ST_Covers(w.geom, i.location::geometry))`;

function where(queue: QueueName): Prisma.Sql {
  switch (queue) {
    case 'sensitive':
      return Prisma.sql`i.is_sensitive AND i.moderated_at IS NULL AND ${OPEN}`;
    case 'out_of_area':
      return Prisma.sql`i.moderated_at IS NULL AND ${OPEN} AND i.location IS NOT NULL AND ${OUTSIDE}`;
    case 'flagged':
      return Prisma.sql`EXISTS (SELECT 1 FROM moderation_flags f WHERE f.issue_id = i.id AND f.status = 'open')`;
  }
}

export async function queueCounts(): Promise<{ sensitive: number; flagged: number; outOfArea: number }> {
  const [row] = await prisma.$queryRaw<{ sensitive: bigint; flagged: bigint; out_of_area: bigint }[]>`
    SELECT
      (SELECT count(*) FROM issues i WHERE ${where('sensitive')}) AS sensitive,
      (SELECT count(*) FROM issues i WHERE ${where('flagged')}) AS flagged,
      (SELECT count(*) FROM issues i WHERE ${where('out_of_area')}) AS out_of_area`;
  return { sensitive: Number(row!.sensitive), flagged: Number(row!.flagged), outOfArea: Number(row!.out_of_area) };
}

const encode = (offset: number) => Buffer.from(`o:${offset}`).toString('base64url');
function decode(cursor: string | undefined): number {
  if (!cursor) return 0;
  const m = /^o:(\d{1,7})$/.exec(Buffer.from(cursor, 'base64url').toString());
  if (!m) throw new AppError('VALIDATION_FAILED', { details: [{ field: 'cursor', issue: 'Invalid cursor.' }] });
  return Number(m[1]);
}

interface Row {
  id: string;
  title: string;
  status: string;
  visibility: string;
  is_sensitive: boolean;
  created_at: Date;
  category_slug: string;
  category_name_en: string;
  category_name_gu: string;
  category_icon: string;
  category_colour: string;
  ward_id: string | null;
  ward_number: number | null;
  ward_name_en: string | null;
  ward_name_gu: string | null;
  flag_count: bigint;
  photo_id: string | null;
}

export async function listQueue(queue: QueueName, cursor: string | undefined, limit: number) {
  const offset = decode(cursor);
  const order =
    queue === 'flagged'
      ? Prisma.sql`ORDER BY flag_count DESC, first_flag ASC, i.id`
      : Prisma.sql`ORDER BY i.created_at ASC, i.id`;
  const rows = await prisma.$queryRaw<Row[]>`
    SELECT i.id, i.title, i.status::text, i.visibility::text, i.is_sensitive, i.created_at,
           c.slug AS category_slug, c.name_en AS category_name_en, c.name_gu AS category_name_gu,
           c.icon AS category_icon, c.colour_token AS category_colour,
           w.id AS ward_id, w.number AS ward_number, w.name_en AS ward_name_en, w.name_gu AS ward_name_gu,
           (SELECT count(*) FROM moderation_flags f WHERE f.issue_id = i.id AND f.status = 'open') AS flag_count,
           (SELECT min(f.created_at) FROM moderation_flags f WHERE f.issue_id = i.id AND f.status = 'open') AS first_flag,
           (SELECT p.photo_id FROM issue_photos p WHERE p.issue_id = i.id AND p.kind = 'report' ORDER BY p.position LIMIT 1) AS photo_id
    FROM issues i
    JOIN categories c ON c.id = i.category_id
    LEFT JOIN wards w ON w.id = i.ward_id
    WHERE ${where(queue)}
    ${order}
    LIMIT ${limit + 1} OFFSET ${offset}`;
  const page = rows.slice(0, limit);
  const reasons = await flagReasons(page.map((r) => r.id));
  return {
    items: page.map((r) => ({
      id: r.id,
      title: r.title,
      status: r.status,
      visibility: r.visibility,
      isSensitive: r.is_sensitive,
      createdAt: r.created_at,
      category: { slug: r.category_slug, nameEn: r.category_name_en, nameGu: r.category_name_gu, icon: r.category_icon, colourToken: r.category_colour },
      ward: r.ward_id ? { id: r.ward_id, number: r.ward_number, nameEn: r.ward_name_en, nameGu: r.ward_name_gu } : null,
      openFlags: reasons.get(r.id) ?? [],
      photoThumbUrl: r.photo_id ? `/api/v1/media/photos/${r.photo_id}?w=320` : null,
    })),
    nextCursor: rows.length > limit ? encode(offset + limit) : null,
  };
}

/** Open flag counts per reason for each issue. */
export async function flagReasons(issueIds: string[]): Promise<Map<string, { reason: string; count: number }[]>> {
  const out = new Map<string, { reason: string; count: number }[]>();
  if (issueIds.length === 0) return out;
  const grouped = await prisma.moderationFlag.groupBy({
    by: ['issueId', 'reason'],
    where: { issueId: { in: issueIds }, status: 'open' },
    _count: { _all: true },
  });
  for (const g of grouped) {
    const list = out.get(g.issueId) ?? [];
    list.push({ reason: g.reason, count: g._count._all });
    out.set(g.issueId, list);
  }
  for (const list of out.values()) list.sort((a, b) => b.count - a.count);
  return out;
}
