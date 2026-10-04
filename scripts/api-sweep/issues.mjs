// Groups 5 (issues — write) and 6 (issues — lifecycle) (TASK-14 §5.3).
import { auditFor } from './auth.mjs';
import { check, env, expect, get, jpeg, post, section, upload, uuid } from './lib.mjs';
import { FAR_OUTSIDE, NEAR_OUTSIDE, PT18 } from './public.mjs';

let seq = 0;
/** A point inside ward 18, a few metres apart per call (stays within the ward's interior point area). */
export function spot() {
  seq += 1;
  return { latitude: +(PT18.lat + ((seq % 7) - 3) * 0.00004).toFixed(6), longitude: +(PT18.lng + (Math.floor(seq / 7) % 7 - 3) * 0.00004).toFixed(6) };
}

export async function photo(token, purpose = 'report', issueId) {
  const r = await upload(token, await jpeg(), { purpose, ...(issueId ? { issueId } : {}) });
  return r.data?.photoId ?? r.data?.id;
}

export function issueBody(ctx, photoId, extra = {}) {
  return {
    clientSubmissionId: uuid(), categorySlug: ctx.cat.slug, photoIds: [photoId], ...spot(), gpsAccuracyM: 8, pinAdjusted: false,
    deviceCapturedAt: new Date().toISOString(), description: 'Sweep test issue (fictional).', platform: 'android', appVersion: '2.0.0', ...extra,
  };
}

export async function g5IssuesWrite(ctx) {
  section('5 Issues — write');
  const A = ctx.A.token;
  expect('POST /photos without token → 401 AUTH_REQUIRED', await upload(null, await jpeg(), { purpose: 'report' }), 401, 'AUTH_REQUIRED');
  const up = await upload(A, await jpeg(), { purpose: 'report' });
  const pid = up.data?.photoId ?? up.data?.id;
  check('POST /photos → 201 photo id', up.status === 201 && Boolean(pid), `${up.status}`);
  const big = Buffer.alloc(Number(env.PHOTO_MAX_UPLOAD_BYTES) + 1024, 0xff);
  expect('POST /photos over PHOTO_MAX_UPLOAD_BYTES → 413 PHOTO_TOO_LARGE', await upload(A, big, { purpose: 'report' }), 413, 'PHOTO_TOO_LARGE');
  expect('POST /photos not a JPEG → 415 PHOTO_TYPE_UNSUPPORTED', await upload(A, Buffer.from('plain text, not an image'), { purpose: 'report' }, 'text/plain'), 415, 'PHOTO_TYPE_UNSUPPORTED');
  expect('POST /photos bad purpose → 400 VALIDATION_FAILED', await upload(A, await jpeg(), { purpose: 'selfie' }), 400, 'VALIDATION_FAILED');

  expect('POST /issues without token → 401 AUTH_REQUIRED', await post('/issues', issueBody(ctx, pid)), 401, 'AUTH_REQUIRED');
  expect('POST /issues far outside the city → 422 OUTSIDE_SERVICE_AREA', await post('/issues', issueBody(ctx, pid, { latitude: FAR_OUTSIDE.lat, longitude: FAR_OUTSIDE.lng }), { token: A }), 422, 'OUTSIDE_SERVICE_AREA');
  expect('POST /issues just outside, unconfirmed → 422 WARD_CONFIRMATION_REQUIRED', await post('/issues', issueBody(ctx, pid, { latitude: NEAR_OUTSIDE.lat, longitude: NEAR_OUTSIDE.lng }), { token: A }), 422, 'WARD_CONFIRMATION_REQUIRED');
  expect('POST /issues unknown category → 422 CATEGORY_INACTIVE', await post('/issues', issueBody(ctx, pid, { categorySlug: 'zz_sweep_none' }), { token: A }), 422, 'CATEGORY_INACTIVE');
  expect('POST /issues someone else\'s photo → 422 PHOTO_UNUSABLE', await post('/issues', issueBody(ctx, pid), { token: ctx.B.token }), 422, 'PHOTO_UNUSABLE');
  const body = issueBody(ctx, pid);
  const i1 = await post('/issues', body, { token: A });
  check('POST /issues → 201 reported in ward 18', i1.status === 201 && i1.data?.issue?.status === 'reported' && i1.data?.issue?.wardId === ctx.ward18.id, `${i1.status} ${i1.data?.issue?.status}`);
  ctx.I1 = i1.data?.issue?.id;
  const again = await post('/issues', body, { token: A });
  check('POST /issues same clientSubmissionId → 200 same issue (idempotent)', again.status === 200 && again.data?.issue?.id === ctx.I1, `${again.status}`);
  expect('POST /issues clientSubmissionId reused by another user → 409 IDEMPOTENCY_KEY_REUSED', await post('/issues', body, { token: ctx.B.token }), 409, 'IDEMPOTENCY_KEY_REUSED');
  const i2 = await post('/issues', issueBody(ctx, await photo(A)), { token: A });
  ctx.I2 = i2.data?.issue?.id;
  check('second issue by A → 201', i2.status === 201, `${i2.status}`);
  const near = await get(`/issues/nearby?lat=${PT18.lat}&lng=${PT18.lng}&category=${ctx.cat.slug}`);
  check('GET /issues/nearby → 200 includes the new issue', near.status === 200 && (near.data?.items ?? []).some((x) => x.id === ctx.I1), `${near.status} n=${near.data?.items?.length}`);
  expect('GET /issues/nearby missing category → 400 VALIDATION_FAILED', await get(`/issues/nearby?lat=${PT18.lat}&lng=${PT18.lng}`), 400, 'VALIDATION_FAILED');

  // Daily issue quota (QUOTA_ISSUES_PER_DAY, default 10) on citizen D.
  const limit = Number(env.QUOTA_ISSUES_PER_DAY || 10);
  let created = 0;
  ctx.dIssues = [];
  for (let i = 0; i < limit; i++) {
    const r = await post('/issues', issueBody(ctx, await photo(ctx.D.token)), { token: ctx.D.token });
    if (r.status === 201) {
      created += 1;
      ctx.dIssues.push(r.data.issue.id);
    }
  }
  check(`${limit} issues in a day accepted`, created === limit, `${created}/${limit}`);
  const over = await post('/issues', issueBody(ctx, await photo(ctx.D.token)), { token: ctx.D.token });
  expect(`issue ${limit + 1} in a day → 429 RATE_LIMITED`, over, 429, 'RATE_LIMITED');
  check('quota 429 names issues_per_day and sends Retry-After', over.data?.error?.details?.[0]?.issue === 'issues_per_day' && Boolean(over.headers.get('retry-after')));
}

