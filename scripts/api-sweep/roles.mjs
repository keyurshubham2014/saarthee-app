// §5.5 role matrix (visitor / citizen sweeps) and the audit/log content checks (REQ-S-010, no bodies).
import { auditLines, logFiles, readLines } from './auth.mjs';
import { PHONES } from './accounts.mjs';
import { check, expect, get, post, section, uuid } from './lib.mjs';

export async function rolesMatrix(ctx) {
  section('5.5 Role matrix — visitor');
  const reads = [
    ['feed', `/feed?ward=${ctx.ward18.id}`], ['map', '/map/issues?bbox=72.53,23.01,72.57,23.05&zoom=14'], ['issue detail', `/issues/${ctx.I2}`],
    ['alerts', `/alerts?wards=${ctx.ward18.id}`], ['services', '/services'], ['ward directory', `/wards/${ctx.ward18.id}/representatives`], ['initiatives', '/initiatives'],
  ];
  for (const [n, u] of reads) {
    const r = await get(u);
    check(`visitor can browse ${n} → 200`, r.status === 200, `${r.status}`);
  }
  const writes = [
    ['report', 'POST', '/issues', {}], ['Me too', 'POST', `/issues/${ctx.I2}/me-too`], ['follow', 'POST', `/issues/${ctx.I2}/follow`],
    ['verify', 'POST', `/issues/${ctx.I2}/verifications`, {}], ['message', 'POST', '/representatives/00000009-0018-4000-8000-000000000002/messages', {}],
    ['RSVP', 'POST', `/initiatives/${ctx.initiativeId ?? uuid()}/rsvp`], ['flag', 'POST', `/issues/${ctx.I2}/flags`, { reason: 'spam' }],
  ];
  for (const [n, , u, b] of writes) expect(`visitor ${n} → 401 AUTH_REQUIRED (sent to sign-in)`, await post(u, b), 401, 'AUTH_REQUIRED');

  section('5.5 Role matrix — citizen on every staff endpoint');
  const staffGets = [
    '/staff/me', '/staff/summary', '/staff/moderation?queue=flagged', `/staff/issues/${ctx.I2}`, '/staff/alerts', '/staff/rep-claims', '/staff/users',
    '/staff/categories', '/staff/settings', '/staff/settings/election-mode', `/staff/ward-dashboard?ward=${ctx.ward18.id}`, '/staff/ward/scope',
    '/staff/rep-messages', '/staff/representatives', '/staff/services', '/staff/initiatives', '/staff/tips', '/staff/export?dataset=issues&from=2026-01-01&to=2026-01-02',
  ];
  const bad = [];
  for (const u of staffGets) {
    const r = await get(u, { token: ctx.B.token });
    if (r.status !== 403) bad.push(`${u.split('?')[0]} ${r.status}`);
  }
  check(`citizen gets 403 on all ${staffGets.length} staff endpoints`, bad.length === 0, bad.join('; '));
  const anon = [];
  for (const u of staffGets) {
    const r = await get(u);
    if (r.status !== 401) anon.push(`${u.split('?')[0]} ${r.status}`);
  }
  check(`visitor gets 401 on all ${staffGets.length} staff endpoints`, anon.length === 0, anon.join('; '));
}

/** Free texts the sweep sent that must never reach the audit file or the API log. */
const BODY_MARKERS = [
  'sweep hide reason text', 'sweep unhide reason text', 'sweep reject note text', 'sweep suspend reason text', 'sweep comment note text', 'sweep reply body text',
  'Fictional sweep test message', 'Fictional sweep message body', 'Sweep claim (fictional).', 'Fictional sweep alert body text.', 'Fictional sweep drive.',
];

export function auditAndLogContent(ctx) {
  section('Audit file and API log content');
  const lines = auditLines();
  check('audit file exists and has lines', lines.length > 0, `${lines.length} lines`);
  const staff = lines.filter((l) => l.msg === 'staff_action');
  const incomplete = staff.filter((l) => !l.actorId || !l.role || !l.action || !l.targetId);
  check('every staff audit line has actorId, role, action, targetId', incomplete.length === 0, incomplete.slice(0, 3).map((l) => l.action).join(', '));
  const auditText = lines.map((l) => JSON.stringify(l)).join('\n');
  const leakedA = BODY_MARKERS.filter((m) => auditText.includes(m));
  check('audit file contains no request bodies, notes, reasons or messages', leakedA.length === 0, leakedA.join(' | '));
  const log = readLines(logFiles()).join('\n');
  check('API log file present', log.length > 0, `${logFiles().length} file(s)`);
  const leakedL = BODY_MARKERS.filter((m) => log.includes(m));
  check('API log contains no request bodies, notes, reasons or messages', leakedL.length === 0, leakedL.join(' | '));
  const phones = Object.values(PHONES).filter((p) => log.includes(p.slice(3)) || auditText.includes(p.slice(3)));
  check('API log and audit file contain no test phone numbers', phones.length === 0, `${phones.length} found`);
  const tokens = [ctx.A?.token, ctx.B?.token, ctx.MOD?.token, ctx.ADMIN?.token].filter(Boolean).filter((t) => log.includes(t) || auditText.includes(t));
  check('API log and audit file contain no session tokens', tokens.length === 0, `${tokens.length} found`);
}
