/**
 * Assembly-constituency + ward mapping importer (`npm run constituencies:import -- --file <csv> [--dry-run]`).
 * Columns: ac_number,ac_name_en,ac_name_gu,pc_name_en,pc_name_gu,ward_numbers ("9;10;11"),source_url.
 * Upsert by ac_number; the AC's ward mapping is replaced by the file's list. One transaction; any error aborts.
 */
import { prisma } from '../../lib/db';
import { CONSTITUENCY_HEADER, isHttpsUrl } from './roster.validate';
import { readCsv, type ImportReport, type RowAction, type RowReport } from './roster.import';

interface AcRecord {
  number: number;
  nameEn: string;
  nameGu: string;
  pcNameEn: string;
  pcNameGu: string;
  wardNumbers: number[];
  sourceUrl: string;
}

export async function importConstituencies(text: string, opts: { dryRun: boolean }): Promise<ImportReport> {
  const counts: Record<RowAction, number> = { create: 0, update: 0, unchanged: 0, error: 0 };
  const { rows, headerError } = readCsv(text, CONSTITUENCY_HEADER);
  if (headerError) return { rows: [], counts, committed: false, headerError };
  const wards = await prisma.ward.findMany({ select: { id: true, number: true } });
  const wardId = new Map(wards.map((w) => [w.number, w.id]));
  const existing = await prisma.assemblyConstituency.findMany({ include: { wards: { include: { ward: { select: { number: true } } } } } });
  const byNumber = new Map(existing.map((a) => [a.number, a]));

  const report: RowReport[] = [];
  const valid: AcRecord[] = [];
  const seen = new Set<number>();
  rows.forEach((raw, i) => {
    const v = (k: string) => (raw[k] ?? '').trim();
    const errors: string[] = [];
    const number = Number(v('ac_number'));
    if (!Number.isInteger(number) || number < 1 || number > 400) errors.push('ac_number: must be an ECI constituency number.');
    else if (seen.has(number)) errors.push('ac_number: duplicate row.');
    seen.add(number);
    for (const k of ['ac_name_en', 'ac_name_gu', 'pc_name_en', 'pc_name_gu']) {
      if (v(k).length < 2 || v(k).length > 80) errors.push(`${k}: must be 2–80 characters.`);
    }
    const wardNumbers = v('ward_numbers').split(';').map((s) => s.trim()).filter(Boolean).map(Number);
    if (wardNumbers.length === 0) errors.push('ward_numbers: list at least one ward, like 9;10;11.');
    for (const n of wardNumbers) if (!wardId.has(n)) errors.push(`ward_numbers: ward ${n} is not in the ward list.`);
    if (!isHttpsUrl(v('source_url'))) errors.push('source_url: every row needs an https:// source link.');
    const name = v('ac_name_en');
    if (errors.length) {
      report.push({ row: i + 2, name, action: 'error', errors });
      return;
    }
    const rec: AcRecord = { number, nameEn: name, nameGu: v('ac_name_gu'), pcNameEn: v('pc_name_en'), pcNameGu: v('pc_name_gu'), wardNumbers, sourceUrl: v('source_url') };
    const e = byNumber.get(number);
    const same =
      e && e.nameEn === rec.nameEn && e.nameGu === rec.nameGu && e.pcNameEn === rec.pcNameEn && e.pcNameGu === rec.pcNameGu && e.sourceUrl === rec.sourceUrl &&
      e.wards.map((w) => w.ward.number).sort((a, b) => a - b).join(';') === [...wardNumbers].sort((a, b) => a - b).join(';') &&
      e.wards.every((w) => w.sourceUrl === rec.sourceUrl);
    report.push({ row: i + 2, name, action: !e ? 'create' : same ? 'unchanged' : 'update' });
    valid.push(rec);
  });
  for (const r of report) counts[r.action] += 1;
  if (opts.dryRun || counts.error > 0) return { rows: report, counts, committed: false };

  await prisma.$transaction(async (tx) => {
    for (const r of valid) {
      const data = { nameEn: r.nameEn, nameGu: r.nameGu, pcNameEn: r.pcNameEn, pcNameGu: r.pcNameGu, sourceUrl: r.sourceUrl };
      const ac = await tx.assemblyConstituency.upsert({ where: { number: r.number }, create: { number: r.number, ...data }, update: data });
      await tx.wardConstituency.deleteMany({ where: { assemblyConstituencyId: ac.id } });
      await tx.wardConstituency.createMany({
        data: r.wardNumbers.map((n) => ({ wardId: wardId.get(n)!, assemblyConstituencyId: ac.id, sourceUrl: r.sourceUrl })),
      });
    }
  });
  return { rows: report, counts, committed: true };
}
