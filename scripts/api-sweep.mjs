#!/usr/bin/env node
// V2 TASK-14 contract, role and error-code sweep. Run against a running API (its own instance, never port 4000):
//   node scripts/api-sweep.mjs [baseUrl] [--report <file.json>] [--skip-env]
// Reads the API's env (SWEEP_ENV_FILE, default apps/api/.env) for the admin login, audit/log file locations and the
// database used for cleanup of the sweep's own rows. Sign-in uses the Firebase Auth Emulator. Prints PASS/FAIL per
// check and exits 1 on any FAIL. Never prints secrets, OTPs, tokens or phone numbers.
import { writeFileSync } from 'node:fs';
import { closeDb, db } from './api-sweep/auth.mjs';
import { g2Auth, preClean } from './api-sweep/accounts.mjs';
import { codeTable } from './api-sweep/codes.mjs';
import { g7Discovery, g8Alerts } from './api-sweep/discovery.mjs';
import { envSweep } from './api-sweep/env.mjs';
import { g5IssuesWrite, g6Lifecycle } from './api-sweep/issues.mjs';
import { BASE, check, del, results, section, seenCodes } from './api-sweep/lib.mjs';
import { g1Health, g3Geo, g4Categories, g4RateLimit } from './api-sweep/public.mjs';
import { g10Services, g9Representatives } from './api-sweep/reps.mjs';
import { auditAndLogContent, rolesMatrix } from './api-sweep/roles.mjs';
import { g11Alerts, g11Claims, g11Moderation } from './api-sweep/staff1.mjs';
import { g11Config, g11Messages, g11Users, g11Ward } from './api-sweep/staff2.mjs';
import { g11Roster, g11Services } from './api-sweep/staff3.mjs';

const arg = (name) => (process.argv.includes(name) ? process.argv[process.argv.indexOf(name) + 1] : undefined);
const ctx = {};

async function cleanup() {
  section('Cleanup (sweep data only)');
  const p = db();
  const users = [ctx.A, ctx.B, ctx.C, ctx.D].map((s) => s?.user?.id).filter(Boolean);
  try {
    // Sweep issues leave public lists: hidden (they stay for audit history; reporters are erased below).
    const hidden = await p.issue.updateMany({ where: { reporterId: { in: users } }, data: { visibility: 'hidden' } });
    if (ctx.alertIds?.length) await p.alert.deleteMany({ where: { id: { in: ctx.alertIds }, status: { not: 'published' } } });
    if (ctx.sweepServiceId) await p.service.deleteMany({ where: { id: ctx.sweepServiceId } });
    if (ctx.sweepRepId) await p.representative.deleteMany({ where: { id: ctx.sweepRepId } });
    if (ctx.initiativeId) {
      await p.rsvp.deleteMany({ where: { initiativeId: ctx.initiativeId } });
      await p.initiative.deleteMany({ where: { id: ctx.initiativeId } });
    }
    let erased = 0;
    for (const s of [ctx.A, ctx.B, ctx.C, ctx.D]) {
      if (!s?.token) continue;
      const r = await del('/me', { confirm: 'DELETE' }, { token: s.token });
      if (r.status === 204) erased += 1;
    }
    console.log(`   hidden ${hidden.count} sweep issue(s); erased ${erased} sweep account(s)`);
  } catch (err) {
    console.log(`   cleanup error: ${err.message}`);
  }
}

async function main() {
  console.log(`api-sweep against ${BASE} at ${new Date().toISOString()}`);
  await preClean();
  const groups = [
    g1Health, g3Geo, g4Categories, g2Auth, g5IssuesWrite, g6Lifecycle, g7Discovery, g8Alerts, g9Representatives, g10Services,
    g11Moderation, g11Alerts, g11Claims, g11Ward, g11Messages, g11Users, g11Config, g11Roster, g11Services, rolesMatrix,
  ];
  for (const g of groups) {
    try {
      await g(ctx);
    } catch (err) {
      check(`${g.name} completed without an exception`, false, err.message);
    }
  }
  auditAndLogContent(ctx);
  await g4RateLimit();
  await cleanup();

  for (const [code, where] of ctx.seenLater ?? []) if (!seenCodes.has(code)) seenCodes.set(code, where);
  section('Error-code sweep');
  const codes = codeTable(seenCodes);
  for (const c of codes) console.log(`${c.code.padEnd(30)} ${String(c.status)}  produced: ${c.produced}  |  app: ${c.mobile}`);
  check('every reachable ERROR_CODES entry is produced by the sweep or a Vitest test', codes.every((c) => c.produced !== 'NOT PRODUCED'), codes.filter((c) => c.produced === 'NOT PRODUCED').map((c) => c.code).join(', '));
  console.log(`INFO  unreachable codes (findings): ${codes.filter((c) => c.produced.startsWith('unreachable')).map((c) => c.code).join(', ') || 'none'}`);
  const missing = codes.filter((c) => c.missing).map((c) => c.code);
  console.log(`INFO  user-facing codes without an app message (report only; mobile not edited): ${missing.length ? missing.join(', ') : 'none'}`);

  let envRows = [];
  if (!process.argv.includes('--skip-env')) {
    section('Env-var sweep');
    envRows = await envSweep();
    for (const r of envRows) console.log(`${r.name.padEnd(34)} example:${r.inExample ? 'yes' : 'NO '}  ${r.required ? `required → startup ${r.startupFails ? 'fails' : 'DOES NOT FAIL'}: ${r.message}` : 'optional (default)'}`);
    check('every src/config variable is listed in apps/api/.env.example', envRows.every((r) => r.inExample), envRows.filter((r) => !r.inExample).map((r) => r.name).join(', '));
    check('removing any required variable fails startup with a "Config error: <NAME>" message', envRows.filter((r) => r.required).every((r) => r.startupFails), envRows.filter((r) => r.required && !r.startupFails).map((r) => r.name).join(', '));
  }

  const failed = results.filter((r) => !r.ok);
  console.log(`\nSUMMARY  ${results.length - failed.length} passed, ${failed.length} failed, ${results.length} checks`);
  for (const f of failed) console.log(`  FAIL [${f.group}] ${f.name}${f.info ? ` — ${f.info}` : ''}`);
  const report = arg('--report');
  if (report) writeFileSync(report, JSON.stringify({ base: BASE, at: new Date().toISOString(), results, codes, envRows, retractedAlert: ctx.retractedAlertBehaviour }, null, 2));
  await closeDb();
  process.exit(failed.length ? 1 : 0);
}

main().catch(async (err) => {
  console.error(`api-sweep crashed: ${err.message}`);
  await closeDb();
  process.exit(1);
});
