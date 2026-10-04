// Fixtures for claims/relay/comments, then P2-03 relay, P2-05 export, P2-08 staff exports, P2-09 claim evidence.
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import path from 'node:path';
import { containsAny, env, phoneForms } from './lib.mjs';
import { PHONES } from './v2-setup.mjs';

export async function prepareClaimsAndRelay(ctx, f) {
  const { request, upload } = ctx;
  const list = await request('GET', `/wards/${f.ward.id}/representatives`);
  const reps = [...(list.data?.corporators ?? []), ...(list.data?.mlas ?? []), ...(list.data?.mps ?? [])];
  f.relayRepId = env.PRIVACY_RELAY_REP_ID || reps.find((r) => r.verified && r.canMessage)?.id;
  // B claims an unverified representative profile with a private evidence photo.
  const ev = await upload('/photos', f.jpeg, { purpose: 'rep_evidence' }, f.b.token);
  f.evidencePhotoId = ev.data?.photoId;
  for (const r of reps.filter((x) => !x.verified).reverse()) {
    const res = await request('POST', `/representatives/${r.id}/claims`, {
      token: f.b.token,
      body: { evidencePhotoIds: [f.evidencePhotoId], note: `Probe claim ${f.run}` },
    });
    if (res.status === 201) {
      f.claimId = res.data.claimId;
      f.claimRepId = r.id;
      break;
    }
  }
  // Relay: A without phone opt-in, B with it, both to the verified representative (seeded rep user's inbox).
  f.subjectA = `Probe relay A ${f.run}`;
  f.subjectB = `Probe relay B ${f.run}`;
  f.bodyA = `Streetlight outside block ${f.run} has been dark for a week, please help.`;
  f.bodyB = `Water logging near lane ${f.run} after every rain, please look into it.`;
  ctx.secrets.set('relayBody:a', f.bodyA);
  ctx.secrets.set('relayBody:b', f.bodyB);
  f.relayA = await request('POST', `/representatives/${f.relayRepId}/messages`, {
    token: f.a.token,
    body: { clientMessageId: randomUUID(), subject: f.subjectA, body: f.bodyA, sharePhone: false },
  });
  f.relayB = await request('POST', `/representatives/${f.relayRepId}/messages`, {
    token: f.b.token,
    body: { clientMessageId: randomUUID(), subject: f.subjectB, body: f.bodyB, sharePhone: true },
  });
  // Representative comment on A's issue (note must never reach the log).
  f.commentNote = `Probe comment ${f.run}: crew scheduled for Tuesday`;
  ctx.secrets.set('comment', f.commentNote);
  f.comment = await request('POST', `/staff/issues/${f.issueId}/comments`, { token: f.rep.token, body: { note: f.commentNote } });
  // CSV formula probe in a reporter-controlled field.
  f.ccrs = await request('POST', `/issues/${f.issueId}/ccrs`, { token: f.a.token, body: { ccrsNumber: '=HYPERLINK("http://x")', filedVia: 'web' } });
}

function mailsContaining(marker) {
  const dir = env.EMAIL_FILE_DIR;
  if (!dir || !existsSync(dir)) return [];
  const out = [];
  const walk = (d) => {
    for (const n of readdirSync(d)) {
      const p = path.join(d, n);
      if (statSync(p).isDirectory()) walk(p);
      else {
        const raw = readFileSync(p, 'utf8');
        // Decode base64 MIME parts so the check sees what the recipient reads.
        const parts = [...raw.matchAll(/Content-Transfer-Encoding: base64\r?\n(?:[^\r\n]+\r?\n)*\r?\n([A-Za-z0-9+/=\r\n]+)/g)];
        const t = raw + parts.map((m) => Buffer.from(m[1].replace(/\s+/g, ''), 'base64').toString('utf8')).join('\n');
        if (t.includes(marker)) out.push(t);
      }
    }
  };
  walk(dir);
  return out;
}

export async function p203(ctx, f, db) {
  const c = ctx.checker('P2-03', 'relay shows the citizen phone only with opt-in');
  c.assert([200, 202].includes(f.relayA.status) && [200, 202].includes(f.relayB.status), `relay status A ${f.relayA.status} B ${f.relayB.status}`);
  const a = phoneForms(PHONES.a);
  const b = phoneForms(PHONES.b);
  const inbox = await ctx.request('GET', '/staff/rep-messages?limit=50', { token: f.rep.token });
  c.assert(inbox.status === 200, `GET /staff/rep-messages status ${inbox.status}`);
  const items = inbox.data?.items ?? [];
  const msgA = items.find((m) => m.subject === f.subjectA);
  const msgB = items.find((m) => m.subject === f.subjectB);
  c.assert(msgA && !containsAny(JSON.stringify(msgA), a), 'inbox: A (no opt-in) shows a phone');
  c.assert(msgB && JSON.stringify(msgB).includes(PHONES.b), 'inbox: B (opt-in) does not show the shared phone');
  c.assert(!containsAny(inbox.text, a), 'inbox contains A phone anywhere');
  const mailA = mailsContaining(f.subjectA);
  const mailB = mailsContaining(f.subjectB);
  if (env.EMAIL_FILE_DIR) {
    c.assert(mailA.length > 0 && mailA.every((t) => !containsAny(t, a)), 'outgoing email A missing or contains A phone');
    c.assert(mailB.length > 0 && mailB.some((t) => t.includes(PHONES.b)), 'outgoing email B (opt-in) lacks the phone');
  } else c.note('EMAIL_FILE_DIR not set — outgoing payload not inspected');
  if (db) {
    const rows = await db.query('SELECT row_to_json(m)::text AS j FROM rep_messages m WHERE subject = ANY($1)', [[f.subjectA, f.subjectB]]);
    c.assert(rows.rows.length === 2, `stored relay rows ${rows.rows.length}`);
    c.assert(rows.rows.every((r) => !containsAny(r.j, [...a, ...b])), 'stored relay row contains a phone');
  }
  return c.done();
}

