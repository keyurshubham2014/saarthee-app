import type { Prisma, Service } from '@prisma/client';
import { SERVICES_SOURCE } from '../../../prisma/seed-data/services';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';

/** Public list fields (TASK-12 §5.3 `GET /services`). */
export function listItem(s: Service) {
  return {
    slug: s.slug,
    category: s.category,
    nameEn: s.nameEn,
    nameGu: s.nameGu,
    summaryEn: s.summaryEn,
    summaryGu: s.summaryGu,
    online: s.online,
    visitWardOffice: s.visitWardOffice,
    linkOk: s.linkOk,
  };
}

export async function listServices(opts: { category?: string; q?: string }) {
  const where: Prisma.ServiceWhereInput = { isActive: true };
  if (opts.category) where.category = opts.category;
  const q = opts.q?.trim();
  if (q) {
    // Prisma renders `contains` + insensitive as a parameterised ILIKE.
    where.OR = (['nameEn', 'nameGu', 'summaryEn', 'summaryGu'] as const).map((f) => ({ [f]: { contains: q, mode: 'insensitive' } }));
  }
  const rows = await prisma.service.findMany({ where, orderBy: [{ category: 'asc' }, { sortOrder: 'asc' }, { slug: 'asc' }] });
  return { items: rows.map(listItem) };
}

async function wardOffice(wardId: string) {
  const w = await prisma.ward.findUnique({
    where: { id: wardId },
    select: { id: true, number: true, nameEn: true, nameGu: true, officeAddressEn: true, officeAddressGu: true, officePhone: true },
  });
  if (!w) return null;
  return {
    wardId: w.id,
    number: w.number,
    nameEn: w.nameEn,
    nameGu: w.nameGu,
    officeAddress: w.officeAddressEn,
    officeAddressGu: w.officeAddressGu,
    officePhone: w.officePhone,
  };
}

/** `GET /services/{slug}`: active services only; `?ward` adds that ward's office. */
export async function getService(slug: string, wardId?: string) {
  const s = await prisma.service.findUnique({ where: { slug } });
  if (!s || !s.isActive) throw new AppError('NOT_FOUND', { message: 'This service is no longer listed.' });
  return {
    ...listItem(s),
    department: s.department,
    departmentGu: s.departmentGu,
    howToEn: s.howToEn,
    howToGu: s.howToGu,
    url: s.url,
    lastCheckedAt: s.lastCheckedAt,
    verifiedAt: s.verifiedAt,
    wardOffice: wardId ? await wardOffice(wardId) : null,
    source: { name: SERVICES_SOURCE.name, url: s.url },
  };
}

/** Today's date (YYYY-MM-DD) in the city's time zone. */
export function cityToday(now: Date = new Date(), tz = process.env.TZ_CITY ?? 'Asia/Kolkata'): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit' }).format(now);
}

/** `GET /services/tips`: at most 3 tips active on `date`, ward-specific first. */
export async function listTips(opts: { ward?: string; date?: string }) {
  const day = new Date(`${opts.date ?? cityToday()}T00:00:00Z`);
  const rows = await prisma.serviceTip.findMany({
    where: {
      isActive: true,
      activeFrom: { lte: day },
      activeTo: { gte: day },
      OR: [{ wardId: null }, ...(opts.ward ? [{ wardId: opts.ward }] : [])],
    },
    include: { service: { select: { slug: true, isActive: true } } },
    orderBy: [{ activeFrom: 'desc' }, { id: 'asc' }],
  });
  rows.sort((a, b) => Number(b.wardId !== null) - Number(a.wardId !== null));
  return {
    items: rows.slice(0, 3).map((t) => ({
      id: t.id,
      titleEn: t.titleEn,
      titleGu: t.titleGu,
      bodyEn: t.bodyEn,
      bodyGu: t.bodyGu,
      serviceSlug: t.service?.isActive ? t.service.slug : null,
    })),
  };
}
