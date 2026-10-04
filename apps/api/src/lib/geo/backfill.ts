/**
 * geo:backfill (V2 TASK-02 §5.2): sets ward_id/zone_id on issues where ward_id IS NULL — point-in-polygon first
 * (lowest ward number on shared boundaries), else the nearest ward within maxNearestM; farther issues stay NULL.
 * One transaction; idempotent (only NULL wards are touched).
 */
import type { PrismaClient } from '@prisma/client';

export interface BackfillResult {
  checked: number;
  inside: number;
  nearest: number;
  outside: number;
}

export async function backfillIssueWards(prisma: PrismaClient, maxNearestM: number): Promise<BackfillResult> {
  return prisma.$transaction(
    async (tx) => {
      const [{ n: checked } = { n: 0n }] = await tx.$queryRaw<{ n: bigint }[]>`
        SELECT count(*) AS n FROM issues WHERE ward_id IS NULL`;
      const inside = await tx.$executeRaw`
        UPDATE issues i SET ward_id = m.ward_id, zone_id = m.zone_id
        FROM (
          SELECT i2.id, w.id AS ward_id, w.zone_id
          FROM issues i2
          CROSS JOIN LATERAL (
            SELECT id, zone_id FROM wards WHERE ST_Covers(geom, i2.location::geometry) ORDER BY number LIMIT 1
          ) w
          WHERE i2.ward_id IS NULL
        ) m
        WHERE i.id = m.id`;
      const nearest = await tx.$executeRaw`
        UPDATE issues i SET ward_id = m.ward_id, zone_id = m.zone_id
        FROM (
          SELECT i2.id, w.id AS ward_id, w.zone_id
          FROM issues i2
          CROSS JOIN LATERAL (
            SELECT x.id, x.zone_id
            FROM (SELECT id FROM wards ORDER BY geom <-> i2.location::geometry LIMIT 5) c
            JOIN wards x ON x.id = c.id
            WHERE ST_DWithin(x.geom::geography, i2.location, ${maxNearestM})
            ORDER BY ST_Distance(x.geom::geography, i2.location), x.number LIMIT 1
          ) w
          WHERE i2.ward_id IS NULL
        ) m
        WHERE i.id = m.id`;
      const total = Number(checked);
      return { checked: total, inside, nearest, outside: total - inside - nearest };
    },
    { timeout: 120_000 },
  );
}

export const formatBackfill = (r: BackfillResult) =>
  `geo:backfill checked=${r.checked} inside=${r.inside} nearest=${r.nearest} outside=${r.outside}`;
