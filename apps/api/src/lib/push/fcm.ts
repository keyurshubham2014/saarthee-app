import type { Message } from 'firebase-admin/messaging';
import { firebaseAdminApp } from '../firebase/google';
import type { PushDriver, PushPayload, SendResult } from './drivers';

const errorCode = (err: unknown) =>
  typeof (err as { code?: unknown })?.code === 'string' ? (err as { code: string }).code : 'messaging/unknown';

/**
 * FCM HTTP v1 through firebase-admin (staging/production). Notification messages (not data-only) so OEM
 * battery managers still show them; high priority for alerts; channelId = our Android channel.
 */
export class FcmPushDriver implements PushDriver {
  readonly name = 'fcm' as const;

  private messaging() {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const { getMessaging } = require('firebase-admin/messaging') as typeof import('firebase-admin/messaging');
    return getMessaging(firebaseAdminApp());
  }

  private base(payload: PushPayload): Omit<Message, 'topic' | 'token' | 'condition'> {
    return {
      notification: { title: payload.title, body: payload.body },
      data: payload.data,
      android: {
        priority: payload.channel === 'updates' ? 'normal' : 'high',
        notification: { channelId: payload.channel },
      },
    };
  }

  async sendToTopic(topic: string, payload: PushPayload): Promise<SendResult> {
    try {
      const messageId = await this.messaging().send({ ...this.base(payload), topic });
      return { ok: true, messageId };
    } catch (err) {
      return { ok: false, errorCode: errorCode(err) };
    }
  }

  async sendToTokens(tokens: string[], payload: PushPayload): Promise<SendResult[]> {
    if (tokens.length === 0) return [];
    try {
      const res = await this.messaging().sendEach(tokens.map((token) => ({ ...this.base(payload), token })));
      return res.responses.map((r) =>
        r.success && r.messageId ? { ok: true, messageId: r.messageId } : { ok: false, errorCode: errorCode(r.error) },
      );
    } catch (err) {
      const code = errorCode(err);
      return tokens.map(() => ({ ok: false, errorCode: code }));
    }
  }
}
