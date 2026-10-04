// EmulatorFirebaseGateway against a stub of the Auth Emulator REST API (unsigned alg "none" tokens).
import { createServer, type Server } from 'node:http';
import type { AddressInfo } from 'node:net';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { EmulatorFirebaseGateway, FirebaseTokenError, FirebaseUnavailableError } from '../../src/lib/firebase';

const b64 = (o: unknown) => Buffer.from(JSON.stringify(o)).toString('base64url');
const now = () => Math.floor(Date.now() / 1000);

function emulatorToken(over: Record<string, unknown> = {}) {
  const claims = {
    aud: 'demo-saarthee',
    iss: 'https://securetoken.google.com/demo-saarthee',
    sub: 'emu-uid-1',
    iat: now() - 5,
    auth_time: now() - 5,
    exp: now() + 3600,
    phone_number: '+919000000001',
    firebase: { sign_in_provider: 'phone' },
    ...over,
  };
  return `${b64({ alg: 'none', typ: 'JWT' })}.${b64(claims)}.`;
}

const users: Record<string, { localId: string; disabled?: boolean; validSince?: string }> = {
  'emu-uid-1': { localId: 'emu-uid-1' },
  'emu-disabled': { localId: 'emu-disabled', disabled: true },
};
const deleted: string[] = [];
let server: Server;
let host = '';

beforeAll(async () => {
  server = createServer((req, res) => {
    let raw = '';
    req.on('data', (c) => (raw += c));
    req.on('end', () => {
      const body = JSON.parse(raw || '{}');
      res.setHeader('content-type', 'application/json');
      if (req.headers.authorization !== 'Bearer owner') return res.writeHead(401).end('{}');
      if (req.url?.endsWith('/projects/demo-saarthee/accounts:lookup')) {
        const u = users[body.localId?.[0]];
        return res.end(JSON.stringify(u ? { users: [u] } : {}));
      }
      if (req.url?.endsWith('/projects/demo-saarthee/accounts:delete')) {
        if (!users[body.localId]) return res.writeHead(400).end(JSON.stringify({ error: { message: 'USER_NOT_FOUND' } }));
        deleted.push(body.localId);
        return res.end('{}');
      }
      res.writeHead(404).end('{}');
    });
  });
  await new Promise<void>((r) => server.listen(0, '127.0.0.1', r));
  host = `127.0.0.1:${(server.address() as AddressInfo).port}`;
});
afterAll(() => new Promise<void>((r) => server.close(() => r())));

describe('EmulatorFirebaseGateway', () => {
  it('accepts a valid emulator phone token and rejects bad claims, disabled and revoked users', async () => {
    const gw = new EmulatorFirebaseGateway(host, 'demo-saarthee');
    expect(await gw.verifyIdToken(emulatorToken())).toMatchObject({ uid: 'emu-uid-1', phoneE164: '+919000000001' });
    const codes = async (t: string) => gw.verifyIdToken(t).then(() => 'ok', (e: FirebaseTokenError) => e.code);
    expect(await codes(emulatorToken({ aud: 'other' }))).toBe('wrong-audience');
    expect(await codes(emulatorToken({ exp: now() - 1 }))).toBe('expired');
    expect(await codes(emulatorToken({ firebase: { sign_in_provider: 'anonymous' } }))).toBe('not-phone-provider');
    expect(await codes(emulatorToken({ sub: 'emu-disabled' }))).toBe('user-disabled');
    expect(await codes(emulatorToken({ sub: 'emu-missing' }))).toBe('user-not-found');
    users['emu-uid-1']!.validSince = String(now() + 10);
    expect(await codes(emulatorToken())).toBe('revoked');
    delete users['emu-uid-1']!.validSince;
    expect(await codes('garbage')).toBe('malformed');
  });

  it('deleteUser deletes, treats a missing user as success; unreachable emulator → unavailable', async () => {
    const gw = new EmulatorFirebaseGateway(host, 'demo-saarthee');
    await gw.deleteUser('emu-uid-1');
    await gw.deleteUser('emu-missing');
    expect(deleted).toEqual(['emu-uid-1']);
    const down = new EmulatorFirebaseGateway('127.0.0.1:1', 'demo-saarthee');
    await expect(down.verifyIdToken(emulatorToken({ sub: 'emu-disabled' }))).rejects.toBeInstanceOf(FirebaseUnavailableError);
  });
});
