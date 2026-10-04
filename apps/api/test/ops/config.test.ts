/** T-13-03 (V2 TASK-13 AC-2): driver-specific required variables; errors name the variable, never the value. */
import { describe, expect, it } from 'vitest';
import { parseConfig } from '../../src/config';

const SECRET = 'r2-secret-do-not-print-0123456789';
const JWT = 'jwt-secret-that-is-long-enough-0123456789abcdef';

function base(): NodeJS.ProcessEnv {
  const env: NodeJS.ProcessEnv = { ...process.env };
  for (const k of Object.keys(env)) if (k.startsWith('R2_')) delete env[k];
  return { ...env, JWT_SECRET: JWT };
}

function errorsOf(env: NodeJS.ProcessEnv): string[] {
  const r = parseConfig(env);
  return r.ok ? [] : r.errors;
}

describe('storage configuration validation', () => {
  it('local driver without PHOTO_STORAGE_DIR fails naming the variable', () => {
    const env: NodeJS.ProcessEnv = { ...base(), STORAGE_DRIVER: 'local' };
    delete env.PHOTO_STORAGE_DIR;
    const errors = errorsOf(env);
    expect(errors.join('\n')).toContain('PHOTO_STORAGE_DIR is required when STORAGE_DRIVER=local');
  });

  it('cloudflare_r2 without R2_BUCKET fails naming R2_BUCKET and printing no secret', () => {
    const env: NodeJS.ProcessEnv = {
      ...base(),
      STORAGE_DRIVER: 'cloudflare_r2',
      R2_ACCOUNT_ID: 'abc123',
      R2_ACCESS_KEY_ID: 'AKIAEXAMPLE',
      R2_SECRET_ACCESS_KEY: SECRET,
    };
    const text = errorsOf(env).join('\n');
    expect(text).toContain('R2_BUCKET is required when STORAGE_DRIVER=cloudflare_r2');
    expect(text).not.toContain(SECRET);
    expect(text).not.toContain('AKIAEXAMPLE');
    expect(text).not.toContain(JWT);
  });

  it('cloudflare_r2 with every R2 variable is valid without PHOTO_STORAGE_DIR', () => {
    const env: NodeJS.ProcessEnv = {
      ...base(),
      STORAGE_DRIVER: 'cloudflare_r2',
      R2_ACCOUNT_ID: 'abc123',
      R2_ACCESS_KEY_ID: 'AKIAEXAMPLE',
      R2_SECRET_ACCESS_KEY: SECRET,
      R2_BUCKET: 'saarthee-staging-photos',
    };
    delete env.PHOTO_STORAGE_DIR;
    const r = parseConfig(env);
    expect(r.ok).toBe(true);
    if (r.ok) {
      expect(r.config.DEPLOY_ENV).toBe('local');
      expect(r.config.RETENTION_CLOSED_PHOTO_DAYS).toBe(730);
      expect(r.config.RETENTION_NOTIFICATION_DAYS).toBe(90);
      expect(r.config.RETENTION_LOG_DAYS).toBe(14);
    }
  });

  it('an invalid value is reported by name only', () => {
    const env = { ...base(), JWT_SECRET: 'short-secret-value-xyz' };
    const text = errorsOf(env).join('\n');
    expect(text).toContain('JWT_SECRET');
    expect(text).not.toContain('short-secret-value-xyz');
  });
});
