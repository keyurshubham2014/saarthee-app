import pino from 'pino';
import { config } from '../../config';

const SENSITIVE = [
  'password',
  'phone',
  'phoneE164',
  'note',
  'token',
  'verifyToken',
  // v2 TASK-04 (REQ-S-015): Firebase / session / FCM tokens, OTPs, phone numbers and message bodies.
  'idToken',
  'accessToken',
  'refreshToken',
  'fcmToken',
  'fcm_token',
  'otp',
  'smsCode',
  'verificationId',
  'body',
  'body_en',
  'body_gu',
  'bodyEn',
  'bodyGu',
  'message',
  'phone_e164',
  'phoneNumber',
  'phone_number',
  'tokens',
];

// `code` is an OTP only inside request/notification payloads; at the top level it is our error code
// (`{code}` lines from the error handler and the Firebase gateway), so it is redacted by path (TASK-04 §5.6).
const PAYLOAD_CODE_PATHS = ['req.body.code', 'body.code', 'payload.code', 'data.code', '*.payload.code', '*.data.code'];

// Wildcard paths cover these keys up to four levels deep; bodies are never logged at all.
const redactPaths = [
  'req.headers.authorization',
  'req.headers["x-verify-token"]',
  'req.headers["x-firebase-token"]',
  'headers.authorization',
  'headers["x-verify-token"]',
  'headers["x-firebase-token"]',
  ...PAYLOAD_CODE_PATHS,
  ...SENSITIVE.flatMap((k) => [k, `*.${k}`, `*.*.${k}`, `*.*.*.${k}`]),
];

function baseDestination(): pino.DestinationStream {
  if (!config.LOG_FILE_DIR) return pino.destination(1);
  return pino.transport({
    targets: [
      { target: 'pino/file', options: { destination: 1 } },
      {
        target: 'pino-roll',
        options: { file: `${config.LOG_FILE_DIR}/api`, frequency: 'daily', limit: { count: 14 }, mkdir: true },
      },
    ],
  });
}

export const logger = pino(
  {
    level: config.LOG_LEVEL,
    redact: { paths: redactPaths, remove: true },
    base: { service: 'saarthee-api' },
    timestamp: pino.stdTimeFunctions.isoTime,
  },
  tapped(baseDestination()),
);

type LogTap = (line: string) => void;
const taps = new Set<LogTap>();

/** Wraps the destination so tests can observe the exact (already redacted) lines written. */
function tapped(dest: pino.DestinationStream): pino.DestinationStream {
  return {
    write(line: string) {
      for (const tap of taps) tap(line);
      dest.write(line);
    },
  };
}

/** Tests only (redaction test T-04-15): records every log line until the returned function is called. */
export function captureLogs(): { lines: string[]; stop: () => void } {
  const lines: string[] = [];
  const tap: LogTap = (line) => lines.push(line);
  taps.add(tap);
  return { lines, stop: () => taps.delete(tap) };
}
