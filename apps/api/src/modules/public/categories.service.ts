import { prisma } from '../../lib/db';

/** Active categories in display order (03 §2.2). */
export async function listActiveCategories(): Promise<{ id: string; name: string }[]> {
  return prisma.ccrsCategory.findMany({
    where: { isActive: true },
    orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
    select: { id: true, name: true },
  });
}
