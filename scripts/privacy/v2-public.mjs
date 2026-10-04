// P2-01 public issue views, P2-02 representative views, P2-07 alerts, P2-10 stored photo metadata.
import { apiRequire, containsAny, phoneForms } from './lib.mjs';
import { PHONES } from './v2-setup.mjs';

/** Every object key in a JSON value (recursively). */
function keysOf(v, out = new Set()) {
  if (Array.isArray(v)) v.forEach((x) => keysOf(x, out));
  else if (v && typeof v === 'object') for (const [k, x] of Object.entries(v)) (out.add(k), keysOf(x, out));
  return out;
}

export async function p201(ctx, f) {
  const c = ctx.checker('P2-01', 'public issue views hide the reporter');
  const { request } = ctx;
  const d = 0.01;
  const bbox = `${f.lng0 - d},${f.lat0 - d},${f.lng0 + d},${f.lat0 + d}`;
  const views = {
    'GET /issues': await request('GET', `/issues?ward=${f.ward.id}&limit=50`),
    'GET /issues/{id}': await request('GET', `/issues/${f.issueId}`),
    'GET /feed': await request('GET', `/feed?ward=${f.ward.id}`),
    'GET /map/issues': await request('GET', `/map/issues?bbox=${bbox}&zoom=19`),
    'GET /issues/nearby': await request('GET', `/issues/nearby?lat=${f.lat0}&lng=${f.lng0}&category=roads`),
    'GET /issues/{id}/events': await request('GET', `/issues/${f.issueId}/events`),
  };
  const forbidden = [...phoneForms(PHONES.a), f.a.name, f.a.user?.id].filter(Boolean);
  for (const [name, r] of Object.entries(views)) {
    c.assert(r.status === 200, `${name} status ${r.status}`);
    c.assert(!containsAny(r.text, forbidden), `${name} contains reporter phone/name/id`);
    c.assert(!/reporter_?id/i.test(r.text), `${name} has a reporterId field`);
    // AMC office / published representative numbers are public; any other phone-ish key is not.
    const phoneKeys = [...keysOf(r.data)].filter((k) => /phone/i.test(k) && !/^(office|public)/i.test(k));
    c.assert(phoneKeys.length === 0, `${name} has phone field(s) ${phoneKeys.join(',')}`);
  }
  c.assert(views['GET /issues'].text.includes(f.issueId), 'test issue missing from GET /issues');
  c.assert(views['GET /map/issues'].text.includes(f.issueId), 'test issue missing from GET /map/issues');
  c.assert(views['GET /issues/{id}'].text.includes(`A resident of ${f.ward.nameEn}`), `detail does not say "A resident of ${f.ward.nameEn}"`);
  c.note(`6 views, reporter shown as "A resident of ${f.ward.nameEn}"`);
  return c.done();
}

export async function p202(ctx, f) {
  const c = ctx.checker('P2-02', 'representative views expose only public contact fields');
  const { request } = ctx;
  const list = await request('GET', `/wards/${f.ward.id}/representatives`);
  c.assert(list.status === 200, `ward list status ${list.status}`);
  const ids = [...list.text.matchAll(/"id":"([0-9a-f-]{36})"/g)].map((m) => m[1]);
  const reps = [list];
  for (const id of new Set(ids)) {
    const r = await request('GET', `/representatives/${id}`);
    if (r.status === 200) reps.push(r);
  }
  const forbiddenKeys = /^(userId|user_id|user|claim.*|claimant.*|phoneE164|phone|email|firebaseUid|evidence.*|reviewerId)$/i;
  // publicPhone/publicEmail are the representative's published contacts; officePhone is the AMC ward office line.
  const allowed = /^(public(Phone|Email)|officePhone)$/;
  const forbidden = [...phoneForms(PHONES.b), ...phoneForms(PHONES.representative), f.b.name, f.b.user?.id, f.rep.user?.id].filter(Boolean);
  for (const r of reps) {
    const bad = [...keysOf(r.data)].filter((k) => forbiddenKeys.test(k) || (/phone|email/i.test(k) && !allowed.test(k)));
    c.assert(bad.length === 0, `non-public fields: ${[...new Set(bad)].join(',')}`);
    c.assert(!containsAny(r.text, forbidden), 'linked user / claimant data in a representative view');
  }
  c.assert(f.claimRepId && reps.some((r) => r.text.includes(f.claimRepId)), 'claimed representative not among the checked views');
  c.note(`${reps.length - 1} representative details + ward list`);
  return c.done();
}

export async function p207(ctx, f) {
  const c = ctx.checker('P2-07', 'alerts carry source and validity; warnings have two approvers');
  const { request } = ctx;
  const lists = [await request('GET', `/alerts?wards=${f.ward.id}`), await request('GET', `/alerts?wards=${f.ward.id}&active=false`)];
  for (const l of lists) c.assert(l.status === 200, `GET /alerts status ${l.status}`);
  const items = [...new Map(lists.flatMap((l) => l.data?.items ?? []).map((a) => [a.id, a])).values()];
  const has = (a) => a && a.sourceName && a.sourceUrl && a.validFrom && a.validTo;
  for (const a of items) {
    c.assert(has(a), `list item ${a.id} missing source/validity`);
    const d = await request('GET', `/alerts/${a.id}`);
    c.assert(d.status === 200 && has(d.data?.alert ?? d.data), `detail ${a.id} missing source/validity (status ${d.status})`);
  }
  const staff = await request('GET', '/staff/alerts?status=published&limit=50', { token: f.admin });
  c.assert(staff.status === 200, `GET /staff/alerts status ${staff.status}`);
  let warnings = 0;
  for (const s of staff.data?.items ?? []) {
    if (s.severity !== 'warning' && s.severity !== 'critical') continue;
    warnings += 1;
    const d = await request('GET', `/staff/alerts/${s.id}`, { token: f.admin });
    const approvers = new Set((d.data?.approvals ?? []).map((x) => x.actorId));
    c.assert(approvers.size >= 2, `${s.severity} alert ${s.id} has ${approvers.size} distinct approver(s)`);
  }
  c.assert(items.length > 0, 'no public alerts to check');
  c.note(`${items.length} public alerts, ${warnings} published warning/critical`);
  return c.done();
}

export async function p210(ctx, f) {
  const c = ctx.checker('P2-10', 'stored issue photo has no EXIF/GPS/Make/Model');
  const sharp = apiRequire('sharp');
  c.assert(f.jpeg.includes(Buffer.from('LeakyCamCo')), 'test JPEG lacks EXIF before upload');
  const detail = await ctx.request('GET', `/issues/${f.issueId}`);
  const urls = detail.data?.photos?.report ?? detail.data?.issue?.photos?.report ?? [];
  c.assert(urls.length > 0, 'issue detail lists no report photo URL');
  const origin = new URL(ctx.base).origin;
  for (const u of [...urls, ...urls.map((x) => x.replace(/w=\d+/, 'w=320'))]) {
    const r = await ctx.request('GET', origin + u, { raw: true });
    const meta = await sharp(r.buf).metadata().catch(() => ({}));
    c.assert(r.status === 200, `${u} status ${r.status}`);
    c.assert(!meta.exif && !meta.xmp && !meta.iptc, `${u} has EXIF/XMP/IPTC`);
    c.assert(!containsAny(r.buf.toString('latin1'), ['LeakyCamCo', 'SpyPhone', 'Exif\0\0']), `${u} contains camera/GPS bytes`);
  }
  return c.done();
}
