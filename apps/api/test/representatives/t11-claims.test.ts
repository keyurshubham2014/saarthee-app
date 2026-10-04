// TASK-11 claims: T-11-01 submit, T-11-02 guards, T-11-03 approve, T-11-04 reject/permissions, T-11-15 public block.
import { beforeEach, describe, expect, it } from 'vitest';
import { captureAudit } from '../../src/lib/audit';
import { prisma } from '../../src/lib/db';
import { resetDb } from '../helpers/db';
import { useMemoryPush } from '../auth/helpers';
import { fixtureWards, makeRep } from './helpers';
import { del, evidence, get, post, resign, signed } from './t11-helpers';

const push = useMemoryPush();
const OFFICE = '+917926000001';
let ward1: string;

beforeEach(async () => {
  await resetDb();
  ward1 = (await fixtureWards()).get(1)!;
  push.sent.length = 0;
});

async function pendingClaim(repId: string) {
  const c = await signed('citizen');
  const res = await post(c.auth, `/representatives/${repId}/claims`, { evidencePhotoIds: await evidence(c.user.id, 2) });
  expect(res.status).toBe(201);
  return { ...c, claimId: res.body.claimId as string };
}

describe('claim submission (T-11-01)', () => {
  it('201 pending with otp_verified, phone_match and private evidence; Me lists it', async () => {
    const rep = await makeRep({ publicPhone: OFFICE }, [{ wardId: ward1 }]);
    const c = await signed('citizen', { phoneE164: OFFICE });
    const photos = await evidence(c.user.id, 2);
    const res = await post(c.auth, `/representatives/${rep.id}/claims`, { evidencePhotoIds: photos, note: 'I am the corporator' });
    expect(res.status).toBe(201);
    expect(res.body).toEqual({ claimId: expect.any(String), status: 'pending' });
    const row = await prisma.repClaim.findUniqueOrThrow({ where: { id: res.body.claimId } });
    expect(row).toMatchObject({ otpVerified: true, phoneMatch: true, status: 'pending', claimantNote: 'I am the corporator' });
    expect(row.evidencePhotoIds.sort()).toEqual(photos.sort());
    expect(JSON.stringify(row)).not.toContain('7926000001');
    const mine = await get(c.auth, '/me/rep-claims');
    expect(mine.body.items).toEqual([expect.objectContaining({ claimId: res.body.claimId, status: 'pending', representative: expect.objectContaining({ id: rep.id }) })]);
  });

  it('phone_match is false for a different number; a photo with another purpose is refused', async () => {
    const rep = await makeRep({ publicPhone: OFFICE }, [{ wardId: ward1 }]);
    const c = await signed('citizen');
    const bad = await evidence(c.user.id, 1, { purpose: 'report' });
    expect((await post(c.auth, `/representatives/${rep.id}/claims`, { evidencePhotoIds: bad })).body.error.code).toBe('PHOTO_UNUSABLE');
    const res = await post(c.auth, `/representatives/${rep.id}/claims`, { evidencePhotoIds: await evidence(c.user.id) });
    expect((await prisma.repClaim.findUniqueOrThrow({ where: { id: res.body.claimId } })).phoneMatch).toBe(false);
  });
});

describe('claim guards (T-11-02)', () => {
  it('duplicate pending 409, 4th per day 429, foreign photo 422, withdraw', async () => {
    const rep = await makeRep({}, [{ wardId: ward1 }]);
    const c = await signed('citizen');
    const first = await post(c.auth, `/representatives/${rep.id}/claims`, { evidencePhotoIds: await evidence(c.user.id) });
    expect(first.status).toBe(201);
    const dup = await post(c.auth, `/representatives/${rep.id}/claims`, { evidencePhotoIds: await evidence(c.user.id) });
    expect([dup.status, dup.body.error.code]).toEqual([409, 'CLAIM_ALREADY_PENDING']);
    const other = await signed('citizen');
    const foreign = await post(c.auth, `/representatives/${rep.id}/claims`, { evidencePhotoIds: await evidence(other.user.id) });
    expect([foreign.status, foreign.body.error.code]).toEqual([422, 'PHOTO_UNUSABLE']);
    const fourth = await post(c.auth, `/representatives/${rep.id}/claims`, { evidencePhotoIds: await evidence(c.user.id) });
    expect(fourth.status).toBe(429);
    expect((await del(c.auth, `/me/rep-claims/${first.body.claimId}`)).status).toBe(204);
    expect((await del(c.auth, `/me/rep-claims/${first.body.claimId}`)).status).toBe(409);
  });

  it('term ended 422, staff ROLE_CONFLICT, already verified 409, visitor 401', async () => {
    const ended = await makeRep({ termStart: new Date('2020-01-01'), termEnd: new Date('2021-01-01') }, [{ wardId: ward1 }]);
    const live = await makeRep({}, [{ wardId: ward1 }]);
    const c = await signed('citizen');
    const r1 = await post(c.auth, `/representatives/${ended.id}/claims`, { evidencePhotoIds: await evidence(c.user.id) });
    expect([r1.status, r1.body.error.code]).toEqual([422, 'REPRESENTATIVE_TERM_ENDED']);
    const mod = await signed('moderator');
    const r2 = await post(mod.auth, `/representatives/${live.id}/claims`, { evidencePhotoIds: await evidence(mod.user.id) });
    expect([r2.status, r2.body.error.code]).toEqual([409, 'ROLE_CONFLICT']);
    const holder = await signed('representative');
    const taken = await makeRep({ userId: holder.user.id, verifiedAt: new Date() }, [{ wardId: ward1 }]);
    const r3 = await post(c.auth, `/representatives/${taken.id}/claims`, { evidencePhotoIds: await evidence(c.user.id) });
    expect([r3.status, r3.body.error.code]).toEqual([409, 'REPRESENTATIVE_ALREADY_VERIFIED']);
    expect((await post(undefined, `/representatives/${live.id}/claims`, { evidencePhotoIds: [] })).status).toBe(401);
  });
});

