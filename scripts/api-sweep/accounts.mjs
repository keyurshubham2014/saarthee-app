// Group 2 (auth & me) and the per-role accounts used by the rest of the sweep (TASK-14 §5.3 row 2, §5.5).
import { adminLogin, CONSENTS, db, emulatorDelete, emulatorIdToken, exchange, signIn } from './auth.mjs';
import { apiRequire, check, del, env, expect, get, installId, patch, post, section, uuid } from './lib.mjs';

/** Fictional test numbers (TASK-14 brief: +9190000000NN, NN 80–95). Never printed. */
export const PHONES = {
  A: '+919000000080',
  B: '+919000000081',
  E: '+919000000082',
  U18: '+919000000083',
  C: '+919000000084',
  D: '+919000000085',
  MOD: '+919000000025',
  REP: '+919000000027',
};
const SWEEP_CITIZENS = ['A', 'B', 'E', 'C', 'D'];

/** Leftovers from an aborted earlier run: active sweep citizens are deleted through the API first. */
export async function preClean() {
  const left = await db().user.findMany({ where: { phoneE164: { in: SWEEP_CITIZENS.map((k) => PHONES[k]) }, status: { not: 'deleted' } }, select: { phoneE164: true, status: true, id: true } });
  for (const u of left) {
    if (u.status === 'suspended') await db().user.update({ where: { id: u.id }, data: { status: 'active' } });
    const s = await signIn(u.phoneE164);
    if (s.token) await del('/me', { confirm: 'DELETE' }, { token: s.token });
  }
  if (left.length) console.log(`   (pre-clean: removed ${left.length} leftover sweep account(s))`);
}

function unsignedFirebaseToken(claims) {
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  return `${b64({ alg: 'none', typ: 'JWT' })}.${b64(claims)}.`;
}

