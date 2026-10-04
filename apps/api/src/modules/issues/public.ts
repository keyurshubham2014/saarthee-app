/**
 * Public issue serializers (V2 TASK-07 §5.2, REQ-S-006). The ONLY shapes public routes return:
 * `toPublicIssue()` (detail) and `toCard()` (feed, lists, map preview). Never reporter id, phone, name,
 * client_submission_id, ccrs_number, device fields or legacy_complaint_id. Reporters are always
 * "A resident of <ward>".
 */
import { Prisma, type IssueStatus } from '@prisma/client';
import { deriveIssue, type DisplayStatus } from './derive';
import { localDescription } from './issues.schemas';

export type Lang = 'en' | 'gu';

export const photoUrl = (id: string, w = 1024) => `/api/v1/media/photos/${id}?w=${w}`;

/** "A resident of Paldi" / "પાલડીના રહેવાસી" (ARB key reporter.residentOf). */
export function reporterLabel(wardEn: string | null, wardGu: string | null) {
  return {
    en: wardEn ? `A resident of ${wardEn}` : 'A resident of Ahmedabad',
    gu: wardGu ? `${wardGu}ના રહેવાસી` : 'અમદાવાદના રહેવાસી',
  };
}

export function localTitle(lang: Lang, cat: { nameEn: string; nameGu: string }, ward: { nameEn: string; nameGu: string } | null) {
  return lang === 'gu' ? `${cat.nameGu} · ${ward?.nameGu ?? 'અમદાવાદ'}` : `${cat.nameEn} · ${ward?.nameEn ?? 'Ahmedabad'}`;
}

/** Prisma include for [toPublicIssue]. */
export const publicIssueInclude = {
  category: { select: { slug: true, nameEn: true, nameGu: true, icon: true, colourToken: true } },
  ward: { select: { id: true, number: true, nameEn: true, nameGu: true } },
  zone: { select: { code: true, nameEn: true, nameGu: true } },
  photos: { orderBy: { position: 'asc' }, select: { photoId: true, kind: true, photo: { select: { blurApplied: true } } } },
} satisfies Prisma.IssueInclude;

export type PublicIssueRow = Prisma.IssueGetPayload<{ include: typeof publicIssueInclude }>;

export function toPublicIssue(i: PublicIssueRow, lang: Lang) {
  const urls = (kind: string) => i.photos.filter((p) => p.kind === kind).map((p) => photoUrl(p.photoId));
  const d = deriveIssue(i);
  return {
    id: i.id,
    title: localTitle(lang, i.category, i.ward),
    category: { slug: i.category.slug, nameEn: i.category.nameEn, nameGu: i.category.nameGu, icon: i.category.icon, colourToken: i.category.colourToken },
    status: i.status,
    displayStatus: d.displayStatus,
    isOverdue: d.isOverdue,
    slaDueAt: i.slaDueAt,
    ward: i.ward ? { id: i.ward.id, number: i.ward.number, nameEn: i.ward.nameEn, nameGu: i.ward.nameGu } : null,
    zone: i.zone ? { code: i.zone.code, nameEn: i.zone.nameEn, nameGu: i.zone.nameGu } : null,
    location: { lat: Number(i.lat), lng: Number(i.lng) },
    description: localDescription(i.category.slug, i.description, lang),
    photos: { report: urls('report'), after: urls('after'), verification: urls('verification') },
    blurApplied: i.photos.some((p) => p.kind === 'report' && p.photo.blurApplied),
    reporterLabel: reporterLabel(i.ward?.nameEn ?? null, i.ward?.nameGu ?? null),
    meTooCount: i.meTooCount,
    followerCount: i.followerCount,
    createdAt: i.createdAt,
    statusChangedAt: i.statusChangedAt,
    verifyWindowClosesAt: d.verifyWindowClosesAt,
    mergedIntoId: i.mergedIntoId,
  };
}

export type PublicIssue = ReturnType<typeof toPublicIssue>;

/** Raw row shape every card query selects (see CARD_COLUMNS). */
export interface CardRow {
  id: string;
  status: IssueStatus;
  sla_due_at: Date;
  marked_fixed_at: Date | null;
  created_at: Date;
  me_too_count: number;
  slug: string;
  cat_en: string;
  cat_gu: string;
  ward_en: string | null;
  ward_gu: string | null;
  photo_id: string | null;
  visibility: 'public' | 'hidden';
}

/** SELECT list for [CardRow]; the query must alias issues `i`, categories `c` and LEFT JOIN wards `w`. */
export const CARD_COLUMNS = Prisma.sql`
  i.id::text AS id, i.status, i.visibility, i.sla_due_at, i.marked_fixed_at, i.created_at, i.me_too_count,
  c.slug, c.name_en AS cat_en, c.name_gu AS cat_gu, w.name_en AS ward_en, w.name_gu AS ward_gu,
  (SELECT ip.photo_id::text FROM issue_photos ip WHERE ip.issue_id = i.id AND ip.kind = 'report'
    ORDER BY ip.position LIMIT 1) AS photo_id`;

export interface Card {
  id: string;
  title: string;
  categorySlug: string;
  status: IssueStatus;
  displayStatus: DisplayStatus;
  isOverdue: boolean;
  wardNameEn: string | null;
  wardNameGu: string | null;
  createdAt: Date;
  meTooCount: number;
  thumbnailUrl: string | null;
  /** True only on the reporter's own hidden issue (`mine=true`): "Moderator check pending". */
  pendingReview: boolean;
}

export function toCard(r: CardRow, lang: Lang): Card {
  const d = deriveIssue({ status: r.status, slaDueAt: r.sla_due_at, markedFixedAt: r.marked_fixed_at });
  const ward = r.ward_en === null ? null : { nameEn: r.ward_en, nameGu: r.ward_gu ?? r.ward_en };
  return {
    id: r.id,
    title: localTitle(lang, { nameEn: r.cat_en, nameGu: r.cat_gu }, ward),
    categorySlug: r.slug,
    status: r.status,
    displayStatus: d.displayStatus,
    isOverdue: d.isOverdue,
    wardNameEn: r.ward_en,
    wardNameGu: r.ward_gu,
    createdAt: r.created_at,
    meTooCount: Number(r.me_too_count),
    thumbnailUrl: r.photo_id ? photoUrl(r.photo_id, 320) : null,
    pendingReview: r.visibility === 'hidden',
  };
}
