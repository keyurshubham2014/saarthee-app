import { Router } from 'express';
import { z } from 'zod';
import { sendJpeg } from '../../lib/http/sendJpeg';
import { MSG, evidenceFields } from '../../lib/validation';
import { clientMeta } from '../../middleware/clientMeta';
import { photoUpload } from '../../middleware/photoUpload';
import { rateLimit } from '../../middleware/rateLimit';
import { requireVerifyToken } from '../../middleware/requireVerifyToken';
import { validate } from '../../middleware/validate';
import { storeUploadedPhoto } from '../photos/photos.service';
import { getVerifySummary, openVerifyReportPhoto, submitVerification } from './verify.service';

export const verifyRouter = Router();

// 03 §10: all /verify/* share 60 per IP per hour. Applied before the token guard so probing is limited too.
const verifyLimiter = rateLimit({ windowMs: 60 * 60_000, max: 60 });
verifyRouter.use('/verify', verifyLimiter, requireVerifyToken);

verifyRouter.get('/verify/complaint', async (req, res) => {
  res.json(await getVerifySummary(req.verify!, clientMeta(req).installId));
});

verifyRouter.get('/verify/complaint/photo', async (req, res) => {
  await sendJpeg(res, await openVerifyReportPhoto(req.verify!));
});

verifyRouter.post('/verify/photos', photoUpload, async (req, res) => {
  const result = await storeUploadedPhoto(req.file!.buffer, 'verification', req.verify!.complaintId);
  res.status(201).json(result);
});

const submissionBody = z.object({
  clientSubmissionId: z.uuidv4(),
  result: z.enum(['fixed', 'not_fixed']),
  photoId: z.uuid({ error: 'Please retake the photo.' }),
  ...evidenceFields,
  note: z.string().trim().max(1000, MSG.note).optional(),
});

verifyRouter.post('/verify/submissions', validate({ body: submissionBody }), async (req, res) => {
  const body = req.body as z.infer<typeof submissionBody>;
  const r = await submitVerification(body, req.verify!, clientMeta(req).installId);
  res.status(r.created ? 201 : 200).json({ verificationId: r.verificationId, createdAt: r.createdAt.toISOString() });
});
