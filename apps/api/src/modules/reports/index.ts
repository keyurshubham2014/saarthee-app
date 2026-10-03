import { Router } from 'express';
import { z } from 'zod';
import { clientMeta } from '../../middleware/clientMeta';
import { rateLimit } from '../../middleware/rateLimit';
import { validate } from '../../middleware/validate';
import { MSG, consentVersionSchema, evidenceFields, normalizeIndianMobile } from '../../lib/validation';
import { submitReport } from './reports.service';

export const reportsRouter = Router();

// 03 §10: POST /reports 30 per IP per hour.
const reportsLimiter = rateLimit({ windowMs: 60 * 60_000, max: 30 });

const reportBody = z.object({
  clientSubmissionId: z.uuidv4(),
  inviteCode: z.string().max(50).optional(),
  categoryId: z.uuid(),
  ccrsNumber: z.string({ error: MSG.ccrs }).trim().min(1, MSG.ccrs).max(50, MSG.ccrs),
  photoId: z.uuid({ error: 'Please retake the photo.' }),
  ...evidenceFields,
  phone: z
    .string({ error: MSG.phone })
    .transform((v, ctx) => {
      const e164 = normalizeIndianMobile(v);
      if (!e164) {
        ctx.addIssue({ code: 'custom', message: MSG.phone });
        return z.NEVER;
      }
      return e164;
    }),
  consentGivenAt: z.iso.datetime({ offset: true, error: MSG.consent }).transform((v) => new Date(v)),
  consentTextVersion: consentVersionSchema,
});

reportsRouter.post('/reports', reportsLimiter, validate({ body: reportBody }), async (req, res) => {
  const { phone, ...rest } = req.body as z.infer<typeof reportBody>;
  const result = await submitReport(
    { ...rest, phoneE164: phone },
    { requestId: req.id, installId: clientMeta(req).installId },
  );
  res.status(result.created ? 201 : 200).json({ complaintId: result.complaintId, createdAt: result.createdAt.toISOString() });
});
