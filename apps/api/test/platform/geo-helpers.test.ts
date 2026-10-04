// src/lib/geo helpers (V2 TASK-01 §6 step 7).
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { distanceMetres, pointSql } from '../../src/lib/geo';
import { resetDb } from '../helpers/db';
import { makeIssue } from '../helpers/factories';

beforeEach(resetDb);

describe('geo helpers', () => {
  it('pointSql builds a bound WGS84 point', async () => {
    const [row] = await prisma.$queryRaw<{ wkt: string; srid: number }[]>`
      SELECT ST_AsText(${pointSql(23.0225, 72.5714)}) AS wkt, ST_SRID(${pointSql(23.0225, 72.5714)}) AS srid`;
    expect(row).toEqual({ wkt: 'POINT(72.5714 23.0225)', srid: 4326 });
  });

  it('distanceMetres measures from the issue location in metres', async () => {
    const issue = await makeIssue({ lat: 23.0, lng: 72.5 });
    expect(await distanceMetres(issue.id, 23.0, 72.5)).toBe(0);
    // 0.001° latitude ≈ 110.7 m at 23° N.
    const d = await distanceMetres(issue.id, 23.001, 72.5);
    expect(d).toBeGreaterThan(105);
    expect(d).toBeLessThan(115);
    expect(await distanceMetres('00000000-0000-4000-8000-000000000000', 23, 72.5)).toBeNull();
  });
});
