import { backfillIssueWards, formatBackfill } from '../../../src/lib/geo/backfill';
import { formatImportResult, importWards } from '../../../src/lib/geo/import';
import { loadGeoSources } from '../../../src/lib/geo/ward-data';
import { defineSeedModule } from '../types';

/**
 * V2 TASK-02: 48 wards and 7 zones from the committed OpenCity GeoJSON + AMC ward list (same code path as
 * `geo:import`), then assigns wards to seeded and legacy issues that have none (`geo:backfill`). Idempotent.
 */
export default defineSeedModule({
  name: 'wards',
  requires: ['zones', 'wards'],
  async run({ prisma, log }) {
    log(`Seed wards: ${formatImportResult(await importWards(prisma, loadGeoSources()))}`);
    const maxNearestM = Number(process.env.GEO_NEAREST_MAX_M || 3000);
    log(`Seed wards: ${formatBackfill(await backfillIssueWards(prisma, maxNearestM))}`);
  },
});
