import { registerErasureStep, registerExportSection } from '../me/privacy.registry';

/**
 * TASK-14 privacy sweep (P2-05/P2-06) for TASK-11 representative claims: `GET /me/export` section
 * `rep_claims`, and the `DELETE /me` step that removes the claimant's evidence photos (files and rows,
 * after commit), clears their note and withdraws a still-pending claim. Decided claims keep the decision
 * (audit of who verified a representative) without the claimant's content.
 */
registerExportSection('rep_claims', async (userId, tx) => {
  const rows = await tx.repClaim.findMany({ where: { userId }, orderBy: { createdAt: 'asc' } });
  return rows.map((c) => ({
    id: c.id,
    representativeId: c.representativeId,
    status: c.status,
    claimantNote: c.claimantNote,
    evidencePhotoCount: c.evidencePhotoIds.length,
    createdAt: c.createdAt,
    decidedAt: c.decidedAt,
  }));
});

registerErasureStep('rep_claims', async (userId, tx, ctx) => {
  const claims = await tx.repClaim.findMany({ where: { userId }, select: { evidencePhotoIds: true } });
  for (const c of claims) for (const id of c.evidencePhotoIds) ctx.photoIds.add(id);
  // Evidence uploaded but never attached to a claim is the claimant's too.
  const loose = await tx.photo.findMany({ where: { uploadedByUserId: userId, purpose: 'rep_evidence', deletedAt: null }, select: { id: true } });
  for (const p of loose) ctx.photoIds.add(p.id);
  await tx.repClaim.updateMany({ where: { userId, status: 'pending' }, data: { status: 'withdrawn', decidedAt: new Date() } });
  await tx.repClaim.updateMany({ where: { userId }, data: { evidencePhotoIds: [], claimantNote: null } });
});
