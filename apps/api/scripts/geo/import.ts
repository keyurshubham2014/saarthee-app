/**
 * npm run geo:import [-- --version <boundaryVersion>] — loads zones and wards from prisma/data/geo (V2 TASK-02 §5.2).
 * Idempotent; refuses unless 48 wards and 7 zones resolve. Logs per-ward area change when the version changes.
 */
import { PrismaClient } from '@prisma/client';
import { formatImportResult, importWards } from '../../src/lib/geo/import';
import { loadGeoSources } from '../../src/lib/geo/ward-data';
import { DEFAULT_BOUNDARY_VERSION, argValue } from './common';

async function main() {
  const prisma = new PrismaClient();
  try {
    const version = argValue('--version') ?? DEFAULT_BOUNDARY_VERSION;
    console.log(formatImportResult(await importWards(prisma, loadGeoSources(version))));
  } catch (err) {
    console.error('geo:import failed:', err instanceof Error ? err.message : err);
    process.exitCode = 1;
  } finally {
    await prisma.$disconnect();
  }
}

void main();
