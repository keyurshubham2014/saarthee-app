// T-11-05 (AC-5): request-time term check, reps:expire effects and idempotency, token_version bump, revoke.
import { beforeEach, describe, expect, it } from 'vitest';
import { captureAudit } from '../../src/lib/audit';
import { prisma } from '../../src/lib/db';
import { runRepsExpire } from '../../src/modules/rep-claims/jobs';
import { resetDb } from '../helpers/db';
import { fixtureWards } from './helpers';
import { get, post, signed, verifiedRep } from './t11-helpers';

let ward1: string;
const yesterday = () => new Date(Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth(), new Date().getUTCDate()) - 2 * 86_400_000);

beforeEach(async () => {
  await resetDb();
  ward1 = (await fixtureWards()).get(1)!;
});

describe('expiry at term end (T-11-05)', () => {
  it('refuses at request time before the job; the job expires once; old token → TOKEN_REVOKED', async () => {
    const rep = await verifiedRep([ward1]);
    expect((await get(rep.auth, `/staff/ward-dashboard?ward=${ward1}`)).status).toBe(200);
    await prisma.representative.update({ where: { id: rep.rep.id }, data: { termStart: new Date('2020-01-01'), termEnd: yesterday() } });

    const before = await get(rep.auth, `/staff/ward-dashboard?ward=${ward1}`);
    expect([before.status, before.body.error.code]).toEqual([403, 'WARD_OUT_OF_SCOPE']);
    expect((await get(undefined, `/representatives/${rep.rep.id}`)).body.verification.status).toBe('expired');

    const audit = captureAudit();
    expect(await runRepsExpire()).toEqual({ expired: 1 });
    audit.stop();
    expect(audit.lines).toEqual([expect.objectContaining({ action: 'rep_verification_expired', targetId: rep.rep.id, actorKind: 'system' })]);
    expect(await prisma.representative.findUniqueOrThrow({ where: { id: rep.rep.id } })).toMatchObject({ userId: null, verifiedAt: null });
    expect(await prisma.repClaim.findFirstOrThrow({ where: { representativeId: rep.rep.id } })).toMatchObject({ status: 'expired' });
    const u = await prisma.user.findUniqueOrThrow({ where: { id: rep.user.id } });
    expect(u).toMatchObject({ role: 'citizen', tokenVersion: 1 });
    const after = await get(rep.auth, '/staff/me');
    expect([after.status, after.body.error.code]).toEqual([401, 'TOKEN_REVOKED']);
    expect((await get(undefined, `/representatives/${rep.rep.id}`)).body.verification.status).toBe('expired');

    expect(await runRepsExpire()).toEqual({ expired: 0 });
    expect((await prisma.user.findUniqueOrThrow({ where: { id: rep.user.id } })).tokenVersion).toBe(1);
  });

  it('a term ending today still counts; revoke has the same effect immediately and is audited', async () => {
    const ist = new Date(Date.now() + 330 * 60_000);
    const today = new Date(Date.UTC(ist.getUTCFullYear(), ist.getUTCMonth(), ist.getUTCDate()));
    const rep = await verifiedRep([ward1], { termEnd: today });
    expect(await runRepsExpire()).toEqual({ expired: 0 });
    const admin = await signed('admin');
    expect((await post(admin.auth, `/staff/representatives/${rep.rep.id}/revoke-verification`, { reason: 'x' })).status).toBe(400);
    const audit = captureAudit();
    const res = await post(admin.auth, `/staff/representatives/${rep.rep.id}/revoke-verification`, { reason: 'Wrong person' });
    audit.stop();
    expect(res.status).toBe(200);
    expect(audit.lines).toEqual([expect.objectContaining({ action: 'rep_verification_revoked', targetType: 'representative', targetId: rep.rep.id })]);
    expect(JSON.stringify(audit.lines)).not.toContain('Wrong person');
    expect(await prisma.repClaim.findFirstOrThrow({ where: { representativeId: rep.rep.id } })).toMatchObject({ status: 'revoked' });
    expect((await get(rep.auth, '/staff/me')).status).toBe(401);
    expect((await post(admin.auth, `/staff/representatives/${rep.rep.id}/revoke-verification`, { reason: 'Wrong person' })).status).toBe(409);
    const mod = await signed('moderator');
    expect((await post(mod.auth, `/staff/representatives/${rep.rep.id}/revoke-verification`, { reason: 'Wrong person' })).status).toBe(403);
  });
});
