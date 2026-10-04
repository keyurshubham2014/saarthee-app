import type { Prisma } from '@prisma/client';

/**
 * Export / erasure registries (TASK-04 §5.2). Each task that stores personal data registers one export
 * section and, if needed, one erasure step at import time, e.g. TASK-09:
 *   registerExportSection('rep_messages', (userId, tx) => tx.repMessage.findMany({ where: { userId } }));
 *   registerErasureStep('rep_messages', async (userId, tx) => { await tx.repMessage.deleteMany(...) });
 * Erasure steps run inside the DELETE /me transaction (a throw rolls everything back); photo ids added to
 * ctx.photoIds are deleted from storage after the commit.
 */
export interface ErasureContext {
  /** Photo ids whose files are deleted (and photos.deleted_at set) after the transaction commits. */
  photoIds: Set<string>;
}

export type ExportSection = (userId: string, tx: Prisma.TransactionClient) => Promise<unknown>;
export type ErasureStep = (userId: string, tx: Prisma.TransactionClient, ctx: ErasureContext) => Promise<void>;

const exportSections = new Map<string, ExportSection>();
const erasureSteps = new Map<string, ErasureStep>();

const NAME = /^[a-z][a-z0-9_]{1,40}$/;

export function registerExportSection(name: string, fn: ExportSection): void {
  if (!NAME.test(name)) throw new Error(`invalid export section name: ${name}`);
  if (exportSections.has(name)) throw new Error(`export section already registered: ${name}`);
  exportSections.set(name, fn);
}

export function registerErasureStep(name: string, fn: ErasureStep): void {
  if (!NAME.test(name)) throw new Error(`invalid erasure step name: ${name}`);
  if (erasureSteps.has(name)) throw new Error(`erasure step already registered: ${name}`);
  erasureSteps.set(name, fn);
}

/** Tests only: removes a registration made by a test. */
export function unregisterErasureStep(name: string): void {
  erasureSteps.delete(name);
}

export function listExportSections(): [string, ExportSection][] {
  return [...exportSections.entries()];
}

export function listErasureSteps(): [string, ErasureStep][] {
  return [...erasureSteps.entries()];
}
