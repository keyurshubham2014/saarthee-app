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
import { pickLang, type AppLang } from '../../lib/lang';
import { publicIssueInclude, toPublicIssue } from '../issues/public';

/** Status words as the app shows them (ARB status* / discoveryStatus*). */
const STATUS_WORD: Record<AppLang, Record<string, string>> = {
  en: {
    reported: 'Reported', sent: 'Sent to AMC', acknowledged: 'Acknowledged', in_progress: 'In progress', marked_fixed: 'Fixed',
    fixed_unverified: 'Fixed (not verified)', verified: 'Verified fixed', reopened: 'Reopened', merged: 'Merged',
  },
  gu: {
    reported: 'નોંધાઈ', sent: 'AMC ને મોકલાઈ', acknowledged: 'સ્વીકારાઈ', in_progress: 'કામ ચાલુ', marked_fixed: 'ઉકેલાઈ',
    fixed_unverified: 'ઉકેલાઈ (ચકાસાઈ નથી)', verified: 'ચકાસાઈ', reopened: 'ફરી ખૂલી', merged: 'બીજી સમસ્યામાં જોડાઈ',
  },
};

const TEXT = {
  en: {
    notFoundTitle: 'Not found · Saarthee',
    notFound: "<h1>This issue isn't available.</h1><p>It may have been removed.</p>",
    independence: 'Independent citizen app. Not run by or linked to AMC.',
    age: (days: number) => (days === 0 ? 'today' : days === 1 ? '1 day ago' : `${days} days ago`),
    ward: (n: number, name: string) => `Ward ${n} · ${name}`,
    city: 'Ahmedabad',
    affected: (n: number) => (n === 1 ? '1 resident affected.' : `${n} residents affected.`),
    desc: (status: string, ward: string, age: string, affected: string) => `${status} · ${ward} · reported ${age}. ${affected}`,
    reported: (who: string) => `${who} reported this.`,
    open: 'Open in Saarthee',
    switchTo: { href: 'gu', label: 'ગુજરાતીમાં જુઓ' },
  },
  gu: {
    notFoundTitle: 'મળ્યું નથી · સારથી',
    notFound: '<h1>આ સમસ્યા ઉપલબ્ધ નથી.</h1><p>કદાચ તે દૂર કરવામાં આવી છે.</p>',
    independence: 'સ્વતંત્ર નાગરિક એપ. AMC દ્વારા ચલાવાતી નથી કે તેની સાથે જોડાયેલી નથી.',
    age: (days: number) => (days === 0 ? 'આજે' : days === 1 ? '1 દિવસ પહેલાં' : `${days} દિવસ પહેલાં`),
    ward: (n: number, name: string) => `વોર્ડ ${n} · ${name}`,
    city: 'અમદાવાદ',
    affected: (n: number) => (n === 1 ? '1 રહેવાસી અસરગ્રસ્ત.' : `${n} રહેવાસીઓ અસરગ્રસ્ત.`),
    desc: (status: string, ward: string, age: string, affected: string) => `${status} · ${ward} · ${age} નોંધાઈ. ${affected}`,
    reported: (who: string) => `${who}એ આ સમસ્યા નોંધાવી.`,
    open: 'સારથીમાં ખોલો',
    switchTo: { href: 'en', label: 'View in English' },
  },
} as const;

export const escapeHtml = (s: string) =>
  s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);

const CSP = "default-src 'none'; img-src 'self'; style-src 'unsafe-inline'";
const STYLE =
  'body{font-family:system-ui,sans-serif;margin:0;background:#F3F6F1;color:#18211C}main{max-width:560px;margin:0 auto;padding:16px}' +
  'img{width:100%;border-radius:14px}h1{font-size:22px}.s{display:inline-block;padding:4px 10px;border-radius:999px;background:#E3EFE8}' +
  'a.b{display:inline-block;margin:16px 0;padding:12px 18px;border-radius:14px;background:#14674A;color:#fff;text-decoration:none}small{color:#55625A}';

function page(lang: AppLang, title: string, body: string, head = ''): string {
  return `<!doctype html><html lang="${lang}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">` +
    `<meta name="robots" content="noindex"><title>${escapeHtml(title)}</title>${head}<style>${STYLE}</style></head><body><main>${body}</main></body></html>`;
}

export const sharePageRouter = Router();
const limiter = rateLimit({ windowMs: 60_000, max: 120 });

/**
 * Language: `?lang=gu|en`, else Accept-Language, else English (link-preview crawlers rarely send a language).
 * The page links to the other language; `Vary` keeps caches from mixing the two.
 */
sharePageRouter.get('/i/:id', limiter, async (req, res) => {
  res.setHeader('Content-Security-Policy', CSP);
  res.setHeader('X-Robots-Tag', 'noindex');
  res.vary('Accept-Language');
  res.type('html');
  const lang = pickLang(req.query.lang, req.header('accept-language'));
  const t = TEXT[lang];
  const id = z.uuid().safeParse(req.params.id);
  const row = id.success ? await prisma.issue.findUnique({ where: { id: id.data }, include: publicIssueInclude }) : null;
  if (!row || row.visibility !== 'public' || row.status === 'rejected') {
    res.status(404).send(page(lang, t.notFoundTitle, `${t.notFound}<small>${escapeHtml(t.independence)}</small>`));
    return;
  }
  const i = toPublicIssue(row, lang);
  const base = config.PUBLIC_WEB_BASE_URL.replace(/\/$/, '');
  const status = STATUS_WORD[lang][i.displayStatus] ?? i.displayStatus;
  const days = Math.max(0, Math.floor((clockNow().getTime() - i.createdAt.getTime()) / 86_400_000));
  const age = t.age(days);
  const ward = i.ward ? t.ward(i.ward.number, lang === 'gu' ? i.ward.nameGu : i.ward.nameEn) : t.city;
  const affected = t.affected(i.meTooCount);
  const desc = t.desc(status, ward, age, affected);
  const photo = i.photos.report[0];
  const brand = lang === 'gu' ? 'સારથી' : 'Saarthee';
  const head =
    `<meta property="og:title" content="${escapeHtml(i.title)}"><meta property="og:description" content="${escapeHtml(desc)}">` +
    `<meta property="og:type" content="article"><meta property="og:url" content="${escapeHtml(`${base}/i/${i.id}`)}">` +
    `<meta property="og:locale" content="${lang === 'gu' ? 'gu_IN' : 'en_IN'}"><meta property="og:site_name" content="${brand}">` +
    (photo ? `<meta property="og:image" content="${escapeHtml(`${base}${photo}`)}">` : '');
  const body =
    (photo ? `<img src="${escapeHtml(photo)}" alt="${escapeHtml(i.title)}">` : '') +
    `<h1>${escapeHtml(i.title)}</h1><p><span class="s">${escapeHtml(status)}</span></p><p>${escapeHtml(ward)} · ${escapeHtml(age)}</p>` +
    (i.description ? `<p>${escapeHtml(i.description)}</p>` : '') +
    `<p>${escapeHtml(t.reported(i.reporterLabel[lang]))} ${escapeHtml(affected)}</p>` +
    `<a class="b" href="${escapeHtml(`${base}/issues/${i.id}`)}">${escapeHtml(t.open)}</a><br>` +
    `<small>${escapeHtml(t.independence)}</small><br>` +
    `<small><a href="?lang=${t.switchTo.href}" lang="${t.switchTo.href}">${escapeHtml(t.switchTo.label)}</a></small>`;
  res.status(200).send(page(lang, `${i.title} · ${brand}`, body, head));
});
