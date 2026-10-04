// Group 11 (staff) part 3: roster and services CRUD with the v1 admin login (TASK-09/12 staff APIs).
import { auditFor, db } from './auth.mjs';
import { check, del, expect, get, patch, post, section } from './lib.mjs';
import { audited } from './staff1.mjs';

export async function g11Roster(ctx) {
  section('11 Staff — representatives roster');
  const { MOD, ADMIN } = ctx;
  const lm = await get('/staff/representatives?ward=18', { token: MOD.token });
  check('moderator GET /staff/representatives → 200', lm.status === 200, `${lm.status}`);
  const la = await get('/staff/representatives?ward=18', { token: ADMIN.token });
  check('admin (v1 login) GET /staff/representatives → 200', la.status === 200, `${la.status} ${la.data?.error?.code ?? ''}`);
  const today = new Date().toISOString().slice(0, 10);
  // Every ward already has its 4 corporators and the dev constituencies are fictional (901+, outside the 1–400 roster
  // rule), so the sweep frees a seat: it deactivates sample corporator 18-D and restores it right after (DB).
  const SEAT = '00000009-0018-4000-8000-000000000004';
  const rep = { nameEn: 'Sweep Test Corporator', nameGu: 'સ્વીપ ટેસ્ટ', role: 'corporator', termStart: '2021-03-01', wardNumber: 18, sourceUrl: 'https://saarthee.in/sweep', lastVerifiedAt: today };
  expect('moderator POST /staff/representatives → 403 FORBIDDEN', await post('/staff/representatives', rep, { token: MOD.token }), 403, 'FORBIDDEN');
  expect('roster entry with a mobile number → 400 REP_PERSONAL_NUMBER', await post('/staff/representatives', { ...rep, officePhone: '+919000000090' }, { token: ADMIN.token }), 400, 'REP_PERSONAL_NUMBER');
  const full = await post('/staff/representatives', rep, { token: ADMIN.token });
  check('fifth active corporator in a ward → 400 VALIDATION_FAILED (seat cap)', full.status === 400 && full.data?.error?.code === 'VALIDATION_FAILED', `${full.status}`);
  ctx.restoreSeat = SEAT;
  await audited('admin DELETE /staff/representatives/{sample 18-D} → 200 deactivated', 'rep_deactivated', SEAT, 'admin', () => del(`/staff/representatives/${SEAT}`, undefined, { token: ADMIN.token }));
  try {
    const created = await post('/staff/representatives', rep, { token: ADMIN.token });
    const id = created.data?.id;
    check('admin POST /staff/representatives → 201', created.status === 201 && Boolean(id), `${created.status} ${created.data?.error?.code ?? ''}`);
    if (!id) return;
    ctx.sweepRepId = id;
    const cl = await auditFor('rep_created', id);
    check('  ↳ one audit line rep_created (actor, role admin, target)', cl.length === 1 && cl[0].role === 'admin' && Boolean(cl[0].actorId), `lines=${cl.length}`);
    await audited('admin PATCH /staff/representatives/{id} → 200', 'rep_updated', id, 'admin', () => patch(`/staff/representatives/${id}`, { partyText: 'Sweep Party' }, { token: ADMIN.token }));
    await audited('admin DELETE /staff/representatives/{id} → 200 deactivated', 'rep_deactivated', id, 'admin', () => del(`/staff/representatives/${id}`, undefined, { token: ADMIN.token }));
    expect('same name, role and term again → 409 REP_DUPLICATE', await post('/staff/representatives', rep, { token: ADMIN.token }), 409, 'REP_DUPLICATE');
  } finally {
    await db().representative.update({ where: { id: SEAT }, data: { isActive: true } });
    check('sample corporator 18-D restored (active)', (await db().representative.findUnique({ where: { id: SEAT } }))?.isActive === true);
  }
}

export async function g11Services(ctx) {
  section('11 Staff — services');
  const { MOD, ADMIN } = ctx;
  const ms = await get('/staff/services', { token: MOD.token });
  check('moderator GET /staff/services → 200 (read-only access)', ms.status === 200, `${ms.status}`);
  const l = await get('/staff/services', { token: ADMIN.token });
  check('admin (v1 login) GET /staff/services → 200', l.status === 200, `${l.status} ${l.data?.error?.code ?? ''}`);
  const svc = {
    slug: 'zz-sweep-test-service', category: l.data?.items?.[0]?.category ?? 'certificates', nameEn: 'Sweep test service', nameGu: 'સ્વીપ સેવા',
    department: 'Sweep', departmentGu: 'સ્વીપ', summaryEn: 'Fictional sweep service.', summaryGu: 'કાલ્પનિક.', howToEn: '1. Do nothing', howToGu: '1. કંઈ નહીં',
    url: 'https://saarthee.in/sweep', online: true, isActive: false,
  };
  expect('moderator POST /staff/services → 403 FORBIDDEN', await post('/staff/services', svc, { token: MOD.token }), 403, 'FORBIDDEN');
  const c = await post('/staff/services', svc, { token: ADMIN.token });
  const id = c.data?.id;
  check('admin POST /staff/services → 201', c.status === 201 && Boolean(id), `${c.status} ${c.data?.error?.code ?? ''}`);
  if (!id) return;
  ctx.sweepServiceId = id;
  expect('same slug again → 409 SLUG_TAKEN', await post('/staff/services', svc, { token: ADMIN.token }), 409, 'SLUG_TAKEN');
  await audited('admin PATCH /staff/services/{id} → 200', 'service.updated', id, 'admin', () => patch(`/staff/services/${id}`, { sortOrder: 999 }, { token: ADMIN.token }));
  await audited('admin DELETE /staff/services/{id} → 200 deactivated', 'service.deactivated', id, 'admin', () => del(`/staff/services/${id}`, undefined, { token: ADMIN.token }));
}
