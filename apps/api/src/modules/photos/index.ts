import { Router } from 'express';
import { z } from 'zod';
import { AppError } from '../../lib/errors';
import { photoUpload } from '../../middleware/photoUpload';
import { rateLimit } from '../../middleware/rateLimit';
import { validate } from '../../middleware/validate';
import { storeUploadedPhoto } from './photos.service';

export const photosRouter = Router();

// 03 §10: POST /photos and POST /verify/photos 60 per IP per hour (separate budgets per route).
const photosLimiter = rateLimit({ windowMs: 60 * 60_000, max: 60 });

const fields = z.object({ purpose: z.literal('report', { error: 'Must be report.' }) });

photosRouter.post('/photos', photosLimiter, photoUpload, validate({ body: fields }), async (req, res) => {
  if (!req.file) throw new AppError('VALIDATION_FAILED', { details: [{ field: 'photo', issue: 'Photo is required.' }] });
  const result = await storeUploadedPhoto(req.file.buffer, 'report');
  res.status(201).json(result);
});
