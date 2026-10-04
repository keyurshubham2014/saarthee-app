// Group 11 (staff) part 1: moderation, alerts two-person rule, representative claims (TASK-14 §5.3, §5.5).
import { auditFor } from './auth.mjs';
import { call, check, expect, get, post, section } from './lib.mjs';

/** Runs a staff action and asserts exactly one audit line with actor, role and target. */
export async function audited(name, action, targetId, role, fn) {
  const since = new Date().toISOString();
  const r = await fn();
  const ok = r.status >= 200 && r.status < 300;
  check(name, ok, `${r.status}${r.data?.error?.code ? ` ${r.data.error.code}` : ''}`);
  if (!ok) return r;
  const lines = await auditFor(action, targetId, since);
  check(`  ↳ one audit line ${action} (actor, role ${role}, target)`, lines.length === 1 && Boolean(lines[0].actorId) && lines[0].role === role && lines[0].targetId === targetId, `lines=${lines.length}${lines[0] ? ` role=${lines[0].role}` : ''}`);
  return r;
}

export async function g11Moderation(ctx) {
  section('11 Staff — moderation');
  const { MOD, REP, B } = ctx;
  const q = await get('/staff/moderation?queue=flagged', { token: MOD.token });
  check('moderator GET /staff/moderation → 200', q.status === 200, `${q.status}`);
  expect('citizen GET /staff/moderation → 403 FORBIDDEN', await get('/staff/moderation?queue=flagged', { token: B.token }), 403, 'FORBIDDEN');
  expect('representative GET /staff/moderation → 403 FORBIDDEN', await get('/staff/moderation?queue=flagged', { token: REP.token }), 403, 'FORBIDDEN');
  expect('visitor GET /staff/moderation → 401 AUTH_REQUIRED', await get('/staff/moderation?queue=flagged'), 401, 'AUTH_REQUIRED');
  const d = await get(`/staff/issues/${ctx.I2}`, { token: MOD.token });
  check('moderator GET /staff/issues/{id} → 200', d.status === 200, `${d.status}`);
  if (ctx.flagId) await audited('moderator resolves a flag → 200', 'flag_resolved', ctx.flagId, 'moderator', () => post(`/staff/flags/${ctx.flagId}/resolve`, { outcome: 'dismissed' }, { token: MOD.token }));
  else check('flag id available for resolve', false);
  const [h, rj, mg] = ctx.dIssues;
  await audited('moderator hides an issue → 200', 'issue_hidden', h, 'moderator', () => post(`/staff/issues/${h}/hide`, { reason: 'sweep hide reason text' }, { token: MOD.token }));
  await audited('moderator unhides it → 200', 'issue_unhidden', h, 'moderator', () => post(`/staff/issues/${h}/unhide`, { reason: 'sweep unhide reason text' }, { token: MOD.token }));
  await audited('moderator rejects an issue → 200', 'issue_rejected', rj, 'moderator', () => post(`/staff/issues/${rj}/reject`, { reason: 'spam', note: 'sweep reject note text' }, { token: MOD.token }));
  expect('reject it again → 409 ISSUE_STATE_INVALID', await post(`/staff/issues/${rj}/reject`, { reason: 'spam' }, { token: MOD.token }), 409, 'ISSUE_STATE_INVALID');
  expect('merge an issue into itself → 422 MERGE_INVALID', await post(`/staff/issues/${mg}/merge`, { targetIssueId: mg }, { token: MOD.token }), 422, 'MERGE_INVALID');
  expect('representative rejects an issue → 403 FORBIDDEN', await post(`/staff/issues/${mg}/reject`, { reason: 'spam' }, { token: REP.token }), 403, 'FORBIDDEN');
  expect('representative merges → 403 FORBIDDEN', await post(`/staff/issues/${mg}/merge`, { targetIssueId: ctx.I2 }, { token: REP.token }), 403, 'FORBIDDEN');
  expect('representative hides → 403 FORBIDDEN', await post(`/staff/issues/${mg}/hide`, { reason: 'x' }, { token: REP.token }), 403, 'FORBIDDEN');
}

