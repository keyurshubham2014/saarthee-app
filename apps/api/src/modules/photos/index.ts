import { Router } from 'express';
import { z } from 'zod';
import { AppError } from '../../lib/errors';
import { assertDailyQuota } from '../../lib/quota';
import { photoUpload } from '../../middleware/photoUpload';
import { rateLimit } from '../../middleware/rateLimit';
import { optionalUser, requireUser } from '../../middleware/requireUser';
import { validate } from '../../middleware/validate';
import { sendPublicPhoto } from './media.service';
import { storeUploadedPhoto } from './photos.service';

export const photosRouter = Router();

// 03 §10: POST /photos and POST /verify/photos 60 per IP per hour (separate budgets per route).
const photosLimiter = rateLimit({ windowMs: 60 * 60_000, max: 60 });
// V2 TASK-05 §5.3: public photo read 120 per IP per minute.
const mediaLimiter = rateLimit({ windowMs: 60_000, max: 120 });

const fields = z.object({
  purpose: z.literal('report', { error: 'Must be report.' }),
  blurApplied: z.enum(['true', 'false']).optional().transform((v) => v === 'true'),
});

// V2 TASK-05: signed-in citizens only; the photo is owned (uploaded_by_user_id) and counted against
// QUOTA_PHOTOS_PER_DAY. The v1 pipeline (re-encode, EXIF/GPS strip, resize) still applies.
photosRouter.post('/photos', photosLimiter, requireUser, photoUpload, validate({ body: fields }), async (req, res) => {
  if (!req.file) throw new AppError('VALIDATION_FAILED', { details: [{ field: 'photo', issue: 'Photo is required.' }] });
  const user = req.user!;
  await assertDailyQuota(user.id, 'photos', { res });
  const body = req.body as z.infer<typeof fields>;
  const result = await storeUploadedPhoto(req.file.buffer, 'report', null, { uploadedByUserId: user.id, blurApplied: body.blurApplied });
  res.status(201).json(result);
});

const mediaParams = z.object({ id: z.uuid() });
const mediaQuery = z.object({ w: z.enum(['320', '1024']).optional() });

photosRouter.get('/media/photos/:id', mediaLimiter, optionalUser, validate({ params: mediaParams, query: mediaQuery }), async (req, res) => {
  const { id } = res.locals.params as z.infer<typeof mediaParams>;
  const { w } = res.locals.query as z.infer<typeof mediaQuery>;
  await sendPublicPhoto(res, id, w ? Number(w) : null, req.user);
});
