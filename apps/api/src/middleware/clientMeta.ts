import type { Request } from 'express';
import { z } from 'zod';

export type ClientPlatform = 'android' | 'ios';

export interface ClientMeta {
  installId: string | null;
  platform: ClientPlatform | null;
  appVersion: string | null;
}

const installIdSchema = z.uuid();
const platformSchema = z.enum(['android', 'ios']);
const appVersionSchema = z.string().trim().min(1).max(20);

/**
 * Reads the standard citizen headers (03 §2.1): X-Install-Id, X-Platform, X-App-Version.
 * They are informational (events, abuse checks); malformed values become null instead of failing the request.
 */
export function clientMeta(req: Request): ClientMeta {
  const installId = installIdSchema.safeParse(req.header('x-install-id'));
  const platform = platformSchema.safeParse(req.header('x-platform')?.toLowerCase());
  const appVersion = appVersionSchema.safeParse(req.header('x-app-version'));
  return {
    installId: installId.success ? installId.data.toLowerCase() : null,
    platform: platform.success ? platform.data : null,
    appVersion: appVersion.success ? appVersion.data : null,
  };
}
