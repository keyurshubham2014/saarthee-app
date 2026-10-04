/**
 * Outbound email (V2 TASK-09 §6 step 8). One interface, three drivers:
 * - `ses`    Amazon SES v2 (SES_REGION, default ap-south-1) — staging/pilot;
 * - `file`   writes an .eml file to EMAIL_FILE_DIR (outside the repo) — local dev;
 * - `memory` keeps messages in memory with optional failure injection — tests only.
 * Callers never log addresses, subjects or bodies; only the tag and provider message id.
 */
import { randomUUID } from 'node:crypto';
import { mkdir, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { config } from '../../config';

export interface MailMessage {
  from: string;
  to: string;
  replyTo?: string;
  subject: string;
  text: string;
  html: string;
  /** Non-personal category for logs and provider tags, e.g. `relay`. */
  tag: string;
}

export interface MailDriver {
  readonly name: string;
  send(msg: MailMessage): Promise<{ providerMessageId: string }>;
}

function encodeHeader(v: string): string {
  // RFC 2047 for non-ASCII header values (Gujarati names and subjects).
  return /^[\x20-\x7e]*$/.test(v) ? v : `=?UTF-8?B?${Buffer.from(v, 'utf8').toString('base64')}?=`;
}

/** Builds a multipart/alternative MIME message (text + HTML, base64 bodies). */
export function toEml(msg: MailMessage, id: string): string {
  const boundary = `b-${id}`;
  const b64 = (s: string) => Buffer.from(s, 'utf8').toString('base64').replace(/(.{76})/g, '$1\r\n');
  return [
    `Message-ID: <${id}@saarthee.local>`,
    `From: ${encodeHeader(msg.from)}`,
    `To: ${msg.to}`,
    ...(msg.replyTo ? [`Reply-To: ${msg.replyTo}`] : []),
    `Subject: ${encodeHeader(msg.subject)}`,
    `X-Saarthee-Tag: ${msg.tag}`,
    'MIME-Version: 1.0',
    `Content-Type: multipart/alternative; boundary="${boundary}"`,
    '',
    `--${boundary}`,
    'Content-Type: text/plain; charset=UTF-8',
    'Content-Transfer-Encoding: base64',
    '',
    b64(msg.text),
    `--${boundary}`,
    'Content-Type: text/html; charset=UTF-8',
    'Content-Transfer-Encoding: base64',
    '',
    b64(msg.html),
    `--${boundary}--`,
    '',
  ].join('\r\n');
}

export class FileMailDriver implements MailDriver {
  readonly name = 'file';
  constructor(private readonly dir: string) {}
  async send(msg: MailMessage) {
    const id = randomUUID();
    await mkdir(this.dir, { recursive: true });
    await writeFile(path.join(this.dir, `${new Date().toISOString().replace(/[:.]/g, '-')}-${id}.eml`), toEml(msg, id), 'utf8');
    return { providerMessageId: `file-${id}` };
  }
}

export class MemoryMailDriver implements MailDriver {
  readonly name = 'memory';
  readonly sent: MailMessage[] = [];
  /** Number of upcoming sends that throw (failure injection for retry tests). */
  failNext = 0;
  async send(msg: MailMessage) {
    if (this.failNext > 0) {
      this.failNext -= 1;
      throw Object.assign(new Error('injected mail failure'), { code: 'MAIL_TEST_FAILURE' });
    }
    this.sent.push(msg);
    return { providerMessageId: `mem-${randomUUID()}` };
  }
  reset() {
    this.sent.length = 0;
    this.failNext = 0;
  }
}

export class SesMailDriver implements MailDriver {
  readonly name = 'ses';
  async send(msg: MailMessage) {
    const { SESv2Client, SendEmailCommand } = await import('@aws-sdk/client-sesv2');
    const client = new SESv2Client({ region: config.SES_REGION });
    const out = await client.send(
      new SendEmailCommand({
        FromEmailAddress: msg.from,
        Destination: { ToAddresses: [msg.to] },
        ReplyToAddresses: msg.replyTo ? [msg.replyTo] : undefined,
        Content: {
          Simple: {
            Subject: { Data: msg.subject, Charset: 'UTF-8' },
            Body: { Text: { Data: msg.text, Charset: 'UTF-8' }, Html: { Data: msg.html, Charset: 'UTF-8' } },
          },
        },
        EmailTags: [{ Name: 'tag', Value: msg.tag }],
      }),
    );
    return { providerMessageId: out.MessageId ?? `ses-${randomUUID()}` };
  }
}

let driver: MailDriver | undefined;

export function mailDriver(): MailDriver {
  if (!driver) {
    if (config.EMAIL_DRIVER === 'ses') driver = new SesMailDriver();
    else if (config.EMAIL_DRIVER === 'memory') driver = new MemoryMailDriver();
    else driver = new FileMailDriver(config.EMAIL_FILE_DIR ?? path.join(os.tmpdir(), 'saarthee-mail'));
  }
  return driver;
}

/** Tests only: swap the driver (e.g. a MemoryMailDriver). */
export function setMailDriver(d: MailDriver | undefined): void {
  driver = d;
}

export function sendMail(msg: MailMessage) {
  return mailDriver().send(msg);
}
