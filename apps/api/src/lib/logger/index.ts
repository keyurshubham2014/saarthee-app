import pino from 'pino';
import { config } from '../../config';

const SENSITIVE = ['password', 'phone', 'phoneE164', 'note', 'token', 'verifyToken'];

// Wildcard paths cover these keys up to four levels deep; bodies are never logged at all.
const redactPaths = [
  'req.headers.authorization',
  'req.headers["x-verify-token"]',
  'headers.authorization',
  'headers["x-verify-token"]',
  ...SENSITIVE.flatMap((k) => [k, `*.${k}`, `*.*.${k}`, `*.*.*.${k}`]),
];

function destination() {
  if (!config.LOG_FILE_DIR) return undefined;
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
  destination(),
);
