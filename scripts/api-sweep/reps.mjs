// Groups 9 (representatives, relay, claims) and 10 (services, initiatives) (TASK-14 §5.3).
import { auditFor } from './auth.mjs';
import { check, del, expect, get, patch, post, section, uuid } from './lib.mjs';
import { photo } from './issues.mjs';

const REP18 = (n) => `00000009-0018-4000-8000-00000000000${n}`; // seeded sample corporators 18-A … 18-D

export async function g9Representatives(ctx) {
  section('9 Representatives');
  const w = await get(`/wards/${ctx.ward18.id}/representatives`);
  check('GET /wards/{id}/representatives → 200 corporators', w.status === 200 && (w.data?.corporators ?? []).length >= 1, `${w.status}`);
  check('directory exposes no user_id / claimant data', !/userId|user_id|claim/i.test(w.text));
  const r = await get(`/representatives/${REP18(1)}`);
  check('GET /representatives/{id} → 200 verified profile', r.status === 200 && r.data?.verified === true, `${r.status}`);
  check('profile exposes only public contact fields', !/userId|user_id|phoneE164/i.test(r.text));
  expect('GET /representatives/{unknown} → 404 NOT_FOUND', await get(`/representatives/${uuid()}`), 404, 'NOT_FOUND');
  const sc = await get(`/wards/${ctx.ward18.id}/scorecard`);
  check('GET /wards/{id}/scorecard → 200', sc.status === 200, `${sc.status}`);

  const msg = (extra = {}) => ({ clientMessageId: uuid(), subject: 'Sweep test message', body: 'Fictional sweep test message about a pothole.', ...extra });
  const url = `/representatives/${REP18(2)}/messages`;
  expect('relay without token → 401 AUTH_REQUIRED', await post(url, msg()), 401, 'AUTH_REQUIRED');
  expect('relay without the share consent → 403 CONSENT_REQUIRED', await post(url, msg(), { token: ctx.C.token }), 403, 'CONSENT_REQUIRED');
  const first = msg();
  const sent = [await post(url, first, { token: ctx.A.token })];
  check('POST /representatives/{id}/messages → 202 queued', sent[0].status === 202, `${sent[0].status} ${sent[0].data?.error?.code ?? ''}`);
  ctx.messageId = sent[0].data?.messageId;
  const replay = await post(url, first, { token: ctx.A.token });
  check('same clientMessageId → 200 idempotent', replay.status === 200 && replay.data?.messageId === ctx.messageId, `${replay.status}`);
  for (let i = 0; i < 4; i++) sent.push(await post(url, msg(), { token: ctx.A.token }));
  check('5 messages to one representative in a day accepted', sent.every((s) => s.status === 202), sent.map((s) => s.status).join(','));
  const sixth = await post(url, msg(), { token: ctx.A.token });
  expect('6th message to the same representative → 429 RATE_LIMITED', sixth, 429, 'RATE_LIMITED');
  check('relay 429 sends Retry-After', Boolean(sixth.headers.get('retry-after')));
  await post('/me/consents', { purpose: 'share_with_representatives', granted: true, textVersion: 'v2-1' }, { token: ctx.B.token });
  expect('profanity in a relay message → 422 MESSAGE_LANGUAGE', await post(url, msg({ body: 'This is a fucking disgrace, fix the road.' }), { token: ctx.B.token }), 422, 'MESSAGE_LANGUAGE');

  // Claims (TASK-11): B claims; evidence is a private rep_evidence photo.
  const ev = await photo(ctx.B.token, 'rep_evidence');
  ctx.evidencePhotoId = ev;
  expect('claim a verified profile → 409 REPRESENTATIVE_ALREADY_VERIFIED', await post(`/representatives/${REP18(1)}/claims`, { evidencePhotoIds: [ev] }, { token: ctx.B.token }), 409, 'REPRESENTATIVE_ALREADY_VERIFIED');
  const c = await post(`/representatives/${REP18(2)}/claims`, { evidencePhotoIds: [ev], note: 'Sweep claim (fictional).' }, { token: ctx.B.token });
  check('POST /representatives/{id}/claims → 201 pending', c.status === 201 && c.data?.status === 'pending', `${c.status} ${c.data?.error?.code ?? ''}`);
  ctx.claimId = c.data?.claimId;
  expect('second claim while one is pending → 409 CLAIM_ALREADY_PENDING', await post(`/representatives/${REP18(3)}/claims`, { evidencePhotoIds: [await photo(ctx.B.token, 'rep_evidence')] }, { token: ctx.B.token }), 409, 'CLAIM_ALREADY_PENDING');
  const mine = await get('/me/rep-claims', { token: ctx.B.token });
  check('GET /me/rep-claims → 200 with the claim', mine.status === 200 && mine.text.includes(ctx.claimId ?? 'none'), `${mine.status}`);
}

