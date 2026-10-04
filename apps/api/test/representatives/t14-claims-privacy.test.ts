// TASK-14 privacy sweep (P2-05/P2-06): a claimant's rep claims are exported, and DELETE /me removes their
// claim evidence photos (attached and loose), clears their note and withdraws a pending claim.
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { resetDb } from '../helpers/db';
import { useFakeFirebase } from '../auth/helpers';
import { fixtureWards, makeRep } from './helpers';
import { evidence, get, post, signed } from './t11-helpers';
import { api } from '../helpers/app';

useFakeFirebase();
let ward1: string;

beforeEach(async () => {
  await resetDb();
  ward1 = (await fixtureWards()).get(1)!;
});

describe('rep claim privacy hooks (TASK-14 P2-05/P2-06)', () => {
  it('exports the claimant’s claims without evidence ids and erases evidence on DELETE /me', async () => {
    const rep = await makeRep({}, [{ wardId: ward1 }]);
    const c = await signed('citizen');
    const other = await signed('citizen');
    const photos = await evidence(c.user.id, 2);
    const loose = await evidence(c.user.id, 1);
    const otherPhotos = await evidence(other.user.id, 1);
    const res = await post(c.auth, `/representatives/${rep.id}/claims`, { evidencePhotoIds: photos, note: 'I am the corporator' });
    expect(res.status).toBe(201);

    const exp = await get(c.auth, '/me/export');
    expect(exp.status).toBe(200);
    const body = typeof exp.body === 'object' && Object.keys(exp.body).length > 0 ? exp.body : JSON.parse(exp.text);
    expect(body.rep_claims).toEqual([
      expect.objectContaining({ id: res.body.claimId, representativeId: rep.id, status: 'pending', claimantNote: 'I am the corporator', evidencePhotoCount: 2 }),
    ]);
    expect(JSON.stringify(body.rep_claims)).not.toContain(photos[0]);

    const del = await api().delete('/api/v1/me').set(c.auth).send({ confirm: 'DELETE' });
    expect(del.status).toBe(204);
    const claim = await prisma.repClaim.findUniqueOrThrow({ where: { id: res.body.claimId } });
    expect(claim).toMatchObject({ status: 'withdrawn', claimantNote: null, evidencePhotoIds: [] });
    expect(claim.decidedAt).not.toBeNull();
    const gone = await prisma.photo.findMany({ where: { id: { in: [...photos, ...loose] } } });
    expect(gone.every((p) => p.deletedAt !== null)).toBe(true);
    expect((await prisma.photo.findUniqueOrThrow({ where: { id: otherPhotos[0]! } })).deletedAt).toBeNull();
  });
});
