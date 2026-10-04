import { randomUUID } from 'node:crypto';
import { logger } from '../logger';

export type PushChannel = 'critical_alerts' | 'alerts' | 'updates';

/** One localized message as handed to a driver. */
export interface PushPayload {
  title: string;
  body: string;
  channel: PushChannel;
  data: { kind: string; refId: string; route: string; notificationId: string };
}

export type SendResult = { ok: true; messageId: string } | { ok: false; errorCode: string };

export interface PushDriver {
  readonly name: 'fcm' | 'log' | 'memory';
  sendToTopic(topic: string, payload: PushPayload): Promise<SendResult>;
  /** One result per token, same order. */
  sendToTokens(tokens: string[], payload: PushPayload): Promise<SendResult[]>;
}

/** FCM error codes meaning "this token is dead" → clear devices.fcm_token. */
export const DEAD_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

/** Local default: sends nothing, logs the target type only (never title/body/tokens). */
export class LogPushDriver implements PushDriver {
  readonly name = 'log' as const;

  async sendToTopic(topic: string): Promise<SendResult> {
    logger.debug({ driver: 'log', topic }, 'push (not sent: log driver)');
    return { ok: true, messageId: `log/${randomUUID()}` };
  }

  async sendToTokens(tokens: string[]): Promise<SendResult[]> {
    logger.debug({ driver: 'log', tokenCount: tokens.length }, 'push (not sent: log driver)');
    return tokens.map(() => ({ ok: true, messageId: `log/${randomUUID()}` }));
  }
}

export interface MemorySend {
  topic?: string;
  token?: string;
  payload: PushPayload;
}

/** Tests: records every send in `sent`; tokens/topics listed in `failures` fail with the given code. */
export class MemoryPushDriver implements PushDriver {
  readonly name = 'memory' as const;
  readonly sent: MemorySend[] = [];
  readonly failures = new Map<string, string>();

  async sendToTopic(topic: string, payload: PushPayload): Promise<SendResult> {
    const code = this.failures.get(topic);
    if (code) return { ok: false, errorCode: code };
    this.sent.push({ topic, payload });
    return { ok: true, messageId: `projects/demo/messages/${randomUUID()}` };
  }

  async sendToTokens(tokens: string[], payload: PushPayload): Promise<SendResult[]> {
    return tokens.map((token) => {
      const code = this.failures.get(token);
      if (code) return { ok: false, errorCode: code };
      this.sent.push({ token, payload });
      return { ok: true, messageId: `projects/demo/messages/${randomUUID()}` };
    });
  }
}
