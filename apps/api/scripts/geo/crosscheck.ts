/**
 * npm run geo:crosscheck [-- --version <v>] [--write] — checks the sources and the imported wards (V2 TASK-02 §5.2).
 * Prints the report; exit 1 on any error. `--write` saves it to prisma/data/geo/CROSSCHECK.md.
 */
import { writeFileSync } from 'node:fs';
import path from 'node:path';
import { PrismaClient } from '@prisma/client';
import { crosscheck, formatCrosscheck } from '../../src/lib/geo/crosscheck';
import { loadGeoSources } from '../../src/lib/geo/ward-data';
import { DEFAULT_BOUNDARY_VERSION, GEO_DATA_DIR, argValue } from './common';

async function main() {
  const prisma = new PrismaClient();
  try {
    const version = argValue('--version') ?? DEFAULT_BOUNDARY_VERSION;
    const maxNearestM = Number(process.env.GEO_NEAREST_MAX_M || 3000);
    const report = await crosscheck(prisma, loadGeoSources(version), { maxNearestM });
    const text = formatCrosscheck(report, version);
    console.log(text);
    if (process.argv.includes('--write')) writeFileSync(path.join(GEO_DATA_DIR, 'CROSSCHECK.md'), text);
    if (!report.ok) process.exitCode = 1;
  } catch (err) {
    console.error('geo:crosscheck failed:', err instanceof Error ? err.message : err);
    process.exitCode = 1;
  } finally {
    await prisma.$disconnect();
  }
}

void main();
