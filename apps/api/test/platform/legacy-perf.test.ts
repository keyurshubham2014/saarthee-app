// TASK-01 §7.2: `legacy:migrate` on 10,000 synthetic complaints completes in under 60 s (batching works).
// Opt-in (adds ~10–20 s): LEGACY_PERF=1 npx vitest run test/platform/legacy-perf.test.ts
import { beforeAll, describe, expect, it } from 'vitest';
import { prisma, withLegacyWrite } from '../../src/lib/db';
import { migrateLegacyComplaints } from '../../src/lib/legacy/migrate';
import { resetDb } from '../helpers/db';
import { makeCategory, makeCcrsCategory } from '../helpers/factories';

const N = 10_000;

describe.runIf(process.env.LEGACY_PERF === '1')('legacy:migrate performance', () => {
  beforeAll(async () => {
    await resetDb();
    await makeCategory({ slug: 'roads' });
    const ccrs = await makeCcrsCategory('Pothole or damaged road');
    await withLegacyWrite(
      async (tx) => {
        await tx.$executeRaw`
          INSERT INTO photos (id, storage_key, purpose, mime_type, byte_size, width_px, height_px, sha256, attached_at)
          SELECT gen_random_uuid(), 'photos/perf/' || g || '.jpg', 'report', 'image/jpeg', 1000, 640, 480,
                 lpad(to_hex(g), 64, '0'), now()
          FROM generate_series(1, ${N}) g`;
        await tx.$executeRaw`
          INSERT INTO complaints (client_submission_id, ccrs_number_raw, ccrs_number_normalized, category_id, photo_id,
                                  latitude, longitude, device_captured_at, phone_e164, consent_given_at,
                                  consent_text_version, app_platform, app_version)
          SELECT gen_random_uuid(), 'AMC-PERF-' || n, 'AMCPERF' || n, ${ccrs.id}::uuid, p.id,
                 23.0225, 72.5714, now(), '+919000000099', now(), 'v1', 'android', 'perf'
          FROM (SELECT id, row_number() OVER (ORDER BY storage_key) AS n FROM photos WHERE storage_key LIKE 'photos/perf/%') p`;
      },
      prisma,
      { timeout: 120_000 },
    );
  }, 180_000);

  it(`imports ${N} complaints in under 60 s`, async () => {
    const start = Date.now();
    const result = await migrateLegacyComplaints(prisma);
    const ms = Date.now() - start;
    console.error(`legacy:migrate perf: ${N} complaints in ${ms} ms`);
    expect(result).toEqual({ complaints: N, imported: N, skipped: 0 });
    expect(ms).toBeLessThan(60_000);
  }, 120_000);
});
