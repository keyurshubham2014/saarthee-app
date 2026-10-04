// Group 11 (staff) part 2: ward dashboard + representative scope, rep messages, users, categories, settings,
// exports, roster and services CRUD (TASK-14 §5.3 row 11, §5.5).
import { signIn } from './auth.mjs';
import { PHONES } from './accounts.mjs';
import { check, del, expect, get, patch, post, put, section, uuid } from './lib.mjs';
import { issueBody, photo } from './issues.mjs';
import { PT15 } from './public.mjs';
import { audited } from './staff1.mjs';

export async function g11Ward(ctx) {
  section('11 Staff — ward dashboard and representative scope');
  const { REP, MOD } = ctx;
  const scope = await get('/staff/ward/scope', { token: REP.token });
  const wardIds = (scope.data?.items ?? scope.data?.wards ?? []).map((w) => w.id ?? w.wardId);
  check('representative GET /staff/ward/scope → 200, only ward 18', scope.status === 200 && wardIds.length === 1 && wardIds[0] === ctx.ward18.id, `${scope.status} n=${wardIds.length}`);
  const dash = await get(`/staff/ward-dashboard?ward=${ctx.ward18.id}`, { token: REP.token });
  check('representative GET /staff/ward-dashboard own ward → 200', dash.status === 200, `${dash.status}`);
  expect('representative dashboard for another ward → 403 WARD_OUT_OF_SCOPE', await get(`/staff/ward-dashboard?ward=${ctx.ward15.id}`, { token: REP.token }), 403, 'WARD_OUT_OF_SCOPE');
  const today = new Date().toISOString().slice(0, 10);
  const from = new Date(Date.now() - 30 * 86_400_000).toISOString().slice(0, 10);
  const csv = await get(`/staff/ward-dashboard/export?ward=${ctx.ward18.id}&from=${from}&to=${today}`, { token: REP.token });
  check('ward dashboard export → 200 CSV without phone digits', csv.status === 200 && !/9000000\d{3}|\+91\d{10}/.test(csv.text), `${csv.status}`);
  const list = await get(`/staff/ward/issues?ward=${ctx.ward18.id}`, { token: REP.token });
  check('representative GET /staff/ward/issues own ward → 200', list.status === 200, `${list.status}`);
  const mdash = await get(`/staff/ward-dashboard?ward=${ctx.ward15.id}`, { token: MOD.token });
  check('moderator dashboard for any ward → 200', mdash.status === 200, `${mdash.status}`);
  await audited('representative comments on an own-ward issue → 201', 'rep_issue_comment', ctx.I2, 'representative', () => post(`/staff/issues/${ctx.I2}/comments`, { note: 'sweep comment note text' }, { token: REP.token }));
  // An issue in ward 15 (outside the representative's scope).
  const i15 = await post('/issues', issueBody(ctx, await photo(ctx.A.token), { latitude: PT15.lat, longitude: PT15.lng }), { token: ctx.A.token });
  ctx.I15 = i15.data?.issue?.id;
  check('issue in ward 15 created for scope checks', i15.status === 201, `${i15.status}`);
  expect('representative comments outside own wards → 403 WARD_OUT_OF_SCOPE', await post(`/staff/issues/${ctx.I15}/comments`, { note: 'x' }, { token: REP.token }), 403, 'WARD_OUT_OF_SCOPE');
  expect('representative status change outside own wards → 403 WARD_OUT_OF_SCOPE', await post(`/issues/${ctx.I15}/status`, { to: 'acknowledged', expectedStatus: 'reported', clientActionId: uuid() }, { token: REP.token }), 403, 'WARD_OUT_OF_SCOPE');
  const cur = (await get(`/issues/${ctx.I2}`)).data?.issue?.status;
  await audited(`representative acknowledges an own-ward issue (${cur}) → 200`, 'rep_issue_status', ctx.I2, 'representative', () => post(`/issues/${ctx.I2}/status`, { to: 'acknowledged', expectedStatus: cur, clientActionId: uuid() }, { token: REP.token }));
}

