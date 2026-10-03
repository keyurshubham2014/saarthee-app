export type CsvValue = string | number | boolean | Date | null | undefined | { toString(): string };

/**
 * One CSV cell (06 §3.1): values starting with = + - @ are prefixed with ' (formula injection), then
 * every cell is quoted RFC-4180 style with embedded quotes doubled.
 */
export function csvCell(v: CsvValue): string {
  let s: string;
  if (v === null || v === undefined) s = '';
  else if (v instanceof Date) s = v.toISOString();
  else s = String(v);
  if (/^[=+\-@]/.test(s)) s = `'${s}`;
  return `"${s.replace(/"/g, '""')}"`;
}

export function csvRow(values: CsvValue[]): string {
  return values.map(csvCell).join(',') + '\r\n';
}
