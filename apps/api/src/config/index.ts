import { z } from 'zod';

const bool = z.enum(['true', 'false']).transform((v) => v === 'true');
const int = (min: number) => z.coerce.number().int().min(min);
const optionalEmpty = <T extends z.ZodTypeAny>(schema: T) =>
  z.preprocess((v) => (v === '' || v === undefined ? undefined : v), schema.optional());

const schema = z.object({
  APP_ENV: z.enum(['development', 'production']),
  API_HOST: z.string().min(1),
  API_PORT: int(1).max(65535),
  DATABASE_URL: z.string().regex(/^postgres(ql)?:\/\//, 'must be a postgresql:// URL'),
  JWT_SECRET: z.string().refine((v) => Buffer.byteLength(v, 'utf8') >= 32, 'must be at least 32 bytes'),
  JWT_ISSUER: z.string().min(1),
  JWT_AUDIENCE: z.string().min(1),
  JWT_EXPIRES_IN: z.string().regex(/^\d+[smhd]$/, 'must look like 8h, 30m, 1d'),
  STORAGE_DRIVER: z.enum(['local', 'cloudflare_r2']),
  // Driver-specific requirements are checked in the superRefine below (V2 TASK-13 §5.3).
  PHOTO_STORAGE_DIR: optionalEmpty(z.string().refine((v) => v.startsWith('/'), 'must be an absolute path')),
  R2_ACCOUNT_ID: optionalEmpty(z.string().regex(/^[a-z0-9]{1,64}$/i, 'must be a Cloudflare account id')),
  R2_ACCESS_KEY_ID: optionalEmpty(z.string().min(1)),
  R2_SECRET_ACCESS_KEY: optionalEmpty(z.string().min(1)),
  R2_BUCKET: optionalEmpty(z.string().regex(/^[a-z0-9][a-z0-9-]{1,62}$/, 'must be a bucket name')),
  R2_ENDPOINT: optionalEmpty(z.string().url()),
  DEPLOY_ENV: z.enum(['local', 'staging', 'pilot']).default('local'),
  SENTRY_DSN: optionalEmpty(z.string().url()),
  SENTRY_TRACES_SAMPLE_RATE: z.coerce.number().min(0).max(1).default(0),
  RETENTION_CLOSED_PHOTO_DAYS: int(1).default(730),
  RETENTION_NOTIFICATION_DAYS: int(1).default(90),
  RETENTION_LOG_DAYS: int(1).default(14),
  REOPEN_WINDOW_DAYS: int(0).default(7),
  PHOTO_MAX_UPLOAD_BYTES: int(1),
  PHOTO_MAX_EDGE_PX: int(1),
  UNATTACHED_PHOTO_TTL_HOURS: int(1),
  REMINDER_INTERVAL_DAYS: int(1),
  VERIFY_LINK_BASE: z.string().min(1),
  VERIFY_DISTANCE_WARN_M: optionalEmpty(z.coerce.number().positive()),
  CONSENT_TEXT_VERSIONS: z
    .string()
    .min(1)
    .transform((v) => v.split(',').map((s) => s.trim()).filter(Boolean)),
  // Known reminder template versions (modules/reminders); an unknown version fails startup.
  REMINDER_TEMPLATE_VERSION: z.enum(['v1']),
  CORS_ORIGINS: z
    .string()
    .default('')
    .transform((v) => v.split(',').map((s) => s.trim()).filter(Boolean)),
  TRUST_PROXY: bool,
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace']),
  LOG_FILE_DIR: optionalEmpty(z.string().refine((v) => v.startsWith('/'), 'must be an absolute path')),
  SEED_ADMIN_EMAIL: optionalEmpty(z.string().email()),
  SEED_ADMIN_PASSWORD: optionalEmpty(z.string()),
});

const R2_REQUIRED = ['R2_ACCOUNT_ID', 'R2_ACCESS_KEY_ID', 'R2_SECRET_ACCESS_KEY', 'R2_BUCKET'] as const;

const checked = schema.superRefine((c, ctx) => {
  if (c.STORAGE_DRIVER === 'local' && !c.PHOTO_STORAGE_DIR) {
    ctx.addIssue({ code: 'custom', path: ['PHOTO_STORAGE_DIR'], message: 'is required when STORAGE_DRIVER=local' });
  }
  if (c.STORAGE_DRIVER === 'cloudflare_r2') {
    for (const name of R2_REQUIRED) {
      if (!c[name]) ctx.addIssue({ code: 'custom', path: [name], message: 'is required when STORAGE_DRIVER=cloudflare_r2' });
    }
  }
});

export type Config = Readonly<z.infer<typeof schema>>;

/**
 * Validates an environment. Errors carry the variable name and the problem only, never the value
 * (T-13-03), so they are safe to print at startup.
 */
export function parseConfig(env: NodeJS.ProcessEnv): { ok: true; config: Config } | { ok: false; errors: string[] } {
  const parsed = checked.safeParse(env);
  if (!parsed.success) {
    return { ok: false, errors: parsed.error.issues.map((i) => `Config error: ${i.path.join('.')} ${i.message}`) };
  }
  return { ok: true, config: Object.freeze(parsed.data) };
}

function load(): Config {
  const result = parseConfig(process.env);
  if (!result.ok) {
    for (const line of result.errors) console.error(line);
    process.exit(1);
  }
  return result.config;
}

export const config: Config = load();