export async function g11Messages(ctx) {
  section('11 Staff — representative messages');
  const { REP, B } = ctx;
  const sent = await post('/representatives/00000009-0018-4000-8000-000000000001/messages', { clientMessageId: uuid(), subject: 'Sweep to verified rep', body: 'Fictional sweep message body for reply test.' }, { token: B.token });
  check('citizen messages the verified representative → 202', sent.status === 202, `${sent.status} ${sent.data?.error?.code ?? ''}`);
  const id = sent.data?.messageId;
  const inbox = await get('/staff/rep-messages', { token: REP.token });
  check('representative GET /staff/rep-messages → 200 with the message', inbox.status === 200 && inbox.text.includes(id ?? 'none'), `${inbox.status}`);
  check('rep inbox shows no citizen phone (no opt-in)', !inbox.text.includes(PHONES.B.slice(3)));
  expect('moderator GET /staff/rep-messages → 403 FORBIDDEN', await get('/staff/rep-messages', { token: ctx.MOD.token }), 403, 'FORBIDDEN');
  if (!id) return;
  await audited('representative replies → 200', 'rep_message_replied', id, 'representative', () => post(`/staff/rep-messages/${id}/reply`, { body: 'sweep reply body text' }, { token: REP.token }));
  expect('second reply → 409 ALREADY_REPLIED', await post(`/staff/rep-messages/${id}/reply`, { body: 'again' }, { token: REP.token }), 409, 'ALREADY_REPLIED');
  const mine = await get('/me/messages', { token: B.token });
  check('citizen GET /me/messages → 200 sees the reply', mine.status === 200 && mine.text.includes('sweep reply body text'), `${mine.status}`);
  expect('webhook without signature → 401 BAD_SIGNATURE', await post('/webhooks/mail-inbound', { to: 'x@reply.saarthee.local', text: 'x' }), 401, 'BAD_SIGNATURE');
}

export async function g11Users(ctx) {
  section('11 Staff — users and roles');
  const { MOD, ADMIN, C } = ctx;
  const cid = C.user?.id;
  expect('moderator changes a role → 403 FORBIDDEN', await post(`/staff/users/${cid}/role`, { role: 'moderator' }, { token: MOD.token }), 403, 'FORBIDDEN');
  const users = await get('/staff/users', { token: ADMIN.token });
  check('admin GET /staff/users → 200 with masked phones only', users.status === 200 && !/\+91\d{10}/.test(users.text), `${users.status}`);
  await audited('admin makes citizen C a moderator → 200', 'role_changed', cid, 'admin', () => post(`/staff/users/${cid}/role`, { role: 'moderator' }, { token: ADMIN.token }));
  await audited('admin returns C to citizen → 200', 'role_changed', cid, 'admin', () => post(`/staff/users/${cid}/role`, { role: 'citizen' }, { token: ADMIN.token }));
  expect('admin changes a representative\'s role → 422 ROLE_CHANGE_INVALID', await post(`/staff/users/${ctx.REP.user.id}/role`, { role: 'citizen' }, { token: ADMIN.token }), 422, 'ROLE_CHANGE_INVALID');
  const c2 = await signIn(PHONES.C);
  ctx.C = c2;
  await audited('moderator suspends C → 200', 'user_suspended', cid, 'moderator', () => post(`/staff/users/${cid}/suspend`, { reason: 'sweep suspend reason text' }, { token: MOD.token }));
  const sus = await get('/me', { token: c2.token });
  check('suspended user\'s session refused (§5.5: 401/403)', (sus.status === 401 && sus.data?.error?.code === 'TOKEN_REVOKED') || (sus.status === 403 && sus.data?.error?.code === 'ACCOUNT_SUSPENDED'), `${sus.status} ${sus.data?.error?.code}`);
  const again = await signIn(PHONES.C);
  expect('suspended user signs in → 403 ACCOUNT_SUSPENDED', again.res, 403, 'ACCOUNT_SUSPENDED');
  expect('suspend again → 409 USER_STATE_INVALID', await post(`/staff/users/${cid}/suspend`, { reason: 'x' }, { token: MOD.token }), 409, 'USER_STATE_INVALID');
  expect('moderator suspends self → 409 SELF_SUSPEND', await post(`/staff/users/${MOD.user.id}/suspend`, { reason: 'x' }, { token: MOD.token }), 409, 'SELF_SUSPEND');
  await audited('moderator unsuspends C → 200', 'user_unsuspended', cid, 'moderator', () => post(`/staff/users/${cid}/unsuspend`, { reason: 'sweep unsuspend reason' }, { token: MOD.token }));
  expect('deleted user on a staff endpoint → 401 TOKEN_REVOKED', await get('/staff/me', { token: ctx.deletedToken }), 401, 'TOKEN_REVOKED');
  for (const [k, role] of [['MOD', 'moderator'], ['REP', 'representative'], ['ADMIN', 'admin']]) {
    const me = await get('/staff/me', { token: ctx[k].token });
    check(`${role} GET /staff/me → 200 role ${role}`, me.status === 200 && me.data?.role === role, `${me.status} ${me.data?.role}`);
  }
  expect('citizen GET /staff/me → 403 FORBIDDEN', await get('/staff/me', { token: ctx.B.token }), 403, 'FORBIDDEN');
}