function alertBody(ctx, severity) {
  const from = new Date(Date.now() + 60_000);
  return {
    type: 'other', severity, titleEn: 'Sweep test alert', titleGu: 'સ્વીપ ટેસ્ટ', bodyEn: 'Fictional sweep alert body text.', bodyGu: 'કાલ્પનિક સ્વીપ સંદેશ.',
    sourceName: 'Saarthee sweep', sourceUrl: 'https://saarthee.in/sweep', validFrom: from.toISOString(), validTo: new Date(from.getTime() + 3_600_000).toISOString(),
    target: { scope: 'wards', wardIds: [ctx.ward18.id] },
  };
}

export async function g11Alerts(ctx) {
  section('11 Staff — alerts (two-person rule)');
  const { MOD, ADMIN } = ctx;
  expect('citizen POST /staff/alerts → 403 FORBIDDEN', await post('/staff/alerts', alertBody(ctx, 'warning'), { token: ctx.B.token }), 403, 'FORBIDDEN');
  expect('representative POST /staff/alerts → 403 FORBIDDEN', await post('/staff/alerts', alertBody(ctx, 'warning'), { token: ctx.REP.token }), 403, 'FORBIDDEN');
  const since = new Date().toISOString();
  const created = await post('/staff/alerts', alertBody(ctx, 'warning'), { token: MOD.token });
  const A = created.data?.id;
  check('moderator creates a Warning draft → 201', created.status === 201 && Boolean(A), `${created.status}`);
  ctx.alertIds = [A].filter(Boolean);
  if (!A) return;
  const cl = await auditFor('alert_created', A, since);
  check('  ↳ one audit line alert_created (actor, role moderator, target)', cl.length === 1 && cl[0].role === 'moderator' && Boolean(cl[0].actorId), `lines=${cl.length}`);
  await audited('moderator submits → 200', 'alert_submitted', A, 'moderator', () => post(`/staff/alerts/${A}/submit`, {}, { token: MOD.token }));
  await audited('moderator gives the first approval → 200', 'alert_approved', A, 'moderator', () => post(`/staff/alerts/${A}/approve`, {}, { token: MOD.token }));
  expect('same moderator approves again → 409 ALERT_ALREADY_APPROVED', await post(`/staff/alerts/${A}/approve`, {}, { token: MOD.token }), 409, 'ALERT_ALREADY_APPROVED');
  expect('moderator publishes before the second approval → 409 ALERT_APPROVALS_MISSING', await post(`/staff/alerts/${A}/publish`, {}, { token: MOD.token }), 409, 'ALERT_APPROVALS_MISSING');
  await audited('admin gives the second approval → 200', 'alert_approved', A, 'admin', () => post(`/staff/alerts/${A}/approve`, {}, { token: ADMIN.token }));
  expect('moderator publishes a Warning → 403 FORBIDDEN', await post(`/staff/alerts/${A}/publish`, {}, { token: MOD.token }), 403, 'FORBIDDEN');
  await audited('admin publishes → 200', 'alert_published', A, 'admin', () => post(`/staff/alerts/${A}/publish`, {}, { token: ADMIN.token }));
  const pub = await get(`/alerts/${A}`);
  const approvers = pub.data?.approvedBy ?? pub.data?.approvers;
  check('GET /alerts/{id} → 200 with source, validity', pub.status === 200 && pub.data?.sourceName && pub.data?.sourceUrl && pub.data?.validFrom && pub.data?.validTo, `${pub.status}`);
  check('published Warning lists two different approvers (staff view)', await twoApprovers(ctx, A, approvers));
  await audited('admin retracts → 200', 'alert_retracted', A, 'admin', () => post(`/staff/alerts/${A}/retract`, { reason: 'Sweep test cleanup' }, { token: ADMIN.token }));
  const gone = await get(`/alerts/${A}`);
  check('retracted alert detail: public read shows it as retracted or gone', (gone.status === 200 && ['retracted', 'ended'].includes(gone.data?.status)) || gone.status === 404 || gone.status === 410, `${gone.status} ${gone.data?.status ?? gone.data?.error?.code ?? ''}`);
  ctx.retractedAlertBehaviour = `${gone.status} ${gone.data?.status ?? gone.data?.error?.code ?? ''}`;

  const b = await post('/staff/alerts', alertBody(ctx, 'warning'), { token: MOD.token });
  const Bid = b.data?.id;
  if (Bid) ctx.alertIds.push(Bid);
  await post(`/staff/alerts/${Bid}/submit`, {}, { token: MOD.token });
  const first = await post(`/staff/alerts/${Bid}/approve`, {}, { token: ADMIN.token });
  check('admin gives the first approval on a second Warning → 200', first.status === 200, `${first.status}`);
  expect('moderator gives the second approval → 403 ALERT_SECOND_APPROVER_ADMIN', await post(`/staff/alerts/${Bid}/approve`, {}, { token: MOD.token }), 403, 'ALERT_SECOND_APPROVER_ADMIN');
  expect('same admin gives the second approval → 409 ALERT_ALREADY_APPROVED', await post(`/staff/alerts/${Bid}/approve`, {}, { token: ADMIN.token }), 409, 'ALERT_ALREADY_APPROVED');
  expect('submit an alert that is already pending → 409 ALERT_STATE_INVALID', await call('POST', `/staff/alerts/${Bid}/submit`, { body: {}, token: MOD.token }), 409, 'ALERT_STATE_INVALID');
}

