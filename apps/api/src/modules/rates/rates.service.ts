import type { Prisma } from '@prisma/client';
import { prisma } from '../../lib/db';

export interface RateRow {
  group: string;
  complaints: number;
  reminded: number;
  verified: number;
  h1Rate: number | null;
  notFixed: number;
  h2Rate: number | null;
}

interface ViewRow {
  group: string;
  complaints: number;
  reminded: number;
  verified: number;
  h1_rate: Prisma.Decimal | null;
  verifications: number;
  not_fixed: number;
  h2_rate: Prisma.Decimal | null;
}

const ORDER = ['trusted', 'rwa', 'activist', 'social', 'network', 'unknown'];

/** H1/H2 straight from pilot_rates_v (04 §3.9) — definitions are owned by the view. */
export async function getRates(): Promise<{ rows: RateRow[]; computedAt: string }> {
  const rows = await prisma.$queryRaw<ViewRow[]>`SELECT * FROM pilot_rates_v`;
  const mapped = rows
    .map((r) => ({
      group: r.group,
      complaints: Number(r.complaints),
      reminded: Number(r.reminded),
      verified: Number(r.verified),
      h1Rate: r.h1_rate === null ? null : Number(r.h1_rate),
      notFixed: Number(r.not_fixed),
      h2Rate: r.h2_rate === null ? null : Number(r.h2_rate),
    }))
    .sort((a, b) => ORDER.indexOf(a.group) - ORDER.indexOf(b.group));
  return { rows: mapped, computedAt: new Date().toISOString() };
}