export async function g11Config(ctx) {
  section('11 Staff — categories, settings, election mode, exports');
  const { MOD, ADMIN } = ctx;
  const cats = await get('/staff/categories', { token: MOD.token });
  check('moderator GET /staff/categories → 200', cats.status === 200, `${cats.status}`);
  const cat = (cats.data?.items ?? []).find((c) => c.slug === ctx.cat.slug);
  expect('moderator PATCH /staff/categories → 403 FORBIDDEN', await patch(`/staff/categories/${cat?.id}`, { sortOrder: cat?.sortOrder }, { token: MOD.token }), 403, 'FORBIDDEN');
  await audited('admin PATCH /staff/categories/{id} (same sort order) → 200', 'category_updated', cat?.id, 'admin', () => patch(`/staff/categories/${cat?.id}`, { sortOrder: cat?.sortOrder }, { token: ADMIN.token }));
  const s = await get('/staff/settings', { token: MOD.token });
  check('moderator GET /staff/settings → 200', s.status === 200, `${s.status}`);
  expect('admin PUT /staff/settings/{unknown} → 400 SETTING_UNKNOWN', await put('/staff/settings/zz_sweep', { value: 1 }, { token: ADMIN.token }), 400, 'SETTING_UNKNOWN');
  const em = await get('/staff/settings/election-mode', { token: ADMIN.token });
  check('admin (v1 login) GET /staff/settings/election-mode → 200', em.status === 200, `${em.status} ${em.data?.error?.code ?? ''}`);
  const emMod = await get('/staff/settings/election-mode', { token: MOD.token });
  check('moderator GET /staff/settings/election-mode → 200', emMod.status === 200, `${emMod.status}`);
  const current = emMod.data;
  expect('moderator PUT election mode → 403 FORBIDDEN', await put('/staff/settings/election-mode', current, { token: MOD.token }), 403, 'FORBIDDEN');
  if (em.status === 200) await audited('admin PUT election mode (unchanged value) → 200', 'election_mode_set', 'election_mode', 'admin', () => put('/staff/settings/election-mode', current, { token: ADMIN.token }));
  const today = new Date().toISOString().slice(0, 10);
  expect('moderator GET /staff/export → 403 FORBIDDEN', await get(`/staff/export?dataset=issues&from=${today}&to=${today}`, { token: MOD.token }), 403, 'FORBIDDEN');
  const ex = await get(`/staff/export?dataset=issues&from=${today}&to=${today}&ward=${ctx.ward18.id}`, { token: ADMIN.token });
  check('admin GET /staff/export → 200 CSV without phone', ex.status === 200 && !/\+?91?9000000\d{3}/.test(ex.text), `${ex.status}`);
}
