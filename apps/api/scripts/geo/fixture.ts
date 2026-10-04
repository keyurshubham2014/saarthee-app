/**
 * npm run geo:fixture [-- --out <path>] — writes the `GET /api/v1/wards` response body (same service code, read
 * from the database in apps/api/.env) to apps/mobile/test/fixtures/wards.json so widget tests use the 48 real wards
 * (V2 TASK-02 §6 step 9). Run geo:import (or the seed) first.
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { prisma } from '../../src/lib/db';
import { listWards, listZones } from '../../src/modules/geo/geo.service';
import { argValue } from './common';

async function main() {
  try {
    const out = path.resolve(argValue('--out') ?? path.join(__dirname, '../../../mobile/test/fixtures/wards.json'));
    const wards = await listWards();
    if (wards.items.length === 0) throw new Error('No wards in the database — run geo:import first.');
    const zones = await listZones();
    mkdirSync(path.dirname(out), { recursive: true });
    writeFileSync(out, `${JSON.stringify({ ...wards, zones: zones.items }, null, 2)}\n`);
    console.log(`geo:fixture wards=${wards.items.length} zones=${zones.items.length} boundaryVersion=${wards.boundaryVersion} out=${out}`);
  } catch (err) {
    console.error('geo:fixture failed:', err instanceof Error ? err.message : err);
    process.exitCode = 1;
  } finally {
    await prisma.$disconnect();
  }
}

void main();