describe('decide approve (T-11-03) and public block (T-11-15)', () => {
  it('approves in one transaction, rejects other pending claims, notifies, audits, shows the badge', async () => {
    const rep = await makeRep({}, [{ wardId: ward1 }]);
    const winner = await pendingClaim(rep.id);
    const loser = await pendingClaim(rep.id);
    const admin = await signed('admin');
    const audit = captureAudit();
    const res = await post(admin.auth, `/staff/rep-claims/${winner.claimId}/decide`, { decision: 'approve', method: 'certificate_of_election' });
    audit.stop();
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ claimId: winner.claimId, status: 'approved' });
    const r = await prisma.representative.findUniqueOrThrow({ where: { id: rep.id } });
    expect(r).toMatchObject({ userId: winner.user.id, verifiedMethod: 'certificate_of_election' });
    expect(r.verifiedAt).not.toBeNull();
    expect((await prisma.user.findUniqueOrThrow({ where: { id: winner.user.id } })).role).toBe('representative');
    expect(await prisma.repClaim.findUniqueOrThrow({ where: { id: loser.claimId } })).toMatchObject({ status: 'rejected', rejectReason: 'Another claim was approved' });
    expect(push.sent.length + (await prisma.notification.count({ where: { userId: winner.user.id } }))).toBeGreaterThan(0);
    expect(audit.lines).toHaveLength(1);
    expect(audit.lines[0]).toMatchObject({ action: 'rep_claim_decided', role: 'admin', targetType: 'rep_claim', targetId: winner.claimId, extra: { decision: 'approve', method: 'certificate_of_election' } });

    const pub = await get(undefined, `/representatives/${rep.id}`);
    expect(pub.body.verification).toEqual({ status: 'verified', method: 'certificate_of_election', verifiedAt: expect.any(String), validUntil: '2031-02-28' });
    expect(pub.body.verified).toBe(true);
    expect(JSON.stringify(pub.body)).not.toContain(winner.user.id);
    expect(pub.body).not.toHaveProperty('userId');
    const unverified = await makeRep({}, [{ wardId: ward1 }]);
    expect((await get(undefined, `/representatives/${unverified.id}`)).body.verification).toMatchObject({ status: 'unverified', method: null });
    // A new session for the approved user opens the representative console.
    expect((await get(await resign(winner.user.id), '/staff/me')).body).toMatchObject({ role: 'representative', wardIds: [ward1] });
  });
});

describe('decide reject and permissions (T-11-04)', () => {
  it('moderator 403 on decide and evidence, reason required, reject notifies, claimant may claim again', async () => {
    const rep = await makeRep({}, [{ wardId: ward1 }]);
    const claim = await pendingClaim(rep.id);
    const mod = await signed('moderator');
    const admin = await signed('admin');
    expect((await post(mod.auth, `/staff/rep-claims/${claim.claimId}/decide`, { decision: 'reject', reason: 'Document unreadable' })).status).toBe(403);
    const detail = await get(mod.auth, `/staff/rep-claims/${claim.claimId}`);
    expect(detail.status).toBe(200);
    expect(detail.body).toMatchObject({ claimId: claim.claimId, otpVerified: true, evidence: [{ photoId: expect.any(String) }, { photoId: expect.any(String) }] });
    const photoId = detail.body.evidence[0].photoId as string;
    expect((await get(mod.auth, `/staff/rep-claims/${claim.claimId}/evidence/${photoId}`)).status).toBe(403);
    expect((await get(mod.auth, `/media/photos/${photoId}`)).status).toBe(404);
    expect((await get(mod.auth, '/staff/rep-claims?status=pending')).body.items).toHaveLength(1);
    expect((await post(admin.auth, `/staff/rep-claims/${claim.claimId}/decide`, { decision: 'reject' })).status).toBe(400);
    expect((await post(admin.auth, `/staff/rep-claims/${claim.claimId}/decide`, { decision: 'approve' })).status).toBe(400);
    const ok = await post(admin.auth, `/staff/rep-claims/${claim.claimId}/decide`, { decision: 'reject', reason: 'Document unreadable' });
    expect(ok.body).toEqual({ claimId: claim.claimId, status: 'rejected' });
    expect((await post(admin.auth, `/staff/rep-claims/${claim.claimId}/decide`, { decision: 'reject', reason: 'Again please' })).status).toBe(409);
    expect((await get(claim.auth, '/me/rep-claims')).body.items[0]).toMatchObject({ status: 'rejected', rejectReason: 'Document unreadable' });
    const again = await post(claim.auth, `/representatives/${rep.id}/claims`, { evidencePhotoIds: await evidence(claim.user.id) });
    expect(again.status).toBe(201);
  });
});