export async function g6Lifecycle(ctx) {
  section('6 Issues — lifecycle');
  const ev = await get(`/issues/${ctx.I1}/events`);
  check('GET /issues/{id}/events → 200 with the reported event', ev.status === 200 && (ev.data?.items ?? []).length >= 1, `${ev.status}`);
  expect('GET /issues/{unknown}/events → 404 NOT_FOUND', await get(`/issues/${uuid()}/events`), 404, 'NOT_FOUND');
  const st = (to, expectedStatus, token) => post(`/issues/${ctx.I1}/status`, { to, expectedStatus, clientActionId: uuid() }, { token });
  expect('citizen (not reporter) changes status → 403 FORBIDDEN_ROLE', await st('acknowledged', 'reported', ctx.B.token), 403, 'FORBIDDEN_ROLE');
  expect('stale expectedStatus → 409 STALE_STATUS', await st('acknowledged', 'in_progress', ctx.MOD.token), 409, 'STALE_STATUS');
  const since = new Date().toISOString();
  const ack = await st('acknowledged', 'reported', ctx.MOD.token);
  check('moderator acknowledges → 200 acknowledged', ack.status === 200 && ack.data?.issue?.status === 'acknowledged', `${ack.status}`);
  const lines = await auditFor('issue_status_changed', ctx.I1, since);
  check('moderator status change → exactly one audit line (actor, role, target)', lines.length === 1 && lines[0].actorId === ctx.MOD.user?.id && lines[0].role === 'moderator', `lines=${lines.length}`);
  expect('disallowed transition (acknowledged → acknowledged) → 409 INVALID_TRANSITION', await st('acknowledged', 'acknowledged', ctx.MOD.token), 409, 'INVALID_TRANSITION');
  const fixed = await st('marked_fixed', 'acknowledged', ctx.MOD.token);
  check('moderator marks fixed → 200 marked_fixed', fixed.status === 200 && fixed.data?.issue?.status === 'marked_fixed', `${fixed.status} ${fixed.data?.error?.code ?? ''}`);

  const vb = async (token, extra = {}) => ({
    clientSubmissionId: uuid(), answer: 'fixed', photoId: await photo(token, 'verification', ctx.I1), latitude: ctx.I1spot?.latitude ?? PT18.lat,
    longitude: ctx.I1spot?.longitude ?? PT18.lng, gpsAccuracyM: 10, deviceCapturedAt: new Date().toISOString(), ...extra,
  });
  const B = ctx.B.token;
  expect('verify more than 100 m away → 422 TOO_FAR_FROM_ISSUE', await post(`/issues/${ctx.I1}/verifications`, await vb(B, { latitude: PT18.lat + 0.003 }), { token: B }), 422, 'TOO_FAR_FROM_ISSUE');
  expect('verify with 80 m accuracy → 422 LOCATION_TOO_INACCURATE', await post(`/issues/${ctx.I1}/verifications`, await vb(B, { gpsAccuracyM: 80 }), { token: B }), 422, 'LOCATION_TOO_INACCURATE');
  expect('representative verifies → 403 FORBIDDEN_ROLE', await post(`/issues/${ctx.I1}/verifications`, { ...(await vb(B)) }, { token: ctx.REP.token }), 403, 'FORBIDDEN_ROLE');
  const v = await post(`/issues/${ctx.I1}/verifications`, await vb(B), { token: B });
  check('neighbour verifies within 100 m → 201', v.status === 201, `${v.status} ${v.data?.error?.code ?? ''}`);
  const own = await post(`/issues/${ctx.I1}/verifications`, await vb(ctx.A.token), { token: ctx.A.token });
  check('reporter may answer on own issue (TASK-06 §5.6: reporter\'s answer counts) → 201', own.status === 201, `${own.status} ${own.data?.error?.code ?? ''}`);
  const v2 = await post(`/issues/${ctx.I1}/verifications`, await vb(B), { token: B });
  check('second answer the same day → 409 (ALREADY_ANSWERED_TODAY or VERIFY_NOT_OPEN)', v2.status === 409 && ['ALREADY_ANSWERED_TODAY', 'VERIFY_NOT_OPEN'].includes(v2.data?.error?.code), `${v2.status} ${v2.data?.error?.code}`);
  if (v2.status === 409) ctx.seenLater = [...(ctx.seenLater ?? []), [v2.data?.error?.code, 'sweep: second verification answer']];

  const esc = await post(`/issues/${ctx.I2}/escalations`, { level: 'corporators', language: 'en' }, { token: ctx.A.token });
  check('POST /issues/{id}/escalations by reporter (follower) → 200 prepared message', esc.status === 200, `${esc.status} ${esc.data?.error?.code ?? ''}`);
  expect('escalation by a non-follower → 403 FORBIDDEN', await post(`/issues/${ctx.I2}/escalations`, { level: 'corporators', language: 'en' }, { token: B }), 403, 'FORBIDDEN');
  expect('POST /issues/{id}/ccrs/closed before linking → 409 CCRS_NOT_LINKED', await post(`/issues/${ctx.I2}/ccrs/closed`, {}, { token: ctx.A.token }), 409, 'CCRS_NOT_LINKED');
  const link = await post(`/issues/${ctx.I2}/ccrs`, { ccrsNumber: 'SWEEP-0001', filedVia: 'web' }, { token: ctx.A.token });
  check('POST /issues/{id}/ccrs link → 200', link.status === 200, `${link.status} ${link.data?.error?.code ?? ''}`);
  expect('link a different CCRS number → 409 CCRS_ALREADY_LINKED', await post(`/issues/${ctx.I2}/ccrs`, { ccrsNumber: 'SWEEP-0002', filedVia: 'web' }, { token: ctx.A.token }), 409, 'CCRS_ALREADY_LINKED');
}
