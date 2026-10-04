/**
 * Roster CSV importer (`npm run reps:import -- --file <csv> [--dry-run]`, TASK-09 §5.2, REQ-F-045).
 * Header must match exactly (unknown or missing columns are rejected). Every row is validated; the dry run
 * reports create|update|unchanged|error per row and writes nothing; a commit runs in one transaction and
 * aborts (writes nothing) if any row has an error. Upsert key (role, lower(name_en), term_start).
 */
import { parse } from 'csv-parse/sync';
import type { Prisma } from '@prisma/client';
import { prisma } from '../../lib/db';
import { MAX_CORPORATORS_PER_WARD, ROSTER_HEADER, rosterKey, validateRosterRow, type RosterRecord } from './roster.validate';

export type RowAction = 'create' | 'update' | 'unchanged' | 'error';
export interface RowReport {
  row: number;
  name: string;
  action: RowAction;
  errors?: string[];
}
export interface ImportReport {
  rows: RowReport[];
  counts: Record<RowAction, number>;
  committed: boolean;
  headerError?: string;
}

export function readCsv(text: string, header: readonly string[]): { rows: Record<string, string>[]; headerError?: string } {
  const records = parse(text.replace(/^\u{FEFF}/u, ''), { skip_empty_lines: true, relax_column_count: true, trim: false }) as string[][];
  const head = (records[0] ?? []).map((h) => h.trim());
  const unknown = head.filter((h) => !header.includes(h));
  const missing = header.filter((h) => !head.includes(h));
  if (unknown.length || missing.length) {
    return {
      rows: [],
      headerError: [unknown.length ? `unknown columns: ${unknown.join(', ')}` : '', missing.length ? `missing columns: ${missing.join(', ')}` : '']
        .filter(Boolean)
        .join('; '),
    };
  }
  return { rows: records.slice(1).map((cells) => Object.fromEntries(head.map((h, i) => [h, cells[i] ?? '']))) };
}

const dateStr = (d: Date | null) => (d ? d.toISOString().slice(0, 10) : null);

type Existing = Prisma.RepresentativeGetPayload<{ include: { areas: { include: { ward: true; assemblyConstituency: true } } } }>;

function sameAs(e: Existing, r: RosterRecord): boolean {
  const areas = e.areas.map((a) => (a.ward ? `w${a.ward.number}` : `a${a.assemblyConstituency!.number}`)).sort().join(',');
  const want = (r.wardNumber !== null ? [`w${r.wardNumber}`] : r.acNumbers.map((n) => `a${n}`)).sort().join(',');
  return (
    e.nameEn === r.nameEn && e.nameGu === r.nameGu && e.partyText === r.partyText && dateStr(e.termEnd) === dateStr(r.termEnd) &&
    e.publicPhone === r.publicPhone && e.publicEmail === r.publicEmail && e.sourceUrl === r.sourceUrl &&
    dateStr(e.lastVerifiedAt) === dateStr(r.lastVerifiedAt) && e.isActive && areas === want
  );
}

export async function importRoster(text: string, opts: { dryRun: boolean; today?: Date }): Promise<ImportReport> {
  const counts: Record<RowAction, number> = { create: 0, update: 0, unchanged: 0, error: 0 };
  const { rows, headerError } = readCsv(text, ROSTER_HEADER);
  if (headerError) return { rows: [], counts, committed: false, headerError };

  const [wards, acs, existing] = await Promise.all([
    prisma.ward.findMany({ select: { id: true, number: true } }),
    prisma.assemblyConstituency.findMany({ select: { id: true, number: true } }),
    prisma.representative.findMany({ include: { areas: { include: { ward: true, assemblyConstituency: true } } } }),
  ]);
  const wardId = new Map(wards.map((w) => [w.number, w.id]));
  const acId = new Map(acs.map((a) => [a.number, a.id]));
  const byKey = new Map(existing.map((e) => [rosterKey(e), e]));

  const report: RowReport[] = [];
  const valid: { row: number; record: RosterRecord; existing?: Existing }[] = [];
  const seen = new Set<string>();
  rows.forEach((raw, i) => {
    const row = i + 2;
    const name = (raw.name_en ?? '').trim();
    const res = validateRosterRow(raw, opts.today);
    const errors = res.ok ? [] : [...res.errors];
    if (res.ok) {
      const r = res.record;
      if (r.wardNumber !== null && !wardId.has(r.wardNumber)) errors.push(`ward_number: ward ${r.wardNumber} is not in the ward list.`);
      for (const n of r.acNumbers) if (!acId.has(n)) errors.push(`ac_number: constituency ${n} is not imported yet (run constituencies:import first).`);
      const key = rosterKey(r);
      if (seen.has(key)) errors.push('duplicate row for the same person, role and term.');
      seen.add(key);
      if (errors.length === 0) valid.push({ row, record: r, existing: byKey.get(key) });
    }
    report.push(errors.length ? { row, name, action: 'error', errors } : { row, name, action: 'create' });
  });

  // Ward seat cap: active corporators after the import (existing ones not in this file + this file's rows).
  const importedKeys = new Set(valid.map((v) => rosterKey(v.record)));
  const perWard = new Map<number, number>();
  for (const e of existing) {
    if (e.role !== 'corporator' || !e.isActive || importedKeys.has(rosterKey(e))) continue;
    for (const a of e.areas) if (a.ward) perWard.set(a.ward.number, (perWard.get(a.ward.number) ?? 0) + 1);
  }
  for (const v of [...valid]) {
    const n = v.record.wardNumber;
    if (n === null) continue;
    const count = (perWard.get(n) ?? 0) + 1;
    perWard.set(n, count);
    if (count > MAX_CORPORATORS_PER_WARD) {
      const rep = report.find((r) => r.row === v.row)!;
      rep.action = 'error';
      rep.errors = [`ward_number: ward ${n} already has ${MAX_CORPORATORS_PER_WARD} active corporators.`];
      valid.splice(valid.indexOf(v), 1);
    }
  }
  for (const v of valid) {
    const rep = report.find((r) => r.row === v.row)!;
    rep.action = !v.existing ? 'create' : sameAs(v.existing, v.record) ? 'unchanged' : 'update';
  }
  for (const r of report) counts[r.action] += 1;
  if (opts.dryRun || counts.error > 0) return { rows: report, counts, committed: false };

  await prisma.$transaction(async (tx) => {
    for (const v of valid) {
      const r = v.record;
      const rep = report.find((x) => x.row === v.row)!;
      if (rep.action === 'unchanged') continue;
      const data = {
        nameEn: r.nameEn, nameGu: r.nameGu, role: r.role, partyText: r.partyText, termStart: r.termStart, termEnd: r.termEnd,
        publicPhone: r.publicPhone, publicEmail: r.publicEmail, sourceUrl: r.sourceUrl, lastVerifiedAt: r.lastVerifiedAt, isActive: true,
      };
      const saved = v.existing
        ? await tx.representative.update({ where: { id: v.existing.id }, data })
        : await tx.representative.create({ data });
      await tx.representativeArea.deleteMany({ where: { representativeId: saved.id } });
      await tx.representativeArea.createMany({
        data:
          r.wardNumber !== null
            ? [{ representativeId: saved.id, wardId: wardId.get(r.wardNumber)! }]
            : r.acNumbers.map((n) => ({ representativeId: saved.id, assemblyConstituencyId: acId.get(n)! })),
      });
    }
  });
  return { rows: report, counts, committed: true };
}
