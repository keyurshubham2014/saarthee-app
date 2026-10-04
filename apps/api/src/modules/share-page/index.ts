/**
 * GET /i/{id} (outside /api/v1; V2 TASK-07 §5.3, REQ-F-032): a minimal public page for share and evidence
 * links — title, status word, ward, age, report photo, Open Graph tags, independence line. No PII; every
 * user-supplied string is HTML-escaped; strict CSP; noindex.
 */
import { Router } from 'express';
import { z } from 'zod';
import { config } from '../../config';
import { now as clockNow } from '../../lib/clock';
import { prisma } from '../../lib/db';
import { rateLimit } from '../../middleware/rateLimit';
import { publicIssueInclude, toPublicIssue } from '../issues/public';

const STATUS_WORD: Record<string, string> = {
  reported: 'Reported', sent: 'Sent to AMC', acknowledged: 'Acknowledged', in_progress: 'In progress', marked_fixed: 'Fixed',
  fixed_unverified: 'Fixed (not verified)', verified: 'Verified fixed', reopened: 'Reopened', merged: 'Merged',
};

export const escapeHtml = (s: string) =>
  s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);

const CSP = "default-src 'none'; img-src 'self'; style-src 'unsafe-inline'";
const STYLE =
  'body{font-family:system-ui,sans-serif;margin:0;background:#F3F6F1;color:#18211C}main{max-width:560px;margin:0 auto;padding:16px}' +
  'img{width:100%;border-radius:14px}h1{font-size:22px}.s{display:inline-block;padding:4px 10px;border-radius:999px;background:#E3EFE8}' +
  'a.b{display:inline-block;margin:16px 0;padding:12px 18px;border-radius:14px;background:#14674A;color:#fff;text-decoration:none}small{color:#55625A}';

function page(title: string, body: string, head = ''): string {
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">` +
    `<meta name="robots" content="noindex"><title>${escapeHtml(title)}</title>${head}<style>${STYLE}</style></head><body><main>${body}</main></body></html>`;
}

const INDEPENDENCE = 'Independent citizen app. Not run by or linked to AMC.';

export const sharePageRouter = Router();
const limiter = rateLimit({ windowMs: 60_000, max: 120 });

sharePageRouter.get('/i/:id', limiter, async (req, res) => {
  res.setHeader('Content-Security-Policy', CSP);
  res.setHeader('X-Robots-Tag', 'noindex');
  res.type('html');
  const id = z.uuid().safeParse(req.params.id);
  const row = id.success ? await prisma.issue.findUnique({ where: { id: id.data }, include: publicIssueInclude }) : null;
  if (!row || row.visibility !== 'public' || row.status === 'rejected') {
    res.status(404).send(page('Not found · Saarthee', `<h1>This issue isn't available.</h1><p>It may have been removed.</p><small>${INDEPENDENCE}</small>`));
    return;
  }
  const i = toPublicIssue(row, 'en');
  const base = config.PUBLIC_WEB_BASE_URL.replace(/\/$/, '');
  const status = STATUS_WORD[i.displayStatus] ?? i.displayStatus;
  const days = Math.max(0, Math.floor((clockNow().getTime() - i.createdAt.getTime()) / 86_400_000));
  const age = days === 0 ? 'today' : days === 1 ? '1 day ago' : `${days} days ago`;
  const ward = i.ward ? `Ward ${i.ward.number} · ${i.ward.nameEn}` : 'Ahmedabad';
  const desc = `${status} · ${ward} · reported ${age}. ${i.meTooCount} residents affected.`;
  const photo = i.photos.report[0];
  const head =
    `<meta property="og:title" content="${escapeHtml(i.title)}"><meta property="og:description" content="${escapeHtml(desc)}">` +
    `<meta property="og:type" content="article"><meta property="og:url" content="${escapeHtml(`${base}/i/${i.id}`)}">` +
    (photo ? `<meta property="og:image" content="${escapeHtml(`${base}${photo}`)}">` : '');
  const body =
    (photo ? `<img src="${escapeHtml(photo)}" alt="${escapeHtml(i.title)}">` : '') +
    `<h1>${escapeHtml(i.title)}</h1><p><span class="s">${escapeHtml(status)}</span></p><p>${escapeHtml(ward)} · ${escapeHtml(age)}</p>` +
    (i.description ? `<p>${escapeHtml(i.description)}</p>` : '') +
    `<p>${escapeHtml(i.reporterLabel.en)} reported this. ${i.meTooCount} residents affected.</p>` +
    `<a class="b" href="${escapeHtml(`${base}/issues/${i.id}`)}">Open in Saarthee</a><br><small>${INDEPENDENCE}</small>`;
  res.status(200).send(page(`${i.title} · Saarthee`, body, head));
});
