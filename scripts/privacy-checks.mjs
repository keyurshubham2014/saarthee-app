#!/usr/bin/env node
// Privacy / security checks against a running API (v1: TASK-10 06 §12.3; v2: TASK-14 §5.3 P2-01…P2-12).
//   node scripts/privacy-checks.mjs [baseUrl] [--v1] [--v2]      (default --v2; npm run privacy:check)
// v2 signs in through the Firebase Auth Emulator (FIREBASE_AUTH_EMULATOR_HOST, default 127.0.0.1:9099) with
// fictional +9190000000NN numbers, the seeded moderator/representative, and the v1 admin email login
// (SEED_ADMIN_EMAIL / SEED_ADMIN_PASSWORD from apps/api/.env). DB-side assertions use DATABASE_URL when reachable.
// Prints PASS/FAIL (SKIP) per check; exits 1 on any FAIL, 2 if the run itself crashes.
// Never prints phone numbers, OTPs, tokens or message bodies.
import { apiRequire, createContext, env } from './privacy/lib.mjs';
import { runV1 } from './privacy/v1.mjs';
import { setup } from './privacy/v2-setup.mjs';
import { p201, p202, p207, p210 } from './privacy/v2-public.mjs';
import { p203, p205, p208, p209, prepareClaimsAndRelay } from './privacy/v2-account.mjs';
import { p204, p206, p211, p212 } from './privacy/v2-lifecycle.mjs';

const args = process.argv.slice(2);
const base = (args.find((a) => !a.startsWith('--')) ?? `http://localhost:${env.API_PORT || 4000}/api/v1`).replace(/\/$/, '');
const wantV1 = args.includes('--v1');
const wantV2 = args.includes('--v2') || !wantV1;

async function openDb() {
  if (!env.DATABASE_URL || /^https:/.test(base)) return null;
  try {
    const { Client } = apiRequire('pg');
    const db = new Client({ connectionString: env.DATABASE_URL });
    await db.connect();
    return db;
  } catch {
    return null;
  }
}

async function runV2(ctx) {
  const db = await openDb();
  const steps = [];
  const safe = (fn) => async (...a) => {
    try {
      await fn(ctx, ...a);
    } catch (e) {
      const id = fn.name.replace(/^p2(\d\d)$/, 'P2-$1');
      ctx.results.push({ id, ok: false, status: 'FAIL' });
      console.log(`FAIL  ${id} — crashed: ${e.message}`);
    }
  };
  try {
    let f;
    try {
      f = await setup(ctx);
      await prepareClaimsAndRelay(ctx, f);
    } catch (e) {
      // e.g. no Auth Emulator (staging): report it, still run the transport check.
      ctx.results.push({ id: 'P2-setup', ok: false, status: 'FAIL' });
      console.log(`FAIL  P2-setup — fixtures could not be created: ${e.message}`);
      await safe(p212)();
      return;
    }
    console.log(`v2 fixtures ready (run ${f.run}, ward ${f.ward.nameEn})\n`);
    steps.push(
      () => safe(p201)(f),
      () => safe(p202)(f),
      () => safe(p203)(f, db),
      () => safe(p205)(f),
      () => safe(p207)(f),
      () => safe(p208)(f),
      () => safe(p209)(f),
      () => safe(p210)(f),
      () => safe(p206)(f, db),
      () => safe(p212)(),
      () => safe(p211)(f), // rate limits last: they exhaust this IP's budgets for a minute
      () => safe(p204)(), // pure log read, after every request of the run
    );
    for (const s of steps) await s();
  } finally {
    await db?.end().catch(() => undefined);
  }
}

async function main() {
  const ctx = createContext(base);
  console.log(`privacy-checks against ${base} (${[wantV1 && 'v1', wantV2 && 'v2'].filter(Boolean).join(' + ')}) at ${new Date().toISOString()}\n`);
  if (wantV1) await runV1(ctx);
  if (wantV2) await runV2(ctx);
  const failed = ctx.results.filter((r) => !r.ok).length;
  const skipped = ctx.results.filter((r) => r.status === 'SKIP').length;
  console.log(`\n${ctx.results.length - failed - skipped} passed, ${failed} failed, ${skipped} skipped (${ctx.results.length} checks)`);
  process.exit(failed ? 1 : 0);
}

main().catch((e) => {
  console.error('privacy-checks crashed:', e.message);
  process.exit(2);
});
