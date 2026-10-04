// Groups 7 (discovery) and 8 (alerts — public/citizen side) (TASK-14 §5.3).
import { check, del, expect, get, post, put, section, uuid } from './lib.mjs';
import { PT18 } from './public.mjs';

const BBOX18 = `${(PT18.lng - 0.02).toFixed(4)},${(PT18.lat - 0.02).toFixed(4)},${(PT18.lng + 0.02).toFixed(4)},${(PT18.lat + 0.02).toFixed(4)}`;

export async function g7Discovery(ctx) {
  section('7 Discovery');
  const list = await get(`/issues?ward=${ctx.ward18.id}&limit=50`);
  check('GET /issues?ward → 200 list', list.status === 200 && Array.isArray(list.data?.items), `${list.status} n=${list.data?.items?.length}`);
  check('public list carries no reporterId / phone', !list.text.includes('reporterId') && !list.text.includes('9000000080'));
  expect('GET /issues bad cursor → 400 VALIDATION_FAILED', await get(`/issues?ward=${ctx.ward18.id}&cursor=not-a-cursor`), 400, 'VALIDATION_FAILED');
  expect('GET /issues bad status filter → 400 VALIDATION_FAILED', await get('/issues?status=nope'), 400, 'VALIDATION_FAILED');
  const d = await get(`/issues/${ctx.I2}`);
  check('GET /issues/{id} → 200 detail without reporter identity', d.status === 200 && d.data?.issue?.id === ctx.I2 && !d.text.includes('reporterId') && !d.text.includes('Sweep A'), `${d.status}`);
  expect('GET /issues/{unknown} → 404 NOT_FOUND', await get(`/issues/${uuid()}`), 404, 'NOT_FOUND');
  const B = ctx.B.token;
  const m1 = await post(`/issues/${ctx.I2}/me-too`, undefined, { token: B });
  check('POST /issues/{id}/me-too → 201', m1.status === 201 && m1.data?.meTooCount >= 1, `${m1.status}`);
  const m2 = await post(`/issues/${ctx.I2}/me-too`, undefined, { token: B });
  check('duplicate me-too → 200 idempotent, count unchanged', m2.status === 200 && m2.data?.meTooCount === m1.data?.meTooCount, `${m2.status}`);
  expect('me-too on own issue → 409 OWN_ISSUE', await post(`/issues/${ctx.I2}/me-too`, undefined, { token: ctx.A.token }), 409, 'OWN_ISSUE');
  const m3 = await del(`/issues/${ctx.I2}/me-too`, undefined, { token: B });
  check('DELETE /issues/{id}/me-too → 200', m3.status === 200, `${m3.status}`);
  const f1 = await post(`/issues/${ctx.I2}/follow`, undefined, { token: B });
  check('POST /issues/{id}/follow → 200 following', f1.status === 200 && f1.data?.isFollowing === true, `${f1.status}`);
  const f2 = await del(`/issues/${ctx.I2}/follow`, undefined, { token: B });
  check('DELETE /issues/{id}/follow → 200 not following', f2.status === 200 && f2.data?.isFollowing === false, `${f2.status}`);
  const feed = await get(`/feed?ward=${ctx.ward18.id}`);
  check('GET /feed?ward → 200', feed.status === 200, `${feed.status}`);
  expect('GET /feed without ward (visitor) → 400 WARD_REQUIRED', await get('/feed'), 400, 'WARD_REQUIRED');
  const map = await get(`/map/issues?bbox=${BBOX18}&zoom=16`);
  check('GET /map/issues → 200', map.status === 200, `${map.status}`);
  expect('GET /map/issues bbox too large → 400 VALIDATION_FAILED', await get('/map/issues?bbox=72,22,73,23.5&zoom=10'), 400, 'VALIDATION_FAILED');
  const fl = await post(`/issues/${ctx.I2}/flags`, { reason: 'spam' }, { token: B });
  check('POST /issues/{id}/flags → 201', fl.status === 201, `${fl.status} ${fl.data?.error?.code ?? ''}`);
  ctx.flagId = fl.data?.id ?? fl.data?.flagId;
  expect('POST /issues/{id}/flags bad reason → 400 VALIDATION_FAILED', await post(`/issues/${ctx.I2}/flags`, { reason: 'meh' }, { token: B }), 400, 'VALIDATION_FAILED');
}

export async function g8Alerts(ctx) {
  section('8 Alerts');
  const a = await get(`/alerts?wards=${ctx.ward18.id}`);
  check('GET /alerts?wards → 200 list', a.status === 200 && Array.isArray(a.data?.items), `${a.status}`);
  check('every alert item has source and validity', (a.data?.items ?? []).every((x) => x.sourceName && x.sourceUrl && x.validFrom && x.validTo));
  expect('GET /alerts without wards → 400 VALIDATION_FAILED', await get('/alerts'), 400, 'VALIDATION_FAILED');
  expect('GET /alerts/{unknown} → 404 NOT_FOUND', await get(`/alerts/${uuid()}`), 404, 'NOT_FOUND');
  const A = ctx.A.token;
  const s = await get('/me/subscriptions', { token: A });
  check('GET /me/subscriptions → 200', s.status === 200, `${s.status}`);
  const sp = await put('/me/subscriptions', { extraWardIds: [ctx.ward15.id], mutedTypes: ['heat'], criticalOnly: false }, { token: A });
  check('PUT /me/subscriptions → 200', sp.status === 200, `${sp.status} ${sp.data?.error?.code ?? ''}`);
  expect('PUT /me/subscriptions duplicate wards → 400 VALIDATION_FAILED', await put('/me/subscriptions', { extraWardIds: [ctx.ward15.id, ctx.ward15.id], mutedTypes: [], criticalOnly: false }, { token: A }), 400, 'VALIDATION_FAILED');
  expect('GET /me/subscriptions without token → 401 AUTH_REQUIRED', await get('/me/subscriptions'), 401, 'AUTH_REQUIRED');
  expect('signed-in user on the device subscriptions endpoint → 409 SIGNED_IN_USE_ME', await get(`/devices/${uuid()}/subscriptions`, { token: A }), 409, 'SIGNED_IN_USE_ME');
  const n = await get('/me/notifications', { token: A });
  check('GET /me/notifications → 200', n.status === 200 && Array.isArray(n.data?.items), `${n.status}`);
  const r = await post('/me/notifications/read', { all: true }, { token: A });
  check('POST /me/notifications/read all → 200 unreadCount 0', r.status === 200 && r.data?.unreadCount === 0, `${r.status}`);
  expect('GET /me/notifications without token → 401 AUTH_REQUIRED', await get('/me/notifications'), 401, 'AUTH_REQUIRED');
}
