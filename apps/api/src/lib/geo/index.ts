import { Prisma } from '@prisma/client';
import { prisma } from '../db';

/**
 * PostGIS helpers (V2 TASK-01 §6 step 7). Values are always bound parameters; never build SQL strings.
 */

/** WGS84 point geometry for (lat, lng) as a Prisma.sql fragment. Cast with `::geography` for metres. */
export function pointSql(lat: number, lng: number): Prisma.Sql {
  return Prisma.sql`ST_SetSRID(ST_MakePoint(${lng}::double precision, ${lat}::double precision), 4326)`;
}

/** Distance in metres (spheroid) from an issue's stored location to (lat, lng); null when the issue does not exist. */
export async function distanceMetres(issueId: string, lat: number, lng: number): Promise<number | null> {
  const rows = await prisma.$queryRaw<{ d: number }[]>`
    SELECT ST_Distance(location, ${pointSql(lat, lng)}::geography) AS d
    FROM issues WHERE id = ${issueId}::uuid`;
  const d = rows[0]?.d;
  return d === undefined || d === null ? null : Number(d);
}
