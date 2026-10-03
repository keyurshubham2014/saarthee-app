#!/usr/bin/env python3
"""Set coverage-verification.md rows: set-coverage.py <STATUS> "<evidence>" REQ-X-001 [REQ-...]"""
import re, sys
from pathlib import Path
M = Path(__file__).resolve().parent.parent / 'docs/tasks/coverage-verification.md'
status, evidence, ids = sys.argv[1], sys.argv[2].replace('|', '/'), set(sys.argv[3:])
out, hit = [], set()
for line in M.read_text().splitlines():
    m = re.match(r'^\|\s*(REQ-[A-Z]-\d{3})\s*\|', line)
    if m and m.group(1) in ids:
        cells = line.strip().strip('|').split('|')
        cells = [c.strip() for c in cells]
        cells[3], cells[4], cells[5] = status, evidence, '2026-10-03'
        line = '| ' + ' | '.join(cells) + ' |'
        hit.add(m.group(1))
    out.append(line)
M.write_text('\n'.join(out) + '\n')
missing = ids - hit
print(f'updated {len(hit)}' + (f'; missing {sorted(missing)}' if missing else ''))
