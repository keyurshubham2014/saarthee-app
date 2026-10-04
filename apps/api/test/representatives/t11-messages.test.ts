// T-11-12 inbox (AC-13), T-11-13 inbound webhook (AC-13), T-11-14 redaction of logs (AC-8, AC-13).
import { randomUUID } from 'node:crypto';
import { Writable } from 'node:stream';
import pino from 'pino';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { prisma } from '../../src/lib/db';
import { logger } from '../../src/lib/logger';
import { signInbound, stripQuoted } from '../../src/modules/rep-messages/inbox.service';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { useMemoryPush } from '../auth/helpers';
import { issueInWard } from '../staff/helpers';
import { fixtureWards, makeRep } from './helpers';
import { electionOff, electionOn, evidence, get, post, PREFIX, signed, verifiedRep } from './t11-helpers';

useMemoryPush();
const SECRET = 'test-inbound-secret-123456';
let wards: Map<number, string>;
let rep: Awaited<ReturnType<typeof verifiedRep>>;
let sharer: Awaited<ReturnType<typeof signed>>;
let quiet: Awaited<ReturnType<typeof signed>>;

vi.mock('../../src/config', async (orig) => {
  const real = (await orig()) as { config: Record<string, unknown> };
  return { ...real, config: { ...real.config, MAIL_INBOUND_SECRET: 'test-inbound-secret-123456' } };
});

async function message(repId: string, citizenId: string, sharePhone = false, body = 'BODY-SECRET the drain overflows every night') {
  return prisma.repMessage.create({
    data: { clientMessageId: randomUUID(), representativeId: repId, citizenId, subject: 'Drain overflow', body, sharePhone, status: 'sent', sentAt: new Date(), replyToken: randomUUID().replace(/-/g, '') },
  });
}

beforeEach(async () => {
  await resetDb();
  wards = await fixtureWards();
  rep = await verifiedRep([wards.get(1)!]);
  sharer = await signed('citizen', { homeWardId: wards.get(1), phoneE164: '+919000012345' });
  quiet = await signed('citizen', { homeWardId: wards.get(1), phoneE164: '+919000054321' });
});

const inbound = (payload: object, sig?: string) => {
  const raw = JSON.stringify(payload);
  return api().post(`${PREFIX}/webhooks/mail-inbound`).set('Content-Type', 'application/json').set('X-Saarthee-Signature', sig ?? signInbound(raw, SECRET)).send(raw);
};

describe('inbox (T-11-12)', () => {
  it('own messages only, resident label, phone only when shared, read state, in-app reply', async () => {
    const m1 = await message(rep.rep.id, sharer.user.id, true);
    const m2 = await message(rep.rep.id, quiet.user.id);
    const other = await verifiedRep([wards.get(2)!]);
    const foreign = await message(other.rep.id, quiet.user.id);
    const list = await get(rep.auth, '/staff/rep-messages');
    expect(list.status).toBe(200);
    expect(list.body.unread).toBe(2);
    expect(list.body.items).toHaveLength(2);
    const a = list.body.items.find((i: { id: string }) => i.id === m1.id);
    const b = list.body.items.find((i: { id: string }) => i.id === m2.id);
    expect(a.citizenLabel.en).toBe('A resident of ward 1 ' + (await prisma.ward.findUniqueOrThrow({ where: { id: wards.get(1)! } })).nameEn);
    expect(a.sharedPhone).toBe('+919000012345');
    expect(b).not.toHaveProperty('sharedPhone');
    expect(JSON.stringify(list.body)).not.toContain('+919000054321');
    expect((await get(rep.auth, `/staff/rep-messages/${foreign.id}`)).status).toBe(403);
    const read = await get(rep.auth, `/staff/rep-messages/${m1.id}`);
    expect(read.body).toMatchObject({ id: m1.id, body: m1.body, readByRepAt: expect.any(String) });
    expect((await get(rep.auth, '/staff/rep-messages')).body.unread).toBe(1);
    const reply = await post(rep.auth, `/staff/rep-messages/${m2.id}/reply`, { body: 'We have asked AMC to clean it.' });
    expect(reply.body).toEqual({ status: 'replied', repliedAt: expect.any(String) });
    expect((await post(rep.auth, `/staff/rep-messages/${m2.id}/reply`, { body: 'again' })).status).toBe(409);
    expect((await post(rep.auth, `/staff/rep-messages/${m1.id}/reply`, { body: 'x'.repeat(2001) })).status).toBe(400);
    const mine = await get(quiet.auth, '/me/messages');
    expect(mine.body.items.find((i: { id: string }) => i.id === m2.id)).toMatchObject({ status: 'replied', replyChannel: 'in_app', reply: 'We have asked AMC to clean it.' });
    expect(await prisma.notification.count({ where: { userId: quiet.user.id } })).toBe(1);
    const mod = await signed('moderator');
    expect((await get(mod.auth, '/staff/rep-messages')).status).toBe(403);
  });

  it('in-app reply is frozen in election mode; email reply still tracked', async () => {
    const m = await message(rep.rep.id, quiet.user.id);
    await electionOn([wards.get(1)!]);
    const r = await post(rep.auth, `/staff/rep-messages/${m.id}/reply`, { body: 'Vote for me' });
    expect([r.status, r.body.error.code]).toEqual([409, 'ELECTION_MODE_FROZEN']);
    expect((await inbound({ to: `reply+${m.replyToken}@reply.saarthee.local`, text: 'Thanks, noted.' })).status).toBe(202);
    await electionOff();
  });
});

