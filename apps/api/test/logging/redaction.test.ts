// T-04-15 (AC-14, REQ-S-015): logs written during sign-in, device registration, push and deletion contain no
// ID token, session token, FCM token, phone digits, OTP or push body text.
import { randomUUID } from 'node:crypto';
import { beforeEach, describe, expect, it } from 'vitest';
import { captureLogs, logger } from '../../src/lib/logger';
import { notifyTopic, notifyUser } from '../../src/lib/push';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { signIn, signInBody, useFakeFirebase, useMemoryPush } from '../auth/helpers';

const gw = useFakeFirebase();
const driver = useMemoryPush();
beforeEach(resetDb);

describe('log redaction', () => {
  it('captured logs contain no token, phone, OTP or body values', async () => {
    const cap = captureLogs();
    const phone = '+919000000077';
    const fcmToken = `fcm-${randomUUID()}-secret`;
    const otp = '493817';
    const bodyText = 'Body text that must never be logged 5521';
    let idToken = '';
    let accessToken = '';
    try {
      const a = await signIn(gw, { phone });
      idToken = a.idToken;
      accessToken = a.token;
      // A rejected token goes down the error path (logged as a code only).
      const bad = gw.issueToken({ uid: 'x', phone, aud: 'other' });
      await api().post('/api/v1/auth/firebase').send(signInBody(bad));
      const installId = randomUUID();
      await api().post('/api/v1/devices').set(a.auth).send({ installId, fcmToken, platform: 'android', appVersion: '2', language: 'gu' });
      driver.failures.set(fcmToken, 'messaging/registration-token-not-registered');
      await notifyUser(a.user.id, { kind: 'system', channel: 'updates', title: { en: 'T', gu: 'T' }, body: { en: bodyText, gu: bodyText } });
      await notifyTopic('city_all', { kind: 'alert', channel: 'alerts', title: { en: 'T', gu: 'T' }, body: { en: bodyText, gu: bodyText } });
      // Direct log calls with sensitive keys at several depths.
      logger.warn({ idToken, accessToken, fcmToken, otp, phoneNumber: phone, req: { body: { code: otp, phone_e164: phone } } }, 'probe');
      logger.warn({ payload: { body: bodyText, message: bodyText, tokens: [fcmToken] } }, 'probe2');
      await api().delete('/api/v1/me').set(a.auth).send({ confirm: 'DELETE' });
    } finally {
      cap.stop();
    }
    const text = cap.lines.join('\n');
    expect(cap.lines.length).toBeGreaterThan(5);
    expect(text).toContain('"probe"');
    for (const secret of [idToken, idToken.split('.')[1]!, accessToken, accessToken.split('.')[2]!, fcmToken, phone, '9000000077', otp, bodyText]) {
      expect(text.split(secret).length - 1, `found ${secret.slice(0, 8)}…`).toBe(0);
    }
    // Error codes still present for diagnosis.
    expect(text).toContain('wrong-audience');
  });
});
