/**
 * GET /categories v2 (V2 TASK-05 §5.3, REQ-F-012): the 14 categories with their AMC CCRS problem types.
 * Replaces the v1 `{id, name}` list (v1 admin ccrs_categories screens are untouched). ETag = max updated_at.
 */
import { Router } from 'express';
import { prisma } from '../../lib/db';
import { rateLimit } from '../../middleware/rateLimit';

export const categoriesRouter = Router();

const categoriesLimiter = rateLimit({ windowMs: 60_000, max: 120 });

export interface AmcProblemTypeDto {
  id: string;
  deptEn: string;
  deptGu: string;
  problemEn: string;
  problemGu: string;
  isPrimary: boolean;
}

export const toAmcDto = (p: AmcProblemTypeDto): AmcProblemTypeDto => ({
  id: p.id, deptEn: p.deptEn, deptGu: p.deptGu, problemEn: p.problemEn, problemGu: p.problemGu, isPrimary: p.isPrimary,
});

/** Active problem types for a category, primary first (also used by POST /issues for the AMC hand-off). */
export async function amcProblemTypesFor(categoryId: string): Promise<AmcProblemTypeDto[]> {
  const rows = await prisma.amcProblemType.findMany({
    where: { categoryId, isActive: true },
    orderBy: [{ isPrimary: 'desc' }, { ccrsRow: 'asc' }],
  });
  return rows.map(toAmcDto);
}

async function categoriesEtag(): Promise<string> {
  const [c, p] = await Promise.all([
    prisma.category.aggregate({ _max: { updatedAt: true }, _count: true }),
    prisma.amcProblemType.aggregate({ _max: { updatedAt: true }, _count: true }),
  ]);
  const t = (d: Date | null | undefined) => (d ? d.getTime() : 0);
  return `W/"c${c._count}-${t(c._max.updatedAt)}-p${p._count}-${t(p._max.updatedAt)}"`;
}

categoriesRouter.get('/categories', categoriesLimiter, async (req, res) => {
  const etag = await categoriesEtag();
  res.setHeader('ETag', etag);
  res.setHeader('Cache-Control', 'public, max-age=300');
  if (req.header('if-none-match') === etag) {
    res.status(304).end();
    return;
  }
  const cats = await prisma.category.findMany({
    where: { isActive: true },
    orderBy: [{ sortOrder: 'asc' }, { slug: 'asc' }],
    include: { amcProblemTypes: { where: { isActive: true }, orderBy: [{ isPrimary: 'desc' }, { ccrsRow: 'asc' }] } },
  });
  res.json({
    items: cats.map((c) => ({
      id: c.id,
      slug: c.slug,
      nameEn: c.nameEn,
      nameGu: c.nameGu,
      icon: c.icon,
      colourToken: c.colourToken,
      slaDays: c.slaDays,
      sensitive: c.sensitive,
      sortOrder: c.sortOrder,
      amcProblemTypes: c.amcProblemTypes.map(toAmcDto),
    })),
  });
});
