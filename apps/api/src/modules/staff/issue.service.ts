/** Staff issue tools read side (TASK-10 §5.4): detail for moderators and nearby merge candidates. */
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { flagReasons } from './queue.service';

const photoUrl = (id: string) => `/api/v1/media/photos/${id}?w=1024`;

export async function staffIssueDetail(id: string) {
  const issue = await prisma.issue.findUnique({
    where: { id },
    include: {
      category: true,
      ward: { select: { id: true, number: true, nameEn: true, nameGu: true } },
      photos: { orderBy: [{ kind: 'asc' }, { position: 'asc' }] },
      events: { orderBy: { createdAt: 'asc' }, include: { hide: true } },
      moderationFlags: { orderBy: { createdAt: 'asc' } },
    },
  });
  if (!issue) throw new AppError('NOT_FOUND');
  const reasons = await flagReasons([id]);
  return {
    id: issue.id,
    title: issue.title,
    description: issue.description,
    status: issue.status,
    visibility: issue.visibility,
    isSensitive: issue.isSensitive,
    lat: Number(issue.lat),
    lng: Number(issue.lng),
    createdAt: issue.createdAt,
    slaDueAt: issue.slaDueAt,
    moderatedAt: issue.moderatedAt,
    mergedIntoId: issue.mergedIntoId,
    meTooCount: issue.meTooCount,
    followerCount: issue.followerCount,
    category: { id: issue.category.id, slug: issue.category.slug, nameEn: issue.category.nameEn, nameGu: issue.category.nameGu, icon: issue.category.icon, colourToken: issue.category.colourToken },
    ward: issue.ward,
    /** Opaque id for "Suspend reporter…"; the UI shows only "A resident of <ward>" — never name or phone. */
    reporterId: issue.reporterId,
    photos: issue.photos.map((p) => ({ id: p.photoId, kind: p.kind, url: photoUrl(p.photoId) })),
    openFlags: reasons.get(id) ?? [],
    flags: issue.moderationFlags.map((f) => ({
      id: f.id, targetType: f.targetType, targetId: f.targetId, reason: f.reason, note: f.note, status: f.status, createdAt: f.createdAt,
    })),
    timeline: issue.events.map((e) => ({
      id: e.id, type: e.type, fromStatus: e.fromStatus, toStatus: e.toStatus, actorRole: e.actorRole,
      note: e.note, photoUrl: e.photoId ? photoUrl(e.photoId) : null, createdAt: e.createdAt, hidden: e.hide !== null,
    })),
  };
}

/** Open, public issues of any category within `radiusM` of the issue (merge targets), nearest first. */
export async function mergeCandidates(id: string, radiusM = 500) {
  const exists = await prisma.issue.count({ where: { id } });
  if (!exists) throw new AppError('NOT_FOUND');
  const rows = await prisma.$queryRaw<
    { id: string; title: string; status: string; created_at: Date; me_too_count: number; distance_m: number; category_slug: string; category_name_en: string; category_name_gu: string }[]
  >`
    SELECT o.id, o.title, o.status::text, o.created_at, o.me_too_count,
           ST_Distance(o.location, s.location)::float8 AS distance_m,
           c.slug AS category_slug, c.name_en AS category_name_en, c.name_gu AS category_name_gu
    FROM issues s
    JOIN issues o ON o.id <> s.id AND ST_DWithin(o.location, s.location, ${radiusM})
    JOIN categories c ON c.id = o.category_id
    WHERE s.id = ${id}::uuid
      AND o.status IN ('reported', 'sent', 'acknowledged', 'in_progress', 'reopened')
      AND o.visibility = 'public'
    ORDER BY distance_m ASC, o.created_at ASC
    LIMIT 20`;
  return {
    items: rows.map((r) => ({
      id: r.id, title: r.title, status: r.status, createdAt: r.created_at, meTooCount: r.me_too_count,
      distanceM: Math.round(r.distance_m),
      farWarning: r.distance_m > 200,
      category: { slug: r.category_slug, nameEn: r.category_name_en, nameGu: r.category_name_gu },
    })),
  };
}
