import type { RequestHandler } from 'express';
import multer from 'multer';
import { config } from '../config';
import { AppError } from '../lib/errors';

/**
 * Multipart parser for one `photo` file (03 §8.2 step 1). Memory storage with `limits.fileSize`
 * aborts the upload as soon as it exceeds PHOTO_MAX_UPLOAD_BYTES, before the whole body is buffered.
 * Nothing is written to disk here; the cleaned bytes are stored by the photos service.
 */
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: config.PHOTO_MAX_UPLOAD_BYTES,
    files: 1,
    fields: 5,
    fieldSize: 1024,
    parts: 6,
  },
}).single('photo');

export const photoUpload: RequestHandler = (req, res, next) => {
  if (!req.is('multipart/form-data')) {
    return next(new AppError('VALIDATION_FAILED', { details: [{ field: 'photo', issue: 'Send the photo as multipart/form-data.' }] }));
  }
  upload(req, res, (err: unknown) => {
    if (!err) {
      if (!req.file) {
        return next(new AppError('VALIDATION_FAILED', { details: [{ field: 'photo', issue: 'Photo is required.' }] }));
      }
      return next();
    }
    if (err instanceof multer.MulterError) {
      if (err.code === 'LIMIT_FILE_SIZE') return next(new AppError('PHOTO_TOO_LARGE'));
      return next(new AppError('VALIDATION_FAILED', { details: [{ field: err.field ?? 'photo', issue: 'Unexpected upload field.' }] }));
    }
    return next(new AppError('VALIDATION_FAILED', { details: [{ field: 'photo', issue: 'Upload could not be read.' }] }));
  });
};
