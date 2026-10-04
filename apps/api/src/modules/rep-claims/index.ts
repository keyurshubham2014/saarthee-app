/**
 * TASK-11 representative claims (REQ-F-053): citizen submit/list/withdraw; staff list/detail (admin, moderator
 * read), evidence photos and decisions (admin only), revoke verification (admin). Audit lines carry ids,
 * enums and booleans only — never note text, reasons or phone numbers.
 */
import type { Request } from 'express';
import { Router } from 'express';
import { z } from 'zod';
import { config } from '../../config';
import { auditStaff } from '../../lib/audit';
import { writeAudit } from '../../lib/audit/staff';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
// TASK-14 sweep: claims in GET /me/export and withdrawn by DELETE /me.
import './privacy';
import { decodeCursor, encodeCursor } from '../../lib/pagination';
import { rateLimit } from '../../middleware/rateLimit';
import { requireStaff } from '../../middleware/requireStaff';
import { requireUser } from '../../middleware/requireUser';
import { validate } from '../../middleware/validate';
import { openPhoto } from '../photos/read.service';
import './privacy';
import { myClaims, submitClaim, withdrawClaim, type ClaimInput } from './claims.service';
import { claimDetail, decideClaim, listClaims, revokeVerification, VERIFIED_METHODS, type Decision } from './review.service';

export const repClaimsRouter = Router();

const userKey = (p: string) => (req: Request) => `${p}:${req.user?.id ?? req.staff?.actorId ?? 'none'}`;
const claimLimiter = rateLimit({ windowMs: 24 * 60 * 60_000, max: config.REP_CLAIM_MAX_PER_DAY, keyGenerator: userKey('rep-claim') });
const staffLimiter = rateLimit({ windowMs: 60_000, max: 120, keyGenerator: userKey('rep-claims-staff') });
const readers = [requireStaff('admin', 'moderator'), staffLimiter];
const admins = [requireStaff('admin'), staffLimiter];

const idParams = z.object({ id: z.uuid() });
const claimIdParams = z.object({ claimId: z.uuid() });
const evidenceParams = z.object({ id: z.uuid(), photoId: z.uuid() });
const claimBody = z.strictObject({
  evidencePhotoIds: z.array(z.uuid()).min(1).max(3),
  note: z.string().trim().max(500).optional(),
});
const listQuery = z.object({
  status: z.enum(['pending', 'approved', 'rejected', 'expired', 'revoked', 'withdrawn']).optional(),
  cursor: z.string().max(200).optional(),
  limit: z.coerce.number().int().min(1).max(50).default(25),
});
const decideBody = z.discriminatedUnion('decision', [
  z.strictObject({ decision: z.literal('approve'), method: z.enum(VERIFIED_METHODS) }),
  z.strictObject({ decision: z.literal('reject'), reason: z.string().trim().min(5).max(300) }),
]);
const revokeBody = z.strictObject({ reason: z.string().trim().min(5).max(300) });

repClaimsRouter.post('/representatives/:id/claims', requireUser, claimLimiter, validate({ params: idParams, body: claimBody }), async (req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  const user = req.user!;
  const claim = await submitClaim(user.id, id, req.body as ClaimInput);
  writeAudit({ requestId: req.id, actorId: user.id, actorKind: 'user', role: user.role, action: 'rep_claim_submitted', targetType: 'rep_claim', targetId: claim.id, extra: { representativeId: id } });
  res.status(201).json({ claimId: claim.id, status: claim.status });
});

repClaimsRouter.get('/me/rep-claims', requireUser, async (req, res) => {
  res.json(await myClaims(req.user!.id));
});

repClaimsRouter.delete('/me/rep-claims/:claimId', requireUser, validate({ params: claimIdParams }), async (req, res) => {
  const { claimId } = res.locals.params as z.infer<typeof claimIdParams>;
  await withdrawClaim(req.user!.id, claimId);
  res.status(204).end();
});

repClaimsRouter.get('/staff/rep-claims', ...readers, validate({ query: listQuery }), async (_req, res) => {
  const q = res.locals.query as z.infer<typeof listQuery>;
  const page = await listClaims(q.status, q.cursor ? decodeCursor(q.cursor) : null, q.limit);
  res.json({ items: page.items, nextCursor: page.more && page.last ? encodeCursor({ k: page.last.createdAt.toISOString(), id: page.last.id }) : null });
});

repClaimsRouter.get('/staff/rep-claims/:id', ...readers, validate({ params: idParams }), async (_req, res) => {
  res.json(await claimDetail((res.locals.params as z.infer<typeof idParams>).id));
});

repClaimsRouter.get('/staff/rep-claims/:id/evidence/:photoId', ...admins, validate({ params: evidenceParams }), async (_req, res) => {
  const { id, photoId } = res.locals.params as z.infer<typeof evidenceParams>;
  const claim = await prisma.repClaim.findUnique({ where: { id }, select: { evidencePhotoIds: true } });
  if (!claim || !claim.evidencePhotoIds.includes(photoId)) throw new AppError('NOT_FOUND');
  const stream = await openPhoto(photoId);
  res.setHeader('Content-Type', 'image/jpeg');
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  stream.pipe(res);
});

repClaimsRouter.post('/staff/rep-claims/:id/decide', ...admins, validate({ params: idParams, body: decideBody }), async (req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  const d = req.body as Decision;
  const s = req.staff!;
  const out = await decideClaim(id, s.actorKind === 'user' ? s.actorId : null, d);
  auditStaff(req, 'rep_claim_decided', {
    targetType: 'rep_claim', targetId: id,
    extra: { decision: d.decision, method: d.decision === 'approve' ? d.method : null, autoRejected: out.autoRejected },
  });
  res.json({ claimId: out.claimId, status: out.status });
});

repClaimsRouter.post('/staff/representatives/:id/revoke-verification', ...admins, validate({ params: idParams, body: revokeBody }), async (req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  await revokeVerification(id);
  auditStaff(req, 'rep_verification_revoked', { targetType: 'representative', targetId: id });
  res.json({ representativeId: id, verification: 'unverified' });
});