async function twoApprovers(ctx, id, publicApprovers) {
  const s = await get(`/staff/alerts/${id}`, { token: ctx.ADMIN.token });
  const list = s.data?.approvedBy ?? s.data?.approvals?.map((x) => x.actorId ?? x.by) ?? publicApprovers ?? [];
  return Array.isArray(list) && new Set(list.map((x) => (typeof x === 'string' ? x : x.id ?? x.actorId))).size === 2;
}

export async function g11Claims(ctx) {
  section('11 Staff — representative claims');
  const { MOD, ADMIN, REP } = ctx;
  const l = await get('/staff/rep-claims?status=pending', { token: MOD.token });
  check('moderator GET /staff/rep-claims → 200', l.status === 200, `${l.status}`);
  if (!ctx.claimId) return check('claim available for staff checks', false);
  const ev = `/staff/rep-claims/${ctx.claimId}/evidence/${ctx.evidencePhotoId}`;
  expect('claim evidence without token → 401 AUTH_REQUIRED', await get(ev), 401, 'AUTH_REQUIRED');
  expect('claim evidence as moderator → 403 FORBIDDEN', await get(ev, { token: MOD.token }), 403, 'FORBIDDEN');
  expect('claim evidence as representative → 403 FORBIDDEN', await get(ev, { token: REP.token }), 403, 'FORBIDDEN');
  const img = await get(ev, { token: ADMIN.token });
  check('claim evidence as admin → 200 image, Cache-Control no-store', img.status === 200 && /no-store/.test(img.headers.get('cache-control') ?? ''), `${img.status} ${img.headers.get('cache-control')}`);
  expect('moderator decides a claim → 403 FORBIDDEN', await post(`/staff/rep-claims/${ctx.claimId}/decide`, { decision: 'reject', reason: 'Sweep test reject' }, { token: MOD.token }), 403, 'FORBIDDEN');
  await audited('admin rejects the claim → 200', 'rep_claim_decided', ctx.claimId, 'admin', () => post(`/staff/rep-claims/${ctx.claimId}/decide`, { decision: 'reject', reason: 'Sweep test reject' }, { token: ADMIN.token }));
  expect('revoke verification of an unverified profile → 409 NOT_VERIFIED', await post('/staff/representatives/00000009-0018-4000-8000-000000000003/revoke-verification', { reason: 'Sweep test revoke' }, { token: ADMIN.token }), 409, 'NOT_VERIFIED');
  expect('decide it again → 409 CLAIM_NOT_PENDING', await post(`/staff/rep-claims/${ctx.claimId}/decide`, { decision: 'reject', reason: 'Sweep test reject' }, { token: ADMIN.token }), 409, 'CLAIM_NOT_PENDING');
}