describe('inbound webhook (T-11-13)', () => {
  it('valid HMAC records an email reply with quotes stripped; bad signature 401; unknown token ignored', async () => {
    const m = await message(rep.rep.id, quiet.user.id);
    const text = 'Work order raised today.\n\nOn Mon, 5 Oct 2026, Saarthee Relay wrote:\n> BODY-SECRET original';
    expect((await inbound({ to: `reply+${m.replyToken}@reply.saarthee.local`, text }, 'f'.repeat(64))).status).toBe(401);
    expect((await prisma.repMessage.findUniqueOrThrow({ where: { id: m.id } })).repliedAt).toBeNull();
    const ok = await inbound({ to: `Office <reply+${m.replyToken}@reply.saarthee.local>`, from: 'office@example.org', text, receivedAt: new Date().toISOString() });
    expect(ok.status).toBe(202);
    expect(await prisma.repMessage.findUniqueOrThrow({ where: { id: m.id } })).toMatchObject({ status: 'replied', replyChannel: 'email', replyBody: 'Work order raised today.' });
    expect((await inbound({ to: `reply+${'0'.repeat(32)}@reply.saarthee.local`, text: 'hello' })).body).toEqual({ status: 'ignored' });
    expect((await inbound({ to: `reply+${m.replyToken}@reply.saarthee.local`, text: 'second' })).body).toEqual({ status: 'ignored' });
    const msgs = await get(quiet.auth, '/me/messages');
    expect(msgs.body.items[0]).toMatchObject({ replyChannel: 'email', reply: 'Work order raised today.' });
    expect(stripQuoted('Yes.\n> old\nmore')).toBe('Yes.');
  });
});

describe('redaction (T-11-14)', () => {
  it('logs during claim, comment, reply, webhook and export contain no phone, note or body', async () => {
    const lines: string[] = [];
    const sink = pino({ level: 'trace' }, new Writable({ write(chunk, _e, cb) { lines.push(String(chunk)); cb(); } }));
    const spies = (['info', 'warn', 'error', 'debug'] as const).map((lvl) => vi.spyOn(logger, lvl).mockImplementation(((...args: unknown[]) => (sink[lvl] as (...a: unknown[]) => void)(...args)) as never));
    try {
      const m = await message(rep.rep.id, sharer.user.id, true);
      const free = await makeRep({ publicPhone: '+917926000001' }, [{ wardId: wards.get(1)! }]);
      await post(sharer.auth, `/representatives/${free.id}/claims`, { evidencePhotoIds: await evidence(sharer.user.id), note: 'NOTE-SECRET claim' });
      const i = await issueInWard(1, { status: 'reported' });
      await post(rep.auth, `/staff/issues/${i.id}/comments`, { note: 'NOTE-SECRET comment' });
      await post(rep.auth, `/staff/rep-messages/${m.id}/reply`, { body: 'REPLY-SECRET text' });
      const m2 = await message(rep.rep.id, quiet.user.id);
      await inbound({ to: `reply+${m2.replyToken}@reply.saarthee.local`, text: 'EMAIL-SECRET text' });
      await get(rep.auth, `/staff/ward-dashboard/export?ward=${wards.get(1)}&from=2026-01-01&to=2026-12-31`);
    } finally {
      spies.forEach((s) => s.mockRestore());
    }
    const all = lines.join('\n');
    expect(lines.length).toBeGreaterThan(0);
    for (const bad of ['NOTE-SECRET', 'BODY-SECRET', 'REPLY-SECRET', 'EMAIL-SECRET', '+919000012345', '9000054321']) expect(all).not.toContain(bad);
  });
});
