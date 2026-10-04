import { readdirSync } from 'node:fs';
import path from 'node:path';
import type { PrismaClient } from '@prisma/client';
import type { SeedContext, SeedModule } from './types';

const MODULE_FILE = /^\d{3}-[a-z0-9-]+\.ts$/;

/** Seed modules in run order: every `modules/NNN-name.ts`, sorted by file name. */
export async function loadSeedModules(dir = path.join(__dirname, 'modules')): Promise<SeedModule[]> {
  const files = readdirSync(dir).filter((f) => MODULE_FILE.test(f)).sort();
  const modules: SeedModule[] = [];
  for (const f of files) {
    const mod = (await import(path.join(dir, f))) as { default?: SeedModule | { default?: SeedModule } };
    // tsx (CJS) and Vitest (ESM) wrap default exports differently.
    const m = (mod.default && 'run' in mod.default ? mod.default : (mod.default as { default?: SeedModule })?.default) as
      | SeedModule
      | undefined;
    if (!m || typeof m.run !== 'function') throw new Error(`Seed module ${f} has no default export`);
    modules.push(m);
  }
  return modules;
}

async function missingTables(prisma: PrismaClient, tables: string[]): Promise<string[]> {
  const missing: string[] = [];
  for (const t of tables) {
    const rows = await prisma.$queryRaw<{ ok: boolean }[]>`SELECT to_regclass(${`public.${t}`}) IS NOT NULL AS ok`;
    if (!rows[0]?.ok) missing.push(t);
  }
  return missing;
}

/** Runs every registered module in order; returns the names of modules that ran and were skipped. */
export async function runSeed(ctx: SeedContext): Promise<{ ran: string[]; skipped: string[] }> {
  const ran: string[] = [];
  const skipped: string[] = [];
  for (const m of await loadSeedModules()) {
    const missing = await missingTables(ctx.prisma, m.requires);
    if (missing.length > 0) {
      ctx.log(`Seed ${m.name}: skipped (requires ${missing.join(', ')})`);
      skipped.push(m.name);
      continue;
    }
    await m.run(ctx);
    ctx.log(`Seed ${m.name}: done`);
    ran.push(m.name);
  }
  return { ran, skipped };
}