export async function g10Services(ctx) {
  section('10 Services & initiatives');
  const s = await get('/services');
  const items = s.data?.items ?? [];
  check('GET /services → 200 list', s.status === 200 && items.length >= 1, `${s.status} n=${items.length}`);
  const slug = items[0]?.slug;
  const one = await get(`/services/${slug}`);
  check('GET /services/{slug} → 200', one.status === 200 && one.data?.slug === slug, `${one.status}`);
  expect('GET /services/{unknown slug} → 404 NOT_FOUND', await get('/services/zz-sweep-none'), 404, 'NOT_FOUND');
  const list = await get(`/initiatives?ward=${ctx.ward18.id}`);
  check('GET /initiatives → 200', list.status === 200 && Array.isArray(list.data?.items), `${list.status}`);

  // Admin (v1 email login) creates a published drive with capacity 1 (TASK-12 staff API).
  const starts = new Date(Date.now() + 3 * 86_400_000);
  const since = new Date().toISOString();
  const created = await post('/staff/initiatives', {
    titleEn: 'Sweep test drive', titleGu: 'સ્વીપ ટેસ્ટ', descriptionEn: 'Fictional sweep drive.', descriptionGu: 'કાલ્પનિક.', type: 'cleanup',
    organiser: 'Saarthee', organiserName: 'Sweep', wardId: ctx.ward18.id, locationTextEn: 'Ward office', locationTextGu: 'વોર્ડ ઓફિસ',
    startsAt: starts.toISOString(), endsAt: new Date(starts.getTime() + 7_200_000).toISOString(), capacity: 1, status: 'published',
  }, { token: ctx.ADMIN.token });
  check('admin (v1 login) POST /staff/initiatives → 201', created.status === 201, `${created.status} ${created.data?.error?.code ?? ''}`);
  ctx.initiativeId = created.data?.id;
  if (!ctx.initiativeId) return;
  const lines = await auditFor('initiative.created', ctx.initiativeId, since);
  check('initiative.created → one audit line (actor, role admin, target)', lines.length === 1 && lines[0].actorId && lines[0].role === 'admin', `lines=${lines.length}`);
  expect('GET /initiatives/{unknown} → 404 NOT_FOUND', await get(`/initiatives/${uuid()}`), 404, 'NOT_FOUND');
  const rs = await post(`/initiatives/${ctx.initiativeId}/rsvp`, undefined, { token: ctx.A.token });
  check('POST /initiatives/{id}/rsvp → 2xx going', rs.status === 200 || rs.status === 201, `${rs.status} ${rs.data?.error?.code ?? ''}`);
  expect('RSVP to a full drive → 409 INITIATIVE_FULL', await post(`/initiatives/${ctx.initiativeId}/rsvp`, undefined, { token: ctx.B.token }), 409, 'INITIATIVE_FULL');
  expect('RSVP without token → 401 AUTH_REQUIRED', await post(`/initiatives/${ctx.initiativeId}/rsvp`), 401, 'AUTH_REQUIRED');
  const un = await del(`/initiatives/${ctx.initiativeId}/rsvp`, undefined, { token: ctx.A.token });
  check('DELETE /initiatives/{id}/rsvp → 2xx', un.status === 200 || un.status === 204, `${un.status}`);
  expect('admin marks attendance before start → 409 INITIATIVE_NOT_STARTED', await post(`/staff/initiatives/${ctx.initiativeId}/attendance`, { userIds: [ctx.A.user.id], attended: true }, { token: ctx.ADMIN.token }), 409, 'INITIATIVE_NOT_STARTED');
  const cancel = await patch(`/staff/initiatives/${ctx.initiativeId}`, { status: 'cancelled' }, { token: ctx.ADMIN.token });
  check('admin cancels the sweep drive → 200', cancel.status === 200, `${cancel.status}`);
  expect('cancelled → published → 409 INVALID_TRANSITION', await patch(`/staff/initiatives/${ctx.initiativeId}`, { status: 'published' }, { token: ctx.ADMIN.token }), 409, 'INVALID_TRANSITION');
  expect('RSVP to a cancelled drive → 409 INITIATIVE_NOT_OPEN', await post(`/initiatives/${ctx.initiativeId}/rsvp`, undefined, { token: ctx.B.token }), 409, 'INITIATIVE_NOT_OPEN');
}