export async function p205(ctx, f) {
  const c = ctx.checker('P2-05', 'GET /me/export returns only the caller’s data');
  const r = await ctx.request('GET', '/me/export', { token: f.a.token });
  c.assert(r.status === 200, `status ${r.status}`);
  const d = r.data ?? {};
  const sec = d.sections ?? d;
  for (const k of ['profile', 'consents', 'issues', 'issue_verifications', 'rep_messages', 'follows']) c.assert(k in sec, `section ${k} missing`);
  c.assert(JSON.stringify(sec.profile ?? {}).includes(f.a.user.id), 'profile is not the caller');
  c.assert((sec.issues ?? []).length === 1 && sec.issues[0].id === f.issueId, 'issues section is not exactly the caller’s issue');
  c.assert(JSON.stringify(sec.rep_messages ?? []).includes(f.subjectA), 'own relay message missing');
  c.assert((sec.follows ?? []).some((x) => x.issueId === f.issueId), 'own follow missing');
  const other = [...phoneForms(PHONES.b), f.b.user.id, f.b.name, f.subjectB, f.bodyB, f.claimId, f.rep.user?.id, f.mod.user?.id].filter(Boolean);
  c.assert(!containsAny(r.text, other), 'export contains another user’s data');
  c.assert(!containsAny(r.text, [ctx.secrets.get('fcm:a')]), 'export contains the FCM token');
  c.note(`sections: ${Object.keys(sec).join(',')}`);
  return c.done();
}

export async function p208(ctx, f) {
  const c = ctx.checker('P2-08', 'staff CSV exports carry no phone; formula cells escaped');
  const today = new Date();
  const to = new Date(today.getTime() + 86_400_000).toISOString().slice(0, 10);
  const from = new Date(today.getTime() - 86_400_000).toISOString().slice(0, 10);
  const phones = [...phoneForms(PHONES.a), ...phoneForms(PHONES.b)];
  const csvs = {};
  for (const ds of ['issues', 'issue_events', 'verifications']) {
    csvs[`staff/export ${ds}`] = await ctx.request('GET', `/staff/export?dataset=${ds}&from=${from}&to=${to}`, { token: f.admin });
  }
  csvs['ward-dashboard/export'] = await ctx.request('GET', `/staff/ward-dashboard/export?ward=${f.ward.id}&from=${from}&to=${to}`, { token: f.rep.token });
  for (const [name, r] of Object.entries(csvs)) {
    const header = r.text.split(/\r?\n/)[0] ?? '';
    c.assert(r.status === 200, `${name} status ${r.status}`);
    c.assert(!/phone/i.test(header), `${name} has a phone column`);
    c.assert(!containsAny(r.text, phones), `${name} contains test phone digits`);
    c.assert(!/(^|,)"?[=+@]/m.test(r.text.split(/\r?\n/).slice(1).join('\n')), `${name} has an unescaped formula cell`);
  }
  const issues = csvs['staff/export issues'].text;
  if (f.ccrs.status === 200) c.assert(issues.includes(`'=HYPERLINK`), 'CCRS formula probe not escaped with a leading quote');
  else c.note(`CCRS probe not stored (status ${f.ccrs.status})`);
  c.assert(issues.includes(f.issueId), 'test issue missing from the issues export');
  return c.done();
}

export async function p209(ctx, f) {
  const c = ctx.checker('P2-09', 'claim evidence photo is admin-only, no-store');
  c.assert(f.claimId && f.evidencePhotoId, 'no claim with evidence was created');
  const url = `/staff/rep-claims/${f.claimId}/evidence/${f.evidencePhotoId}`;
  const none = await ctx.request('GET', url, { raw: true });
  const mod = await ctx.request('GET', url, { token: f.mod.token, raw: true });
  const rep = await ctx.request('GET', url, { token: f.rep.token, raw: true });
  const adm = await ctx.request('GET', url, { token: f.admin, raw: true });
  const pub = await ctx.request('GET', `/media/photos/${f.evidencePhotoId}`, { raw: true });
  c.assert(none.status === 401, `no token → ${none.status}`);
  c.assert(mod.status === 403, `moderator → ${mod.status}`);
  c.assert(rep.status === 403, `representative → ${rep.status}`);
  c.assert(adm.status === 200 && adm.headers.get('cache-control') === 'no-store', `admin → ${adm.status} cache-control ${adm.headers.get('cache-control')}`);
  c.assert(pub.status !== 200, `public media URL serves the evidence (${pub.status})`);
  return c.done();
}
