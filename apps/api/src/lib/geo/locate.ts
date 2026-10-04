/**
 * Point → ward/zone resolution (V2 TASK-02 §5.3 "/geo/locate algorithm"); also used by geo:crosscheck,
 * geo:backfill and (via modules/geo resolveWard) by TASK-05's POST /issues.
 * 1. inside: ST_Covers, lowest ward number wins on shared boundaries;
 * 2. nearest within maxNearestM (spheroid distance) → confirm:true;
 * 3. otherwise null (the API answers 422 OUTSIDE_SERVICE_AREA).
 */
import { Prisma, type PrismaClient } from '@prisma/client';
import { pointSql } from './index';

type Db = PrismaClient | Prisma.TransactionClient;

export interface ZoneRef {
  id: string;
  code: string;
  nameEn: string;
  nameGu: string;
}
export interface LocatedWard {
  ward: { id: string; number: number; nameEn: string; nameGu: string; zone: ZoneRef };
  zone: ZoneRef;
  match: 'inside' | 'nearest';
  confirm: boolean;
  distanceM: number;
  boundaryVersion: string;
}

interface Row {
  id: string;
  number: number;
  name_en: string;
  name_gu: string;
  boundary_version: string;
  zone_id: string;
  zone_code: string;
  zone_name_en: string;
  zone_name_gu: string;
  distance_m: number;
}

const select = Prisma.sql`
  SELECT w.id::text, w.number, w.name_en, w.name_gu, w.boundary_version,
         z.id::text AS zone_id, z.code AS zone_code, z.name_en AS zone_name_en, z.name_gu AS zone_name_gu`;

export async function locatePoint(db: Db, lat: number, lng: number, maxNearestM: number): Promise<LocatedWard | null> {
  const pt = pointSql(lat, lng);
  const inside = await db.$queryRaw<Row[]>`
    ${select}, 0::float8 AS distance_m
    FROM wards w JOIN zones z ON z.id = w.zone_id
    WHERE ST_Covers(w.geom, ${pt})
    ORDER BY w.number LIMIT 1`;
  if (inside[0]) return toResult(inside[0], 'inside');

  // Index-assisted candidate set (planar KNN on the GIST index), then exact spheroid distance.
  const nearest = await db.$queryRaw<Row[]>`
    WITH c AS (
      SELECT w.id FROM wards w ORDER BY w.geom <-> ${pt} LIMIT 5
    )
    ${select}, ST_Distance(w.geom::geography, ${pt}::geography) AS distance_m
    FROM c JOIN wards w ON w.id = c.id JOIN zones z ON z.id = w.zone_id
    ORDER BY distance_m, w.number LIMIT 1`;
  const n = nearest[0];
  if (!n || Number(n.distance_m) > maxNearestM) return null;
  return toResult(n, 'nearest');
}

function toResult(r: Row, match: 'inside' | 'nearest'): LocatedWard {
  const zone: ZoneRef = { id: r.zone_id, code: r.zone_code, nameEn: r.zone_name_en, nameGu: r.zone_name_gu };
  return {
    ward: { id: r.id, number: Number(r.number), nameEn: r.name_en, nameGu: r.name_gu, zone },
    zone,
    match,
    confirm: match === 'nearest',
    distanceM: match === 'inside' ? 0 : Math.round(Number(r.distance_m)),
    boundaryVersion: r.boundary_version,
  };
}
