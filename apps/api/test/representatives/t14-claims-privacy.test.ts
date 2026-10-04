// TASK-14 sweep fix: a representative claim is the claimant's personal data — listed in GET /me/export, and
// DELETE /me withdraws a pending claim (so an admin can never approve a deleted account) and drops the note.
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { useMemoryPush } from '../auth/helpers';
import { fixtureWards, makeRep } from './helpers';
import { evidence, get, post, PREFIX, signed } from './t11-helpers';

useMemoryPush();
const NOTE = 'CLAIM-NOTE-SECRET I am the corporator';

beforeEach(async () => {
  await resetDb();
});

describe('rep claims and the privacy registry (T-14 sweep)', () => {
  it('export lists the claim; erasure withdraws it and removes the note', async () => {
    const wards = await fixtureWards();
    const rep = await makeRep({}, [{ wardId: wards.get(1)! }]);
    const claimant = await signed('citizen');
    const sent = await post(claimant.auth, `/representatives/${rep.id}/claims`, { evidencePhotoIds: await evidence(claimant.user.id), note: NOTE });
    expect(sent.status).toBe(201);

    const exp = await get(claimant.auth, '/me/export');
    expect(exp.status).toBe(200);
    expect(exp.body.rep_claims).toEqual([expect.objectContaining({ claimId: sent.body.claimId, representativeId: rep.id, status: 'pending', note: NOTE })]);

    const del = await api().delete(`${PREFIX}/me`).set(claimant.auth).send({ confirm: 'DELETE' });
    expect(del.status).toBe(204);
    const claim = await prisma.repClaim.findUniqueOrThrow({ where: { id: sent.body.claimId } });
    expect(claim.status).toBe('withdrawn');
    expect(claim.decidedAt).not.toBeNull();
    expect(claim.claimantNote).toBeNull();

    const admin = await signed('admin');
    const queue = await get(admin.auth, '/staff/rep-claims?status=pending');
    expect(queue.status).toBe(200);
    expect(JSON.stringify(queue.body)).not.toContain(sent.body.claimId);
    const decide = await post(admin.auth, `/staff/rep-claims/${sent.body.claimId}/decide`, { decision: 'approve', method: 'certificate_of_election' });
    expect(decide.status).toBe(409);
    expect(decide.body.error.code).toBe('CLAIM_NOT_PENDING');
  });
});
