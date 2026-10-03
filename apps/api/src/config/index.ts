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
  PHOTO_STORAGE_DIR: z.string().refine((v) => v.startsWith('/'), 'must be an absolute path'),
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

export type Config = Readonly<z.infer<typeof schema>>;

function load(): Config {
  const parsed = schema.safeParse(process.env);
  if (!parsed.success) {
    // Name + problem only, never the value.
    for (const issue of parsed.error.issues) {
      console.error(`Config error: ${issue.path.join('.')} ${issue.message}`);
    }
    process.exit(1);
  }
  return Object.freeze(parsed.data);
}

export const config: Config = load();
