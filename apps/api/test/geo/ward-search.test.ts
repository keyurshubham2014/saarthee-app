// T-02-07 (AC-6): ward search normaliser. The SAME table is used by the app's F-02-01 (ward_search_test.dart):
// keep test/fixtures/geo/ward-search-cases.json as the single source for both.
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { parseWardQuery, wardMatches } from '../../src/modules/geo/ward-search';

interface Case {
  query: string;
  expect: number[];
}
const table = JSON.parse(readFileSync(path.resolve(__dirname, '../fixtures/geo/ward-search-cases.json'), 'utf8')) as {
  wards: { number: number; nameEn: string; nameGu: string }[];
  cases: Case[];
};

describe('ward search (shared table with the app)', () => {
  it.each(table.cases)('"$query" → $expect', ({ query, expect: want }) => {
    const q = parseWardQuery(query);
    expect(table.wards.filter((w) => wardMatches(w, q)).map((w) => w.number)).toEqual(want);
  });

  it('parses number queries in ASCII and Gujarati digits, with ward prefixes', () => {
    expect(parseWardQuery('15')).toEqual({ kind: 'number', number: 15 });
    expect(parseWardQuery('૧૫')).toEqual({ kind: 'number', number: 15 });
    expect(parseWardQuery('Ward 15')).toEqual({ kind: 'number', number: 15 });
    expect(parseWardQuery('વોર્ડ ૧૫')).toEqual({ kind: 'number', number: 15 });
    expect(parseWardQuery('ward no. 7')).toEqual({ kind: 'number', number: 7 });
    expect(parseWardQuery('   ')).toEqual({ kind: 'all' });
  });
});
