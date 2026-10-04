/** Moderation queue and issue tools routes (TASK-10 §5.3). Moderators and admins only. */
import { Router } from 'express';
import { z } from 'zod';
import { auditStaff } from '../../lib/audit';
import { AppError } from '../../lib/errors';
import { validate } from '../../middleware/validate';
import { eventActor, idOf, idParams, moderators } from './common';
import { mergeCandidates, staffIssueDetail } from './issue.service';
import { hideComment, markReviewed, mergeIssue, recategoriseIssue, rejectIssue, REJECT_REASONS, resolveFlag, setHidden } from './moderation.service';
import { listQueue } from './queue.service';
import { staffTransition } from './status.service';

export const moderationRouter = Router();

const queueQuery = z.object({
  queue: z.enum(['sensitive', 'flagged', 'out_of_area']),
  cursor: z.string().max(200).optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});
const rejectBody = z.strictObject({ reason: z.enum(REJECT_REASONS), note: z.string().trim().max(500).optional() });
const mergeBody = z.strictObject({ targetIssueId: z.uuid(), note: z.string().trim().max(500).optional() });
const recatBody = z
  .strictObject({ categoryId: z.uuid().optional(), wardId: z.uuid().optional(), note: z.string().trim().max(500).optional() })
  .refine((v) => v.categoryId !== undefined || v.wardId !== undefined, { message: 'Choose a category or a ward.', path: ['categoryId'] });
const reasonBody = z.strictObject({ reason: z.string().trim().min(1).max(200) });
const resolveBody = z.strictObject({ outcome: z.enum(['actioned', 'dismissed']) });
const statusBody = z.strictObject({
  to: z.enum(['acknowledged', 'in_progress', 'marked_fixed']),
  note: z.string().trim().max(500).optional(),
  photoIds: z.array(z.uuid()).max(3).optional(),
  expectedStatus: z.enum(['reported', 'sent', 'acknowledged', 'in_progress', 'marked_fixed', 'verified', 'reopened', 'rejected', 'merged']).optional(),
});
const issue = (targetId: string) => ({ targetType: 'issue' as const, targetId });

moderationRouter.get('/staff/moderation', ...moderators, validate({ query: queueQuery }), async (_req, res) => {
  const q = res.locals.query as z.infer<typeof queueQuery>;
  res.json(await listQueue(q.queue, q.cursor, q.limit));
});

moderationRouter.get('/staff/issues/:id', ...moderators, validate({ params: idParams }), async (_req, res) => {
  res.json(await staffIssueDetail(idOf(res)));
});

moderationRouter.get('/staff/issues/:id/merge-candidates', ...moderators, validate({ params: idParams }), async (_req, res) => {
  res.json(await mergeCandidates(idOf(res)));
});

moderationRouter.post('/staff/issues/:id/reject', ...moderators, validate({ params: idParams, body: rejectBody }), async (req, res) => {
  const id = idOf(res);
  const body = req.body as z.infer<typeof rejectBody>;
  await rejectIssue(id, eventActor(req), body.reason, body.note);
  auditStaff(req, 'issue_rejected', { ...issue(id), extra: { reason: body.reason } });
  res.json(await staffIssueDetail(id));
});

moderationRouter.post('/staff/issues/:id/merge', ...moderators, validate({ params: idParams, body: mergeBody }), async (req, res) => {
  const id = idOf(res);
  const body = req.body as z.infer<typeof mergeBody>;
  await mergeIssue(id, body.targetIssueId, eventActor(req), body.note);
  auditStaff(req, 'issue_merged', { ...issue(id), extra: { intoIssueId: body.targetIssueId } });
  res.json(await staffIssueDetail(id));
});

moderationRouter.post('/staff/issues/:id/recategorise', ...moderators, validate({ params: idParams, body: recatBody }), async (req, res) => {
  const id = idOf(res);
  const changed = await recategoriseIssue(id, eventActor(req), req.body as z.infer<typeof recatBody>);
  if (changed.categoryChanged) auditStaff(req, 'issue_recategorised', issue(id));
  if (changed.wardChanged) auditStaff(req, 'issue_ward_changed', issue(id));
  res.json(await staffIssueDetail(id));
});

moderationRouter.post('/staff/issues/:id/hide', ...moderators, validate({ params: idParams, body: reasonBody }), async (req, res) => {
  const id = idOf(res);
  await setHidden(id, eventActor(req), true, (req.body as z.infer<typeof reasonBody>).reason);
  auditStaff(req, 'issue_hidden', issue(id));
  res.json(await staffIssueDetail(id));
});

moderationRouter.post('/staff/issues/:id/unhide', ...moderators, validate({ params: idParams, body: reasonBody }), async (req, res) => {
  const id = idOf(res);
  await setHidden(id, eventActor(req), false, (req.body as z.infer<typeof reasonBody>).reason);
  auditStaff(req, 'issue_unhidden', issue(id));
  res.json(await staffIssueDetail(id));
});

moderationRouter.post('/staff/issues/:id/reviewed', ...moderators, validate({ params: idParams }), async (req, res) => {
  const id = idOf(res);
  await markReviewed(id, eventActor(req));
  auditStaff(req, 'issue_reviewed', issue(id));
  res.json(await staffIssueDetail(id));
});

/** Acknowledge / in progress / mark fixed (thin; status.service is the swap point for TASK-06). */
moderationRouter.post('/staff/issues/:id/status', ...moderators, validate({ params: idParams, body: statusBody }), async (req, res) => {
  const id = idOf(res);
  const body = req.body as z.infer<typeof statusBody>;
  if (body.photoIds?.length && req.staff!.actorKind !== 'user') throw new AppError('PHOTO_UNUSABLE');
  await staffTransition(id, body.to, eventActor(req), { note: body.note, photoIds: body.photoIds, expectedStatus: body.expectedStatus });
  auditStaff(req, 'issue_status_changed', { ...issue(id), extra: { to: body.to, photos: body.photoIds?.length ?? 0 } });
  res.json(await staffIssueDetail(id));
});

moderationRouter.post('/staff/comments/:id/hide', ...moderators, validate({ params: idParams, body: reasonBody }), async (req, res) => {
  const id = idOf(res);
  const issueId = await hideComment(id, eventActor(req));
  auditStaff(req, 'comment_hidden', { targetType: 'issue_event', targetId: id });
  res.json({ eventId: id, issueId, hidden: true });
});

moderationRouter.post('/staff/flags/:id/resolve', ...moderators, validate({ params: idParams, body: resolveBody }), async (req, res) => {
  const id = idOf(res);
  const { outcome } = req.body as z.infer<typeof resolveBody>;
  await resolveFlag(id, eventActor(req), outcome);
  auditStaff(req, 'flag_resolved', { targetType: 'flag', targetId: id, extra: { outcome } });
  res.json({ id, status: outcome });
});
