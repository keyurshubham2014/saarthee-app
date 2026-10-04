import { now as clockNow } from '../../lib/clock';
import { registerErasureStep, registerExportSection } from '../me/privacy.registry';

/**
 * TASK-14 sweep fix (TASK-04 privacy registry): a representative claim is the claimant's personal data.
 * `GET /me/export` lists the caller's claims (ids, status, dates — no staff notes). `DELETE /me` withdraws any
 * pending claim (so the admin queue never offers to approve a deleted account) and drops the claimant's note.
 */
registerExportSection('rep_claims', async (userId, tx) => {
  const rows = await tx.repClaim.findMany({
    where: { userId },
    orderBy: { createdAt: 'asc' },
    select: { id: true, representativeId: true, status: true, claimantNote: true, createdAt: true, decidedAt: true },
  });
  return rows.map((c) => ({
    claimId: c.id,
    representativeId: c.representativeId,
    status: c.status,
    note: c.claimantNote,
    createdAt: c.createdAt,
    decidedAt: c.decidedAt,
  }));
});

registerErasureStep('rep_claims', async (userId, tx) => {
  await tx.repClaim.updateMany({ where: { userId, status: 'pending' }, data: { status: 'withdrawn', decidedAt: clockNow() } });
  await tx.repClaim.updateMany({ where: { userId }, data: { claimantNote: null } });
});
