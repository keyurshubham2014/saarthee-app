/** Shared CLI helpers for the geo:* scripts (V2 TASK-02). */
export { DEFAULT_BOUNDARY_VERSION, GEO_DATA_DIR } from '../../src/lib/geo/ward-data';

/** Value after a `--flag` argument (`--flag value`) or `--flag=value`; undefined when absent. */
export function argValue(flag: string, argv: string[] = process.argv.slice(2)): string | undefined {
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]!;
    if (a === flag) return argv[i + 1];
    if (a.startsWith(`${flag}=`)) return a.slice(flag.length + 1);
  }
  return undefined;
}