export async function g2Auth(ctx) {
  section('2 Auth & me');
  const a = await signIn(PHONES.A, { homeWardId: ctx.ward18.id });
  check('POST /auth/firebase new citizen → 201 isNew', a.res.status === 201 && a.res.data?.isNew === true, `${a.res.status}`);
  check('sign-in response masks the phone', typeof a.user?.phoneMasked === 'string' && !a.res.text.includes(PHONES.A.slice(3)));
  ctx.A = a;
  const a2 = await signIn(PHONES.A);
  check('POST /auth/firebase returning citizen → 200 isNew false', a2.res.status === 200 && a2.res.data?.isNew === false, `${a2.res.status}`);
  ctx.A = { ...a2, user: a2.user };
  ctx.B = await signIn(PHONES.B, { homeWardId: ctx.ward18.id });
  ctx.C = await signIn(PHONES.C, { homeWardId: ctx.ward18.id });
  ctx.D = await signIn(PHONES.D, { homeWardId: ctx.ward18.id });
  ctx.MOD = await signIn(PHONES.MOD);
  ctx.REP = await signIn(PHONES.REP);
  check('test accounts signed in (A, B, C, D, moderator, representative)', [ctx.B, ctx.C, ctx.D, ctx.MOD, ctx.REP].every((s) => s.token));
  check('moderator account has role moderator', ctx.MOD.user?.role === 'moderator', ctx.MOD.user?.role);
  check('representative account has role representative', ctx.REP.user?.role === 'representative', ctx.REP.user?.role);
  ctx.ADMIN = await adminLogin();
  check('v1 admin email login → 200', ctx.ADMIN.res.status === 200 && Boolean(ctx.ADMIN.token), `${ctx.ADMIN.res.status}`);

  expect('POST /auth/firebase garbage token → 401 FIREBASE_TOKEN_INVALID', await exchange({ idToken: 'not-a-token', ageConfirmed: true, consents: CONSENTS, language: 'en' }), 401, 'FIREBASE_TOKEN_INVALID');
  const now = Math.floor(Date.now() / 1000);
  const expired = unsignedFirebaseToken({
    iss: `https://securetoken.google.com/${env.FIREBASE_PROJECT_ID || 'demo-saarthee'}`, aud: env.FIREBASE_PROJECT_ID || 'demo-saarthee',
    iat: now - 7200, exp: now - 3600, auth_time: now - 7200, sub: 'sweep-expired', user_id: 'sweep-expired',
    phone_number: '+919000000086', firebase: { sign_in_provider: 'phone', identities: { phone: ['+919000000086'] } },
  });
  expect('POST /auth/firebase expired Firebase token → 401 FIREBASE_TOKEN_INVALID', await exchange({ idToken: expired, ageConfirmed: true, consents: CONSENTS, language: 'en' }), 401, 'FIREBASE_TOKEN_INVALID');
  const u18 = await emulatorIdToken(PHONES.U18);
  expect('POST /auth/firebase without age confirmation → 403 AGE_CONFIRMATION_REQUIRED', await exchange({ idToken: u18.idToken, ageConfirmed: false, consents: CONSENTS, language: 'en' }), 403, 'AGE_CONFIRMATION_REQUIRED');
  expect('POST /auth/firebase without core consent → 422 CONSENT_REQUIRED', await exchange({ idToken: u18.idToken, ageConfirmed: true, consents: [], language: 'en' }), 422, 'CONSENT_REQUIRED');
  check('under-18 attempt created no account', !(await db().user.findFirst({ where: { phoneE164: PHONES.U18 } })));
  await emulatorDelete(u18.localId);

  const me = await get('/me', { token: ctx.A.token });
  check('GET /me → 200 own profile', me.status === 200 && me.data?.id === ctx.A.user?.id, `${me.status}`);
  expect('GET /me without token → 401 AUTH_REQUIRED', await get('/me'), 401, 'AUTH_REQUIRED');
  expect('GET /me malformed bearer → 401 TOKEN_REVOKED', await get('/me', { headers: { Authorization: 'Bearer !!' } }), 401, 'TOKEN_REVOKED');
  const jwt = apiRequire('jsonwebtoken');
  const stale = jwt.sign({ tv: 0, role: 'citizen', typ: 'user' }, env.JWT_SECRET, {
    algorithm: 'HS256', subject: ctx.A.user?.id, issuer: env.JWT_ISSUER, audience: env.USER_JWT_AUDIENCE || 'saarthee-app', expiresIn: -60,
  });
  expect('GET /me expired session token → 401 TOKEN_EXPIRED', await get('/me', { token: stale }), 401, 'TOKEN_EXPIRED');
  const p = await patch('/me', { displayName: 'Sweep A', homeWardId: ctx.ward18.id }, { token: ctx.A.token });
  check('PATCH /me → 200', p.status === 200 && p.data?.displayName === 'Sweep A', `${p.status}`);
  expect('PATCH /me empty body → 400 VALIDATION_FAILED', await patch('/me', {}, { token: ctx.A.token }), 400, 'VALIDATION_FAILED');
  expect('PATCH /me unknown ward → 422 WARD_NOT_FOUND', await patch('/me', { homeWardId: uuid() }, { token: ctx.A.token }), 422, 'WARD_NOT_FOUND');
  const c1 = await post('/me/consents', { purpose: 'share_with_representatives', granted: true, textVersion: 'v2-1' }, { token: ctx.A.token });
  check('POST /me/consents grant → 200', c1.status === 200, `${c1.status}`);
  expect('POST /me/consents withdraw core → 409 CORE_CONSENT_REQUIRED', await post('/me/consents', { purpose: 'core_service', granted: false, textVersion: 'v2-1' }, { token: ctx.A.token }), 409, 'CORE_CONSENT_REQUIRED');
  const dev = await post('/devices', { installId, platform: 'android', appVersion: '2.0.0', language: 'en' }, { token: ctx.A.token });
  check('POST /devices → 2xx', dev.status === 200 || dev.status === 201, `${dev.status}`);
  expect('POST /devices bad body → 400 VALIDATION_FAILED', await post('/devices', { installId: 'x' }), 400, 'VALIDATION_FAILED');
  const ex = await get('/me/export', { token: ctx.A.token });
  check('GET /me/export → 200 JSON with own profile only', ex.status === 200 && ex.text.includes(ctx.A.user?.id) && !ex.text.includes(ctx.B.user?.id ?? 'none'), `${ex.status}`);

  // Session revocation and erasure on a throwaway citizen E.
  const e = await signIn(PHONES.E);
  const lo = await post('/auth/logout', {}, { token: e.token });
  check('POST /auth/logout → 204', lo.status === 204, `${lo.status}`);
  expect('revoked session → 401 TOKEN_REVOKED', await get('/me', { token: e.token }), 401, 'TOKEN_REVOKED');
  const e2 = await signIn(PHONES.E);
  expect('DELETE /me without confirm → 400 VALIDATION_FAILED', await del('/me', {}, { token: e2.token }), 400, 'VALIDATION_FAILED');
  const d = await del('/me', { confirm: 'DELETE' }, { token: e2.token });
  check('DELETE /me → 204', d.status === 204, `${d.status}`);
  expect('deleted user → 401 TOKEN_REVOKED', await get('/me', { token: e2.token }), 401, 'TOKEN_REVOKED');
  ctx.deletedToken = e2.token;
}
